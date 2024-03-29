# This file is part of RedLibSSH2.
# Copyright (C) 2017 Panos Kittenis
# Copyright (C) 2022 Red-M

# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation, version 2.1.

# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

import time
import threading
import select as pyselect
from . import error_codes
from cpython cimport PyObject_AsFileDescriptor
from libc.stdlib cimport malloc, free
from libc.time cimport time_t
from cython.operator cimport dereference as c_dereference
from libc.string cimport strlen, strdup


from .agent cimport PyAgent, agent_auth, agent_init, init_connect_agent
from .channel cimport PyChannel
from .exceptions import SessionHostKeyError, KnownHostError, PublicKeyInitError, ChannelError
from .listener cimport PyListener
from .sftp cimport PySFTP
from .publickey cimport PyPublicKeySystem
from .utils cimport to_bytes, to_str, handle_error_codes
from .statinfo cimport StatInfo
from .knownhost cimport PyKnownHost
from .fileinfo cimport FileInfo


from . cimport c_ssh2
from . cimport c_sftp
from . cimport c_pkey
from . cimport utils


LIBSSH2_SESSION_BLOCK_INBOUND = c_ssh2.LIBSSH2_SESSION_BLOCK_INBOUND
LIBSSH2_SESSION_BLOCK_OUTBOUND = c_ssh2.LIBSSH2_SESSION_BLOCK_OUTBOUND
LIBSSH2_HOSTKEY_HASH_MD5 = c_ssh2.LIBSSH2_HOSTKEY_HASH_MD5
LIBSSH2_HOSTKEY_HASH_SHA1 = c_ssh2.LIBSSH2_HOSTKEY_HASH_SHA1
LIBSSH2_HOSTKEY_TYPE_UNKNOWN = c_ssh2.LIBSSH2_HOSTKEY_TYPE_UNKNOWN
LIBSSH2_HOSTKEY_TYPE_RSA = c_ssh2.LIBSSH2_HOSTKEY_TYPE_RSA
LIBSSH2_HOSTKEY_TYPE_DSS = c_ssh2.LIBSSH2_HOSTKEY_TYPE_DSS

LIBSSH2_CALLBACK_RECV = c_ssh2.LIBSSH2_CALLBACK_RECV
LIBSSH2_CALLBACK_SEND = c_ssh2.LIBSSH2_CALLBACK_SEND
LIBSSH2_CALLBACK_X11 = c_ssh2.LIBSSH2_CALLBACK_X11

LIBSSH2_METHOD_KEX = c_ssh2.LIBSSH2_METHOD_KEX
LIBSSH2_METHOD_HOSTKEY = c_ssh2.LIBSSH2_METHOD_HOSTKEY
LIBSSH2_METHOD_CRYPT_CS = c_ssh2.LIBSSH2_METHOD_CRYPT_CS
LIBSSH2_METHOD_CRYPT_SC = c_ssh2.LIBSSH2_METHOD_CRYPT_SC
LIBSSH2_METHOD_MAC_CS = c_ssh2.LIBSSH2_METHOD_MAC_CS
LIBSSH2_METHOD_MAC_SC = c_ssh2.LIBSSH2_METHOD_MAC_SC
LIBSSH2_METHOD_COMP_CS = c_ssh2.LIBSSH2_METHOD_COMP_CS
LIBSSH2_METHOD_COMP_SC = c_ssh2.LIBSSH2_METHOD_COMP_SC
LIBSSH2_METHOD_LANG_CS = c_ssh2.LIBSSH2_METHOD_LANG_CS
LIBSSH2_METHOD_LANG_SC = c_ssh2.LIBSSH2_METHOD_LANG_SC

LIBSSH2_FLAG_SIGPIPE = c_ssh2.LIBSSH2_FLAG_SIGPIPE
LIBSSH2_FLAG_COMPRESS = c_ssh2.LIBSSH2_FLAG_COMPRESS


cdef void kbd_callback(const char *name, int name_len, const char *instruction, int instruction_len, int num_prompts,
                       const c_ssh2.LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts, c_ssh2.LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses,
                       void **abstract) except *:
    py_sess = (<Session>c_dereference(abstract))
    callback = py_sess.get_callback('kbd')
    if callback is None:
        return
    py_sess._block_lock.acquire()
    cdef bytes b_password = to_bytes(callback())
    cdef char *_password = b_password
    if num_prompts==1:
        responses[0].text = strdup(_password)
        responses[0].length = strlen(_password)
    py_sess._block_lock.release()

cdef class Session:

    """LibSSH2 Session class providing session functions"""

    def __cinit__(self, socket=None):
        self._session = c_ssh2.libssh2_session_init_ex(NULL, NULL, NULL, <void*> self)
        if self._session is NULL:
            raise MemoryError
        if socket is not None:
            self._sock = PyObject_AsFileDescriptor(socket)
            self.sock = socket
        else:
            self._sock = 0
            self.sock = None
        self._callbacks = {}
        self._block_lock = threading.RLock()
        IF HAVE_POLL==1:
            self.c_poll_enabled = True
        ELSE:
            self.c_poll_enabled = False
        self.c_poll_use = True
        self._default_waitsockets = []
        self._waitsockets = []

    def __dealloc__(self):
        if self._session is not NULL:
            c_ssh2.libssh2_session_free(self._session)
        self._session = NULL

    def callback(self,key):
        return(self._callbacks.get(key,None))

    cdef void _build_c_waitsocket_data(Session self) nogil:
        self._c_waitsockets[0].fd = self._sock
        self._c_waitsockets[0].events = 0
        self._c_waitsockets[0].revents = 0

    def _build_waitsocket_data(self):
        self._waitsockets = [self.sock]

    IF HAVE_POLL==1:
        cdef int poll_socket(Session self,int block_dir,int timeout) nogil:
            cdef int rc

            with nogil:
                if(block_dir & c_ssh2.LIBSSH2_SESSION_BLOCK_INBOUND):
                    self._c_waitsockets[0].events |= utils.POLLIN

                if(block_dir & c_ssh2.LIBSSH2_SESSION_BLOCK_OUTBOUND):
                    self._c_waitsockets[0].events |= utils.POLLOUT

                rc = utils.poll(self._c_waitsockets, 1, timeout)
                self._c_waitsockets[0].events = 0
            return rc

    def check_c_poll_enabled(self):
        with self._block_lock:
            return(self.c_poll_enabled==True and self.c_poll_use==True)

    def _block_call(self,_select_timeout=None):
        if _select_timeout==None:
            _select_timeout = 0.005
        with self._block_lock:
            self.keepalive_send()
            block_direction = self.block_directions()
        if block_direction==0:
            time.sleep(0.1)
            return(None)

        if self.check_c_poll_enabled()==True:
            with self._block_lock:
                return(self.poll_socket(block_direction,_select_timeout*1000))
        else:
            rfds = self._default_waitsockets
            wfds = self._default_waitsockets
            if block_direction & c_ssh2.LIBSSH2_SESSION_BLOCK_INBOUND:
                rfds = self._waitsockets

            if block_direction & c_ssh2.LIBSSH2_SESSION_BLOCK_OUTBOUND:
                wfds = self._waitsockets

            return(pyselect.select(rfds,wfds,self._default_waitsockets,_select_timeout))

    def trace(self, int bitmask):
        """Enable trace logging for this session.
        Bitmask is one or more of `ssh2.enum.Trace.*`.
        """
        c_ssh2.libssh2_trace(self._session, bitmask)

    def disconnect(self):
        cdef int rc
        with nogil:
            rc = c_ssh2.libssh2_session_disconnect(self._session, b"end")
        return handle_error_codes(rc)

    def method_pref(self, method_type, pref_methods):
        """Set internal perferences based on ``method_type`` to
        ``pref_methods``.

        Valid ``method_type`` options are:

        - ``LIBSSH2_METHOD_KEX``
            For key exchange.

        - ``LIBSSH2_METHOD_HOSTKEY``
            For selecting host key type.

        - ``LIBSSH2_METHOD_CRYPT_CS``
            Encryption between client to server

        - ``LIBSSH2_METHOD_CRYPT_SC``
            Encryption between server to client

        - ``LIBSSH2_METHOD_MAC_CS``
            MAC between client to server

        - ``LIBSSH2_METHOD_MAC_SC``
            MAC between server to client

        - ``LIBSSH2_METHOD_COMP_CS``
            Compression between client to server

        - ``LIBSSH2_METHOD_COMP_SC``
            Compression between server to client

        - ``LIBSSH2_METHOD_LANG_CS``
            Language between client to server

        - ``LIBSSH2_METHOD_LANG_SC``
            Language between server to client


        Valid options that end in ``CS`` are from the client to the server and
        the inverse is true as well.

        Valid ``pref_methods`` options are dependant on the ``method_type``
        selected. Refer to the libssh2 docs

        Must be called before ``self.handshake()`` if you wish to change
        the defaults.

        Return 0 on success or negative on failure.
        It returns ``ssh2.error_codes.LIBSSH2_ERROR_EAGAIN`` when it would
        otherwise block.
        While ``ssh2.error_codes.LIBSSH2_ERROR_EAGAIN`` is a negative number,
        it isn't
        really a failure per se.

        :raises: :py:class:`ssh2.exceptions.MethodNotSupported` on an incorrect
          ``method_type`` or ``pref_methods`` argument(s).
        :param method_type: Method perference to change.
        :type method_type: ``ssh2.session.LIBSSH2_METHOD_*``
        :param pref_methods: Coma delimited list as a bytes string of preferred
        methods to use with the most preferred listed first and the least
        preferred listed last.
        If a method is listed which is not supported by libssh2 it will be
        ignored and not sent to the remote host during protocol negotiation.
        :type pref_methods: bytes
        :rtype: ``int``
        """
        if (int(method_type)<1 and int(method_type)>10) or self._sock!=0:
            return handle_error_codes(error_codes.LIBSSH2_ERROR_METHOD_NOT_SUPPORTED)
        cdef int rc
        cdef int _method_type = int(method_type)
        cdef bytes b_pref_methods = to_bytes(pref_methods)
        cdef char *_pref_methods = b_pref_methods
        with nogil:
            rc = c_ssh2.libssh2_session_method_pref(self._session,_method_type, _pref_methods)
        return handle_error_codes(rc)

    def methods(self, method_type):
        """Get internal perferences used to negotiate based on ``method_type``.

        Valid ``method_type`` options are:

        - ``LIBSSH2_METHOD_KEX``
            For key exchange.

        - ``LIBSSH2_METHOD_HOSTKEY``
            For selecting host key type.

        - ``LIBSSH2_METHOD_CRYPT_CS``
            Encryption between client to server

        - ``LIBSSH2_METHOD_CRYPT_SC``
            Encryption between server to client

        - ``LIBSSH2_METHOD_MAC_CS``
            MAC between client to server

        - ``LIBSSH2_METHOD_MAC_SC``
            MAC between server to client

        - ``LIBSSH2_METHOD_COMP_CS``
            Compression between client to server

        - ``LIBSSH2_METHOD_COMP_SC``
            Compression between server to client

        - ``LIBSSH2_METHOD_LANG_CS``
            Language between client to server

        - ``LIBSSH2_METHOD_LANG_SC``
            Language between server to client


        Valid options that end in ``CS`` are from the client to the server and
        the inverse is true as well.

        :raises: :py:class:`ssh2.exceptions.MethodNotSupported` on an incorrect
          ``method_type`` argument.
        :param method_type: Method type.
        :type method_type: ``ssh2.session.LIBSSH2_METHOD_*``
        :rtype: ``bytes``
        """
        if (int(method_type)<1 and int(method_type)>10) or self._sock==0:
            return handle_error_codes(error_codes.LIBSSH2_ERROR_METHOD_NOT_SUPPORTED)
        cdef const char *ret
        cdef int _method_type = int(method_type)
        with nogil:
            ret = c_ssh2.libssh2_session_methods(self._session, _method_type)
        return ret

    def supported_algs(self, method_type, algs):
        """Get the supported internal perferences based on ``method_type`` and
        ``algs``.

        Valid ``method_type`` options are:

        - ``LIBSSH2_METHOD_KEX``
            For key exchange.

        - ``LIBSSH2_METHOD_HOSTKEY``
            For selecting host key type.

        - ``LIBSSH2_METHOD_CRYPT_CS``
            Encryption between client to server

        - ``LIBSSH2_METHOD_CRYPT_SC``
            Encryption between server to client

        - ``LIBSSH2_METHOD_MAC_CS``
            MAC between client to server

        - ``LIBSSH2_METHOD_MAC_SC``
            MAC between server to client

        - ``LIBSSH2_METHOD_COMP_CS``
            Compression between client to server

        - ``LIBSSH2_METHOD_COMP_SC``
            Compression between server to client

        - ``LIBSSH2_METHOD_LANG_CS``
            Language between client to server

        - ``LIBSSH2_METHOD_LANG_SC``
            Language between server to client


        :raises: :py:class:`ssh2.exceptions.MethodNotSupported` on an incorrect
          ``method_type`` or ``algs`` argument(s).
        :param method_type: Method type.
        :type method_type: ``ssh2.session.LIBSSH2_METHOD_*``
        :param algs: Coma delimited list as a bytes string.
        :type algs: ``bytes str``
        :rtype: ``array``
        """
        if (int(method_type)<1 and int(method_type)>10) or isinstance(algs, type(b'')) is False:
            return handle_error_codes(error_codes.LIBSSH2_ERROR_METHOD_NOT_SUPPORTED)
        out = []
        # algs = to_bytes(algs)
        algs = algs.split(b',')
        cdef int i, j = 0
        cdef int rc
        cdef int _method_type = int(method_type)
        cdef const char **_algs = <const char**> malloc(len(algs) * sizeof(char*))
        for item in algs:
            _algs[j] = item
            j+=1

        with nogil:
            rc = c_ssh2.libssh2_session_supported_algs(self._session, _method_type, &_algs)

        if rc>0:
            while i<rc:
                out.append(algs[i])
                i+=1
            with nogil:
                c_ssh2.libssh2_free(self._session, _algs)
            return out
        else:
            return handle_error_codes(rc)

    def flag(self, set_flag, value):
        """Set options for the session.

        ``set_flag`` is the option to set, while ``value`` is typically set to
        ``1`` or ``0`` to enable or disable the option.

        Valid flags are:

        - ``ssh2.session.LIBSSH2_FLAG_SIGPIPE``
            If set, libssh2 will not attempt to block SIGPIPEs but will let them
            trigger from the underlying socket layer.
        - ``ssh2.session.LIBSSH2_FLAG_COMPRESS``
            If set - before the connection negotiation is performed -
            libssh2 will try to negotiate compression enabling for this
            connection. By default libssh2 will not attempt to use compression.

        Must be called before ``self.handshake()`` if you wish to change
        options.


        :raises: :py:class:`ssh2.exceptions.MethodNotSupported` on an incorrect
          ``flag`` or ``value`` argument(s).
        :param set_flag: Flag to set. See above for options.
        :type set_flag: ``ssh2.session.LIBSSH2_METHOD_*``
        :param value: Value that ``set_flag`` will be set to. Must be ``0`` or
        ``1``.
        :type value: ``int``
        :rtype: ``int``
        """
        if (int(set_flag)<1 or int(set_flag)>3) or (value!=0 and value!=1):
            return handle_error_codes(
                error_codes.LIBSSH2_ERROR_METHOD_NOT_SUPPORTED)
        cdef int rc
        cdef int _set_flag = int(set_flag)
        cdef int _value = int(value)
        with nogil:
            rc = c_ssh2.libssh2_session_flag(self._session, _set_flag, _value)
        return handle_error_codes(rc)

    def handshake(self, sock not None):
        """Perform SSH handshake.

        Must be called after Session initialisation."""
        cdef int _sock = PyObject_AsFileDescriptor(sock)
        cdef int rc
        with nogil:
            rc = c_ssh2.libssh2_session_handshake(self._session, _sock)
            self._sock = _sock
            if self.c_poll_enabled==True:
                self._build_c_waitsocket_data()
        self.sock = sock
        if self.check_c_poll_enabled()==False:
            self._build_waitsocket_data()
        return handle_error_codes(rc)

    def set_blocking(self, bint blocking):
        """Set session blocking mode on/off.

        :param blocking: ``False`` for non-blocking, ``True`` for blocking.
          Session default is blocking unless set otherwise.
        :type blocking: bool"""
        with nogil:
            c_ssh2.libssh2_session_set_blocking(self._session, blocking)

    def get_blocking(self):
        """Get session blocking mode enabled True/False.

        :rtype: bool"""
        cdef int rc
        with nogil:
            rc = c_ssh2.libssh2_session_get_blocking(self._session)
        return bool(rc)

    def set_timeout(self, long timeout):
        """Set the timeout in milliseconds for how long a blocking
        call may wait until the situation is considered an error and
        :py:class:`ssh2.error_codes.LIBSSH2_ERROR_TIMEOUT` is returned.

        By default or if timeout set is zero, blocking calls do not
        time out.
        :param timeout: Milliseconds to wait before timeout."""
        with nogil:
            c_ssh2.libssh2_session_set_timeout(self._session, timeout)

    def get_timeout(self):
        """Get current session timeout setting"""
        cdef long timeout
        with nogil:
            timeout = c_ssh2.libssh2_session_get_timeout(self._session)
        return timeout

    def userauth_authenticated(self):
        """True/False for is user authenticated or not.

        :rtype: bool"""
        cdef bint rc
        with nogil:
            rc = c_ssh2.libssh2_userauth_authenticated(self._session)
        return bool(rc)

    def userauth_list(self, username not None):
        """Retrieve available authentication methods list.

        :rtype: list"""
        cdef bytes b_username = to_bytes(username)
        cdef char *_username = b_username
        cdef size_t username_len = len(b_username)
        cdef char *_auth
        cdef str auth
        with nogil:
            _auth = c_ssh2.libssh2_userauth_list(self._session, _username, username_len)
        if _auth is NULL:
            return
        auth = to_str(_auth)
        return auth.split(',')

    def userauth_publickey_fromfile(self, username not None, privatekey not None, passphrase='', publickey=None):
        """Authenticate with public key from file.

        :rtype: int"""
        cdef int rc
        cdef bytes b_username = to_bytes(username)
        cdef bytes b_publickey = to_bytes(publickey) if publickey is not None else None
        cdef bytes b_privatekey = to_bytes(privatekey)
        cdef bytes b_passphrase = to_bytes(passphrase)
        cdef char *_username = b_username
        cdef char *_publickey = NULL
        cdef char *_privatekey = b_privatekey
        cdef char *_passphrase = b_passphrase
        if b_publickey is not None:
            _publickey = b_publickey
        with nogil:
            rc = c_ssh2.libssh2_userauth_publickey_fromfile(self._session, _username, _publickey, _privatekey, _passphrase)
        return handle_error_codes(rc)

    def userauth_publickey(self, username not None,
                           bytes pubkeydata not None):
        """Perform public key authentication with provided public key data

        :param username: User name to authenticate as
        :type username: str
        :param pubkeydata: Public key data
        :type pubkeydata: bytes

        :rtype: int"""
        cdef int rc
        cdef bytes b_username = to_bytes(username)
        cdef char *_username = b_username
        cdef unsigned char *_pubkeydata = pubkeydata
        cdef size_t pubkeydata_len = len(pubkeydata)
        with nogil:
            rc = c_ssh2.libssh2_userauth_publickey(self._session, _username, _pubkeydata, pubkeydata_len, NULL, NULL)
        return handle_error_codes(rc)

    def userauth_hostbased_fromfile(self, username not None, privatekey not None, hostname not None, publickey=None, passphrase=''):
        cdef int rc
        cdef bytes b_username = to_bytes(username)
        cdef bytes b_publickey = to_bytes(publickey) if publickey is not None else None
        cdef bytes b_privatekey = to_bytes(privatekey)
        cdef bytes b_passphrase = to_bytes(passphrase)
        cdef bytes b_hostname = to_bytes(hostname)
        cdef char *_username = b_username
        cdef char *_publickey = NULL
        cdef char *_privatekey = b_privatekey
        cdef char *_passphrase = b_passphrase
        cdef char *_hostname = b_hostname
        if b_publickey is not None:
            _publickey = b_publickey
        with nogil:
            rc = c_ssh2.libssh2_userauth_hostbased_fromfile(self._session, _username, _publickey, _privatekey, _passphrase, _hostname)
        return handle_error_codes(rc)

    def userauth_publickey_frommemory(self, username, bytes privatekeyfiledata, passphrase='', bytes publickeyfiledata=None):
        cdef int rc
        cdef bytes b_username = to_bytes(username)
        cdef bytes b_passphrase = to_bytes(passphrase)
        cdef char *_username = b_username
        cdef char *_passphrase = b_passphrase
        cdef char *_publickeyfiledata = NULL
        cdef char *_privatekeyfiledata = privatekeyfiledata
        cdef size_t username_len, pubkeydata_len, privatekeydata_len
        username_len, pubkeydata_len, privatekeydata_len = len(b_username), 0, len(privatekeyfiledata)
        if publickeyfiledata is not None:
            _publickeyfiledata = publickeyfiledata
            pubkeydata_len = len(publickeyfiledata)
        with nogil:
            rc = c_ssh2.libssh2_userauth_publickey_frommemory(self._session, _username, username_len, _publickeyfiledata,
                pubkeydata_len, _privatekeyfiledata, privatekeydata_len, _passphrase)
        return handle_error_codes(rc)

    def userauth_password(self, username not None, password not None):
        """Perform password authentication

        :param username: User name to authenticate.
        :type username: str
        :param password: Password
        :type password: str"""
        cdef int rc
        cdef bytes b_username = to_bytes(username)
        cdef bytes b_password = to_bytes(password)
        cdef const char *_username = b_username
        cdef const char *_password = b_password
        with nogil:
            rc = c_ssh2.libssh2_userauth_password(self._session, _username, _password)
        return handle_error_codes(rc)

    def userauth_keyboardinteractive(self, username not None, password not None):
        """Perform keyboard-interactive authentication

        :param username: User name to authenticate.
        :type username: str
        :param password: Password
        :type password: str
        """
        cdef int rc
        cdef bytes b_username = to_bytes(username)
        cdef const char *_username = b_username

        def passwd():
            return(password)

        self._callbacks['kbd'] = passwd
        rc = c_ssh2.libssh2_userauth_keyboard_interactive(self._session, _username, &kbd_callback)
        self._callbacks['kbd'] = None
        return handle_error_codes(rc)

    def agent_init(self):
        """Initialise SSH agent.

        :rtype: :py:class:`ssh2.agent.Agent`
        """
        cdef c_ssh2.LIBSSH2_AGENT *agent
        with nogil:
            agent = agent_init(self._session)
        return PyAgent(agent, self)

    def agent_auth(self, username not None):
        """Convenience function for performing user authentication via SSH Agent.

        Initialises, connects to, gets list of identities from and attempts
        authentication with each identity from SSH agent.

        Note that agent connections cannot be used in non-blocking mode -
        clients should call `set_blocking(0)` *after* calling this function.

        On completion, or any errors, agent is disconnected and resources freed.

        All steps are performed in C space which makes this function perform
        better than calling the individual Agent class functions from
        Python.

        :raises: :py:class:`MemoryError` on error initialising agent
        :raises: :py:class:`ssh2.exceptions.AgentConnectionError` on error
          connecting to agent
        :raises: :py:class:`ssh2.exceptions.AgentListIdentitiesError` on error
          getting identities from agent
        :raises: :py:class:`ssh2.exceptions.AgentAuthenticationError` on no
          successful authentication with all available identities.
        :raises: :py:class:`ssh2.exceptions.AgentGetIdentityError` on error
          getting known identity from agent

        :rtype: None"""
        cdef bytes b_username = to_bytes(username)
        cdef char *_username = b_username
        cdef c_ssh2.LIBSSH2_AGENT *agent = NULL
        cdef c_ssh2.libssh2_agent_publickey *identity = NULL
        cdef c_ssh2.libssh2_agent_publickey *prev = NULL
        agent = init_connect_agent(self._session)
        with nogil:
            agent_auth(_username, agent)

    def open_session(self):
        """Open new channel session.

        :rtype: :py:class:`ssh2.channel.Channel`
        """
        cdef c_ssh2.LIBSSH2_CHANNEL *channel
        with nogil:
            channel = c_ssh2.libssh2_channel_open_session( self._session)
        if channel is NULL:
            return handle_error_codes(c_ssh2.libssh2_session_last_errno( self._session))
        return PyChannel(channel, self)

    def direct_tcpip_ex(self, host not None, int port,
                        shost not None, int sport):
        cdef c_ssh2.LIBSSH2_CHANNEL *channel
        cdef bytes b_host = to_bytes(host)
        cdef bytes b_shost = to_bytes(shost)
        cdef char *_host = b_host
        cdef char *_shost = b_shost
        with nogil:
            channel = c_ssh2.libssh2_channel_direct_tcpip_ex(self._session, _host, port, _shost, sport)
        if channel is NULL:
            return handle_error_codes(c_ssh2.libssh2_session_last_errno(self._session))
        return PyChannel(channel, self)

    def direct_tcpip(self, host not None, int port):
        """Open direct TCP/IP channel to host:port

        Channel will be listening on an available open port on client side
        as assigned by OS.
        """
        cdef c_ssh2.LIBSSH2_CHANNEL *channel
        cdef bytes b_host = to_bytes(host)
        cdef char *_host = b_host
        with nogil:
            channel = c_ssh2.libssh2_channel_direct_tcpip(self._session, _host, port)
        if channel is NULL:
            return handle_error_codes(c_ssh2.libssh2_session_last_errno(self._session))
        return PyChannel(channel, self)

    def block_directions(self):
        """Get blocked directions for the current session.

        From libssh2 documentation:

        Can be a combination of:

        ``ssh2.session.LIBSSH2_SESSION_BLOCK_INBOUND``: Inbound direction
        blocked.

        ``ssh2.session.LIBSSH2_SESSION_BLOCK_OUTBOUND``: Outbound direction
        blocked.

        Application should wait for data to be available for socket prior to
        calling a libssh2 function again. If ``LIBSSH2_SESSION_BLOCK_INBOUND``
        is set select should contain the session socket in readfds set.

        Correspondingly in case of ``LIBSSH2_SESSION_BLOCK_OUTBOUND`` writefds
        set should contain the socket.

        :rtype: int"""
        cdef int rc
        with nogil:
            rc = c_ssh2.libssh2_session_block_directions(self._session)
        return rc

    def forward_listen(self, int port):
        """Create forward listener on port.

        :param port: Port to listen on.
        :type port: int

        :rtype: :py:class:`ssh2.listener.Listener` or None"""
        cdef c_ssh2.LIBSSH2_LISTENER *listener
        with nogil:
            listener = c_ssh2.libssh2_channel_forward_listen(self._session, port)
        if listener is NULL:
            return handle_error_codes(c_ssh2.libssh2_session_last_errno(self._session))
        return PyListener(listener, self)

    def forward_listen_ex(self, host not None, int port,
                          int bound_port, int queue_maxsize):
        cdef c_ssh2.LIBSSH2_LISTENER *listener
        cdef bytes b_host = to_bytes(host)
        cdef char *_host = b_host
        with nogil:
            listener = c_ssh2.libssh2_channel_forward_listen_ex(self._session, _host, port, &bound_port, queue_maxsize)
        if listener is NULL:
            return handle_error_codes(c_ssh2.libssh2_session_last_errno(self._session))
        return PyListener(listener, self)

    def sftp_init(self):
        """Initialise SFTP channel.

        :rtype: :py:class:`ssh2.sftp.SFTP`
        """
        cdef c_sftp.LIBSSH2_SFTP *_sftp
        with nogil:
            _sftp = c_sftp.libssh2_sftp_init(self._session)
        if _sftp is NULL:
            return handle_error_codes(c_ssh2.libssh2_session_last_errno(self._session))
        return PySFTP(_sftp, self)

    def last_error(self, size_t msg_size=1024):
        """Retrieve last error message from libssh2, if any.
        Returns empty string on no error message.

        :rtype: str
        """
        cdef char *_error_msg
        cdef bytes msg = b''
        cdef int errmsg_len = 0
        with nogil:
            _error_msg = <char *>malloc(sizeof(char) * msg_size)
            c_ssh2.libssh2_session_last_error(self._session, &_error_msg, &errmsg_len, 1)
        try:
            if errmsg_len > 0:
                msg = _error_msg[:errmsg_len]
            return msg
        finally:
            free(_error_msg)

    def last_errno(self):
        """Retrieve last error number from libssh2, if any.
        Returns 0 on no last error.

        :rtype: int
        """
        cdef int rc
        with nogil:
            rc = c_ssh2.libssh2_session_last_errno(self._session)
        return rc

    def set_last_error(self, int errcode, errmsg not None):
        cdef bytes b_errmsg = to_bytes(errmsg)
        cdef char *_errmsg = b_errmsg
        cdef int rc
        with nogil:
            rc = c_ssh2.libssh2_session_set_last_error(self._session, errcode, _errmsg)
        return rc

    def scp_recv2(self, path not None):
        """Receive file via SCP.

        Available only on libssh2 >= 1.7.

        :param path: File path to receive.
        :type path: str

        :rtype: tuple(:py:class:`ssh2.channel.Channel`,
          :py:class:`ssh2.fileinfo.FileInfo`) or ``None``"""
        cdef FileInfo fileinfo = FileInfo()
        cdef bytes b_path = to_bytes(path)
        cdef char *_path = b_path
        cdef c_ssh2.LIBSSH2_CHANNEL *channel
        with nogil:
            channel = c_ssh2.libssh2_scp_recv2(self._session, _path, fileinfo._stat)
        if channel is NULL:
            return handle_error_codes(c_ssh2.libssh2_session_last_errno(self._session))
        return PyChannel(channel, self), fileinfo

    def scp_send64(self, path not None, int mode, c_ssh2.libssh2_uint64_t size,
                   time_t mtime, time_t atime):
        """Send file via SCP.

        :param path: Local file path to send.
        :type path: str
        :param mode: File mode.
        :type mode: int
        :param size: size of file
        :type size: int

        :rtype: :py:class:`ssh2.channel.Channel`"""
        cdef bytes b_path = to_bytes(path)
        cdef char *_path = b_path
        cdef c_ssh2.LIBSSH2_CHANNEL *channel
        with nogil:
            channel = c_ssh2.libssh2_scp_send64(self._session, _path, mode, size, mtime, atime)
        if channel is NULL:
            return handle_error_codes(c_ssh2.libssh2_session_last_errno(self._session))
        return PyChannel(channel, self)

    def publickey_init(self):
        """Initialise public key subsystem for managing remote server
        public keys"""
        cdef c_pkey.LIBSSH2_PUBLICKEY *_pkey
        with nogil:
            _pkey = c_pkey.libssh2_publickey_init(self._session)
        if _pkey is NULL:
            raise PublicKeyInitError
        return PyPublicKeySystem(_pkey, self)

    def hostkey_hash(self, int hash_type):
        """Get computed digest of the remote system's host key.

        :param hash_type: One of ``ssh2.session.LIBSSH2_HOSTKEY_HASH_MD5`` or
          ``ssh2.session.LIBSSH2_HOSTKEY_HASH_SHA1``
        :type hash_type: int

        :rtype: bytes"""
        cdef const char *_hash
        cdef bytes b_hash
        with nogil:
            _hash = c_ssh2.libssh2_hostkey_hash(self._session, hash_type)
        if _hash is NULL:
            return
        b_hash = _hash
        return b_hash

    def hostkey(self):
        """Get server host key for this session.

        Returns key, key_type tuple where key_type is one of
        :py:class:`ssh2.session.LIBSSH2_HOSTKEY_TYPE_RSA`,
        :py:class:`ssh2.session.LIBSSH2_HOSTKEY_TYPE_DSS`, or
        :py:class:`ssh2.session.LIBSSH2_HOSTKEY_TYPE_UNKNOWN`

        :rtype: tuple(bytes, int)"""
        cdef bytes key = b""
        cdef const char *_key
        cdef size_t key_len = 0
        cdef int key_type = 0
        with nogil:
            _key = c_ssh2.libssh2_session_hostkey(self._session, &key_len, &key_type)
        if _key is NULL:
            raise SessionHostKeyError("Error retrieving server host key for session")
        key = _key[:key_len]
        return key, key_type

    def knownhost_init(self):
        """Initialise a collection of known hosts for this session.

        :rtype: :py:class:`ssh2.knownhost.KnownHost`"""
        cdef c_ssh2.LIBSSH2_KNOWNHOSTS *known_hosts
        with nogil:
            known_hosts = c_ssh2.libssh2_knownhost_init(self._session)
        if known_hosts is NULL:
            raise KnownHostError
        return PyKnownHost(self, known_hosts)

    def keepalive_config(self, bint want_reply, unsigned interval):
        """
        Configure keep alive settings.

        :param want_reply: True/False for reply wanted from server on keep
          alive messages being sent or not.
        :type want_reply: bool
        :param interval: Required keep alive interval. Set to ``0`` to disable
          keepalives.
        :type interval: int"""
        with nogil:
            c_ssh2.libssh2_keepalive_config(self._session, want_reply, interval)

    def keepalive_send(self):
        """Send keepalive.

        Returns seconds remaining before next keep alive should be sent.

        :rtype: int"""
        cdef int seconds = 0
        cdef int c_seconds = 0
        cdef int rc
        with nogil:
            rc = c_ssh2.libssh2_keepalive_send(self._session, &c_seconds)
        handle_error_codes(rc)
        return c_seconds
