EVHTTPCONN_DIR = ../evhttpconn
CFLAGS += -I$(EVHTTPCONN_DIR)

all: ev.so evhttpconn.so cy_compress_queue.so

clean:
	-rm *.so *.o

%.c: %.pyx $(wildcard *.pxd)
	cython $<

ev.so: EXTRA_LIBS=-lev
evhttpconn.so: EXTRA_LIBS=-lev -levhttpconn
evhttpconn.so: LDFLAGS+=-L$(EVHTTPCONN_DIR)

%.so: %.o
	gcc -shared -o $@ $^ $(LDFLAGS) $(EXTRA_LIBS) -g

cy_compress_queue.so: cy_compress_queue.o compress_queue.o
	gcc -shared -o $@ $^ $(LDFLAGS) $(EXTRA_LIBS) -g

%.o: %.c
	gcc -c -o $@ $< $(shell python-config --cflags) -fPIC $(CFLAGS) -g -O3
