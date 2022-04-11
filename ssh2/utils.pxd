cdef bytes to_bytes(_str)
cdef object to_str(char *c_str)
cdef object to_str_len(char *c_str, int length)
cpdef int handle_error_codes(int errcode) except -1


IF HAVE_POLL==1:
    cdef extern from "poll.h" nogil:
        ctypedef unsigned int nfds_t
        enum:
            POLLIN
            POLLPRI
            POLLOUT
            POLLERR
            POLLHUP
            POLLNVAL
        struct pollfd:
            int fd
            short events
            short revents
        int poll(pollfd *fds, nfds_t nfds, int timeout)

cdef extern from "openssl/opensslv.h" nogil:
    char* OPENSSL_VERSION_TEXT
