# -*- mode: Makefile; -*-
# $Id$

#  Just to make things easier, a toplevel Make that calls the sub-makes

CP = cp

.PHONY: mcl markov

all: mcl markov

mcl:
	@cd mcl; ${MAKE} binaries; 
	$(CP) -f mcl/bin/* ../bin

markov:
	@cd markov; ${MAKE}; ${MAKE} install
