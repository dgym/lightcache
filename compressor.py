import subprocess

import ev

class CompressionReader(ev.FileReader):
    def __init__(self, loop, file, callback):
        super(CompressionReader, self).__init__(loop, file)
        self.callback = callback

    def on_close(self):
        self.callback(self.read_buffer)

def compress(loop, content, callback):
    def on_close(content):
        callback(content)
        proc.wait()
    proc = subprocess.Popen(['gzip', '-9'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, close_fds=True)
    writer = ev.FileWriter(loop, proc.stdin)
    writer.write(content)
    writer.flush_and_close()
    CompressionReader(loop, proc.stdout, on_close)
