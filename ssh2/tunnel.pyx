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

from . cimport c_ssh2
from . cimport utils

cdef class Tunnel:

    """Tunnel class to provide minor wrapped functions"""

    def __cinit__(self, _session, _tun_channel, sock):
        self._session = _session
        self._tun_channel = _tun_channel
        self._sock = PyObject_AsFileDescriptor(sock)
        self.sock = sock
        self._default_waitsockets = []
        self._waitsockets = []
        self._build_waitsocket_data()
        if self._session.check_c_poll_enabled()==True:
            self._build_c_waitsocket_data()

    def __dealloc__(self):
        if self._session is not None and self._session._session is not NULL and self._tun_channel._channel is not NULL:
            c_ssh2.libssh2_channel_free(self._tun_channel._channel)
        self._tun_channel._channel = NULL

    cdef void _build_c_waitsocket_data(Tunnel self) nogil:
        self._c_waitsockets[0].fd = self._session._sock
        self._c_waitsockets[0].events = 0
        self._c_waitsockets[0].revents = 0
        self._c_waitsockets[1].fd = self._sock
        self._c_waitsockets[1].events = utils.POLLIN | utils.POLLOUT
        self._c_waitsockets[1].revents = 0

    def _build_waitsocket_data(self):
        self._waitsockets = [self._session.sock,self.sock]

    IF HAVE_POLL==1:
        cdef int poll_sockets(Tunnel self,int block_dir,int timeout) nogil:
            cdef int rc

            with nogil:
                if(block_dir & c_ssh2.LIBSSH2_SESSION_BLOCK_INBOUND):
                    self._c_waitsockets[0].events |= utils.POLLIN

                if(block_dir & c_ssh2.LIBSSH2_SESSION_BLOCK_OUTBOUND):
                    self._c_waitsockets[0].events |= utils.POLLOUT

                rc = utils.poll(self._c_waitsockets, 2, timeout)
                self._c_waitsockets[0].events = 0
            return rc

    def _block_call(self,_select_timeout=None):
        if _select_timeout==None:
            _select_timeout = 0.001
        with self._session._block_lock:
            self._session.keepalive_send()
            block_direction = self._session.block_directions()
        if block_direction==0:
            time.sleep(0.1)
            return([[0,0],[],[]])

        if self._session.check_c_poll_enabled()==True:
            with self._session._block_lock:
                self.poll_sockets(block_direction,_select_timeout*1000)
            return([[self._c_waitsockets[0].revents,self._c_waitsockets[1].revents],[],[]])
        else:
            rfds = self._default_waitsockets
            wfds = self._default_waitsockets
            if block_direction & c_ssh2.LIBSSH2_SESSION_BLOCK_INBOUND:
                rfds = self._waitsockets

            if block_direction & c_ssh2.LIBSSH2_SESSION_BLOCK_OUTBOUND:
                wfds = self._waitsockets

            return(pyselect.select(rfds,wfds,self._default_waitsockets,_select_timeout))
