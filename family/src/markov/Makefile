# -*- mode: Makefile; -*-
# $Id$

# CC = /usr/local/bin/gcc 
CC = /bin/cc 

ifeq ($(FAMPATH),)
	INSTALL = echo "don't know where to install to; FAMPATH not set"; exit 2;
else
INSTALL = cp
installdir =  $(FAMPATH)/bin
endif

opt = -g -O

CFLAGS = -c $(opt)


.PHONY: all install

all: markov

install: markov
	$(INSTALL) markov $(installdir)

markov: markov.o
	$(CC) $^ -o $@ -lm

markov.o: markov.c markov.h
	$(CC) $(CFLAGS) $?


