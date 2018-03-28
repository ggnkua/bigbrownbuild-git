set -e			#stop on any error encountered
#set -x                  #echo all commands

mainbrown()
{

    #
    # Make sure this is being run under bash
    # Very bad things happen on other shells (like sh)
    #
    
    if [ -z "$BASH_VERSION"  ]; then
        echo "Please run this script under bash!"
        exit
    fi	

    #   
    # User definable stuff
    #

    # Set this to "A" if you want a completely automated run
    GLOBAL_OVERRIDE=A
    
    # Which gccs to build. 1=Build, anything else=Don't build
    BUILD_4_6_4=1  # Produces Internal Compiler Error when built with gcc 4.8.5?
    BUILD_4_9_4=1
    BUILD_5_4_0=1
    BUILD_6_2_0=1
    BUILD_7_1_0=1
    BUILD_7_2_0=1
    BUILD_7_3_0=1

    # Should we run this as an administrator or user?
    # Administrator mode will install the compiler in
    # the system's folders and will require root priviledges
    RUN_MODE=Admin
    #RUN_MODE=User

    # How are the various gcc versions named. This is tuned for ubuntu 17.10
    # so your mileage may vary! Also you might be able to build all gcc versions using one
    # compiler - so many problems were encountered in Ubuntu (including Internal Compiler
    # Errors) that this is now in full pendantic mode. Again, your mileage may vary!
    CC4=gcc
    CXX4=g++
    CC5=gcc
    CXX5=g++
    CC6=gcc-4.8
    CXX6=g++-4.8
    CC7=gcc-4.8
    CXX7=g++-4.8

    # Some global stuff that are platform dependent
    HOMEDIR=$PWD
    NICE='nice -20'
    JMULT=-j4
    BINPACKAGE_DIR=$PWD/binary-package
    SED=sed
    TAR=tar

    # Only set this to nonzero when you do want to build mintlib
    # Note that if you don't build mintlib then libstdc++v3 will also fail to build
    BUILD_MINTLIB=1
    
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
   
    # If building 4.6.4 warn the user that the coldfire mintlib is hosed
    # and thus disabled for now

    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        SKIP_464_CF=Y
    else
        if [ "$BUILD_4_6_4" == "1" ]; then
            echo You\'re building gcc 4.6.4
            echo Be aware that currently when building MiNTlib the cross compiler
            echo throws an Internal Compiler Error when trying to build the coldfire
            echo target, thus it is disabled. Answer no to the question below
            echo otherwise and/or file a report to the authors if you know how
            echo to overcome this!
            read -p "Disable building MiNTlib for coldfire on 4.6.4?" -n 1 -r SKIP_464_CF
            echo
        fi
    fi
  
    if [ "$RUN_MODE" == "Admin" ]
    then
        # Administrator mode
        SUDO=sudo
        if [ "$machine" == "Mac" ]
        then
            INSTALL_PREFIX_GLOBAL=/opt/local/
        else
            INSTALL_PREFIX_GLOBAL=/opt/compiler-explorer
        fi
    else
        # User mode
        SUDO=
        #INSTALL_PREFIX_GLOBAL=${HOME}/localINSTALL_PREFIX
        INSTALL_PREFIX_GLOBAL=${HOME}/opt
    fi

    # Seems that docker doesn't like/need sudo?
    SUDO=    

    # Cleanup folders
    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        CLEANUP=Y
    else    
        read -p "Cleanup build dirs from previous build?" -n 1 -r
        echo
    fi
    if [[ $CLEANUP =~ ^[Yy]$ ]]
    then
        rm -rf binary-package 
        rm -rf binutils-2.27
        rm -rf mintlib-bigbrownbuild
    fi
    
    # Get all the things
    
    if [ "$BUILD_4_6_4" == "1" ]; then if [ ! -f gcc-4.6.4.tar.bz2 ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-4.6.4/gcc-4.6.4.tar.bz2; fi; fi
    if [ "$BUILD_4_9_4" == "1" ]; then if [ ! -f gcc-4.9.4.tar.bz2 ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-4.9.4/gcc-4.9.4.tar.bz2; fi; fi
    if [ "$BUILD_5_4_0" == "1" ]; then if [ ! -f gcc-5.4.0.tar.bz2 ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-5.4.0/gcc-5.4.0.tar.bz2; fi; fi
    if [ "$BUILD_6_2_0" == "1" ]; then if [ ! -f gcc-6.2.0.tar.bz2 ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-6.2.0/gcc-6.2.0.tar.bz2; fi; fi
    if [ "$BUILD_7_1_0" == "1" ]; then if [ ! -f gcc-7.1.0.tar.bz2 ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-7.1.0/gcc-7.1.0.tar.bz2; fi; fi
    if [ "$BUILD_7_2_0" == "1" ]; then if [ ! -f gcc-7.2.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-7.2.0/gcc-7.2.0.tar.xz; fi; fi
    if [ "$BUILD_7_3_0" == "1" ]; then if [ ! -f gcc-7.3.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-7.3.0/gcc-7.3.0.tar.xz; fi; fi
    if [ ! -f binutils-2.27.tar.bz2 ]; then wget http://ftp.gnu.org/gnu/binutils/binutils-2.27.tar.bz2; fi
    if [ ! -d mintlib-bigbrownbuild ]; then git clone https://github.com/ggnkua/mintlib-bigbrownbuild.git; fi
    # requires GMP, MPFR and MPC
    
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
        if [ "$CLEANUP" == "Y" ]; then
            if [ "$BUILD_4_6_4" == "1" ]; then rm -rf gcc-4.6.4; fi
            if [ "$BUILD_4_9_4" == "1" ]; then rm -rf gcc-4.9.4; fi
            if [ "$BUILD_5_4_0" == "1" ]; then rm -rf gcc-5.4.0; fi
            if [ "$BUILD_6_2_0" == "1" ]; then rm -rf gcc-6.2.0; fi
            if [ "$BUILD_7_1_0" == "1" ]; then rm -rf gcc-7.1.0; fi
            if [ "$BUILD_7_2_0" == "1" ]; then rm -rf gcc-7.2.0; fi
            if [ "$BUILD_7_3_0" == "1" ]; then rm -rf gcc-7.3.0; fi
        fi    
        if [ "$BUILD_4_6_4" == "1" ]; then tar -jxvf gcc-4.6.4.tar.bz2; fi
        if [ "$BUILD_4_9_4" == "1" ]; then tar -jxvf gcc-4.9.4.tar.bz2; fi
        if [ "$BUILD_5_4_0" == "1" ]; then tar -jxvf gcc-5.4.0.tar.bz2; fi
        if [ "$BUILD_6_2_0" == "1" ]; then tar -jxvf gcc-6.2.0.tar.bz2; fi
        if [ "$BUILD_7_1_0" == "1" ]; then tar -jxvf gcc-7.1.0.tar.bz2; fi
        if [ "$BUILD_7_2_0" == "1" ]; then tar -Jxvf gcc-7.2.0.tar.xz; fi
        if [ "$BUILD_7_3_0" == "1" ]; then tar -Jxvf gcc-7.3.0.tar.xz; fi
        tar -jxvf binutils-2.27.tar.bz2
    fi
   
    # 
    # Start the build
    #

    # This might be needed as gcc 7.2 doesn't seem to build 4.6.4...
    # Note that these exports are ubuntu 17.10 specific, you might need to change them depending on your distro!
    export CC=$CC4
    export CXX=$CXX4
    # Building Fortran for old gcc versions doesn't seem to work so it's disabled for now...
    BUILD_FORTRAN=0
    
    if [ "$BUILD_4_6_4" == "1" ]; then buildgcc 4.6.4; fi
    if [ "$BUILD_4_9_4" == "1" ]; then buildgcc 4.9.4; fi
                                       
    export CC=$CC5
    export CXX=$CXX5
                                       
    if [ "$BUILD_5_4_0" == "1" ]; then buildgcc 5.4.0; fi
                                       
    export CC=$CC6
    export CXX=$CXX6
    if [ "$BUILD_6_2_0" == "1" ]; then buildgcc 6.2.0; fi
                                       
    export CC=$CC7
    export CXX=$CXX7
    BUILD_FORTRAN=1
    if [ "$BUILD_7_1_0" == "1" ]; then buildgcc 7.1.0; fi
    if [ "$BUILD_7_2_0" == "1" ]; then buildgcc 7.2.0; fi
    if [ "$BUILD_7_3_0" == "1" ]; then buildgcc 7.3.0; fi
    
    echo "All done!"
}

# Build subroutine
# Parameter 1=version

buildgcc()
{
    # Construct compiler vendor name

    VENDOR=$1
    INSTALL_PREFIX=$INSTALL_PREFIX_GLOBAL/gcc68k-$VENDOR
    export PATH=${INSTALL_PREFIX}/bin:$PATH

    # Clean build folders if requested
    if [ "$CLEANUP" == "Y" ]; then rm -rf build-gcc-$1 build-binutils-$1 mintlib-bigbrownbuild-$1; cp -frp mintlib-bigbrownbuild mintlib-bigbrownbuild-$1; fi

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
        mkdir -p $HOMEDIR/build-binutils-$1
        cd $HOMEDIR/build-binutils-$1
        ../binutils-2.27/configure --disable-multilib --disable-nls --enable-lto --prefix=$INSTALL_PREFIX --target=m68k-$VENDOR-elf
        make
        $SUDO make install
        $SUDO strip $INSTALL_PREFIX/bin/*$VENDOR*
        $SUDO strip $INSTALL_PREFIX/m68k-$VENDOR-elf/bin/*
        $SUDO gzip -f -9 $INSTALL_PREFIX/share/man/*/*.1
    
        # Package up binutils
    
        make install DESTDIR=$BINPACKAGE_DIR
        cd $BINPACKAGE_DIR
        strip .$INSTALL_PREFIX/bin/*
        strip .$INSTALL_PREFIX/m68k-$VENDOR-elf/bin/*
        gzip -f -9 .$INSTALL_PREFIX/share/man/*/*.1
        $TAR --owner=0 --group=0 -jcvf binutils-2.27-$VENDOR-bin.tar.bz2 .$INSTALL_PREFIX
    fi
    
    # Clean install dir
    rm -rf $BINPACKAGE_DIR/$INSTALL_PREFIX
    
    # home directory
    cd $HOMEDIR
    
    #
    # gcc build dir
    # Configure, build and install gcc without any libs for now
    #
    
    # Export flags for target compiler as well as pass them on configuration time.
    # Who knows, maybe one of the two will actually work!
    
    # Fortran is enabled now, but there are still issues when compiling
    # a program with it...
    #LANGUAGES=c,c++,fortran
    LANGUAGES=c,c++
    WL=
    
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
        mkdir -p $HOMEDIR/build-gcc-$1
        cd $HOMEDIR/build-gcc-$1
        ../gcc-$1/configure \
            --target=m68k-$VENDOR-elf \
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
            $SUDO chmod 755 -R $INSTALL_PREFIX/m68k-$VENDOR-elf/
            $SUDO chmod 755 -R $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/
            $SUDO chmod 755 -R $INSTALL_PREFIX/lib/gcc/m68k-$VENDOR-elf/
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
    
    cd $HOMEDIR/build-gcc-$1
    
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

    if [ "$BUILD_MINTLIB" != "0" ]
    then

        # Patch mintlib at the source level
        cd $HOMEDIR
        
        if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
            REPLY=Y
        else    
            read -p "Source patch and build mintlib?" -n 1 -r
            echo
        fi
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
        
            MINTLIBDIR=$HOMEDIR/mintlib-bigbrownbuild-$1
        
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
            
            # When building using cross-gcc-4.6.4 the compilers ICE with coldifre targets at
            # stdio/printf_fp.c. So let's disable this...
            if [[ $SKIP_464_CF =~ ^[Yy]$ ]]; then
                $SED -i -e "s/WITH_V4E_LIB/#WITH_V4E_LIB  #disabled since we get Internal Compiler Error :(/gI" $MINTLIBDIR/configvars
            fi
            
            if [ "$machine" == "MinGw" ]
            then
        
            #   Because MinGW/Msys has mixed forward/backward slashs in paths, convert
            #	installdir=`$(CC) --print-search-dirs | awk '{ print $$2; exit; }'`; \
            #   to:
            #	installdir=`$(CC) --print-search-dirs | awk '{ print $$2; exit; }' | sed -e 's/\\\\/\//gI'`; \
            #   .....
            #   I need a drink...
                $SED -i -e $'s/2; exit; }\'`/2; exit; }\' | sed -e \'s\/\\\\\\\\\\\\\\\\\/\\\\\/\/gi\' `/gI' $MINTLIBDIR/buildrules
            fi
        
            # Set C standard to prevent shit from blowing up
            $SED -i -e "s/-O2 -fomit-frame-pointer/-O2 -fomit-frame-pointer -std=gnu89/gI" $MINTLIBDIR/configvars
        
            # Set cross compiler
            $SED -i -e "s/AM_DEFAULT_VERBOSITY = 1/AM_DEFAULT_VERBOSITY = 0/gI" $MINTLIBDIR/configvars
            $SED -i -e "s/#CROSS=yes/CROSS=yes/gI" $MINTLIBDIR/configvars
            $SED -i -e "s|prefix=/usr/m68k-atari-mint|prefix=${INSTALL_PREFIX}/m68k-$VENDOR-elf|gI" $MINTLIBDIR/configvars
            $SED -i -e "s/m68k-atari-mint/m68k-$VENDOR-elf/gI" $MINTLIBDIR/configvars
        
            # Convert syntax into new gcc/gas format
        
            $SED -i -e "s/|/\/\//gI" $MINTLIBDIR/startup/crt0.S
            $SED -i -e "s/a6/%a6/gI" $MINTLIBDIR/startup/crt0.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/startup/crt0.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/startup/crt0.S
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/startup/crt0.S
            
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/dirent/closedir.c
            
            $SED -i -e "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/mint/mintbind.h
            $SED -i -e "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/mint/mintbind.h
            $SED -i -e "s/,sp \"/,%%sp\"/gI" $MINTLIBDIR/include/mint/mintbind.h
            $SED -i -e "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/mintbind.h
            $SED -i -e "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/mint/osbind.h
            $SED -i -e "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/mint/osbind.h
            $SED -i -e "s/,sp\\\\n/,%%sp\\\\n/gI" $MINTLIBDIR/include/mint/osbind.h
            $SED -i -e "s/,sp \"/,%%sp\"/gI" $MINTLIBDIR/include/mint/osbind.h
            $SED -i -e "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/osbind.h
        
            $SED -i -e "s/sp@-/%sp@-/gI" $MINTLIBDIR/mintlib/checkcpu.S
            $SED -i -e "s/,sp/,%sp/gI" $MINTLIBDIR/mintlib/checkcpu.S
        
            $SED -i -e "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/osbind.h
        
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/frexp.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/frexp.S
            $SED -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/frexp.S
            $SED -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/frexp.S
            $SED -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/frexp.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/frexp.S
            $SED -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/frexp.S
            $SED -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/frexp.S
            $SED -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/frexp.S
            $SED -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/frexp.S
            $SED -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/frexp.S
         
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/getcookie.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/getcookie.S
            $SED -i -e "s/5%a0/5a0/gI" $MINTLIBDIR/mintlib/getcookie.S #lolol
            $SED -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/getcookie.S
            $SED -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/getcookie.S
            $SED -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/getcookie.S
            $SED -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/getcookie.S
            $SED -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/getcookie.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/getcookie.S
            $SED -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/getcookie.S
            $SED -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/getcookie.S
            $SED -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/getcookie.S
            $SED -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/getcookie.S
            $SED -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/getcookie.S
         
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/getsysvar.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/getsysvar.S
            $SED -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/getsysvar.S
            $SED -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/getsysvar.S
            $SED -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/getsysvar.S
            $SED -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/getsysvar.S
            $SED -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/getsysvar.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/getsysvar.S
            $SED -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/getsysvar.S
            $SED -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/getsysvar.S
            $SED -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/getsysvar.S
            $SED -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/getsysvar.S
            $SED -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/getsysvar.S
         
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/ldexp.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/ldexp.S
            $SED -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/ldexp.S
            $SED -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/ldexp.S
            $SED -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/ldexp.S
            $SED -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/ldexp.S
            $SED -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/ldexp.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/ldexp.S
            $SED -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/ldexp.S
            $SED -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/ldexp.S
            $SED -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/ldexp.S
            $SED -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/ldexp.S
            $SED -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/ldexp.S
         
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/a4/%a4/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/a5/%a5/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/a6/%a6/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/libc_exit.S
            $SED -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/libc_exit.S
         
            $SED -i -e "s/d2\/a2\/a6/%%d2\/%%a2\/%%a6/gI" $MINTLIBDIR/include/mint/linea.h
            $SED -i -e "s/d2\/a2\/a6/%%d2\/%%a2\/%%a6/gI" $MINTLIBDIR/mintlib/linea.c
            $SED -i -e "s/sp@/%%sp@/gI" $MINTLIBDIR/include/mint/linea.h
        
            $SED -i -e "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/compiler.h
            $SED -i -e "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/compiler.h
            $SED -i -e "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/compiler.h
        
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/a4/%a4/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/a5/%a5/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/a6/%a6/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/_normdf.S
            $SED -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/_normdf.S
         
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/a4/%a4/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/a5/%a5/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/a6/%a6/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/modf.S
            $SED -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/modf.S
        
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/a4/%a4/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/a5/%a5/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/a6/%a6/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/a7/%a7/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/setjmp.S
            $SED -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/setjmp.S
        
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/a1/%a1/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/a2/%a2/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/a3/%a3/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/a4/%a4/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/a5/%a5/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/a6/%a6/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/a7/%a7/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/d4/%d4/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/d5/%d5/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/d1/%d1/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/d2/%d2/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/d3/%d3/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/d7/%d7/gI" $MINTLIBDIR/mintlib/setstack.S
            $SED -i -e "s/d6/%d6/gI" $MINTLIBDIR/mintlib/setstack.S
        
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/stdlib/alloca.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/stdlib/alloca.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/stdlib/alloca.S
        
            $SED -i -e "s/\tpc@/\t%pc@/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/a1/%a1/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/a2/%a2/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/a3/%a3/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/a4/%a4/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/a5/%a5/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/a6/%a6/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/a7/%a7/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/d4/%d4/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/d5/%d5/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/d1/%d1/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/d2/%d2/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/d3/%d3/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/d7/%d7/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/d6/%d6/gI" $MINTLIBDIR/string/bcopy.S
            $SED -i -e "s/exit_%d2/exit_d2/gI" $MINTLIBDIR/string/bcopy.S
        
            $SED -i -e "s/\tpc@/\t%pc@/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/a1/%a1/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/a2/%a2/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/a3/%a3/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/a4/%a4/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/a5/%a5/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/a6/%a6/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/a7/%a7/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/d4/%d4/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/d5/%d5/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/d1/%d1/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/d2/%d2/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/d3/%d3/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/d7/%d7/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/d6/%d6/gI" $MINTLIBDIR/string/bzero.S
            $SED -i -e "s/exit_%d2/exit_d2/gI" $MINTLIBDIR/string/bzero.S
        
            $SED -i -e "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/mint/falcon.h
            $SED -i -e "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/mint/falcon.h
            $SED -i -e "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/falcon.h
        
            $SED -i -e "s/,sp@/,%%sp@/gI" $MINTLIBDIR/include/mint/metados.h
            $SED -i -e "s/,sp\"/,%%sp\"/gI" $MINTLIBDIR/include/mint/metados.h
            $SED -i -e "s/\tsp/\t%%sp/gI" $MINTLIBDIR/include/mint/metados.h
        
            $SED -i -e "s/\tpc@/\t%pc@/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/sp/%sp/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/a0/%a0/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/a1/%a1/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/a2/%a2/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/a3/%a3/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/a4/%a4/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/a5/%a5/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/a6/%a6/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/a7/%a7/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/d4/%d4/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/d5/%d5/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/d0/%d0/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/d1/%d1/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/d2/%d2/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/d3/%d3/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/d7/%d7/gI" $MINTLIBDIR/unix/vfork.S
            $SED -i -e "s/d6/%d6/gI" $MINTLIBDIR/unix/vfork.S
        
            # Even though -fleading-underscore is enforced in gcc, it still needs setting in these makefiles
            # Go. Figure.
            # (TODO: unless of course it doesn't any more)
            $SED -i -e "s/srcdir)\/time/srcdir)\/time -fleading-underscore/gI" $MINTLIBDIR/tz/Makefile
            $SED -i -e "s/TESTDEFS = -D_GNU_SOURCE -D_REENTRANT/TESTDEFS = -D_GNU_SOURCE -D_REENTRANT -fleading-underscore/gI" $MINTLIBDIR/checkrules
            $SED -i -e "s/-std=gnu89/-std=gnu89 -fleading-underscore/gI" $MINTLIBDIR/configvars
        
            # Furhter targets (020+, coldfire)
            $SED -i -e "s/sp@+/%sp@+/gI" $MINTLIBDIR/mintlib/checkcpu.S
            $SED -i -e "s/\tsp/\t%sp/gI" $MINTLIBDIR/mintlib/checkcpu.S
            
            $SED -i -e "s/,sp/,%%sp/gI" $MINTLIBDIR/include/compiler.h
            $SED -i -e "s/,sp/,%%%%sp/gI" $MINTLIBDIR/syscall/traps.c
            $SED -i -e "s/sp@(/%%%%sp@(/gI" $MINTLIBDIR/syscall/traps.c
        
            # Extra things (clobbered reg lists etc)
            $SED -i -e 's/\\"d0\\"/\\"%%%%d0\\"/gI' $MINTLIBDIR/syscall/traps.c
            $SED -i -e 's/\\"d1\\"/\\"%%%%d1\\"/gI' $MINTLIBDIR/syscall/traps.c
            $SED -i -e 's/\\"d2\\"/\\"%%%%d2\\"/gI' $MINTLIBDIR/syscall/traps.c
            $SED -i -e 's/\\"a0\\"/\\"%%%%a0\\"/gI' $MINTLIBDIR/syscall/traps.c
            $SED -i -e 's/\\"a1\\"/\\"%%%%a1\\"/gI' $MINTLIBDIR/syscall/traps.c
            $SED -i -e 's/\\"a2\\"/\\"%%%%a2\\"/gI' $MINTLIBDIR/syscall/traps.c
            $SED -i -e "s|/usr\$\$local/m68k-atari-mint|${INSTALL_PREFIX}/m68k-$VENDOR-elf|gI" $MINTLIBDIR/buildrules
        
            cd $MINTLIBDIR
        
            # can't safely use -j with mintlib due to bison/flex dependency ordering woe
            make SHELL=/bin/bash
        
            # Install the lib.
            # For some reason math.h isn't installed so we do it by hand
            # ¯\_(ツ)_/¯ 
            $SUDO make install
            $SUDO cp include/math.h $INSTALL_PREFIX/m68k-$VENDOR-elf/include
            if [ "$machine" == "Mac" ]
            then
                $SUDO chmod g+r $INSTALL_PREFIX/m68k-$VENDOR-elf/include/math.h
            fi
        
            # Create lib binary package
            make bin-dist
        
        fi
    fi

    #
    # Build libstdc++-v3
    #
    
    # *** create local build dir
    
    cd $HOMEDIR/gcc-$1
    
    # Some more permissions need to be fixed here
    if [ "$machine" != "Cygwin" ] && [ "$machine" != "MinGw" ] && [ "$machine" != "Mac" ]
    then
        if [ "$BUILD_MINTLIB" != "0" ]
        then
            $SUDO chmod 755 -R $INSTALL_PREFIX/m68k-$VENDOR-elf/include/
            $SUDO chmod 755 -R $INSTALL_PREFIX/m68k-$VENDOR-elf/share/
        fi
    fi
    
    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        REPLY=Y
    else    
        read -p "Patch libstdc++v3 at the source level (meaning the gcc-$1 files will be tinkered)?" -n 1 -r
        echo
    fi
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
    
        # edit file gcc-$1/libstdc++-v3/configure - comment out the line:
        ##as_fn_error "No support for this host/target combination." "$LINENO" 5
    
        $SED -i -e 's/as_fn_error \"No support for this host\/target combination.\" \"\$LINENO\" 5/#ignored/gI' $HOMEDIR/gcc-$1/libstdc++-v3/configure
        
        # *** hack configure to remove dlopen stuff
        
        # # Libtool setup.
        # if test "x${with_newlib}" != "xyes"; then
        #-  AC_LIBTOOL_DLOPEN
        #+#  AC_LIBTOOL_DLOPEN
        # fi
        $SED -i -e "s/  AC_LIBTOOL_DLOPEN/#  AC_LIBTOOL_DLOPEN/gI" $HOMEDIR/gcc-$1/libstdc++-v3/configure.ac
        
        #libstdc++-v3/configure:
        #
        #*** for every instance of: as_fn_error "Link tests are not allowed after GCC_NO_EXECUTABLES." "$LINENO" 5
        #*** change to as_echo_n so the configure doesn't halt on this error
        #
        #  as_echo_n "Link tests are not allowed after GCC_NO_EXECUTABLES." "$LINENO" 5
        $SED -i -e "s/  as_fn_error \"Link tests are not allowed after GCC_NO_EXECUTABLES.*/  \$as_echo \"lolol\"/gI" $HOMEDIR/gcc-$1/libstdc++-v3/configure
    
        #*** remove the contents of cow-stdexcept.cc
        #
        #gcc-$1\libstdc++-v3\src\c++11\cow_stdexcept.cc
        #
        ##if (0)
        #...everything...
        ##endif
   
	if [ -f $HOMEDIR/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc ];
        then
            echo "#if (0)" > $HOMEDIR/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc.new
            cat $HOMEDIR/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc >> $HOMEDIR/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc.new
            echo "#endif" >> $HOMEDIR/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc.new
            mv $HOMEDIR/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc.new $HOMEDIR/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc
	fi
    
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
        #gcc-$1/build/src/Makefile:
        #
        #AM_CXXFLAGS = \
        #	-std=gnu++98 ******** remove this ********
        #	$(glibcxx_compiler_pic_flag) \
        #	$(XTEMPLATE_FLAGS) $(VTV_CXXFLAGS) \
        #	$(WARN_CXXFLAGS) $(OPTIMIZE_CXXFLAGS) $(CONFIG_CXXFLAGS)
        
        cd $HOMEDIR/build-gcc-$1
        $NICE make configure-target-libstdc++-v3
     
        #$SED -i -e "s/-std=gnu++98//gI" $HOMEDIR/gcc-$1/build/src/Makefile
        $SED -i -e "s/-std=gnu++98//gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/libstdc++-v3/src/Makefile
    
        
        #*** fix type_traits to avoid macro collision: convert '_CTp' to '_xCTp' because ctypes.h defines _CTp as 0x20
        #*** note: need to investigate why ctypes.h is even present
        #
        #gcc-$1/build/include/type_traits:
        #
        #  template<typename _xCTp, typename... _Args>
        #    struct __expanded_common_type_wrapper
        #    {
        #      typedef common_type<typename _xCTp::type, _Args...> type;
        #    };
        
        #sed -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/gcc-$1/build/include/type_traits
    
        # Patch all multilib instances
        # TODO: replace this with a grep or find command
        #       (yeah right, that will happen soon)
        if [ "$BUILD_MINTLIB" != "0" ]
        then
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/softfp/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m68060/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m68060/softfp/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/mcpu32/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/mfidoa/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/mfidoa/softfp/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5407/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m54455/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5475/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5475/softfp/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m68040/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m68040/softfp/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m51qe/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5206/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5206e/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5208/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5307/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5329/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m68000/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/libstdc++-v3/include/type_traits
        fi

        #*** fix type_traits to favour <cstdint> over those partially-defined wierd builtin int_leastXX, int_fastXX types
        #*** note: this causes multiply defined std:: or missing :: types depending on _GLIBCXX_USE_C99_STDINT_TR1 1/0
        #
    
        #sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/gcc-$1/build/include/type_traits
    
        # Patch all multilib instances
        # TODO: replace this with a grep or find command
        #       (yeah right, that will happen soon)
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/softfp/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m68060/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m68060/softfp/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/mcpu32/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/mfidoa/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/mfidoa/softfp/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5407/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m54455/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5475/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5475/softfp/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m68040/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m68040/softfp/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m51qe/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5206/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5206e/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5208/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5307/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m5329/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/m68000/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $HOMEDIR/build-gcc-$1/m68k-$VENDOR-elf/libstdc++-v3/include/type_traits
    
    fi
    
    # Build Fortran (not guaranteed to work for gccs earlier than 7)
    if [ "$BUILD_FORTRAN" == "1" ]; then
        if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
            REPLY=N
        else    
            read -p "Configure, source patch and build glibfortran?" -n 1 -r
            echo
        fi
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            # From what I could see libgfortran only has some function re-declarations
            # This might be possible to fix by passing proper configuration options
            # during configuration, but lolwtfwhocares - let's patch some files! 
            $SED -i -e "s/eps = nextafter/eps = __builtin_nextafter/gI" $HOMEDIR/gcc-$1/libgfortran/intrinsics/c99_functions.c
            $SED -i -e "s/#ifndef HAVE_GMTIME_R/#if 0/gI" $HOMEDIR/gcc-$1/libgfortran/intrinsics/date_and_time.c
            $SED -i -e "s/#ifndef HAVE_LOCALTIME_R/#if 0/gI" $HOMEDIR/gcc-$1/libgfortran/intrinsics/time_1.h
            $SED -i -e "s/#ifndef HAVE_STRNLEN/#if 0/gI" $HOMEDIR/gcc-$1/libgfortran/runtime/string.c
            $SED -i -e "s/#ifndef HAVE_STRNDUP/#if 0/gI" $HOMEDIR/gcc-$1/libgfortran/runtime/string.c
            $SED -i -e "s/${WL}--emit-relocs//gI" $HOMEDIR/build-gcc-$1/Makefile
        
            make configure-target-libgfortran
            $NICE make $JMULT all-target-libgfortran
            make install-target-libgfortran
        fi
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
        cd $HOMEDIR/build-gcc-$1
        make all-target-libstdc++-v3 $JMULT
        $SUDO make install-target-libstdc++-v3
    fi
    
    # gcc build dir
    # build everything else
    # (which doesn't amount to much)
    
    cd $HOMEDIR/build-gcc-$1
    
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
            $SUDO chmod 775 $HOMEDIR/build-gcc-$1/gcc/b-header-vars
        fi
        # This system include isn't picked up for some reason 
        if [ "$machine" == "Mac" ]
        then
            $SED -i -e "s/<gmp.h>/\"\/opt\/local\/include\/gmp.h\"/gI" $HOMEDIR/gcc-$1/gcc/system.h 
        fi 
    
        $NICE make all $JMULT
        $SUDO make install
        $SUDO strip $INSTALL_PREFIX/bin/*$VENDOR*
        if [ "$machine" == "Cygwin" ] || [ "$machine" != "MinGw" ] || [ "$machine" != "Mac" ]
        then
            $SUDO strip $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/cc1* \
    			$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/cc1plus* \
    			$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/collect2* \
    			$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/lto1* \
    			$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/lto-wrapper*
        else
            $SUDO strip $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/cc1* \
    			$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/cc1plus* \
    			$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/collect2* \
    			$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/liblto_plugin.so \
    			$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/liblto_plugin.so.0 \
    			$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/liblto_plugin.so.0.0.0 \
    			$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/lto1 \
    			$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/lto-wrapper
        fi
        $SUDO find $INSTALL_PREFIX/m68k-$VENDOR-elf/lib -name '*.a' -print -exec m68k-$VENDOR-elf-strip -S -x '{}' ';'
        $SUDO find $INSTALL_PREFIX/lib/gcc/m68k-$VENDOR-elf/* -name '*.a' -print -exec m68k-$VENDOR-elf-strip -S -x '{}' ';'
        
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
        export PATH=${INSTALL_PREFIX}/bin:$PATH
        cd $BINPACKAGE_DIR
        # Since make install uses the non-patched type_traits file let's patch them here too
        # (yes this could have been done before even configuring stdlib++v3 - anyone wants to try?)
        for i in `find . -name type_traits`; do echo Patching $i; $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $i;done
    
        strip .$INSTALL_PREFIX/bin/*
        if [ "$machine" == "Cygwin" ] || [ "$machine" != "MinGw" ] || [ "$machine" != "Mac" ]
        then
            $SUDO strip .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/cc1* \
    			.$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/cc1plus* \
    			.$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/collect2* \
    			.$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/lto1* \
    			.$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/lto-wrapper*
        else
            $SUDO strip .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/cc1* \
    			.$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/cc1plus* \
    			.$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/collect2* \
    			.$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/liblto_plugin.so \
    			.$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/liblto_plugin.so.0 \
    			.$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/liblto_plugin.so.0.0.0 \
    			.$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/lto1 \
    			.$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$1/lto-wrapper
        fi
    
        find .$INSTALL_PREFIX/m68k-$VENDOR-elf/lib -name '*.a' -print -exec m68k-$VENDOR-elf-strip -S -x '{}' ';'
        find .$INSTALL_PREFIX/lib/gcc/m68k-$VENDOR-elf/* -name '*.a' -print -exec m68k-$VENDOR-elf-strip -S -x '{}' ';'
        $TAR --owner=0 --group=0 -jcvf gcc-$VENDOR-bin.tar.bz2 .$INSTALL_PREFIX
    fi

    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        REPLY=Y
    else    
        read -p "Reorganise MiNTlib folders?" -n 1 -r
        echo
    fi
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        # reorganise install dirs to map libs to all processor switches
        #
        # on completion the target:lib variants will be:
        #
        # m68000/		assumes no fpu
        # m68020/		assumes 68881/2
        # m68020/softfp		assumes no fpu
        # m68020-60/		assumes any 0x0 cpu, 68881/2
        # m68020-60/softfp	assumes any 0x0 cpu, no fpu
        # m68040/		assumes internal fpu
        # m68060/		assumes internal fpu
        
        
        LIBGCC=$INSTALL_PREFIX/lib/gcc/m68k-$VENDOR-elf/$1
        LIBCXX=$INSTALL_PREFIX/m68k-$VENDOR-elf/lib
        
        #-------------------------------------------------------------------------------
        #-------------------------------------------------------------------------------
        
        # make subdir for gcc default cpu (020)
        $SUDO mkdir -p $LIBGCC/m68020
        $SUDO cp -r $LIBGCC/*.o $LIBGCC/m68020/.
        $SUDO cp -r $LIBGCC/*.a $LIBGCC/m68020/.
        $SUDO cp -r $LIBGCC/softfp $LIBGCC/m68020
        
        #-------------------------------------------------------------------------------
        
        # make subdir for gcc cpu (020-60)
        # we aren't generating 060-clean versions yet so we use the
        # soft-float 020 version as a safe compromise
        $SUDO mkdir -p $LIBGCC/m68020-60
        $SUDO cp -r $LIBGCC/softfp/*.o $LIBGCC/m68020-60/.
        $SUDO cp -r $LIBGCC/softfp/*.a $LIBGCC/m68020-60/.
        $SUDO cp -r $LIBGCC/softfp $LIBGCC/m68020-60
        
        #-------------------------------------------------------------------------------
        #-------------------------------------------------------------------------------
        
        # make subdir for libc++ default cpu (020)
        $SUDO mkdir -p $LIBCXX/m68020
        $SUDO mkdir -p $LIBCXX/m68020/softfp
        $SUDO cp -r $LIBCXX/libstdc++.* $LIBCXX/m68020/.
        $SUDO cp -r $LIBCXX/libsupc++.* $LIBCXX/m68020/.
        $SUDO cp -r $LIBCXX/softfp/libstdc++.* $LIBCXX/m68020/softfp/.
        $SUDO cp -r $LIBCXX/softfp/libsupc++.* $LIBCXX/m68020/softfp/.
        
        #-------------------------------------------------------------------------------
        
        # transfer libc to correct subdirs (68k)
        $SUDO mv $LIBCXX/libc.a $LIBCXX/m68000/.
        $SUDO mv $LIBCXX/libiio.a $LIBCXX/m68000/.
        $SUDO mv $LIBCXX/librpcsvc.a $LIBCXX/m68000/.
        
        # publish 020/fpu version of libc as default
        $SUDO cp -r $LIBCXX/m68020/libc.a $LIBCXX/.
        $SUDO cp -r $LIBCXX/m68020/libiio.a $LIBCXX/.
        $SUDO cp -r $LIBCXX/m68020/librpcsvc.a $LIBCXX/.
        
        # publish 020/softfp version of libc as default softfp
        $SUDO cp $LIBCXX/m68020-20_soft/*.a $LIBCXX/softfp/.
        $SUDO cp $LIBCXX/m68020-20_soft/*.a $LIBCXX/m68020/softfp/.
        $SUDO rm -rf $LIBCXX/m68020-20_soft
        
        # transfer libc to correct subdirs (020-60)
        $SUDO mv $LIBCXX/m68020-60_soft $LIBCXX/m68020-60/softfp
        
        $SUDO cp -r $LIBCXX/softfp/libstdc++.* $LIBCXX/m68020-60/softfp/.
        $SUDO cp -r $LIBCXX/softfp/libsupc++.* $LIBCXX/m68020-60/softfp/.
        
        #-------------------------------------------------------------------------------
        # 68040,060
        
        # we prefer not to transfer transfer 020/fpu libs to 040-060 because emulated 
        # fpu ops may be generated. better to build a 040/060 variant of libstdc++
        # as a safe compromise for now we use the 020/softfp variant
        $SUDO cp -r $LIBCXX/m68020/softfp/libstdc++.* $LIBCXX/m68020-60/.
        $SUDO cp -r $LIBCXX/m68020/softfp/libsupc++.* $LIBCXX/m68020-60/.
        
        # we don't bother with LC versions of 040/060 so...
        $SUDO rm -rf $LIBCXX/m68040/softfp 
        $SUDO rm -rf $LIBCXX/m68060/softfp 
        $SUDO rm -rf $LIBGCC/m68040/softfp 
        $SUDO rm -rf $LIBGCC/m68060/softfp 
        
        # crt0.o, gcrt0.o are 68k asm and don't need relocated
    fi

    # The end, just be a good citizen and go back to the directory we were called from
    cd $HOMEDIR
}

mainbrown "$@"

