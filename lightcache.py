import socket
import time

import evhttpconn
import ev

import compressor
import settings

from caching_client import CachingClient

class Page(object):
    def __init__(self, cache, key, headers):
        self.cache = cache
        self.key = key
        self.can_cache = True
        self.headers = headers
        self.response_headers_len = 0
        self.response = ''
        self.partial_response = ''
        self.complete = False
        self.compressed = ''
        self.last_access = time.time()
        self.last_fetch = self.last_access
        self.listeners = []


class Cache(object):
    def __init__(self):
        self.pages = {}
        self.allocated = 0

    def serve_page(self, host, path, headers, client):
        key = (host, path)
        page = self.pages.get(key)
        if page:
            page.last_access = time.time()
            if page.complete:
                if client.accept_deflate and page.compressed:
                    client.send(page.compressed)
                    client.terminate()
                else:
                    client.send(page.response)
                    client.terminate()
                return
            elif page.can_cache:
                client.send(page.partial_response)
                page.listeners.append(client)
                return

        # start a new request
        page = Page(self, key, headers)
        page.listeners.append(client)

        try:
            sock = socket.socket()
            sock.connect(settings.backend_address)
            page.backend = CachingClient(loop, sock, page)
            page.backend.send(headers)
        except IOError:
            client.send_error('bad gateway')

        self.pages[key] = page

    def purge(self, page):
        page.can_cache = False
        self.release(len(page.response))
        self.release(len(page.partial_response))
        page.response = ''
        page.partial_response = ''
        page.headers = ''
        if page.key in self.pages:
            del self.pages[page.key]

    def reserve(self, bytes):
        if bytes > settings.max_memory:
            return False
        while bytes > (settings.max_memory - self.allocated):
            page = min(self.pages.values(), key=lambda x: x.last_access)
            self.purge(page)
        self.allocated += bytes
        return True

    def release(self, bytes):
        self.allocated -= bytes

    def refresh(self):
        now = time.time()
        expired = now - settings.cache_refresh
        forget = now - settings.max_cache_age

        for page in self.pages.values():
            if page.last_access < forget:
                self.purge(page)
                continue

            if page.last_fetch < expired:
                try:
                    sock = socket.socket()
                    sock.connect(settings.backend_address)
                    page.backend = CachingClient(loop, sock, page)
                    page.backend.send(page.headers)
                    page.last_fetch = now
                except IOError:
                    self.purge(page)
                break

cache = Cache()


class BackendClient(evhttpconn.Connection):
    def __init__(self, loop, sock, client):
        super(BackendClient, self).__init__(loop, sock)
        self.client = client

    def on_headers_end(self, message):
        self.client.send(message)

    def on_chunk(self, chunk):
        self.client.send(chunk)

    def on_complete(self):
        self.close()

    def on_close(self):
        super(BackendClient, self).on_close()
        self.client.terminate()


class Client(evhttpconn.Connection):
    all_clients = []

    def __init__(self, loop, sock, addr, server):
        super(Client, self).__init__(loop, sock)
        self.all_clients.append(self)
        self.proxy = True
        self.backend = None
        self.can_cache = True
        self.host = None
        self.path = None
        self.accept_deflate = False

    def on_first_line(self, method, path, protocol):
        if method != 'GET':
            self.can_cache = False
        else:
            self.path = path

    def on_header(self, key, value):
        if key == 'cookie':
            self.can_cache = False
        elif key == 'host':
            self.host = value
        elif key == 'accept-encoding':
            self.accept_deflate = 'deflate' in value

    def on_headers_end(self, message):
        if self.can_cache:
            cache.serve_page(self.host, self.path, message, self)
        else:
            try:
                sock = socket.socket()
                sock.connect(settings.backend_address)
                self.backend = BackendClient(loop, sock, self)
                self.backend.send(message)
            except IOError:
                self.send_error('bad gateway')

    def on_chunk(self, chunk):
        if self.backend:
            self.backend.send(chunk)

    def on_close(self):
        super(Client, self).on_close()
        self.all_clients.remove(self)

    def send_error(self, name):
        code, desc, cont = settings.error_codes[name]
        self.send('HTTP/1.0 %i %s\r\ncontent-length: %i\r\n\r\n%s\n' % (code, desc, len(cont)+1, cont))
        self.terminate()


def main():
    global loop
    loop = ev.Loop()

    # listen on all ports
    servers = []
    for address in settings.listen_addresses:
        sock = socket.socket()
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(address)
        sock.listen(64)
        servers.append(ev.AsyncServer(loop, sock, Client))

    # refresh
    interval = 1.0 / settings.cache_refresh_rate
    refresh_timer = ev.Timer(loop, cache.refresh, interval, interval)

    # compression queue polling
    compress_pop_timer = ev.Timer(loop, compressor.poll, 0.01, 0.01)

    # run forever
    loop.loop(True)

if __name__ == '__main__':
    main()
