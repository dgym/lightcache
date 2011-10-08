import signal
import traceback
import socket

from cpython cimport Py_INCREF, Py_DECREF, PyObject

# a signal
signal.signal(signal.SIGPIPE, signal.SIG_IGN)

cdef void on_signal(ev_loop_t *loop, ev_signal_t *self, int revents) except *:
    try:
        (<Loop>self.data).on_signal(revents)
    except:
        ev_unloop(loop, 1)
        raise

# Loop
cdef class Loop(object):
    def __init__(self):
        self._loop = ev_default_loop(0)
        ev_signal_init(&self.sigint_watcher, on_signal, signal.SIGINT)
        self.sigint_watcher.data = <void *>self
        ev_signal_start(self._loop, &self.sigint_watcher)

    cpdef loop(self, handle_errors=False):
        if handle_errors:
            while True:
                try:
                    ev_loop(self._loop, 0)
                    break
                except KeyboardInterrupt:
                    break
                except:
                    traceback.print_exc()
        else:
            ev_loop(self._loop, 0)

    cpdef unloop(self):
        ev_unloop(self._loop, 1)

    cdef on_signal(self, revents):
        raise KeyboardInterrupt()

# a timer

cdef void on_timer(ev_loop_t *loop, ev_timer_t *self, int revents) except *:
    try:
        (<Timer>self.data).on_timer(revents)
    except:
        ev_unloop(loop, 1)
        raise

cdef class Timer(object):
    def __init__(self, loop, callback, delay, repeat):
        self.loop = loop
        self.callback = callback
        self.once = repeat <= 0
        self.watcher.data = <void *>self
        ev_timer_init(&self.watcher, on_timer, delay, repeat)
        self.start()

    def start(self):
        Py_INCREF(self)
        ev_timer_start(self.loop._loop, &self.watcher)

    def stop(self):
        ev_timer_stop(self.loop._loop, &self.watcher)
        Py_DECREF(self)

    cdef on_timer(self, revents):
        try:
            self.callback()
        finally:
            if self.once:
                self.stop()


# a socket

cdef void on_async_socket_read(ev_loop_t *loop, ev_io_t *self, int revents) except *:
    try:
        (<AsyncSocket>self.data).on_readable(revents)
    except:
        ev_unloop(loop, 1)
        raise

cdef void on_async_socket_write(ev_loop_t *loop, ev_io_t *self, int revents) except *:
    try:
        (<AsyncSocket>self.data).on_writeable(revents)
    except:
        ev_unloop(loop, 1)
        raise

cdef class AsyncSocket(object):
    def __init__(self, loop, sock, server=None):
        self.server = server
        self.sock = sock
        self.loop = loop
        self.read_buffer = ''
        self.write_buffer = ''
        self.close_on_sent = False

        Py_INCREF(self)
        self.read_watcher.data = <void *>self
        self.write_watcher.data = <void *>self

        ev_io_init(&self.read_watcher, on_async_socket_read, sock.fileno(), EV_READ)
        ev_io_init(&self.write_watcher, on_async_socket_write, sock.fileno(), EV_WRITE)

        ev_io_start(self.loop._loop, &self.read_watcher)

    def close(self):
        ev_io_stop(self.loop._loop, &self.read_watcher)
        ev_io_stop(self.loop._loop, &self.write_watcher)
        self.read_watcher.data = NULL
        self.write_watcher.data = NULL
        try:
            self.sock.close()
        except:
            pass
        self.on_close()
        Py_DECREF(self)

    def flush_and_close(self):
        if not self.write_buffer:
            self.close()
        else:
            self.close_on_sent = True

    def send(self, data):
        if not data:
            return
        self.write_buffer += data
        ev_io_start(self.loop._loop, &self.write_watcher)

    cdef on_readable(self, int revents):
        data = self.sock.recv(10240)
        if not data:
            self.close()
        else:
            self.read_buffer += data
            self.on_read()

    cdef on_writeable(self, revents):
        sent = self.sock.send(self.write_buffer)
        if sent < 0:
            self.close()
        else:
            self.write_buffer = self.write_buffer[sent:]
            if not self.write_buffer:
                ev_io_stop(self.loop._loop, &self.write_watcher)
                if self.close_on_sent:
                    self.close()

    def on_read(self):
        pass

    def on_close(self):
        pass

# a server

cdef void on_async_server_read(ev_loop_t *loop, ev_io_t *self, int revents) except *:
    try:
        (<AsyncServer>self.data).on_readable(revents)
    except:
        ev_unloop(loop, 1)
        raise

cdef class AsyncServer(object):
    def __init__(self, loop, sock, Client):
        if isinstance(sock, tuple):
            loc = sock
            sock = socket.socket()
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.bind(loc)
            sock.listen(5)
        self.loop = loop
        self.sock = sock
        self.Client = Client

        Py_INCREF(self)
        self.read_watcher.data = <void *>self
        ev_io_init(&self.read_watcher, on_async_server_read, sock.fileno(), EV_READ)
        ev_io_start(self.loop._loop, &self.read_watcher)

    def close(self):
        ev_io_stop(self.loop._loop, &self.read_watcher)
        self.read_watcher.data = NULL
        try:
            self.sock.close()
        except:
            pass
        Py_DECREF(self)

    cdef on_readable(self, int revents):
        try:
            sock, addr = self.sock.accept()
            self.Client(self.loop, sock, addr, self)
        except:
            import traceback
            traceback.print_exc()


