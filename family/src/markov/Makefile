# -*- mode: Makefile; -*-
# $Id$

# CC = /usr/local/bin/gcc 
CC = /bin/cc 

opt = -O4

CFLAGS = -c $(opt)

.PHONY: all

all: markov

markov: markov.o
	$(CC) $^ -o $@ -lm

markov.o: markov.c markov.h
	$(CC) $(CFLAGS) $^
