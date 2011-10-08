all: ev.so evhttpconn.so

clean:
	-rm *.so *.o

%.c: %.pyx
	cython $<

ev.so: EXTRA_LIBS=-lev
evhttpconn.so: EXTRA_LIBS=-lev -levhttpconn

%.so: %.o
	gcc -shared -o $@ $< $(LDFLAGS) $(EXTRA_LIBS) -g

%.o: %.c
	gcc -c -o $@ $< $(shell python-config --cflags) -fPIC $(CFLAGS) -g -O3
