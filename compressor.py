import subprocess

from cy_compress_queue import CompressQueue
import settings

queue = CompressQueue(settings.compression_threads)

def compress(loop, content, callback):
    queue.add(content, callback)

def poll():
    queue.poll()
