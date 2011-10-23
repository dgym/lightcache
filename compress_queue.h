#include <zlib.h>
#include <pthread.h>

#define COMPRESS_JOB_INIT 0
#define COMPRESS_JOB_PENDING 1
#define COMPRESS_JOB_DONE 2

typedef struct compress_job {
    int status;
    void *src;
    int src_len;
    void *dst;
    int dst_len;
    struct compress_job *next;
    void *user_data;
} compress_job_t;

typedef struct {
    compress_job_t *next_job;
    compress_job_t *last_job;
    compress_job_t *done_job;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
} compress_queue_t;

int compress_queue_init(compress_queue_t *queue, int threads);
int compress_queue_add(compress_queue_t *queue, compress_job_t *job);
compress_job_t *compress_queue_pop(compress_queue_t *queue);

int compress_job_init(compress_job_t *job, void *src, int src_len);
int compress_job_del(compress_job_t *job);
