## Process this file with automake to produce Makefile.in
## $Id$

TROFF = groff
ZOEM = $(top_srcdir)/zoem/zoem

## tidy is a HTML syntax checker and reformatter, available from
## http://www.w3.org/People/Raggett/tidy/ , by Dave Raggett <dsr@w3.org>
TIDY = tidy

docdir = $(datadir)/doc/$(PACKAGE)

## zoemtut.html is "on hold": do not install; zoem is not yet ready
## for prime time
doc_DATA = mcl.html mcl.ps \
            mcx.html mcx.ps \
            mcxconvert.html mcxconvert.ps \
            mcxsubs.html mcxsubs.ps \
            clmdist.html clmdist.ps \
            clminfo.html clminfo.ps \
            clmmeet.html clmmeet.ps \
            clmconf.html clmconf.ps \
            mcxformat.html mcxformat.ps

MAINTAINERCLEANFILES = mcl.1 mcx.1 mcx.5 clmdist.1 clminfo.1 clmconf.1 \
  clmmeet.1 mcxconvert.1 mcxsubs.1 $(doc_DATA)
EXTRA_DIST = man.zmm mcx.zmm clmdist.azm clminfo.azm clmmeet.azm clmconf.azm \
  mcl.azm mcx.azm mcxformat.azm mcxsubs.azm mcxconvert.azm zoemtut.azm \
  $(MAINTAINERCLEANFILES)

man_MANS = mcl.1 mcx.1 mcx.5 clmdist.1 clminfo.1 clmmeet.1 clmconf.1 \
  mcxconvert.1 mcxsubs.1

mcl-all.ps: mcl.ps mcx.ps mcxformat.ps clmdist.ps clminfo.ps clmmeet.ps clmconf.ps mcxsubs.ps mcxconvert.ps
	mpage -c -2 -o -M-50 mcl.ps mcx.ps mcxformat.ps clmdist.ps clminfo.ps clmmeet.ps clmconf.ps mcxsubs.ps mcxconvert.ps > mcl-all.ps

mcl-all.tar.gz:
	tar czf mcl-all.tar.gz *.{1,5,html,ps}

mcxformat: mcxformat.html mcx.5 mcxformat.ps

mcxformat.html: mcxformat.azm
	$(ZOEM) -i mcxformat -d html -o mcxformat.html
	$(ZOEM) -i mcxformat -d html -o mcxformat.html
	- $(TIDY) -e mcxformat.html

mcx.5: mcxformat.azm
	$(ZOEM) -i mcxformat -d roff -o  mcx.5
	$(ZOEM) -i mcxformat -d roff -o  mcx.5

mcxformat.ps: mcx.5
	$(TROFF) -man mcx.5 > mcxformat.ps


clminfo: clminfo.1 clminfo.html clminfo.ps

clminfo.html: clminfo.azm
	$(ZOEM) -i clminfo -d html -o clminfo.html
	$(ZOEM) -i clminfo -d html -o clminfo.html
	- $(TIDY) -e clminfo.html

clminfo.ps: clminfo.1
	$(TROFF) -man clminfo.1 > clminfo.ps

clminfo.1: clminfo.azm
	$(ZOEM) -i clminfo -d roff -o clminfo.1
	$(ZOEM) -i clminfo -d roff -o clminfo.1


clmmeet: clmmeet.1 clmmeet.html clmmeet.ps

clmmeet.html: clmmeet.azm
	$(ZOEM) -i clmmeet -d html -o clmmeet.html
	$(ZOEM) -i clmmeet -d html -o clmmeet.html
	- $(TIDY) -e clmmeet.html

clmmeet.ps: clmmeet.1
	$(TROFF) -man clmmeet.1 > clmmeet.ps

clmmeet.1: clmmeet.azm
	$(ZOEM) -i clmmeet -d roff -o clmmeet.1
	$(ZOEM) -i clmmeet -d roff -o clmmeet.1


clmconf: clmconf.1 clmconf.html clmconf.ps

clmconf.html: clmconf.azm
	$(ZOEM) -i clmconf -d html -o clmconf.html
	$(ZOEM) -i clmconf -d html -o clmconf.html
	- $(TIDY) -e clmconf.html

clmconf.ps: clmconf.1
	$(TROFF) -man clmconf.1 > clmconf.ps

clmconf.1: clmconf.azm
	$(ZOEM) -i clmconf -d roff -o clmconf.1
	$(ZOEM) -i clmconf -d roff -o clmconf.1


clmdist: clmdist.1 clmdist.html clmdist.ps

clmdist.html: clmdist.azm
	$(ZOEM) -i clmdist -d html -o clmdist.html
	$(ZOEM) -i clmdist -d html -o clmdist.html
	- $(TIDY) -e clmdist.html

clmdist.ps: clmdist.1
	$(TROFF) -man clmdist.1 > clmdist.ps

clmdist.1: clmdist.azm
	$(ZOEM) -i clmdist -d roff -o clmdist.1
	$(ZOEM) -i clmdist -d roff -o clmdist.1


mcl: mcl.1 mcl.html mcl.ps

mcl.html: mcl.azm
	$(ZOEM) -i mcl -d html -o mcl.html
	$(ZOEM) -i mcl -d html -o mcl.html
	- $(TIDY) -e mcl.html

mcl.ps: mcl.1
	$(TROFF) -man mcl.1 > mcl.ps

mcl.1: mcl.azm
	$(ZOEM) -i mcl -d roff -o mcl.1
	$(ZOEM) -i mcl -d roff -o mcl.1


mcx: mcx.1 mcx.html mcx.ps

mcx.html: mcx.azm
	$(ZOEM) -i mcx -d html -o mcx.html
	$(ZOEM) -i mcx -d html -o mcx.html
	- $(TIDY) -e mcx.html

mcx.ps: mcx.1
	$(TROFF) -man mcx.1 > mcx.ps

mcx.1: mcx.azm
	$(ZOEM) -i mcx -d roff -o mcx.1
	$(ZOEM) -i mcx -d roff -o mcx.1


mcxsubs: mcxsubs.1 mcxsubs.html mcxsubs.ps

mcxsubs.html: mcxsubs.azm
	$(ZOEM) -i mcxsubs -d html -o mcxsubs.html
	$(ZOEM) -i mcxsubs -d html -o mcxsubs.html
	- $(TIDY) -e mcxsubs.html

mcxsubs.ps: mcxsubs.1
	$(TROFF) -man mcxsubs.1 > mcxsubs.ps

mcxsubs.1: mcxsubs.azm
	$(ZOEM) -i mcxsubs -d roff -o mcxsubs.1
	$(ZOEM) -i mcxsubs -d roff -o mcxsubs.1


mcxconvert: mcxconvert.1 mcxconvert.html mcxconvert.ps

mcxconvert.html: mcxconvert.azm
	$(ZOEM) -i mcxconvert -d html -o mcxconvert.html
	$(ZOEM) -i mcxconvert -d html -o mcxconvert.html
	- $(TIDY) -e mcxconvert.html

mcxconvert.ps: mcxconvert.1
	$(TROFF) -man mcxconvert.1 > mcxconvert.ps

mcxconvert.1: mcxconvert.azm
	$(ZOEM) -i mcxconvert -d roff -o mcxconvert.1
	$(ZOEM) -i mcxconvert -d roff -o mcxconvert.1


faq: mclfaq.1 mclfaq.html mclfaq.ps

mclfaq.html: mclfaq.azm
	$(ZOEM) -i mclfaq -d html -o mclfaq.html
	$(ZOEM) -i mclfaq -d html -o mclfaq.html
	- $(TIDY) -e mclfaq.html

mclfaq.ps: mclfaq.1
	$(TROFF) -man mclfaq.1 > mclfaq.ps

mclfaq.1: mclfaq.azm
	$(ZOEM) -i mclfaq -d roff -o mclfaq.1
	$(ZOEM) -i mclfaq -d roff -o mclfaq.1


buzz: buzz.1 buzz.html buzz.ps

buzz.html: buzz.azm
	$(ZOEM) -i buzz -d html -o buzz.html
	$(ZOEM) -i buzz -d html -o buzz.html
	- $(TIDY) -e buzz.html

buzz.ps: buzz.1
	$(TROFF) -man buzz.1 > buzz.ps

buzz.1: buzz.azm
	$(ZOEM) -i buzz -d roff -o buzz.1
	$(ZOEM) -i buzz -d roff -o buzz.1


zoemtut: zoemtut.html

zoemtut.html: zoemtut.azm
	$(ZOEM) -i zoemtut -d html -o zoemtut.html
	$(ZOEM) -i zoemtut -d html -o zoemtut.html
	- $(TIDY) -e zoemtut.html

# once there's roff support form zoemtut, we might like to add
# zoem.7 to man_MANS


