## Process this file with automake to produce Makefile.in
## $Id$

INCLUDES = -I$(top_srcdir)

bin_PROGRAMS = mcx
mcx_SOURCES  = mcx.c stack.c glob.c util.c ops.c
## mcl_LDADD = @LIBOBJS@

LDADD = ../mcl/libmcl.a ../intalg/libintalg.a ../nonema/libnonema.a ../util/libutil.a

EXTRA_DIST = stack.h glob.h util.h ops.h
