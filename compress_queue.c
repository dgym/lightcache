#include "compress_queue.h"

#include <malloc.h>

void *worker(void *data)
{
    compress_queue_t *queue = (compress_queue_t *)data;
    compress_job_t *job;
    uLongf tmp;

    pthread_mutex_lock(&queue->mutex);

    for (;;)
    {
        while (!queue->next_job)
            pthread_cond_wait(&queue->cond, &queue->mutex);

        job = queue->next_job;
        queue->next_job = job->next;
        if (!queue->next_job)
            queue->last_job = NULL;

        pthread_mutex_unlock(&queue->mutex);

        tmp = job->dst_len;
        compress2(job->dst, &tmp, job->src, job->src_len, 9);
        job->dst_len = tmp;
        job->status = COMPRESS_JOB_DONE;

        pthread_mutex_lock(&queue->mutex);

        job->next = queue->done_job;
        queue->done_job = job;
    }
}

int compress_queue_init(compress_queue_t *queue, int threads)
{
    queue->next_job = NULL;
    queue->last_job = NULL;
    queue->done_job = NULL;
    pthread_mutex_init(&queue->mutex, NULL);
    pthread_cond_init(&queue->cond, NULL);

    int i;
    pthread_t thread;
    for (i=0; i<threads; ++i)
    {
        pthread_create(&thread, NULL, worker, queue);
    }

    return 0;
}

int compress_queue_add(compress_queue_t *queue, compress_job_t *job)
{
    pthread_mutex_lock(&queue->mutex);

    if (!queue->last_job)
    {
        if (!queue->next_job)
            queue->next_job = job;
    }
    else
        queue->last_job->next = job;

    queue->last_job = job;
    job->status = COMPRESS_JOB_PENDING;

    pthread_cond_signal(&queue->cond);
    pthread_mutex_unlock(&queue->mutex);

    return 0;
}

compress_job_t *compress_queue_pop(compress_queue_t *queue)
{
    compress_job_t *job;

    if (!queue->done_job)
        return NULL;

    pthread_mutex_lock(&queue->mutex);
    if (!queue->done_job)
    {
        pthread_mutex_unlock(&queue->mutex);
        return NULL;
    }

    job = queue->done_job;
    queue->done_job = job->next;

    pthread_mutex_unlock(&queue->mutex);

    return job;
}

int compress_job_init(compress_job_t *job, void *src, int src_len)
{
    job->status = COMPRESS_JOB_INIT;
    job->src = src;
    job->src_len = src_len;
    job->dst_len = compressBound(src_len);
    if (!(job->dst = malloc(job->dst_len)))
        return -1;
    job->next = NULL;

    return 0;
}

int compress_job_del(compress_job_t *job)
{
    if (job->status == COMPRESS_JOB_PENDING)
        return -1;

    if (job->dst)
    {
        free(job->dst);
        job->dst = NULL;
    }

    return 0;
}
