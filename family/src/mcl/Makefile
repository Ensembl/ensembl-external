#
#	Compatible with `gmake' only.
#
#	---------------------------------------------------------------------
#
#	begin user configurable options
#

USR_OPT := yes
USR_INTEGRITY :=	no
USR_PROFILE := no
USR_ARCH := $(shell uname)

#
#	end user configurable options
#
#	---------------------------------------------------------------------
#
#	begin non-configurable derived settings
#

### default settings: use gcc
### compiler:
CC =  gcc
### general system-specific compiler options (for gcc)
COMPILE_SYS = \
	-funsigned-char \
	-finline-functions \
	-fPIC \
	-ansi \
	-Wall \
	-Wshadow \
	-W \
	-Wundef \
	-Winline \
	-Wmissing-prototypes \
	-Wno-unused \
	-Wno-comment \
	-Wstrict-prototypes \
	-Wwrite-strings

### additional optimization/debugging options (for gcc):
ifeq ($(strip $(USR_OPT)),yes)
	LINK_DEBUG		=
	OPTIMIZE		:= -DEXTERN__INLINE__DEFINE="extern __inline__ "\
				  -DEXTERN__INLINE__DECLARE="" \
	 			  -O3 -fomit-frame-pointer
	STRIP			= chmod 755 $@; strip $@
else
	LINK_DEBUG		=
	OPTIMIZE := -g -DEXTERN__INLINE__DEFINE="static " \
		       -DEXTERN__INLINE__DECLARE="static "
# following should work on any compiler
	STRIP			= chmod 755 $@
endif

### override any of the above CC, COMPILE_SYS, OPTIMIZE assignments:
ifeq ($(strip $(USR_ARCH)),sgi)
#   COMPILE_SYS  = <archicture/compiler specific options>
    ifeq ($(strip $(USR_OPT)),yes)
#       OPTIMIZE  := <archicture/compiler specific optimization options>
    else
	OPTIMIZE := haha
# 	OPTIMIZE  = <archicture/compiler specific debugging options>
    endif
endif

### etc. for other architectures

ifeq ($(strip $(USR_ARCH)),OSF1)
    arch = ev67  # use 'generic' if you don't know
    CC = /bin/cc 
    COMPILE_SYS = -D__inline__="" -arch $(arch)
    LINK_SYS = 
    ifeq ($(strip $(USR_OPT)),yes)
# 	following not working/debugged yet:	
	OPTIMIZE  := -O4 -fp_reorder -float  -DEXTERN__INLINE__DEFINE="static " \
			 -DEXTERN__INLINE__DECLARE="static "
    else
	OPTIMIZE  :=  -g -DEXTERN__INLINE__DEFINE="static " \
			-DEXTERN__INLINE__DECLARE="static "
    endif
endif

### profiling flags:
ifeq ($(strip $(USR_PROFILE)),yes)
	COMPILE_PROFILE	=	-pg
	LINK_PROFILE		=	-pg
else
	COMPILE_PROFILE	=
	LINK_PROFILE		=
endif

# additional check flags:
ifeq ($(strip $(USR_INTEGRITY)),yes)
	COMPILE_INTEGRITY =	-DRUNTIME_VECTOR_INTEGRITY
else
	COMPILE_INTEGRITY =
endif

### with the above definitions, CFLAGS is (or should be) general:
CFLAGS	= -I. $(COMPILE_SYS) $(OPTIMIZE) \
	  $(COMPILE_PROFILE)	$(COMPILE_INTEGRITY) 
LFLAGS		=	$(LINK_SYS) $(LINK_PROFILE) -lm -lpthread

#
#	end derived settings
#
#	---------------------------------------------------------------------
#
#	begin path and target specifications
#

LIBDIR		=	lib
BINDIR		=	bin


# UTILLIBS	 =	$(LIBDIR)/libutil.a
# MCLLIBS		=	$(LIBDIR)/libutil.a $(LIBDIR)/libmcl.a

libraries:		$(LIBDIR)/libnonema.a		\
					$(LIBDIR)/libintalg.a		\
					$(LIBDIR)/libutil.a			\
					$(LIBDIR)/libmcl.a

binaries:		$(BINDIR)/mcl					\
					$(BINDIR)/mcldoc				\
					$(BINDIR)/mcxview				\
					$(BINDIR)/mcxconvert			\
					$(BINDIR)/mcxmorph			\
					$(BINDIR)/mcxsubs				\
					$(BINDIR)/clminfo				\
					$(BINDIR)/clmdist				\
					$(BINDIR)/clmmeet				\
					$(BINDIR)/clmproject \
					$(BINDIR)/yam
UTILOBJ		=	util/iomagic.o					\
					util/alloc.o					\
					util/buf.o						\
					util/equate.o					\
					util/equate.o					\
					util/checkbounds.o			\
					util/distr.o					\
					util/parse.o					\
					util/file.o						\
					doc/key.o						\
					util/array.o					\
					util/hash.o						\
					util/link.o						\
					util/heap.o						\
					util/txt.o

INTALGOBJ	=	intalg/ilist.o					\
					intalg/parse.o					\
					intalg/la.o						\
					intalg/perm.o

NONEMAOBJ	=	nonema/ivp.o					\
					nonema/vector.o				\
					nonema/matrix.o				\
					nonema/compose.o				\
					nonema/io.o						\
					nonema/float.o					\
					nonema/iface.o

MCLLIBOBJ	=	mcl/compose.o					\
					mcl/mcl.o						\
					mcl/dpsd.o						\
					mcl/params.o					\
					mcl/clm.o						\
					mcl/interpret.o

#	
#	end paths/files
#
#	---------------------------------------------------------------------
#	
#	begin targets and rules
#	

publicar:
	cd ..;\
	tar cfz mcl/mcl.tar.gz\
			--exclude='*.o'\
			--exclude='*.a'\
			--exclude='mcl/bin'\
			--exclude mcl/my\
			--exclude mcl/myshcl\
			--exclude mcl/myshia\
			--exclude mcl/myshmx\
			--exclude mcl/mytest\
			--exclude mcl/mygraphs\
			--exclude mcl/mcldev.tar.gz\
			--exclude mcl/mcl.tar.gz\
				mcl

#	developer's archive
develar:
	cd ..;\
	tar cfz mcl/mcldev.tar.gz\
			--exclude='*.a'\
			--exclude='*.o'\
			--exclude mcl/bin\
			--exclude mcl/NOTAR\
			--exclude mcl/mytest\
			--exclude mcl/mygraphs\
			--exclude mcl/mcldev.tar.gz\
			--exclude mcl/mcl.tar.gz\
				mcl

clean:
	rm -f lib/*.a */*.o
	rm -f bin/*

$(LIBDIR)/libnonema.a: $(NONEMAOBJ)
	ar src $@ $^

$(LIBDIR)/libintalg.a: $(INTALGOBJ)
	ar src $@ $^

$(LIBDIR)/libutil.a: $(UTILOBJ)
	ar src $@ $^

$(LIBDIR)/libmcl.a: $(MCLLIBOBJ)
	ar src $@ $^

$(BINDIR)/mcldoc: shmcl/mcldoc
	cp shmcl/mcldoc bin

$(BINDIR)/mcl: shmcl/mcl.o lib/libmcl.a lib/libintalg.a lib/libnonema.a lib/libutil.a
	mkdir -p bin
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

$(BINDIR)/mcxview: shmx/mcxview.o lib/libnonema.a lib/libutil.a
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

$(BINDIR)/mcxmorph: shmx/mcxmorph.o lib/libnonema.a lib/libutil.a
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

$(BINDIR)/mcxconvert: shmx/mcxconvert.o lib/libnonema.a lib/libutil.a
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

$(BINDIR)/mcxsubs: shmx/mcxsubs.o lib/libmcl.a lib/libnonema.a lib/libintalg.a lib/libutil.a
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

$(BINDIR)/clmproject: shcl/clmproject.o lib/libmcl.a lib/libnonema.a lib/libutil.a lib/libintalg.a
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

$(BINDIR)/clminfo: shcl/clminfo.o intalg/la.o lib/libintalg.a lib/libmcl.a lib/libnonema.a lib/libutil.a
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

$(BINDIR)/clmmeet: shcl/clmmeet.o intalg/la.o lib/libintalg.a lib/libmcl.a lib/libnonema.a lib/libutil.a
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

$(BINDIR)/clmdist: shcl/clmdist.o intalg/la.o lib/libintalg.a lib/libmcl.a lib/libnonema.a lib/libutil.a
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

#$(BINDIR)/mcoarse: shmx/mcoarse.o lib/libnonema.a lib/libutil.a
#	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
#	$(STRIP)

$(BINDIR)/mcxgenix: myshcl/mcxgenix.o intalg/la.o lib/libintalg.a lib/libmcl.a lib/libnonema.a lib/libutil.a
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

$(BINDIR)/man: doc/man.o lib/libutil.a
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

bin/hashfile: shtest/hashfile.o lib/libutil.a
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

bin/yam: doc/yam.o doc/key.o util/txt.o lib/libutil.a
	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
	$(STRIP)

#$(BINDIR)/ipret: shmcl/ipret.o lib/libmcl.a lib/libnonema.a lib/libutil.a 
#	$(CC) -o $@ $^ $(LFLAGS) $(LINK_DEBUG)
#	$(STRIP)

testmake:
	echo USR_ARCH=$(USR_ARCH) USR_OPT=$(USR_OPT) CC=$(CC) OPTIMIZE=$(OPTIMIZE) 

