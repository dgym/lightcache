import evhttpconn
import settings
import re

from compressor import compress

class CachingClient(evhttpconn.Connection):
    def __init__(self, loop, sock, page):
        super(CachingClient, self).__init__(loop, sock)
        self.loop = loop
        self.page = page
        self.cache = self.page.cache

    def on_headers_end(self, message):
        self.send_back(message)
        self.page.response_headers_len = len(message)

    def on_chunk(self, chunk):
        self.send_back(chunk)

    def on_complete(self):
        self.cache.release(len(self.page.response))
        self.page.response = self.page.partial_response
        self.page.partial_response = ''
        self.page.complete = True
        self.close()

        # start compression
        self.page.compressed = ''
        if len(self.page.response) > 100:
            response = self.page.response
            def on_compressed(data):
                if response != self.page.response:
                    return
                headers = re.sub(r'(!\r)\n', '\r\n', response[:self.page.response_headers_len])

                headers = re.sub(r'content-length\s*:[^\r]*', '', headers)

                headers = headers[:-2] + ('content-length: %i\r\ncontent-encoding: deflate\r\n\r\n' % len(data))
                self.page.compressed = headers + data
            compress(self.loop, response[self.page.response_headers_len:], on_compressed)

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
