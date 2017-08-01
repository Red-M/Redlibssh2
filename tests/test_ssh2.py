import unittest
import pwd
import os
import socket
import time

from ssh2.session import Session
from ssh2.utils import wait_socket
from embedded_server.openssh import OpenSSHServer


PKEY_FILENAME = os.path.sep.join([os.path.dirname(__file__), 'unit_test_key'])
PUB_FILE = "{}.pub".format(PKEY_FILENAME)


class SSH2TestCase(unittest.TestCase):

    def __init__(self, methodname):
        unittest.TestCase.__init__(self, methodname)
        self.cmd = 'echo me'
        self.resp = 'me'
        self.user_key = PKEY_FILENAME
        self.user_pub_key = PUB_FILE
        self.host = '127.0.0.1'
        self.port = 2222
        self.server = OpenSSHServer()
        self.server.start_server()
        self.user = pwd.getpwuid(os.geteuid()).pw_name
        self.session = Session()
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((self.host, self.port))
        self.sock = sock
        self.session.handshake(self.sock)

    def _auth(self):
        return self.session.userauth_publickey_fromfile(
            self.user, self.user_pub_key, self.user_key,
            '')

    def test_fromfile_auth(self):
        self.assertEqual(self._auth(), 0)
        self.assertTrue(self.session.userauth_authenticated())

    def test_get_auth_list(self):
        auth_list = sorted(self.session.userauth_list(self.user))
        expected = sorted([b'publickey', b'password', b'keyboard-interactive'])
        self.assertListEqual(auth_list, expected)

    def test_agent(self):
        agent = self.session.agent_init()
        self.assertTrue(agent.connect() == 0)

    def test_execute(self):
        self._auth()
        chan = self.session.open_session()
        self.assertTrue(chan is not None)
        cmd = ';'.join([self.cmd, 'exit 2'])
        self.assertTrue(chan.execute(cmd) == 0)
        size, data = chan.read()
        lines = data.splitlines()
        self.assertTrue(size > 0)
        self.assertListEqual(lines, ['me'])
        self.assertTrue(chan.close() == 0)
        self.assertTrue(chan.wait_eof() == 0)
        exit_code = chan.get_exit_status()
        self.assertEqual(exit_code, 2)

    def test_long_running_execute(self):
        self._auth()
        chan = self.session.open_session()
        chan.execute('sleep 1; exit 3')
        self.assertTrue(chan.wait_eof() == 0)
        self.assertTrue(chan.close() == 0)
        self.assertTrue(chan.wait_closed() == 0)
        self.assertEqual(chan.get_exit_status(), 3)

    def test_read_stderr(self):
        self._auth()
        chan = self.session.open_session()
        expected = ['stderr output']
        chan.execute('echo "stderr output" >&2')
        size, data = chan.read_stderr()
        self.assertTrue(size > 0)
        self.assertListEqual(expected, data.splitlines())

    def test_pty(self):
        self._auth()
        chan = self.session.open_session()
        self.assertTrue(chan.pty() == 0)
        _out = 'stderr output'
        expected = [_out]
        chan.execute('echo "%s" >&2' % (_out,))
        # stderr output gets redirected to stdout with a PTY
        size, data = chan.read()
        self.assertTrue(size > 0)
        self.assertListEqual(expected, data.splitlines())

    def test_write_stdin(self):
        self._auth()
        _in = 'writing to stdin'
        chan = self.session.open_session()
        chan.execute('cat')
        chan.write(_in + '\n')
        chan.close()
        chan.wait_closed()
        size, data = chan.read()
        self.assertTrue(size > 0)
        self.assertListEqual([_in], data.splitlines())

    def test_write_ex(self):
        self._auth()
        _in = 'writing to stdin'
        chan = self.session.open_session()
        chan.execute('cat')
        chan.write_ex(0, _in + '\n')
        chan.close()
        chan.wait_closed()
        size, data = chan.read()
        self.assertTrue(size > 0)
        self.assertListEqual([_in], data.splitlines())

    def test_write_stderr(self):
        self._auth()
        chan = self.session.open_session()
        chan.execute('echo something')
        _in = 'stderr'
        self.assertTrue(chan.write_stderr(_in + '\n') > 0)
        chan.close()
        chan.wait_closed()

    def test_sftp(self):
        self._auth()
        sftp = self.session.sftp_init()
        self.assertTrue(sftp is not None)
        test_file_data = b'test' + os.linesep
        remote_filename = os.sep.join([os.path.dirname(__file__),
                                       'remote_test_file'])
        with open(remote_filename, 'wb') as test_fh:
            test_fh.write(test_file_data)
        remote_fh = sftp.open(remote_filename, 0, 0)
        try:
            self.assertTrue(remote_fh is not None)
            remote_data = ""
            for data in remote_fh:
                remote_data += data
            self.assertEqual(remote_fh.close(), 0)
            self.assertEqual(remote_data, test_file_data)
        finally:
            os.unlink(remote_filename)
