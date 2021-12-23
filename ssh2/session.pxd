# This file is part of ssh2-python.
# Copyright (C) 2017 Panos Kittenis

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

cimport c_ssh2
IF HAVE_POLL==1:
    cimport utils

cdef class Session:
    cdef c_ssh2.LIBSSH2_SESSION *_session
    cdef int _sock
    cdef readonly object sock

    cdef readonly object _callbacks
    cdef readonly bint c_poll_enabled
    cdef public object _block_lock

    IF HAVE_POLL==1:
        cdef void _build_waitsocket_data(Session self) nogil
        cdef int poll_socket(Session self,int block_dir,int timeout) nogil
        cdef utils.pollfd _waitsockets[1]
