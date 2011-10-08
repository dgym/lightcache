import re

from ev cimport *
from cpython cimport PyString_FromStringAndSize, PyString_AsStringAndSize

cdef extern from "Python.h":
    ctypedef int Py_ssize_t

cdef extern from "evhttpconn.h":
    ctypedef struct evhttp_string_t:
        char *data
        int length

    ctypedef void (*evhttp_connection_on_first_line)(evhttp_string_t first, evhttp_string_t second, evhttp_string_t third, void *data)
    ctypedef void (*evhttp_connection_on_header)(evhttp_string_t key, evhttp_string_t value, void *data)
    ctypedef void (*evhttp_connection_on_headers_end)(evhttp_string_t message, void *data)
    ctypedef void (*evhttp_connection_on_content)(evhttp_string_t content, void *data)
    ctypedef void (*evhttp_connection_on_complete)(void *data)
    ctypedef void (*evhttp_connection_on_close)(void *data)

    ctypedef struct evhttp_connection_t:
        pass

    void evhttp_connection_init(evhttp_connection_t *self,
                                ev_loop_t *loop,
                                int fd,
                                evhttp_connection_on_first_line on_first_line,
                                evhttp_connection_on_header on_header,
                                evhttp_connection_on_headers_end on_headers_end,
                                evhttp_connection_on_content on_chunk,
                                evhttp_connection_on_content on_complete_content,
                                evhttp_connection_on_complete on_complete,
                                evhttp_connection_on_close on_close,
                                void *callback_data)
    void evhttp_connection_close(evhttp_connection_t *self)
    int evhttp_connection_send(evhttp_connection_t *self, evhttp_string_t data)
    void evhttp_connection_terminate(evhttp_connection_t *self)


cdef evhttp_string_t p2c(object str):
    cdef evhttp_string_t res
    cdef Py_ssize_t l
    PyString_AsStringAndSize(str, <char **>&res.data, &l)
    res.length = l
    return res

cdef object c2p(evhttp_string_t str):
    return PyString_FromStringAndSize(str.data, str.length)


cdef void on_first_line(evhttp_string_t first, evhttp_string_t second, evhttp_string_t third, void *data):
    (<Connection>data).on_first_line(c2p(first), c2p(second), c2p(third))

cdef void on_header(evhttp_string_t key, evhttp_string_t value, void *data):
    (<Connection>data).on_header(c2p(key), c2p(value))

cdef void on_headers_end(evhttp_string_t message, void *data):
    (<Connection>data).on_headers_end(c2p(message))

cdef void on_chunk(evhttp_string_t content, void *data):
    (<Connection>data).on_chunk(c2p(content))

cdef void on_complete(void *data):
    (<Connection>data).on_complete()

cdef void on_close(void *data):
    (<Connection>data).on_close()


cdef class Connection(object):
    cdef evhttp_connection_t this
    cdef object sock

    def __init__(self, loop, sock):
        self.sock = sock
        evhttp_connection_init(&self.this,
                (<Loop>loop)._loop,
                sock.fileno(),
                on_first_line if self.on_first_line else <evhttp_connection_on_first_line>NULL,
                on_header if self.on_header else <evhttp_connection_on_header>NULL,
                on_headers_end if self.on_headers_end else <evhttp_connection_on_headers_end>NULL,
                on_chunk if self.on_chunk else <evhttp_connection_on_content>NULL,
                NULL,
                on_complete if self.on_complete else <evhttp_connection_on_complete>NULL,
                on_close if self.on_close else <evhttp_connection_on_close>NULL,
                <void *>self)

    def close(self):
        evhttp_connection_close(&self.this)

    def send(self, data):
        if evhttp_connection_send(&self.this, p2c(data)) != 0:
            self.close()

    def terminate(self):
        evhttp_connection_terminate(&self.this)

    on_first_line = False
    on_header = False
    on_headers_end = False
    on_chunk = False
    on_complete = False

    def on_close(self):
        try:
            self.sock.close()
        except:
            pass
