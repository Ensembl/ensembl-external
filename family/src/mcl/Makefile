# -*- mode: Makefile; -*-
# $Id$

#  Just to make things easier, a toplevel Make that calls the sub-makes

CP = cp

.PHONY: mcl markov

all: mcl markov

mcl:
	@cd mcl; ${MAKE} binaries; 
	$(CP) -f mcl/bin/* ../bin || true;  
# the '|| true' avoids make stopping due to cp trying to copy CVS/ subdirs.

markov:
	@cd markov; ${MAKE}; ${MAKE} install
