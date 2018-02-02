set -e			#stop on any error encountered
#set -x                  #echo all commands

#
# Make sure this is being run under bash
# Very bad things happen on other shells (like sh)
#

if [ -z "$BASH_VERSION"  ]; then
    echo "Please run this script under bash!"
    exit
fi

#
# Setup stuff
#

# Figure out from what environment we are being run
# Nicked from https://stackoverflow.com/a/3466183
unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    *)          machine="UNKNOWN:${unameOut}"
esac
echo Host machine: $machine

# Some global stuff that are platform dependent
HOMEDIR=$PWD
NICE='nice -20'
JMULT=-j4
BINPACKAGE_DIR=$PWD/binary-package
# Apple tools are not GNU compatible, use standard gnutool install naming
if [ "$machine" == "Mac" ]
then
    SED=gsed
    TAR=gnutar
else
    SED=sed
    TAR=tar
fi

# Administrator mode
SUDO=sudo
if [ "$machine" == "Mac" ]
then
    INSTALL_PREFIX=/opt/local/
else
    INSTALL_PREFIX=/usr
fi
# User mode
#SUDO=
#INSTALL_PREFIX=${HOME}/localINSTALL_PREFIX

if [ "$machine" == "MinGw" ]
then
    # Msys has no idea what "sudo" and "nice" are.
    # Also, it's not liking parallel builds that much.
    unset SUDO
    unset NICE
    unset JMULT
    # Inform the user that a ramdisk will speed compilation up
    echo "Before we begin...."
    echo
    echo "It seems that you're running this script from Msys/MinGW."
    echo "Be warned that the compilation can take a very very VERY long time!"
    echo "If you can spare the RAM, we really recommend using a RAM drive!"
    echo "Our tests have shown that imdisk (http://www.ltr-data.se/opencode.html/#ImDisk)"
    echo "works fine."
    echo "Of course take notice that you're doing this on your own, we won't"
    echo "accept any liability if something goes wrong with that!!!!"
    echo
    read -p "With that out of the way, press any key to continue" -n 1 -r
    echo
    echo
fi
if [ "$machine" == "Cygwin" ]
then
    # Disable some stuff for cygwin as well
    unset SUDO
    unset NICE
fi

#
# Startup message
#

echo "Ohai!"
echo ""
echo "I'll try to make building this heap of junk as painless as possible!"
echo ""
echo "First of all, I'm going to assume that the following files are in the"
echo "same directory this script is running:"
echo "---------------------------"
echo "gcc-7.2.0.tar.xz (download from one of the mirrors of https://gcc.gnu.org/mirrors.html)"
echo "binutils-2.27.tar.bz2 (download from http://ftp.gnu.org/gnu/binutils/binutils-2.27.tar.bz2)"
echo "mintlib-CVS-20160320.tar (download from http://d-bug.mooo.com/releases/mintlib-CVS-20160320.tar.gz)"
echo "---------------------------"
echo
echo "Also, make sure you have installed the following libraries: GMP, MPFR and MPC for gcc building"
echo "                                                            (dev versions required)"
echo "                                                            bison-bin,flex-bin,flex-dev for mintlib"
echo ""
echo "(On macOS, use Macports and install gmp, mpfr, libmpc, bison, flex, gsed and gnutar)"
echo ""
echo "Finally, this script will install things to $INSTALL_PREFIX and might need root privileges."
echo "Also it'll use $JMULT cores while building"
echo "If this is not to your liking then edit this script and change INSTALL_PREFIX"
echo "to the path you would like to install to (including home folder) and SUDO to"
echo "nothing if you don't need root rights. Also JMULT for number of build cores."
echo ""
echo "The bulk of the script was written by George 'GGN' Nakos"
echo "With enhancements by Douglas 'DML' Little"
echo "                     Patrice 'PMANDIN' Mandin"
echo "                     Troed 'TROED' Sångberg"
echo ""
read -p "Press Enter when you've made sure (or 'a' if you don't want any prompts again)..." -n 1 -r
echo
GLOBAL_OVERRIDE=$REPLY

# Unpack all the things

cd $HOMEDIR

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Unpack gcc, binutils and mintlib?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then
    tar -Jxvf gcc-7.2.0.tar.xz
    tar -jxvf binutils-2.27.tar.bz2
    tar -xvf $HOMEDIR/mintlib-CVS-20160320.tar
fi

# binutils build dir
# Configure, build and install binutils for m68k elf

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Configure build, install and package up binutils?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then
    mkdir -p $HOMEDIR/build-binutils
    cd $HOMEDIR/build-binutils
    ../binutils-2.27/configure --disable-multilib --disable-nls --enable-lto --prefix=$INSTALL_PREFIX --target=m68k-ataribrownerer-elf
    make
    $SUDO make install
    $SUDO strip $INSTALL_PREFIX/bin/*ataribrown*
    $SUDO strip $INSTALL_PREFIX/m68k-ataribrownerer-elf/bin/*
    $SUDO gzip -f -9 $INSTALL_PREFIX/share/man/*/*.1

    # Package up binutils

    make install DESTDIR=$BINPACKAGE_DIR
    cd $BINPACKAGE_DIR
    strip .$INSTALL_PREFIX/bin/*
    strip .$INSTALL_PREFIX/m68k-ataribrownerer-elf/bin/*
    gzip -f -9 .$INSTALL_PREFIX/share/man/*/*.1
    $TAR --owner=0 --group=0 -jcvf binutils-2.27-ataribrownerer-bin.tar.bz2 .$INSTALL_PREFIX
fi

# home directory
cd $HOMEDIR

#
# gcc build dir
# Configure, build and install gcc without any libs for now
#

# Export flags for target compiler as well as pass them on configuration time.
# Who knows, maybe one of the two will actually work!

if [ "$machine" == "Mac" ]
then
    export C_INCLUDE_PATH=/opt/local/include
    export CXX_INCLUDE_PATH=/opt/local/include
    export LDFLAGS="-L/opt/local/lib"
    export LIBRARY_PATH="/opt/local/lib"
    LANGUAGES=c,c++
    WL=-Wl,
else
    # Fortran is enabled now, but there are still issues when compiling
    # a program with it...
    LANGUAGES=c,c++,fortran
    WL=
fi

export CFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fleading-underscore"
export CXXFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fno-threadsafe-statics -fno-exceptions -fno-rtti -fleading-underscore"
export LDFLAGS_FOR_TARGET="${WL}--emit-relocs -Ttext=0"
# TODO: This should build all target for all 000/020/040/060 and fpu/softfpu combos but it doesn't.
#export MULTILIB_OPTIONS="m68000/m68020/m68040/m68060 msoft-float"

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Configure, build and install gcc (without libs)?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then                                                                       
    mkdir -p $HOMEDIR/build-gcc
    cd $HOMEDIR/build-gcc
    ../gcc-7.2.0/configure \
        --target=m68k-ataribrownerer-elf \
        --disable-nls \
        --enable-languages=$LANGUAGES \
        --enable-lto \
        --prefix=$INSTALL_PREFIX \
        --disable-libssp \
        --enable-softfloat \
        --disable-libstdcxx-pch \
        --disable-clocale \
        --disable-libstdcxx-threads \
        --disable-libstdcxx-filesystem-ts \
        --disable-libquadmath \
        --enable-cxx-flags='-O2 -fomit-frame-pointer -fno-threadsafe-statics -fno-exceptions -fno-rtti -fleading-underscore' \
        CFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fleading-underscore" \
        CXXFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fno-threadsafe-statics -fno-exceptions -fno-rtti -fleading-underscore" \
        LDFLAGS_FOR_TARGET="${WL}--emit-relocs -Ttext=0"
    $NICE make all-gcc $JMULT
    $SUDO make install-gcc

    # In some linux distros (linux mint for example) it was observed
    # that make install-gcc didn't set the read permission for users
    # so gcc couldn't work properly. No idea how to fix this propery
    # which means - botch time!                                     
    if [ "$machine" != "Cygwin" ] && [ "$machine" != "Mac" ]
    then
        $SUDO chmod 755 -R $INSTALL_PREFIX/m68k-ataribrownerer-elf/
        $SUDO chmod 755 -R $INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/
        $SUDO chmod 755 -R $INSTALL_PREFIX/lib/gcc/m68k-ataribrownerer-elf/
    fi

fi
# TODO:
# Other candidates to pass to configure:
# This probably won't be used:
#        --disable-multilib \
# Dunno, does anyone NEED unicode for building ST applications?
#        --disable-wchar_t \
# This ditches all coldfire lib building stuff:
#        --with-arch=m68k


#INSTALL_PREFIX
# Build/install libgcc
#

cd $HOMEDIR/build-gcc

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Build and install libgcc?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then
    make all-target-libgcc
    $SUDO make install-target-libgcc

    # Some extra permissions
    if [ "$machine" != "Cygwin" ] && [ "$machine" != "Mac" ]
    then
        $SUDO chmod 755 -R $INSTALL_PREFIX/libexec/
    fi
fi

#
# Mintlib 
#

# Patch mintlib at the source level
cd $HOMEDIR
export PATH=${INSTALL_PREFIX}/bin:$PATH

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Source patch and build mintlib?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then

    MINTLIBDIR=$HOMEDIR/mintlib-CVS-20160320

    # Create missing targets
    cp -R $MINTLIBDIR/lib/ $MINTLIBDIR/lib_mshort
    cp -R $MINTLIBDIR/lib020/ $MINTLIBDIR/lib020_soft
    cp -R $MINTLIBDIR/lib020/ $MINTLIBDIR/lib020-60
    cp -R $MINTLIBDIR/lib020/ $MINTLIBDIR/lib020-60_soft
    cp -R $MINTLIBDIR/lib020/ $MINTLIBDIR/lib040
    cp -R $MINTLIBDIR/lib020/ $MINTLIBDIR/lib060
    # Change build rules for targets
    $SED -i -e "s/instdir =/instdir = m68020_Mshort/gI" \
           -e "s/cflags =/cflags = -m68000 -mshort/gI " \
           -e "s/subdir = lib/subdir = lib_mshort/gI" $MINTLIBDIR/lib_mshort/Makefile
    $SED -i -e "s/instdir = m68020-60/instdir = m68020/gI" \
           -e "s/cflags = -m68020-60/cflags = -m68020/gI " \
           -e "s/subdir = lib020/subdir = lib020/gI" $MINTLIBDIR/lib020/Makefile
    $SED -i -e "s/instdir = m68020-60/instdir = m68020-20_soft/gI" \
           -e "s/cflags = -m68020-60/cflags = -m68020 -msoft-float/gI " \
           -e "s/subdir = lib020/subdir = lib020_soft/gI" $MINTLIBDIR/lib020_soft/Makefile
    $SED -i -e "s/instdir = m68020-60/instdir = m68020-60_soft/gI" \
           -e "s/cflags = -m68020-60/cflags = -m68020-60 -msoft-float/gI " \
           -e "s/subdir = lib020/subdir = lib020-60_soft/gI" $MINTLIBDIR/lib020-60_soft/Makefile
    $SED -i -e "s/instdir = m68020-60/instdir = m68040/gI" \
           -e "s/cflags = -m68020-60/cflags = -m68040/gI " \
           -e "s/subdir = lib020/subdir = lib040/gI" $MINTLIBDIR/lib040/Makefile
    $SED -i -e "s/instdir = m68020-60/instdir = m68060/gI" \
           -e "s/cflags = -m68020-60/cflags = -m68060/gI " \
           -e "s/subdir = lib020/subdir = lib020_soft/gI" $MINTLIBDIR/lib060/Makefile
    $SED -i -e "s/subdir = lib020/subdir = lib020-60/gI" $MINTLIBDIR/lib020-60/Makefile
    # Add targets to main makefile
    $SED -i -e "s/ifeq (\$(WITH_020_LIB), yes)/ifeq (\$(WITH_020SOFT_LIB), yes)\n  SUBDIRS += lib020_soft\n  DIST_SUBDIRS += lib020_soft\nendif\n\n\
    ifeq (\$(WITH_000MSHORT_LIB), yes)\n  SUBDIRS += lib_mshort\n  DIST_SUBDIRS += lib_mshort\nendif\n\n\
    ifeq (\$(WITH_020_060_LIB), yes)\n  SUBDIRS += lib020-60\n  DIST_SUBDIRS += lib020-60\nendif\n\n\
    ifeq (\$(WITH_020_060SOFT_LIB), yes)\n  SUBDIRS += lib020-60_soft\n  DIST_SUBDIRS += lib020-60_soft\nendif\n\n\
    ifeq (\$(WITH_040_LIB), yes)\n  SUBDIRS += lib040\n  DIST_SUBDIRS += lib040\nendif\n\n\
    ifeq (\$(WITH_060_LIB), yes)\n  SUBDIRS += lib060\n  DIST_SUBDIRS += lib060\nendif\n\n\
    ifeq (\$(WITH_020_LIB), yes)/gI" $MINTLIBDIR/Makefile
    # It's probably not possible to build mintlib with mshort....
    $SED -i -e "s/# Uncomment this out if you want extra libraries that are optimized/# Uncomment this out if you want extra libraries that are optimized\n# for m68020 processors.\nWITH_020SOFT_LIB=yes\nWITH_000MSHORT_LIB=no\nWITH_020_060_LIB=yes\nWITH_020_060SOFT_LIB=yes\nWITH_040_LIB=yes\nWITH_060_LIB=yes\n\n# Uncomment this out if you want extra libraries/gI" $MINTLIBDIR/configvars

    # Force 68000 mode in the default lib since our gcc defaults to 68020
    $SED -i -e "s/cflags = /cflags = -m68000/gI " $MINTLIBDIR/lib/Makefile
    
    if [ "$machine" == "MinGw" ]
    then

    #   Because MinGW/Msys has mixed forward/backward slashs in paths, convert
    #	installdir=`$(CC) --print-search-dirs | awk '{ print $$2; exit; }'`; \
    #   to:
    #	installdir=`$(CC) --print-search-dirs | awk '{ print $$2; exit; }' | sed -e 's/\\\\/\//gI'`; \
    #   .....
    #   I need a drink...
        sed -i -e $'s/2; exit; }\'`/2; exit; }\' | sed -e \'s\/\\\\\\\\\\\\\\\\\/\\\\\/\/gi\' `/gI' $MINTLIBDIR/buildrules
    fi

    # Set C standard to avoid shit blow up
    sed -i -e "s/-O2 -fomit-frame-pointer/-O2 -fomit-frame-pointer -std=gnu89/gI" $MINTLIBDIR/configvars

    # Set cross compiler
    sed -i -e "s/AM_DEFAULT_VERBOSITY = 1/AM_DEFAULT_VERBOSITY = 0/gI" $MINTLIBDIR/configvars
    sed -i -e "s/#CROSS=yes/CROSS=yes/gI" $MINTLIBDIR/configvars
    sed -i -e "s|prefix=/usr/m68k-atari-mint|prefix=${INSTALL_PREFIX}/m68k-ataribrownerer-elf|gI" $MINTLIBDIR/configvars
    sed -i -e "s/m68k-atari-mint/m68k-ataribrownerer-elf/gI" $MINTLIBDIR/configvars

    # Convert syntax into new gcc/gas format

    sed -i -e "s/|/\/\//gI" $MINTLIBDIR/startup/crt0.S
    sed -i -e "s/a6/%a6/gI" $MINTLIBDIR/startup/crt0.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/startup/crt0.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/startup/crt0.S
    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/startup/crt0.S
    
    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/dirent/closedir.c
    
    sed -i -e "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/mint/mintbind.h
    sed -i -e "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/mint/mintbind.h
    sed -i -e "s/,sp \"/,%%sp\"/gI" $MINTLIBDIR/include/mint/mintbind.h
    sed -i -e "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/mintbind.h
    sed -i -e "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/mint/osbind.h
    sed -i -e "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/mint/osbind.h
    sed -i -e "s/,sp\\\\n/,%%sp\\\\n/gI" $MINTLIBDIR/include/mint/osbind.h
    sed -i -e "s/,sp \"/,%%sp\"/gI" $MINTLIBDIR/include/mint/osbind.h
    sed -i -e "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/osbind.h

    sed -i -e "s/sp@-/%sp@-/gI" $MINTLIBDIR/mintlib/checkcpu.S
    sed -i -e "s/,sp/,%sp/gI" $MINTLIBDIR/mintlib/checkcpu.S

    sed -i -e "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/osbind.h

    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/frexp.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/frexp.S
    sed -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/frexp.S
    sed -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/frexp.S
    sed -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/frexp.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/frexp.S
    sed -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/frexp.S
    sed -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/frexp.S
    sed -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/frexp.S
    sed -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/frexp.S
    sed -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/frexp.S
 
    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed -i -e "s/5%a0/5a0/gI" $MINTLIBDIR/mintlib/getcookie.S #lolol
    sed -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/getcookie.S
 
    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/getsysvar.S
 
    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/ldexp.S
 
    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/a4/%a4/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/a5/%a5/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/a6/%a6/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/libc_exit.S
 
    sed -i -e "s/d2\/a2\/a6/%%d2\/%%a2\/%%a6/gI" $MINTLIBDIR/include/mint/linea.h
    sed -i -e "s/d2\/a2\/a6/%%d2\/%%a2\/%%a6/gI" $MINTLIBDIR/mintlib/linea.c
    sed -i -e "s/sp@/%%sp@/gI" $MINTLIBDIR/include/mint/linea.h

    sed -i -e "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/compiler.h
    sed -i -e "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/compiler.h
    sed -i -e "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/compiler.h

    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/a4/%a4/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/a5/%a5/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/a6/%a6/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/_normdf.S
 
    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/a4/%a4/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/a5/%a5/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/a6/%a6/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/modf.S
    sed -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/modf.S

    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/a4/%a4/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/a5/%a5/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/a6/%a6/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/a7/%a7/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/setjmp.S

    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/a4/%a4/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/a5/%a5/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/a6/%a6/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/a7/%a7/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/setstack.S
    sed -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/setstack.S

    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/stdlib/alloca.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/stdlib/alloca.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/stdlib/alloca.S

    sed -i -e "s/\tpc@/\t%pc@/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/a1/%a1/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/a2/%a2/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/a3/%a3/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/a4/%a4/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/a5/%a5/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/a6/%a6/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/a7/%a7/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/d4/%d4/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/d5/%d5/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/d1/%d1/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/d2/%d2/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/d3/%d3/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/d7/%d7/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/d6/%d6/gI" $MINTLIBDIR/string/bcopy.S
    sed -i -e "s/exit_%d2/exit_d2/gI" $MINTLIBDIR/string/bcopy.S

    sed -i -e "s/\tpc@/\t%pc@/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/a1/%a1/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/a2/%a2/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/a3/%a3/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/a4/%a4/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/a5/%a5/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/a6/%a6/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/a7/%a7/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/d4/%d4/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/d5/%d5/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/d1/%d1/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/d2/%d2/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/d3/%d3/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/d7/%d7/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/d6/%d6/gI" $MINTLIBDIR/string/bzero.S
    sed -i -e "s/exit_%d2/exit_d2/gI" $MINTLIBDIR/string/bzero.S

    sed -i -e "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/mint/falcon.h
    sed -i -e "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/mint/falcon.h
    sed -i -e "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/falcon.h

    sed -i -e "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/mint/metados.h
    sed -i -e "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/mint/metados.h
    sed -i -e "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/metados.h

    sed -i -e "s/\tpc@/\t%pc@/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/sp/%sp/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/a0/%a0/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/a1/%a1/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/a2/%a2/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/a3/%a3/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/a4/%a4/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/a5/%a5/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/a6/%a6/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/a7/%a7/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/d4/%d4/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/d5/%d5/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/d0/%d0/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/d1/%d1/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/d2/%d2/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/d3/%d3/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/d7/%d7/gI" $MINTLIBDIR/unix/vfork.S
    sed -i -e "s/d6/%d6/gI" $MINTLIBDIR/unix/vfork.S

    # Even though -fleading-underscore is enforced in gcc, it still needs setting in these makefiles
    # Go. Figure.
    # (TODO: unless of course it doesn't any more)
    sed -i -e "s/srcdir)\/time/srcdir)\/time -fleading-underscore/gI" $MINTLIBDIR/tz/Makefile
    sed -i -e "s/TESTDEFS = -D_GNU_SOURCE -D_REENTRANT/TESTDEFS = -D_GNU_SOURCE -D_REENTRANT -fleading-underscore/gI" $MINTLIBDIR/checkrules
    sed -i -e "s/-std=gnu89/-std=gnu89 -fleading-underscore/gI" $MINTLIBDIR/configvars

    # Furhter targets (020+, coldfire)
    sed -i -e "s/sp@+/%sp@+/gI" $MINTLIBDIR/mintlib/checkcpu.S
    sed -i -e "s/\tsp/\t%sp/gI" $MINTLIBDIR/mintlib/checkcpu.S
    
    sed -i -e "s/,sp/,%%sp/gI" $MINTLIBDIR/include/compiler.h
    sed -i -e "s/,sp/,%%%%sp/gI" $MINTLIBDIR/syscall/traps.c
    sed -i -e "s/sp@(/%%%%sp@(/gI" $MINTLIBDIR/syscall/traps.c

    # Extra things (clobbered reg lists etc)
    $SED -i -e 's/\\"d0\\"/\\"%%%%d0\\"/gI' $MINTLIBDIR/syscall/traps.c
    $SED -i -e 's/\\"d1\\"/\\"%%%%d1\\"/gI' $MINTLIBDIR/syscall/traps.c
    $SED -i -e 's/\\"d2\\"/\\"%%%%d2\\"/gI' $MINTLIBDIR/syscall/traps.c
    $SED -i -e 's/\\"a0\\"/\\"%%%%a0\\"/gI' $MINTLIBDIR/syscall/traps.c
    $SED -i -e 's/\\"a1\\"/\\"%%%%a1\\"/gI' $MINTLIBDIR/syscall/traps.c
    $SED -i -e 's/\\"a2\\"/\\"%%%%a2\\"/gI' $MINTLIBDIR/syscall/traps.c
    $SED -i -e "s|/usr\$\$local/m68k-atari-mint|${INSTALL_PREFIX}/m68k-ataribrownerer-elf|gI" $MINTLIBDIR/buildrules

    cd $MINTLIBDIR

    # can't safely use -j with mintlib due to bison/flex dependency ordering woe
    make SHELL=/bin/bash

    # Install the lib.
    # For some reason math.h isn't installed so we do it by hand
    # ¯\_(ツ)_/¯ 
    $SUDO make install
    $SUDO cp include/math.h $INSTALL_PREFIX/m68k-ataribrownerer-elf/include
    if [ "$machine" == "Mac" ]
    then
        $SUDO chmod g+r $INSTALL_PREFIX/m68k-ataribrownerer-elf/include/math.h
    fi

    # Create lib binary package
    make bin-dist

fi

#
# Build libstdc++-v3
#

# *** create local build dir

cd $HOMEDIR/gcc-7.2.0

# Some more permissions need to be fixed here
if [ "$machine" != "Cygwin" ] && [ "$machine" != "MinGw" ] && [ "$machine" != "Mac" ]
then
    $SUDO chmod 755 -R $INSTALL_PREFIX/m68k-ataribrownerer-elf/include/
    $SUDO chmod 755 -R $INSTALL_PREFIX/m68k-ataribrownerer-elf/share/
fi

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Patch libstdc++v3 at the source level (meaning the gcc-7.2.0 files will be tinkered)?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then

    # edit file gcc-7.2.0/libstdc++-v3/configure - comment out the line:
    ##as_fn_error "No support for this host/target combination." "$LINENO" 5

    sed -i -e 's/as_fn_error \"No support for this host\/target combination.\" \"\$LINENO\" 5/#ignored/gI' $HOMEDIR/gcc-7.2.0/libstdc++-v3/configure
    
    # *** hack configure to remove dlopen stuff
    
    # # Libtool setup.
    # if test "x${with_newlib}" != "xyes"; then
    #-  AC_LIBTOOL_DLOPEN
    #+#  AC_LIBTOOL_DLOPEN
    # fi
    sed -i -e "s/  AC_LIBTOOL_DLOPEN/#  AC_LIBTOOL_DLOPEN/gI" $HOMEDIR/gcc-7.2.0/libstdc++-v3/configure.ac
    
    #libstdc++-v3/configure:
    #
    #*** for every instance of: as_fn_error "Link tests are not allowed after GCC_NO_EXECUTABLES." "$LINENO" 5
    #*** change to as_echo_n so the configure doesn't halt on this error
    #
    #  as_echo_n "Link tests are not allowed after GCC_NO_EXECUTABLES." "$LINENO" 5
    sed -i -e "s/  as_fn_error \"Link tests are not allowed after GCC_NO_EXECUTABLES.*/  \$as_echo \"lolol\"/gI" $HOMEDIR/gcc-7.2.0/libstdc++-v3/configure

    #*** remove the contents of cow-stdexcept.cc
    #
    #gcc-7.2.0\libstdc++-v3\src\c++11\cow_stdexcept.cc
    #
    ##if (0)
    #...everything...
    ##endif

    echo "#if (0)" > $HOMEDIR/gcc-7.2.0/libstdc++-v3/src/c++11/cow-stdexcept.cc.new
    cat $HOMEDIR/gcc-7.2.0/libstdc++-v3/src/c++11/cow-stdexcept.cc >> $HOMEDIR/gcc-7.2.0/libstdc++-v3/src/c++11/cow-stdexcept.cc.new
    echo "#endif" >> $HOMEDIR/gcc-7.2.0/libstdc++-v3/src/c++11/cow-stdexcept.cc.new
    mv $HOMEDIR/gcc-7.2.0/libstdc++-v3/src/c++11/cow-stdexcept.cc.new $HOMEDIR/gcc-7.2.0/libstdc++-v3/src/c++11/cow-stdexcept.cc

fi

#*** configure libstdc++-v3

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Patch libstdc++v3's configure scripts?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then
    #*** remove -std=gnu++98 from the toplevel makefile - it gets combined with the c++11 Makefile and causes problems
    #
    #gcc-7.2.0/build/src/Makefile:
    #
    #AM_CXXFLAGS = \
    #	-std=gnu++98 ******** remove this ********
    #	$(glibcxx_compiler_pic_flag) \
    #	$(XTEMPLATE_FLAGS) $(VTV_CXXFLAGS) \
    #	$(WARN_CXXFLAGS) $(OPTIMIZE_CXXFLAGS) $(CONFIG_CXXFLAGS)
    
    cd $HOMEDIR/build-gcc
    $NICE make configure-target-libstdc++-v3
 
    #sed -i -e "s/-std=gnu++98//gI" $HOMEDIR/gcc-7.2.0/build/src/Makefile
    sed -i -e "s/-std=gnu++98//gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/libstdc++-v3/src/Makefile

    
    #*** fix type_traits to avoid macro collision: convert '_CTp' to '_xCTp' because ctypes.h defines _CTp as 0x20
    #*** note: need to investigate why ctypes.h is even present
    #
    #gcc-7.2.0/build/include/type_traits:
    #
    #  template<typename _xCTp, typename... _Args>
    #    struct __expanded_common_type_wrapper
    #    {
    #      typedef common_type<typename _xCTp::type, _Args...> type;
    #    };
    
    #sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/gcc-7.2.0/build/include/type_traits

    # Patch all multilib instances
    # TODO: replace this with a grep or find command
    #       (yeah right, that will happen soon)
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/softfp/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m68060/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m68060/softfp/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/mcpu32/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/mfidoa/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/mfidoa/softfp/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5407/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m54455/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5475/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5475/softfp/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m68040/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m68040/softfp/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m51qe/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5206/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5206e/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5208/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5307/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5329/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m68000/libstdc++-v3/include/type_traits
    sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/libstdc++-v3/include/type_traits

    #*** fix type_traits to favour <cstdint> over those partially-defined wierd builtin int_leastXX, int_fastXX types
    #*** note: this causes multiply defined std:: or missing :: types depending on _GLIBCXX_USE_C99_STDINT_TR1 1/0
    #

    #sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/gcc-7.2.0/build/include/type_traits

    # Patch all multilib instances
    # TODO: replace this with a grep or find command
    #       (yeah right, that will happen soon)
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/softfp/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m68060/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m68060/softfp/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/mcpu32/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/mfidoa/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/mfidoa/softfp/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5407/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m54455/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5475/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5475/softfp/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m68040/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m68040/softfp/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m51qe/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5206/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5206e/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5208/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5307/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m5329/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/m68000/libstdc++-v3/include/type_traits
    sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc/m68k-ataribrownerer-elf/libstdc++-v3/include/type_traits

fi

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Configure, source patch and build glibfortran?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # From what I could see libgfortran only has some function re-declarations
    # This might be possible to fix by passing proper configuration options
    # during configuration, but lolwtfwhocares - let's patch some files! 
    sed -i -e "s/eps = nextafter/eps = __builtin_nextafter/gI" $HOMEDIR/gcc-7.2.0/libgfortran/intrinsics/c99_functions.c
    sed -i -e "s/#ifndef HAVE_GMTIME_R/#if 0/gI" $HOMEDIR/gcc-7.2.0/libgfortran/intrinsics/date_and_time.c
    sed -i -e "s/#ifndef HAVE_LOCALTIME_R/#if 0/gI" $HOMEDIR/gcc-7.2.0/libgfortran/intrinsics/time_1.h
    sed -i -e "s/#ifndef HAVE_STRNLEN/#if 0/gI" $HOMEDIR/gcc-7.2.0/libgfortran/runtime/string.c
    sed -i -e "s/#ifndef HAVE_STRNDUP/#if 0/gI" $HOMEDIR/gcc-7.2.0/libgfortran/runtime/string.c
    sed -i -e "s/${WL}--emit-relocs//gI" $HOMEDIR/build-gcc/Makefile

    make configure-target-libgfortran
    $NICE make $JMULT all-target-libgfortran
    make install-target-libgfortran
fi

#*** build it

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Build and install libstdc++v3?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then
    cd $HOMEDIR/build-gcc
    make all-target-libstdc++-v3 $JMULT
    $SUDO make install-target-libstdc++-v3
fi

# gcc build dir
# build everything else
# (which doesn't amount to much)

cd $HOMEDIR/build-gcc

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Build and install the rest?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then    
    # I dunno why this must be done.
    # It happens on linux mint
    if [ "$machine" != "Cygwin" ] && [ "$machine" != "MinGw" ]
    then
        $SUDO chmod 775 $HOMEDIR/build-gcc/gcc/b-header-vars
    fi
    # This system include isn't picked up for some reason 
    if [ "$machine" == "Mac" ] 
    then
        sed -i -e "s/<gmp.h>/\"\/opt\/local\/include\/gmp.h\"/gI" $HOMEDIR/gcc-7.2.0/gcc/system.h 
    fi 

    $NICE make all $JMULT
    $SUDO make install
    $SUDO strip $INSTALL_PREFIX/bin/*ataribrownerer*
    if [ "$machine" == "Cygwin" ] || [ "$machine" != "MinGw" ] || [ "$machine" != "Mac" ]
    then
        $SUDO strip $INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/cc1* \
			$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/cc1plus* \
			$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/collect2* \
			$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/lto1* \
			$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/lto-wrapper*
    else
        $SUDO strip $INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/cc1* \
			$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/cc1plus* \
			$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/collect2* \
			$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/liblto_plugin.so \
			$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/liblto_plugin.so.0 \
			$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/liblto_plugin.so.0.0.0 \
			$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/lto1 \
			$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/lto-wrapper
    fi
    $SUDO find $INSTALL_PREFIX/m68k-ataribrownerer-elf/lib -name '*.a' -print -exec m68k-ataribrownerer-elf-strip -S -x '{}' ';'
    $SUDO find $INSTALL_PREFIX/lib/gcc/m68k-ataribrownerer-elf/* -name '*.a' -print -exec m68k-ataribrownerer-elf-strip -S -x '{}' ';'
    
fi

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Package up gcc binaries?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then    
    #make install DESTDIR=$PWD/binary-package $JMULT
    make install DESTDIR=$BINPACKAGE_DIR $JMULT
    #cd binary-package
    cd $BINPACKAGE_DIR
    # Since make install uses the non-patched type_traits file let's patch them here too
    # (yes this could have been done before even configuring stdlib++v3 - anyone wants to try?)
    for i in `find . -name type_traits`; do echo Patching $i; sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $i;done

    strip .$INSTALL_PREFIX/bin/*
    if [ "$machine" == "Cygwin" ] || [ "$machine" != "MinGw" ] || [ "$machine" != "Mac" ]
    then
        $SUDO strip .$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/cc1* \
			.$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/cc1plus* \
			.$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/collect2* \
			.$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/lto1* \
			.$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/lto-wrapper*
    else
        $SUDO strip .$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/cc1* \
			.$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/cc1plus* \
			.$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/collect2* \
			.$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/liblto_plugin.so \
			.$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/liblto_plugin.so.0 \
			.$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/liblto_plugin.so.0.0.0 \
			.$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/lto1 \
			.$INSTALL_PREFIX/libexec/gcc/m68k-ataribrownerer-elf/7.2.0/lto-wrapper
    fi

    find .$INSTALL_PREFIX/m68k-ataribrownerer-elf/lib -name '*.a' -print -exec m68k-ataribrownerer-elf-strip -S -x '{}' ';'
    find .$INSTALL_PREFIX/lib/gcc/m68k-ataribrownerer-elf/* -name '*.a' -print -exec m68k-ataribrownerer-elf-strip -S -x '{}' ';'
    $TAR --owner=0 --group=0 -jcvf gcc-7.1-ataribrownererbin.tar.bz2 .$INSTALL_PREFIX
fi

echo "All done!"
echo
echo "If all went well there should be .tar.bz2 files inside"
echo """build-binutils"" and ""build-gcc"" folders"
echo "and mintlib-0.60.1-bin.tar.gz inside ""mintlib-CVS-20160320"" folder!"
