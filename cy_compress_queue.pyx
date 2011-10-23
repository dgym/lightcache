from cpython cimport PyString_FromStringAndSize, PyString_AsStringAndSize
from cpython cimport Py_INCREF, Py_DECREF

cdef extern from "compress_queue.h":
    int COMPRESS_JOB_PENDING = 1
    int COMPRESS_JOB_DONE = 2

    ctypedef struct compress_job_t:
        int status
        void *dst
        int dst_len
        void *user_data

    ctypedef struct compress_queue_t:
        pass

    int compress_queue_init(compress_queue_t *queue, int threads)
    int compress_queue_add(compress_queue_t *queue, compress_job_t *job)
    compress_job_t *compress_queue_pop(compress_queue_t *queue)

    int compress_job_init(compress_job_t *job, void *src, int src_len)
    int compress_job_del(compress_job_t *job)

cdef class CompressJob(object):
    cdef compress_job_t job
    cdef object src
    cdef object callback

    def __init__(self, data, callback):
        self.src = data
        self.callback = callback

        cdef char *src
        cdef Py_ssize_t size
        PyString_AsStringAndSize(self.src, &src, &size)
        if compress_job_init(&self.job, <void *>src, size) != 0:
            raise MemoryError('CompressJob did not initialize')
        Py_INCREF(self)
        self.job.user_data = <void *>self

    def __del__(self):
        if compress_job_del(&self.job) != 0:
            raise RuntimeError('CompressJob deallocated during processing - memory leak')

    def get_result(self):
        if self.job.status != COMPRESS_JOB_DONE:
            return
        result = PyString_FromStringAndSize(<char *>self.job.dst, self.job.dst_len);
        Py_DECREF(self)
        return result

cdef class CompressQueue(object):
    cdef compress_queue_t queue

    def __init__(self, workers=2):
        if compress_queue_init(&self.queue, workers) != 0:
            raise MemoryError('CompressQueues did not initialize')

    def __del__(self):
        raise RuntimeError('CompressQueues must remain in scope')

    cpdef add(self, data, callback):
        cdef CompressJob job
        job = CompressJob(data, callback)
        if compress_queue_add(&self.queue, &job.job) != 0:
            Py_DECREF(job)
            return False
        return True

    cpdef poll(self):
        cdef compress_job_t *done
        cdef CompressJob job
        while True:
            done = compress_queue_pop(&self.queue)
            if done == NULL:
                break
            job = <CompressJob>done.user_data
            callback = job.callback
            callback(job.get_result())
