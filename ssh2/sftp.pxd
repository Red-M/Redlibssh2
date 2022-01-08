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

from .session cimport Session

from . cimport c_ssh2
from . cimport c_sftp


cdef object PySFTP(c_sftp.LIBSSH2_SFTP *sftp, Session session)


cdef class SFTP:
    cdef c_sftp.LIBSSH2_SFTP *_sftp
    cdef Session _session
