## Process this file with automake to produce Makefile.in
## $Id$

INCLUDES = -I$(top_srcdir)

## make sure these do _not_ get build or installed by default
noinst_PROGRAMS = hashfile
hashfile_SOURCES = hashfile.c

LDADD = ../intalg/la.o ../intalg/libintalg.a ../mcl/libmcl.a ../nonema/libnonema.a ../util/libutil.a

