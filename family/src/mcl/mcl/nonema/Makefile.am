## Process this file with automake to produce Makefile.in
## $Id$

INCLUDES = -I$(top_srcdir)

## hack to overrule
## DEFS = @DEFS@ -I. -I$(srcdir)
## -I. blows up our linking
## automake 1.5 doesn't grok this
## DEFS = @DEFS@
## but _does_ grok this:
## DEFAULT_INCLUDES =

## this is gone from automake?
## AUTOMAKE_OPTIONS = nostdinc

noinst_LIBRARIES = libnonema.a
libnonema_a_SOURCES = compose.c floatops.c iface.c io.c ivp.c matrix.c vector.c

EXTRA_DIST = compose.h floatops.h iface.h io.h ivp.h matrix.h types.h vector.h

