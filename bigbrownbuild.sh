set -e			#stop on any error encountered
#set -x         #echo all commands

#
# Setup stuff
#

# sed_inplace(regex, file_to_replace)
# TODO: When this script was first written it used a very old
#       version of sed that didn't have the in-place switch
#       (-i). So probably replace this function with sed -i?
sed_inplace()
{
    sed -e "$1" $2 > $2.orig
    mv $2.orig $2
}

# Some global stuff that are platform dependent
HOMEDIR=$PWD
SUDO=sudo
NICE='nice -20'
J4=-j4
if [ `uname -o` == "Msys" ]
then
    # Msys has no idea what "sudo" and "nice" are.
    # Also, it's not liking parallel builds that much.
    unset SUDO
    unset NICE
    unset J4
fi
if [ `uname -o` == "Cygwin" ]
then
    # Disable -j4 and sudo for cygwin as well
#    unset J4
    unset SUDO
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
echo "gcc-6.2.0.tar.bz2 (download from one of the mirrors of https://gcc.gnu.org/mirrors.html)"
echo "binutils-2.27.tar.bz2 (download from http://ftp.gnu.org/gnu/binutils/binutils-2.27.tar.bz2)"
echo "mintlib-CVS-20160320.tar.gz (download from http://vincent.riviere.free.fr/soft/m68k-atari-mint/archives/mintlib-CVS-20160320.tar.gz)"
echo
echo "Also, make sure you have installed the following libraries: GMP, MPFR and MPC"
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
    tar -jxvf gcc-6.2.0.tar.bz2
    tar -jxvf binutils-2.27.tar.bz2
    tar -zxvf $HOMEDIR/mintlib-CVS-20160320.tar.gz
fi

# binutils build dir
# Configure, build and install binutils for m68k elf

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Configure and build binutils?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then
    mkdir -p $HOMEDIR/build-binutils
    cd $HOMEDIR/build-binutils
    ../binutils-2.27/configure --disable-multilib --disable-nls --enable-lto --prefix=/usr --target=m68k-ataribrown-elf
    make
    $SUDO make install

    # Package up binutils

    make install DESTDIR=$PWD/binary-package
    cd binary-package
    strip usr/bin/*
    gzip -9 usr/share/man/*/*.1    
    tar --owner=0 --group=0 -jcvf m68k-ataribrown-elf.tar.bz2 usr/
fi

# home directory
cd $HOMEDIR

# XXX: Moved to libstdc++v3 section and commented out here - re-enable it
#      if it causes problems
# Comment out errors we don't care about much

# edit file gcc-6.2.0/libstdc++-v3/configure - comment out the line:
##as_fn_error "No support for this host/target combination." "$LINENO" 5

#if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
#    REPLY=Y
#else    
#    read -p "Placebo patch libstdc++-v3 configure (not sure if it's needed)?" -n 1 -r
#    echo
#fi
#if [[ $REPLY =~ ^[Yy]$ ]]
#then
#    sed_inplace 's/as_fn_error \"No support for this host\/target combination.\" \"\$LINENO\" 5/#ignored/gI' $HOMEDIR/gcc-6.2.0/libstdc++-v3/configure
#fi

#
# gcc build dir
# Configure, build and install gcc without any libs for now
#

# Export flags for target compiler as well as pass them on configuration time.
# Who knows, maybe one of the two will actually work!
export CFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fno-threadsafe-statics -fleading-underscore"
export CXXFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fno-threadsafe-statics -fno-exceptions -fno-rtti -fleading-underscore"
export LDFLAGS_FOR_TARGET="--emit-relocs -Ttext=0"
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
    ../gcc-6.2.0/configure \
        --target=m68k-ataribrown-elf \
        --disable-nls \
        --enable-languages=c,c++ \
        --enable-lto \
        --prefix=/usr \
        --disable-libssp \
        --enable-softfloat \
        --disable-libstdcxx-pch \
        --disable-clocale \
        --disable-libstdcxx-threads \
        --disable-libstdcxx-filesystem-ts \
        --disable-libquadmath \
        --enable-cxx-flags='-O2 -fomit-frame-pointer -fno-threadsafe-statics -fno-exceptions -fno-rtti -fleading-underscore' \
        CFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fno-threadsafe-statics -fleading-underscore" \
        CXXFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fno-threadsafe-statics -fno-exceptions -fno-rtti -fleading-underscore" \
        LDFLAGS_FOR_TARGET="--emit-relocs -Ttext=0"
    $NICE make all-gcc $J4
    $SUDO make install-gcc

    # In some linux distros (linux mint for example) it was observed
    # that make install-gcc didn't set the read permission for users
    # so gcc couldn't work properly. No idea how to fix this propery
    # which means - botch time!                                     
    $SUDO chmod 755 -R /usr/m68k-ataribrown-elf/                   
    $SUDO chmod 755 -R /usr/libexec/gcc/m68k-ataribrown-elf/       
    $SUDO chmod 755 -R /usr/lib/gcc/m68k-ataribrown-elf/           


fi
# TODO:
# Other candidates to pass to configure:
# This probably won't be used:
#        --disable-multilib \
# Dunno, does anyone NEED unicode for building ST applications?
#        --disable-wchar_t \
# These are very likely to go in:
#        --enable-cxx-flags='-fno-exceptions -fno-rtti' \
# Probably not needed?
#        --with-gxx-include-dir=/usr/m68k-ataribrown-elf/6.2.0/include
# This ditches all coldfire lib building stuff:
#        --with-arch=m68k


#
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
    $NICE make all-target-libgcc $J4
    $SUDO make install-target-libgcc
fi

#
# Mintlib 
#

# Patch mintlib at the source level
cd $HOMEDIR

# Some extra permissions
$SUDO chmod 755 -R /usr/libexec/            

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Unpack, source patch and build mintlib?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then

    MINTLIBDIR=$HOMEDIR/mintlib-CVS-20160320

    #Requires packages bison-bin,flex-bin,flex-dev
    #
    if [ `uname -o` == "Msys" ]
    then

    #   Because MinGW/Msys has mixed forward/backward slashs in paths, convert
    #	installdir=`$(CC) --print-search-dirs | awk '{ print $$2; exit; }'`; \
    #   to:
    #	installdir=`$(CC) --print-search-dirs | awk '{ print $$2; exit; }' | sed -e 's/\\\\/\//gI'`; \
    #   .....
    #   I need a drink...
        sed_inplace $'s/2; exit; }\'`/2; exit; }\' | sed -e \'s\/\\\\\\\\\\\\\\\\\/\\\\\/\/gi\' `/gI' $MINTLIBDIR/buildrules
    fi

    # Set C standard to avoid shit blow up
    sed_inplace "s/-O2 -fomit-frame-pointer/-O2 -fomit-frame-pointer -std=gnu89/gI" $MINTLIBDIR/configvars

    # Set cross compiler
    sed_inplace "s/#CROSS=yes/CROSS=yes/gI" $MINTLIBDIR/configvars
    sed_inplace "s/m68k-atari-mint/m68k-ataribrown-elf/gI" $MINTLIBDIR/configvars

    # Convert syntax into new gcc/gas format

    sed_inplace "s/|/\/\//gI" $MINTLIBDIR/startup/crt0.S
    sed_inplace "s/a6/%a6/gI" $MINTLIBDIR/startup/crt0.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/startup/crt0.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/startup/crt0.S
    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/startup/crt0.S
    
    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/dirent/closedir.c
    
    sed_inplace "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/mint/mintbind.h
    sed_inplace "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/mint/mintbind.h
    sed_inplace "s/,sp \"/,%%sp\"/gI" $MINTLIBDIR/include/mint/mintbind.h
    sed_inplace "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/mintbind.h
    sed_inplace "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/mint/osbind.h
    sed_inplace "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/mint/osbind.h
    sed_inplace "s/,sp\\\\n/,%%sp\\\\n/gI" $MINTLIBDIR/include/mint/osbind.h
    sed_inplace "s/,sp \"/,%%sp\"/gI" $MINTLIBDIR/include/mint/osbind.h
    sed_inplace "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/osbind.h

    sed_inplace "s/sp@-/%sp@-/gI" $MINTLIBDIR/mintlib/checkcpu.S
    sed_inplace "s/,sp/,%sp/gI" $MINTLIBDIR/mintlib/checkcpu.S

    sed_inplace "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/osbind.h

    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/mintlib/frexp.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/mintlib/frexp.S
    sed_inplace "s/a1/%a1/gI" $MINTLIBDIR/mintlib/frexp.S
    sed_inplace "s/d4/%d4/gI" $MINTLIBDIR/mintlib/frexp.S
    sed_inplace "s/d5/%d5/gI" $MINTLIBDIR/mintlib/frexp.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/mintlib/frexp.S
    sed_inplace "s/d1/%d1/gI" $MINTLIBDIR/mintlib/frexp.S
    sed_inplace "s/d2/%d2/gI" $MINTLIBDIR/mintlib/frexp.S
    sed_inplace "s/d3/%d3/gI" $MINTLIBDIR/mintlib/frexp.S
    sed_inplace "s/d7/%d7/gI" $MINTLIBDIR/mintlib/frexp.S
    sed_inplace "s/d6/%d6/gI" $MINTLIBDIR/mintlib/frexp.S
 
    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed_inplace "s/5%a0/5a0/gI" $MINTLIBDIR/mintlib/getcookie.S #lolol
    sed_inplace "s/a1/%a1/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed_inplace "s/a2/%a2/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed_inplace "s/a3/%a3/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed_inplace "s/d4/%d4/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed_inplace "s/d5/%d5/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed_inplace "s/d1/%d1/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed_inplace "s/d2/%d2/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed_inplace "s/d3/%d3/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed_inplace "s/d7/%d7/gI" $MINTLIBDIR/mintlib/getcookie.S
    sed_inplace "s/d6/%d6/gI" $MINTLIBDIR/mintlib/getcookie.S
 
    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed_inplace "s/a1/%a1/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed_inplace "s/a2/%a2/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed_inplace "s/a3/%a3/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed_inplace "s/d4/%d4/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed_inplace "s/d5/%d5/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed_inplace "s/d1/%d1/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed_inplace "s/d2/%d2/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed_inplace "s/d3/%d3/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed_inplace "s/d7/%d7/gI" $MINTLIBDIR/mintlib/getsysvar.S
    sed_inplace "s/d6/%d6/gI" $MINTLIBDIR/mintlib/getsysvar.S
 
    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed_inplace "s/a1/%a1/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed_inplace "s/a2/%a2/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed_inplace "s/a3/%a3/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed_inplace "s/d4/%d4/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed_inplace "s/d5/%d5/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed_inplace "s/d1/%d1/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed_inplace "s/d2/%d2/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed_inplace "s/d3/%d3/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed_inplace "s/d7/%d7/gI" $MINTLIBDIR/mintlib/ldexp.S
    sed_inplace "s/d6/%d6/gI" $MINTLIBDIR/mintlib/ldexp.S
 
    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/a1/%a1/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/a2/%a2/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/a3/%a3/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/a4/%a4/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/a5/%a5/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/a6/%a6/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/d4/%d4/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/d5/%d5/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/d1/%d1/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/d2/%d2/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/d3/%d3/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/d7/%d7/gI" $MINTLIBDIR/mintlib/libc_exit.S
    sed_inplace "s/d6/%d6/gI" $MINTLIBDIR/mintlib/libc_exit.S
 
    sed_inplace "s/d2\/a2\/a6/%%d2\/%%a2\/%%a6/gI" $MINTLIBDIR/include/mint/linea.h
    sed_inplace "s/d2\/a2\/a6/%%d2\/%%a2\/%%a6/gI" $MINTLIBDIR/mintlib/linea.c
    sed_inplace "s/sp@/%%sp@/gI" $MINTLIBDIR/include/mint/linea.h

    sed_inplace "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/compiler.h
    sed_inplace "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/compiler.h
    sed_inplace "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/compiler.h

    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/a1/%a1/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/a2/%a2/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/a3/%a3/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/a4/%a4/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/a5/%a5/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/a6/%a6/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/d4/%d4/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/d5/%d5/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/d1/%d1/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/d2/%d2/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/d3/%d3/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/d7/%d7/gI" $MINTLIBDIR/mintlib/_normdf.S
    sed_inplace "s/d6/%d6/gI" $MINTLIBDIR/mintlib/_normdf.S
 
    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/a1/%a1/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/a2/%a2/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/a3/%a3/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/a4/%a4/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/a5/%a5/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/a6/%a6/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/d4/%d4/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/d5/%d5/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/d1/%d1/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/d2/%d2/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/d3/%d3/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/d7/%d7/gI" $MINTLIBDIR/mintlib/modf.S
    sed_inplace "s/d6/%d6/gI" $MINTLIBDIR/mintlib/modf.S

    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/a1/%a1/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/a2/%a2/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/a3/%a3/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/a4/%a4/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/a5/%a5/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/a6/%a6/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/a7/%a7/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/d4/%d4/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/d5/%d5/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/d1/%d1/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/d2/%d2/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/d3/%d3/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/d7/%d7/gI" $MINTLIBDIR/mintlib/setjmp.S
    sed_inplace "s/d6/%d6/gI" $MINTLIBDIR/mintlib/setjmp.S

    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/a1/%a1/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/a2/%a2/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/a3/%a3/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/a4/%a4/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/a5/%a5/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/a6/%a6/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/a7/%a7/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/d4/%d4/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/d5/%d5/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/d1/%d1/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/d2/%d2/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/d3/%d3/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/d7/%d7/gI" $MINTLIBDIR/mintlib/setstack.S
    sed_inplace "s/d6/%d6/gI" $MINTLIBDIR/mintlib/setstack.S

    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/stdlib/alloca.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/stdlib/alloca.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/stdlib/alloca.S

    sed_inplace "s/\tpc@/\t%pc@/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/a1/%a1/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/a2/%a2/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/a3/%a3/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/a4/%a4/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/a5/%a5/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/a6/%a6/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/a7/%a7/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/d4/%d4/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/d5/%d5/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/d1/%d1/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/d2/%d2/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/d3/%d3/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/d7/%d7/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/d6/%d6/gI" $MINTLIBDIR/string/bcopy.S
    sed_inplace "s/exit_%d2/exit_d2/gI" $MINTLIBDIR/string/bcopy.S

    sed_inplace "s/\tpc@/\t%pc@/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/a1/%a1/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/a2/%a2/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/a3/%a3/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/a4/%a4/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/a5/%a5/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/a6/%a6/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/a7/%a7/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/d4/%d4/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/d5/%d5/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/d1/%d1/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/d2/%d2/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/d3/%d3/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/d7/%d7/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/d6/%d6/gI" $MINTLIBDIR/string/bzero.S
    sed_inplace "s/exit_%d2/exit_d2/gI" $MINTLIBDIR/string/bzero.S

    sed_inplace "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/mint/falcon.h
    sed_inplace "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/mint/falcon.h
    sed_inplace "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/falcon.h

    sed_inplace "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/mint/metados.h
    sed_inplace "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/mint/metados.h
    sed_inplace "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/metados.h

    sed_inplace "s/\tpc@/\t%pc@/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/sp/%sp/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/a0/%a0/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/a1/%a1/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/a2/%a2/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/a3/%a3/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/a4/%a4/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/a5/%a5/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/a6/%a6/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/a7/%a7/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/d4/%d4/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/d5/%d5/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/d0/%d0/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/d1/%d1/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/d2/%d2/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/d3/%d3/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/d7/%d7/gI" $MINTLIBDIR/unix/vfork.S
    sed_inplace "s/d6/%d6/gI" $MINTLIBDIR/unix/vfork.S

    # Even though -fleading-underscore is enforced in gcc, it still needs setting in these makefiles
    # Go. Figure.
    # (TODO: unless of course it doesn't any more)
    sed_inplace "s/srcdir)\/time/srcdir)\/time -fleading-underscore/gI" $MINTLIBDIR/tz/Makefile
    sed_inplace "s/TESTDEFS = -D_GNU_SOURCE -D_REENTRANT/TESTDEFS = -D_GNU_SOURCE -D_REENTRANT -fleading-underscore/gI" $MINTLIBDIR/checkrules
    sed_inplace "s/-std=gnu89/-std=gnu89 -fleading-underscore/gI" $MINTLIBDIR/configvars

    # Furhter targets (020+, coldfire)
    sed_inplace "s/sp@+/%sp@+/gI" $MINTLIBDIR/mintlib/checkcpu.S
    sed_inplace "s/\tsp/\t%sp/gI" $MINTLIBDIR/mintlib/checkcpu.S
    
    sed_inplace "s/,sp/,%%sp/gI" $MINTLIBDIR/include/compiler.h
    sed_inplace "s/,sp/,%%%%sp/gI" $MINTLIBDIR/syscall/traps.c
    sed_inplace "s/sp@(/%%%%sp@(/gI" $MINTLIBDIR/syscall/traps.c

    # Extra things (clobbered reg lists etc)
    sed -i -e 's/\\"d0\\"/\\"%%%d0\\"/gI' $MINTLIBDIR/syscall/traps.c
    sed -i -e 's/\\"d1\\"/\\"%%%%d1\\"/gI' $MINTLIBDIR/syscall/traps.c
    sed -i -e 's/\\"d2\\"/\\"%%%%d2\\"/gI' $MINTLIBDIR/syscall/traps.c
    sed -i -e 's/\\"a0\\"/\\"%%%%a0\\"/gI' $MINTLIBDIR/syscall/traps.c
    sed -i -e 's/\\"a1\\"/\\"%%%%a1\\"/gI' $MINTLIBDIR/syscall/traps.c
    sed -i -e 's/\\"a2\\"/\\"%%%%a2\\"/gI' $MINTLIBDIR/syscall/traps.c
    sed -i -e 's/%d0/%%d0/gI' $MINTLIBDIR/syscall/traps.c

    cd $MINTLIBDIR

    make SHELL=/bin/bash $J4
    #make SHELL=/bin/bash

    # Install the lib.
    # For some reason math.h isn't installed so we do it by hand
    # ¯\_(ツ)_/¯ 
    $SUDO make install
    $SUDO cp include/math.h /usr/m68k-ataribrown-elf/include

fi

#
# Build libstdc++-v3
#

# *** create local build dir

cd $HOMEDIR/gcc-6.2.0

# Some more permissions need to be fixed here
    $SUDO chmod 755 -R /usr/m68k-ataribrown-elf/include/
    $SUDO chmod 755 -R /usr/m68k-ataribrown-elf/share/


if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Patch libstdc++v3 at the source level (meaning the gcc-6.2.0 files will be tinkered)?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then

    # edit file gcc-6.2.0/libstdc++-v3/configure - comment out the line:
    ##as_fn_error "No support for this host/target combination." "$LINENO" 5

    sed_inplace 's/as_fn_error \"No support for this host\/target combination.\" \"\$LINENO\" 5/#ignored/gI' $HOMEDIR/gcc-6.2.0/libstdc++-v3/configure
    
    # *** hack configure to remove dlopen stuff
    
    # # Libtool setup.
    # if test "x${with_newlib}" != "xyes"; then
    #-  AC_LIBTOOL_DLOPEN
    #+#  AC_LIBTOOL_DLOPEN
    # fi
    sed_inplace "s/  AC_LIBTOOL_DLOPEN/#  AC_LIBTOOL_DLOPEN/gI" $HOMEDIR/gcc-6.2.0/libstdc++-v3/configure.ac
    
    #libstdc++-v3/configure:
    #
    #*** for every instance of: as_fn_error "Link tests are not allowed after GCC_NO_EXECUTABLES." "$LINENO" 5
    #*** change to as_echo_n so the configure doesn't halt on this error
    #
    #  as_echo_n "Link tests are not allowed after GCC_NO_EXECUTABLES." "$LINENO" 5
    sed_inplace "s/  as_fn_error \"Link tests are not allowed after GCC_NO_EXECUTABLES.*/  \$as_echo \"lolol\"/gI" $HOMEDIR/gcc-6.2.0/libstdc++-v3/configure

    #*** remove the contents of cow-stdexcept.cc
    #
    #gcc-6.2.0\libstdc++-v3\src\c++11\cow_stdexcept.cc
    #
    ##if (0)
    #...everything...
    ##endif

    echo "#if (0)" > $HOMEDIR/gcc-6.2.0/libstdc++-v3/src/c++11/cow-stdexcept.cc.new
    cat $HOMEDIR/gcc-6.2.0/libstdc++-v3/src/c++11/cow-stdexcept.cc >> $HOMEDIR/gcc-6.2.0/libstdc++-v3/src/c++11/cow-stdexcept.cc.new
    echo "#endif" >> $HOMEDIR/gcc-6.2.0/libstdc++-v3/src/c++11/cow-stdexcept.cc.new
    mv $HOMEDIR/gcc-6.2.0/libstdc++-v3/src/c++11/cow-stdexcept.cc.new $HOMEDIR/gcc-6.2.0/libstdc++-v3/src/c++11/cow-stdexcept.cc

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
    #gcc-6.2.0/build/src/Makefile:
    #
    #AM_CXXFLAGS = \
    #	-std=gnu++98 ******** remove this ********
    #	$(glibcxx_compiler_pic_flag) \
    #	$(XTEMPLATE_FLAGS) $(VTV_CXXFLAGS) \
    #	$(WARN_CXXFLAGS) $(OPTIMIZE_CXXFLAGS) $(CONFIG_CXXFLAGS)
    
    cd $HOMEDIR/build-gcc
    make configure-target-libstdc++-v3
 
    #sed_inplace "s/-std=gnu++98//gI" $HOMEDIR/gcc-6.2.0/build/src/Makefile
    sed_inplace "s/-std=gnu++98//gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/libstdc++-v3/src/Makefile
    
    #*** fix type_traits to avoid macro collision: convert '_CTp' to '_xCTp' because ctypes.h defines _CTp as 0x20
    #*** note: need to investigate why ctypes.h is even present
    #
    #gcc-6.2.0/build/include/type_traits:
    #
    #  template<typename _xCTp, typename... _Args>
    #    struct __expanded_common_type_wrapper
    #    {
    #      typedef common_type<typename _xCTp::type, _Args...> type;
    #    };
    
    #sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/gcc-6.2.0/build/include/type_traits

    # Patch all multilib instances
    # TODO: replace this with a grep or find command
    #       (yeah right, that will happen soon)
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/softfp/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m68060/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m68060/softfp/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/mcpu32/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/mfidoa/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/mfidoa/softfp/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5407/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m54455/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5475/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5475/softfp/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m68040/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m68040/softfp/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m51qe/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5206/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5206e/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5208/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5307/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5329/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m68000/libstdc++-v3/include/type_traits
    sed_inplace "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/libstdc++-v3/include/type_traits


    #*** fix c++config.h to remove conflicts for sized fundamental types
    #	
    #gcc-6.2.0\build\include\m68k-ataribrown-elf\bits\c++config.h
    #
    ##undef _GLIBCXX_USE_C99_STDINT_TR1
    
    #sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/gcc-6.2.0/build/include/m68k-ataribrown-elf/bits/c++config.h

    # Patch all multilib instances
    # TODO: yeah yeah quite possibly not going to do
    #       something simpler, ever. Bite me.
    
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/mfidoa/softfp/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5475/softfp/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m68060/softfp/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m68040/softfp/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m68040/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m68060/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/mcpu32/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m51qe/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5206/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5206e/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5208/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5307/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5329/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5407/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m54455/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m5475/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/mfidoa/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/m68000/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h
    sed_inplace "s/#define.*_GLIBCXX_USE_C99_STDINT_TR1/\/\/# disabled/gI" $HOMEDIR/build-gcc/m68k-ataribrown-elf/softfp/libstdc++-v3/include/m68k-ataribrown-elf/bits/c++config.h 

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
    make all-target-libstdc++-v3 $J4
    $SUDO make install-target-libstdc++-v3
fi

# gcc build dir
# build everything else
# (which doesn't amount to much)

cd $HOMEDIR/build-gcc

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Build the rest?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then    
    # I dunno why this must be done.
    # It happens on linux mint
    $SUDO chmod 775 $HOMEDIR/build-gcc/gcc/b-header-vars
    
    make all $J4

    make install DESTDIR=$PWD/binary-package $J4
fi

if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
    REPLY=Y
else    
    read -p "Package up binaries?" -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then    
    cd binary-package
    #rm -r include
    #rm    lib/*.a
    #rm -r share/info
    #rm -r share/man/man7
    strip usr/bin/*
    strip usr/libexec/gcc/m68k-ataribrown-elf/6.2.0/*
    strip usr/libexec/gcc/m68k-ataribrown-elf/6.2.0/install-tools/*
    find usr/m68k-ataribrown-elf/lib -name '*.a' -print -exec m68k-ataribrown-elf-strip -S -x '{}' ';'
    find usr/lib/gcc/m68k-ataribrown-elf/* -name '*.a' -print -exec m68k-ataribrown-elf-strip -S -x '{}' ';'
fi

echo "All done - thank you, drive through!"
 
