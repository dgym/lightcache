
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
compress_content = [
    'text/.*(?:;.*)?',
    'application/javascript(?:;.*)?',
]

error_codes = {
    'bad gateway': (502, 'Bad Gateway', 'Bad Gateway'),
}

# if this is set to True the process will background itself at start up
daemonise = False

# security settings
chroot = None # or a directory (string)
chuid = None # or a user name (string)
chgrp = None # or a group name (string)

# load local_settings
try:
    from local_settings import *
except ImportError:
    pass
