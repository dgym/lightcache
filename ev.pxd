cdef extern from "ev.h":

    struct ev_loop_t "ev_loop":
        pass

    struct ev_watcher:
        void *data

    ctypedef double ev_tstamp
    ctypedef void (*callback)(ev_watcher *self, int revents)

    int EV_READ = 1
    int EV_WRITE = 2

    ev_loop_t *ev_default_loop(int)
    void ev_loop(ev_loop_t *, int)
    void ev_unloop(ev_loop_t *, int how)

    # watchers
    void ev_init(ev_loop_t *, callback cb)

    # timers
    struct ev_timer_t "ev_timer":
        void *data
    ctypedef void (*timer_callback)(ev_loop_t *loop, ev_timer_t *self, int revents) except *

    void ev_timer_init(ev_timer_t *, timer_callback cb, ev_tstamp, ev_tstamp)
    void ev_timer_start(ev_loop_t *, ev_timer_t *)
    void ev_timer_stop(ev_loop_t *, ev_timer_t *)

    # signals
    struct ev_signal_t "ev_signal":
        void *data
    ctypedef void (*signal_callback)(ev_loop_t *loop, ev_signal_t *self, int revents) except *
    void ev_signal_init(ev_signal_t *, signal_callback cb, int)
    void ev_signal_start(ev_loop_t *, ev_signal_t *)
    void ev_signal_stop(ev_loop_t *, ev_signal_t *)

    # i/o
    struct ev_io_t "ev_io":
        void *data
    ctypedef void (*io_callback)(ev_loop_t *loop, ev_io_t *self, int revents) except *
    void ev_io_init(ev_io_t *, io_callback cb, int, int events)
    void ev_io_start(ev_loop_t *, ev_io_t *)
    void ev_io_stop(ev_loop_t *, ev_io_t *)


cdef class Loop(object):
    cdef ev_loop_t *_loop
    cdef ev_signal_t sigint_watcher

    cpdef loop(self, handle_errors=?)
    cpdef unloop(self)
    cdef on_signal(self, revents)


cdef class Timer(object):
    cdef ev_timer_t watcher
    cdef Loop loop
    cdef object callback
    cdef bint once

    cdef on_timer(self, revents)


cdef class AsyncServer(object):
    cdef ev_io_t read_watcher
    cdef public Loop loop
    cdef object sock
    cdef object Client
    cdef bint reffed

    cdef on_readable(self, int revents)


cdef class AsyncSocket(object):
    cdef ev_io_t read_watcher
    cdef ev_io_t write_watcher
    cdef public AsyncServer server
    cdef object sock
    cdef Loop loop
    cdef public str read_buffer
    cdef str write_buffer
    cdef bint close_on_sent

    cdef on_readable(self, int revents)
    cdef on_writeable(self, revents)
