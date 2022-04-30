
# =============================================================================
#	Use minimal/barebones CRT & library code (i.e. avoiding MiNTlib)
# =============================================================================
LINK_MINIMAL=yes
# -----------------------------------------------------------------------------

# =============================================================================
#	debug	= Prevent optimization & add debug info
#	testing	= Optimize but retain symbols
#	release	= Optimize, strip
# =============================================================================
USE_CFG=release
# -----------------------------------------------------------------------------


# =============================================================================
#	Some standard C/ASM config - probably won't need changed too often
# =============================================================================

TARGETFLAGS =	-m68000

LIBPATHS =	\
		-L/brown/lib/gcc/m68k-atarisuperbrowner-elf/11.2.0/m68000

LIBS =		\

INCPATHS =	\

LIBCXX = 	libcxx

# -----------------------------------------------------------------------------
#	With LINK_MINIMAL, we modify the linker command to use minimal LIBC
# -----------------------------------------------------------------------------
ifeq ($(LINK_MINIMAL),yes)
# -----------------------------------------------------------------------------

CRTSEQ_S = \
	$(LIBCXX)/brownboot.o \
	$(LIBCXX)/browncrti.o \
	$(LIBCXX)/browncrt++.o \
	$(LIBCXX)/zerolibc.o \
	$(LIBCXX)/zerocrtfini.o
CRTSEQ_E = \
	$(LIBCXX)/browncrtn.o

# GCC6/ELF also needs to generate code with base address = 0 for postprocessing
LDOPTS = -Wl,--emit-relocs -Wl,-e_start -Ttext=0 -nostdlib -nostartfiles

# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
else
# -----------------------------------------------------------------------------

# GCC6/ELF linking for MiNTlib & C++ is complicated by changes to ctor/dtor
# list representation, code required to implement them and having to specify
# all of the link pieces manually.

# crt0:
#  gcc-provided entrypoint/boot code
#
# browncrti:
#  marks beginning of BrownElf .init_array/.fini_array - must be linked early
# browncrtn:
#  marks end of BrownElf .init_array/.fini_array - must be linked last
# brownmint++:
#  when combining MiNTlib with C++ using BrownElf, crtinit.c must be replaced with one
#  which performs the necessary ELF-style static initialisation because MiNTlib
#  doesn't do this and GCC6 doesn't quietly inject static inits before main() as
#  GCC4 does
# browncrt++:
#  implements BrownElf-specific C++ .init_array/.fini_array procedures
#
# zerocrtfini:
#  implements __cxa_atexit/__cxa_finalize needed by C++ static init. missing
#  from MiNTlib and reused for bare-bones builds on both compilers.

CRTSEQ_G = /brown/m68k-atarisuperbrowner-elf/lib/crt0.o
CRTSEQ_S = \
	$(LIBCXX)/browncrti.o \
	$(LIBCXX)/browncrt++.o \
	$(LIBCXX)/brownmint++.o \
	$(LIBCXX)/zerocrtfini.o
CRTSEQ_E = \
	$(LIBCXX)/browncrtn.o

LDOPTS = -Wl,--gc-sections -Wl,--emit-relocs -Wl,-e__start -Ttext=0 -nostdlib -nostartfiles
LIBS = -lgcc -lc

# -----------------------------------------------------------------------------
endif
# -----------------------------------------------------------------------------

VASM = ./vasmm68k_mot.exe -Felf -showcrit -noesc
TOOLCHAIN_PREFIX = /brown/bin/m68k-atarisuperbrowner-elf-

# -----------------------------------------------------------------------------

CC = $(TOOLCHAIN_PREFIX)gcc
CXX = $(TOOLCHAIN_PREFIX)g++
AR = $(TOOLCHAIN_PREFIX)ar
AS = $(TOOLCHAIN_PREFIX)as
NM = $(TOOLCHAIN_PREFIX)nm
LINK = $(TOOLCHAIN_PREFIX)g++
STRIP = $(TOOLCHAIN_PREFIX)strip
STACK = $(TOOLCHAIN_PREFIX)stack
FLAGS = $(TOOLCHAIN_PREFIX)flags

STACKSIZE = 16384


# =============================================================================
#	Projects start here!
# =============================================================================


COMPILERDEFS += \
		-D__ATARI__ -D__M68000__ \
		-DELF_CONFIG_STACK=$(STACKSIZE) \


# -----------------------------------------------------------------------------
#	C Code generation
# -----------------------------------------------------------------------------

ifeq ($(USE_CFG),debug)

CODEOPTFLAGS = $(TARGETFLAGS) -g -O0
CODEGENFLAGS = $(CODEOPTFLAGS)

else

CODEOPTFLAGS = $(TARGETFLAGS) -Ofast -fomit-frame-pointer -fstrict-aliasing
CODEGENFLAGS = $(CODEOPTFLAGS) -fcaller-saves -flto -ffunction-sections -fdata-sections

endif

CODEGENFLAGS += -fleading-underscore

CFLAGS	= $(CODEGENFLAGS) $(COMPILERDEFS) $(INCPATHS) -Wall
CXXFLAGS = $(CODEGENFLAGS) $(COMPILERDEFS) $(INCPATHS) -x c++ -std=c++0x -fno-exceptions -fno-rtti -fno-threadsafe-statics -Wall -Wno-reorder

LDFLAGS = -Wl,-Map,$*.map $(LDOPTS) $(CODEGENFLAGS)

# -----------------------------------------------------------------------------
#	Common objects for the examples
# -----------------------------------------------------------------------------

OBJECTS_O =	\
		vsnprint.o \
		printf.o \

# =============================================================================
#	Targets to be built
# =============================================================================

# rule to build programs

all: example1 example2 example3

# individual programs...

example1: $(OBJECTS_O) lolworld.elf
example2: $(OBJECTS_O) ctest.elf
example3: $(OBJECTS_O) cpptest.elf

# in case we are building the startup objects, don't autodelete after building
.PRECIOUS: $(CRTSEQ_S) $(CRTSEQ_E)

# =============================================================================
#	Rule to clean projects
# =============================================================================

clean:
	-rm -f *.elf
	-rm -f *.tos
	-rm -f $(OBJECTS_O)
	-rm -rf *.o
	-rm -rf *.lst


# =============================================================================
#	Rule build a single program (demo!)
# =============================================================================
%.elf: $(CRTSEQ_G) $(CRTSEQ_S) $(OBJECTS_O) %.o $(CRTSEQ_E) | Makefile
	$(LINK) $(LIBPATHS) -o $*.elf $(CRTSEQ_G) $(CRTSEQ_S) $(OBJECTS_O) $*.o $(LDFLAGS) $(LIBS) $(CRTSEQ_E)
# -----------------------------------------------------------------------------
#	Strip symbols & pack executable
# -----------------------------------------------------------------------------
ifeq ($(USE_CFG),release)
# -----------------------------------------------------------------------------
	./brownout.exe -p 0 -i $*.elf -o $*.tos
# -----------------------------------------------------------------------------
else
# -----------------------------------------------------------------------------
	$(TOOLCHAIN_PREFIX)objdump -h $*.elf
	./brownout.exe -s -x -p 0 -i $*.elf -o $*.tos
# -----------------------------------------------------------------------------
endif
# -----------------------------------------------------------------------------
	cp $*.tos auto/$*.prg

# =============================================================================
# to use MiNTLib with GCC6 static initialisation (for c++) we need to inject
# a custom version of crtinit.c which calls __libc_csu_init().
# The compile flags are very specific and the MiNTLib source includes are not
# installed with the compiler so we have copies.
# -----------------------------------------------------------------------------
# note: alternative LIBC packages may require the same type of modification if
# they don't already call __libc_csu_init()
# -----------------------------------------------------------------------------
# todo: ship this as a precompiled object!
# =============================================================================

$(LIBCXX)/brownmint++.o: $(LIBCXX)/brownmint++.c
	$(TOOLCHAIN_PREFIX)gcc -Wall -m68000 -O2 -std=gnu89 -fleading-underscore -nostdinc \
	-I$(LIBCXX) \
	-I/usr/lib/gcc/m68k-atarisuperbrowner-elf/11.2.0/include \
	-I/usr/lib/gcc/m68k-atarisuperbrowner-elf/11.2.0/include-fixed \
	-I/usr/m68k-atarisuperbrowner-elf/include \
	-DHAVE_CONFIG_H -D_LIBC -D_REENTRANT \
	-c $< -o $@


# =============================================================================
#	Build rules for source files
# =============================================================================

# rule to compile C files
%.o: %.c
	$(CC) -c $(CFLAGS) -o $@ $<

# rule to compile C++ files
%.o: %.cpp
	$(CXX) -c $(CXXFLAGS) -o $@ $<

# rules to assemble .gas files -> .o
%.o: %.gas
	$(AS) -o $@ $<


# rules to assemble unspecified .s files -> .o
%.o: %.s
ifeq ($(USE_CFG),debug)
	$(VASM) $(COMPILERDEFS) -L $@.lst -o $@ $<
else
	$(VASM) $(COMPILERDEFS) -o $@ $<
endif

