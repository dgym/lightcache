
listen_addresses = [
    ('', 80),
]

backend_address = ('localhost', 8080)

max_memory = 64*1024*1024
max_cache_content_length = 1*1024*1024
max_cache_age = 300

cache_refresh = 5
cache_refresh_rate = 20

compression_threads = 2

error_codes = {
    'bad gateway': (502, 'Bad Gateway', 'Bad Gateway'),
}

try:
    from local_settings import *
except ImportError:
    pass
