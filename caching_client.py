import evhttpconn
import settings

class CachingClient(evhttpconn.Connection):
    def __init__(self, loop, sock, page):
        super(CachingClient, self).__init__(loop, sock)
        self.page = page
        self.cache = self.page.cache

    def on_headers_end(self, message):
        self.send_back(message)

    def on_chunk(self, chunk):
        self.send_back(chunk)

    def on_complete(self):
        self.page.complete = True
        self.cache.release(len(self.page.response))
        self.page.response = self.page.partial_response
        self.page.partial_response = ''
        self.close()

    def on_close(self):
        super(CachingClient, self).on_close()
        for listener in self.page.listeners:
            listener.terminate()
        del self.page.listeners[:]
        self.page.backend = None

    def send_back(self, data):
        if not data:
            return
        for listener in self.page.listeners:
            listener.send(data)

        if self.page.can_cache:
            existing = len(self.page.partial_response)
            additional = len(data)
            if (existing + additional) > settings.max_cache_content_length:
                self.cache.purge(self.page)
            elif not self.cache.reserve(additional):
                self.cache.purge(self.page)
            elif self.page.can_cache:
                self.page.partial_response += data
            else:
                self.cache.release(additional)
