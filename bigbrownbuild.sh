set -e          #stop on any error encountered
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
    # Ensure flex and bison is installed
    # Don't look at me about what this does, I just copied it from stack overflow...
    # (https://stackoverflow.com/a/677212)
    #

    #command -v bison >/dev/null 2>&1 || { echo >&2 "I require bison but it's not installed.  Aborting."; exit 1; }
    #command -v flex >/dev/null 2>&1 || { echo >&2 "I require flex but it's not installed.  Aborting."; exit 1; }

    #   
    # User definable stuff
    #

    # Set this to "A" if you want a completely automated run
    GLOBAL_OVERRIDE=A

    # Set this to 0 if you don't want to build fortran at all.
    # For now this is only enabled for gcc 7.x anyway.
    # If anyone wants to test this on older gccs, be my guest
    GLOBAL_BUILD_FORTRAN=0

    # Set this to 1 if you want to tell gcc to download and
    # build prerequisite libraries if they are not installed
    # on your system
    GLOBAL_DOWNLOAD_PREREQUISITES=1

    # Use less RAM when compiling, for low end systems
    USE_MIN_RAM=1

    # Which gccs to build. 1=Build, anything else=Don't build
    BUILD_4_6_4=0  # Produces Internal Compiler Error when built with gcc 4.8.5?
    BUILD_4_9_4=0
    BUILD_5_4_0=0
    BUILD_6_2_0=0
    BUILD_7_1_0=0
    BUILD_7_2_0=0
    BUILD_7_3_0=0
    BUILD_8_1_0=0
    BUILD_8_2_0=0
    BUILD_8_3_0=0
    BUILD_9_1_0=0
    BUILD_9_2_0=0
    BUILD_9_3_0=0
    BUILD_10_1_0=0
    BUILD_10_2_0=0
    BUILD_10_3_0=0
    BUILD_11_1_0=0
    BUILD_TRUNK=1   # NOTE: requires 'makeinfo' (installed by package texinfo on ubuntu, at least)
    TRUNK_VERSION=12.0.0    # This needs to change with every major gcc release

    # Should we run this as an administrator or user?
    # Administrator mode will install the compiler in
    # the system's folders and will require root priviledges
    #RUN_MODE=Admin
    RUN_MODE=User

    # How are the various gcc versions named. This is tuned for ubuntu 17.10
    # so your mileage may vary! Also you might be able to build all gcc versions using one
    # compiler - so many problems were encountered in Ubuntu (including Internal Compiler
    # Errors) that this is now in full pendantic mode. Again, your mileage may vary!
    CC4=gcc-4.8
    CXX4=g++-4.8
    CC5=gcc-5
    CXX5=g++-5
    CC6=gcc-6
    CXX6=g++-6
    CC7=gcc-7
    CXX7=g++-7
    CC8=gcc
    CXX8=g++
    CC9=gcc
    CXX9=g++
    CC10=gcc
    CXX10=g++

    # Some global stuff that are platform dependent
    HOMEDIR=$PWD
    NICE='nice -n 19'
    JMULT=-j1
    BINPACKAGE_DIR=$PWD/binary-package
    SED=sed
    TAR=tar
    TAROPTS='--owner=0 --group=0'

    # Only set this to nonzero when you do want to build mintlib
    # Note that if you don't build mintlib then libstdc++v3 will also fail to build
    BUILD_MINTLIB=1

    # Set this to nonzero to build Newlib instead of MiNTlib (experimental for now)
    BUILD_NEWLIB=0
    
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
        MSYS*)      machine=msys;;
        *)          machine="UNKNOWN:${unameOut}"
    esac
    echo Host machine: $machine
  
    if [ "$machine" == "msys" ]; then
        # msys default compilers generate binaries that are dependent
        # on msys dlls. Which means you need to ship msys dlls alongside.
        # So let's just refuse to build on msys and force people to use
        # a MinGW shell instead (which is what people wanted anyway)
        echo "Refusing to build on Msys shell, use a MinGW shell instead!"
        exit
    fi

    # If building 4.6.4 warn the user that the coldfire mintlib is hosed
    # and thus disabled for now

    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        GLOBAL_SKIP_464_CF=Y
    else
        if [ "$BUILD_4_6_4" == "1" ]; then
            echo You\'re building gcc 4.6.4
            echo Be aware that currently when building MiNTlib the cross compiler
            echo throws an Internal Compiler Error when trying to build the coldfire
            echo target, thus it is disabled. Answer no to the question below
            echo otherwise and/or file a report to the authors if you know how
            echo to overcome this!
            read -p "Disable building MiNTlib for coldfire on 4.6.4?" -n 1 -r GLOBAL_SKIP_464_CF
            echo
        fi
    fi
  
    if [ "$RUN_MODE" == "Admin" ]; then
        # Administrator mode
        SUDO=sudo
        if [ "$machine" == "Mac" ]; then
            INSTALL_PREFIX=/opt/local/
        else
            INSTALL_PREFIX=/home/ggn/brown
        fi
    else
        # User mode
        SUDO=
        #INSTALL_PREFIX=${HOME}/localINSTALL_PREFIX
        INSTALL_PREFIX=/brown
    fi

    if [ "$machine" == "Mac" ]; then
        TAR=tar
        SED=gsed
        TAROPTS=
        CC4=gcc
        CXX4=g++
        CC5=gcc
        CXX5=g++
        CC6=gcc
        CXX6=g++
        CC7=gcc
        CXX7=g++
        CC8=gcc
        CXX8=g++
        CC9=gcc
        CXX9=g++
        CC10=gcc
        CXX10=g++
        CC11=gcc
        CXX11=g++
    fi
    
    if [ "$machine" == "MinGw" ]; then
        # Msys has no idea what "sudo" and "nice" are.
        # Also, it's not liking parallel builds that much.
        unset SUDO
        unset NICE
        unset JMULT
        CC4=x86_64-w64-mingw32-gcc
        CXX4=x86_64-w64-mingw32-g++
        CC5=x86_64-w64-mingw32-gcc
        CXX5=x86_64-w64-mingw32-g++
        CC6=x86_64-w64-mingw32-gcc
        CXX6=x86_64-w64-mingw32-g++
        CC7=x86_64-w64-mingw32-gcc
        CXX7=x86_64-w64-mingw32-g++
        CC8=x86_64-w64-mingw32-gcc
        CXX8=x86_64-w64-mingw32-g++
        CC9=x86_64-w64-mingw32-gcc
        CXX9=x86_64-w64-mingw32-g++
        CC10=x86_64-w64-mingw32-gcc
        CXX10=x86_64-w64-mingw32-g++
        CC11=x86_64-w64-mingw32-gcc
        CXX11=x86_64-w64-mingw32-g++
        # Flex is a msys built package but we use the mingw32 compiler.
        # Instead of modifying the Makefiles (urgh) just copy the
        # flex library over where mingw's lib search path will find it.
        # Not the best practice but hey...
        cp /usr/lib/libfl.a /mingw64/lib
    fi
    if [ "$machine" == "Cygwin" ]; then
        # Disable some stuff for cygwin as well
        unset SUDO
        unset NICE
        # This is probably safe for cygwin, but only been tested
        # when building gcc 7.x
        CC4=gcc
        CXX4=g++
        CC5=gcc
        CXX5=g++
        CC6=gcc
        CXX6=g++
        CC7=gcc
        CXX7=g++
        CC8=gcc
        CXX8=g++
        CC9=gcc
        CXX9=g++
        CC10=gcc
        CXX10=g++
        CC11=gcc
        CXX11=g++
    fi

    # Cleanup folders
    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        CLEANUP=Y
    else    
        read -p "Cleanup build dirs from previous build?" -n 1 -r
        echo
    fi
    if [ "$CLEANUP" == "Y" ] || [ "$CLEANUP" == "y" ]; then
        rm -rf binary-package 
        rm -rf binutils-2.27
        rm -rf binutils-2.31
        rm -rf binutils-2.32
        rm -rf binutils-2.34
        rm -rf binutils-2.35
        rm -rf mintlib-bigbrownbuild
        rm -rf build-newlib*
    fi
    
    # Get all the things
    
    if [ "$BUILD_4_6_4" == "1" ]; then if [ ! -f gcc-4.6.4.tar.bz2 ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-4.6.4/gcc-4.6.4.tar.bz2; fi; fi
    if [ "$BUILD_4_9_4" == "1" ]; then if [ ! -f gcc-4.9.4.tar.bz2 ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-4.9.4/gcc-4.9.4.tar.bz2; fi; fi
    if [ "$BUILD_5_4_0" == "1" ]; then if [ ! -f gcc-5.4.0.tar.bz2 ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-5.4.0/gcc-5.4.0.tar.bz2; fi; fi
    if [ "$BUILD_6_2_0" == "1" ]; then if [ ! -f gcc-6.2.0.tar.bz2 ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-6.2.0/gcc-6.2.0.tar.bz2; fi; fi
    if [ "$BUILD_7_1_0" == "1" ]; then if [ ! -f gcc-7.1.0.tar.bz2 ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-7.1.0/gcc-7.1.0.tar.bz2; fi; fi
    if [ "$BUILD_7_2_0" == "1" ]; then if [ ! -f gcc-7.2.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-7.2.0/gcc-7.2.0.tar.xz; fi; fi
    if [ "$BUILD_7_3_0" == "1" ]; then if [ ! -f gcc-7.3.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-7.3.0/gcc-7.3.0.tar.xz; fi; fi
    if [ "$BUILD_8_1_0" == "1" ]; then if [ ! -f gcc-8.1.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-8.1.0/gcc-8.1.0.tar.xz; fi; fi
    if [ "$BUILD_8_2_0" == "1" ]; then if [ ! -f gcc-8.2.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-8.2.0/gcc-8.2.0.tar.xz; fi; fi
    if [ "$BUILD_8_3_0" == "1" ]; then if [ ! -f gcc-8.3.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-8.3.0/gcc-8.3.0.tar.xz; fi; fi
    if [ "$BUILD_9_1_0" == "1" ]; then if [ ! -f gcc-9.1.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-9.1.0/gcc-9.1.0.tar.xz; fi; fi
    if [ "$BUILD_9_2_0" == "1" ]; then if [ ! -f gcc-9.2.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-9.2.0/gcc-9.2.0.tar.xz; fi; fi
    if [ "$BUILD_9_3_0" == "1" ]; then if [ ! -f gcc-9.3.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-9.3.0/gcc-9.3.0.tar.xz; fi; fi
    if [ "$BUILD_10_1_0" == "1" ]; then if [ ! -f gcc-10.1.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-10.1.0/gcc-10.1.0.tar.xz; fi; fi
    if [ "$BUILD_10_2_0" == "1" ]; then if [ ! -f gcc-10.2.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-10.2.0/gcc-10.2.0.tar.xz; fi; fi
    if [ "$BUILD_10_3_0" == "1" ]; then if [ ! -f gcc-10.3.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-10.3.0/gcc-10.3.0.tar.xz; fi; fi
    if [ "$BUILD_11_1_0" == "1" ]; then if [ ! -f gcc-11.1.0.tar.xz ]; then wget ftp://ftp.gnu.org/pub/pub/gnu/gcc/gcc-11.1.0/gcc-11.1.0.tar.xz; fi; fi
    if [ "$BUILD_TRUNK" == "1" ]; then if [ ! -d gcc-TRUNK ]; then git clone git://gcc.gnu.org/git/gcc.git gcc-TRUNK; fi; fi

    if [ "$BUILD_4_6_4" == "1" ] || [ "$BUILD_4_9_4" == "1" ] || [ "$BUILD_5_4_0" == "1" ] || [ "$BUILD_6_2_0" == "1" ] || [ "$BUILD_7_1_0" == "1" ] || [ "$BUILD_7_2_0" == "1" ] || [ "$BUILD_7_3_0" == "1" ] || [ "$BUILD_8_1_0" == "1" ]; then
        if [ ! -f binutils-2.27.tar.bz2 ]; then wget http://ftp.gnu.org/gnu/binutils/binutils-2.27.tar.bz2; fi
    fi
    if [ "$BUILD_8_2_0" == "1" ]; then
        if [ ! -f binutils-2.31.tar.xz ]; then wget http://ftp.gnu.org/gnu/binutils/binutils-2.31.tar.xz; fi
    fi
    if [ "$BUILD_8_3_0" == "1" ] || [ "$BUILD_9_1_0" == "1" ] || [ "$BUILD_9_2_0" == "1" ] || [ "$BUILD_9_3_0" == "1" ]; then
        if [ ! -f binutils-2.32.tar.xz ]; then wget http://ftp.gnu.org/gnu/binutils/binutils-2.32.tar.xz; fi
    fi
    if [ "$BUILD_10_1_0" == "1" ]; then
        if [ ! -f binutils-2.34.tar.xz ]; then wget http://ftp.gnu.org/gnu/binutils/binutils-2.34.tar.xz; fi
    fi
    if [ "$BUILD_10_2_0" == "1" ] || [ "$BUILD_10_3_0" == "1" ]; then
        if [ ! -f binutils-2.35.tar.xz ]; then wget http://ftp.gnu.org/gnu/binutils/binutils-2.35.tar.xz; fi
    fi
    if [ "$BUILD_11_1_0" == "1" ] || [ "$BUILD_TRUNK" == "1" ]; then
        if [ ! -f binutils-2.36.tar.xz ]; then wget http://ftp.gnu.org/gnu/binutils/binutils-2.36.tar.xz; fi
    fi
    if [ ! -d mintlib-bigbrownbuild ]; then git clone https://github.com/ggnkua/mintlib-bigbrownbuild.git; fi
    if [ "$BUILD_NEWLIB" != "0" ]; then if [ ! -f newlib-4.1.0.tar.gz ]; then wget ftp://sourceware.org/pub/newlib/newlib-4.1.0.tar.gz; fi; fi
    # requires GMP, MPFR and MPC
    
    # Unpack all the things
    cd "$HOMEDIR"
    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        REPLY=Y
    else    
        read -p "Unpack gcc, binutils, Newlib and mintlib?" -n 1 -r
        echo
    fi
    if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
        if [ "$CLEANUP" == "Y" ]; then
            if [ "$BUILD_4_6_4" == "1" ]; then rm -rf gcc-4.6.4; fi
            if [ "$BUILD_4_9_4" == "1" ]; then rm -rf gcc-4.9.4; fi
            if [ "$BUILD_5_4_0" == "1" ]; then rm -rf gcc-5.4.0; fi
            if [ "$BUILD_6_2_0" == "1" ]; then rm -rf gcc-6.2.0; fi
            if [ "$BUILD_7_1_0" == "1" ]; then rm -rf gcc-7.1.0; fi
            if [ "$BUILD_7_2_0" == "1" ]; then rm -rf gcc-7.2.0; fi
            if [ "$BUILD_7_3_0" == "1" ]; then rm -rf gcc-7.3.0; fi
            if [ "$BUILD_8_1_0" == "1" ]; then rm -rf gcc-8.1.0; fi
            if [ "$BUILD_8_2_0" == "1" ]; then rm -rf gcc-8.2.0; fi
            if [ "$BUILD_8_3_0" == "1" ]; then rm -rf gcc-8.3.0; fi
            if [ "$BUILD_9_1_0" == "1" ]; then rm -rf gcc-9.1.0; fi
            if [ "$BUILD_9_2_0" == "1" ]; then rm -rf gcc-9.2.0; fi
            if [ "$BUILD_9_3_0" == "1" ]; then rm -rf gcc-9.3.0; fi
            if [ "$BUILD_10_1_0" == "1" ]; then rm -rf gcc-10.1.0; fi
            if [ "$BUILD_10_2_0" == "1" ]; then rm -rf gcc-10.2.0; fi
            if [ "$BUILD_10_3_0" == "1" ]; then rm -rf gcc-10.3.0; fi
            if [ "$BUILD_11_1_0" == "1" ]; then rm -rf gcc-11.1.0; fi
        fi    
        if [ "$BUILD_4_6_4" == "1" ]; then tar -jxvf gcc-4.6.4.tar.bz2; fi
        if [ "$BUILD_4_9_4" == "1" ]; then tar -jxvf gcc-4.9.4.tar.bz2; fi
        if [ "$BUILD_5_4_0" == "1" ]; then tar -jxvf gcc-5.4.0.tar.bz2; fi
        if [ "$BUILD_6_2_0" == "1" ]; then tar -jxvf gcc-6.2.0.tar.bz2; fi
        if [ "$BUILD_7_1_0" == "1" ]; then tar -jxvf gcc-7.1.0.tar.bz2; fi
        if [ "$BUILD_7_2_0" == "1" ]; then tar -Jxvf gcc-7.2.0.tar.xz; fi
        if [ "$BUILD_7_3_0" == "1" ]; then tar -Jxvf gcc-7.3.0.tar.xz; fi
        if [ "$BUILD_8_1_0" == "1" ]; then tar -Jxvf gcc-8.1.0.tar.xz; fi
        if [ "$BUILD_8_2_0" == "1" ]; then tar -Jxvf gcc-8.2.0.tar.xz; fi
        if [ "$BUILD_8_3_0" == "1" ]; then tar -Jxvf gcc-8.3.0.tar.xz; fi
        if [ "$BUILD_9_1_0" == "1" ]; then tar -Jxvf gcc-9.1.0.tar.xz; fi
        if [ "$BUILD_9_2_0" == "1" ]; then tar -Jxvf gcc-9.2.0.tar.xz; fi
        if [ "$BUILD_9_3_0" == "1" ]; then tar -Jxvf gcc-9.3.0.tar.xz; fi
        if [ "$BUILD_10_1_0" == "1" ]; then tar -Jxvf gcc-10.1.0.tar.xz; fi
        if [ "$BUILD_10_2_0" == "1" ]; then tar -Jxvf gcc-10.2.0.tar.xz; fi
        if [ "$BUILD_10_3_0" == "1" ]; then tar -Jxvf gcc-10.3.0.tar.xz; fi
        if [ "$BUILD_11_1_0" == "1" ]; then tar -Jxvf gcc-11.1.0.tar.xz; fi
        if [ "$BUILD_TRUNK" == "1" ]; then cd gcc-TRUNK && git reset --hard HEAD && cd ..; fi
        if [ "$GLOBAL_DOWNLOAD_PREREQUISITES" == "1" ]; then
            if [ "$BUILD_4_6_4" == "1" ]; then cd gcc-4.6.4;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_4_9_4" == "1" ]; then cd gcc-4.9.4;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_5_4_0" == "1" ]; then cd gcc-5.4.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_6_2_0" == "1" ]; then cd gcc-6.2.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_7_1_0" == "1" ]; then cd gcc-7.1.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_7_2_0" == "1" ]; then cd gcc-7.2.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_7_3_0" == "1" ]; then cd gcc-7.3.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_8_1_0" == "1" ]; then cd gcc-8.1.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_8_2_0" == "1" ]; then cd gcc-8.2.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_8_3_0" == "1" ]; then cd gcc-8.3.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_9_1_0" == "1" ]; then cd gcc-9.1.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_9_2_0" == "1" ]; then cd gcc-9.2.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_9_3_0" == "1" ]; then cd gcc-9.3.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_10_1_0" == "1" ]; then cd gcc-10.1.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_10_2_0" == "1" ]; then cd gcc-10.2.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_10_3_0" == "1" ]; then cd gcc-10.3.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_11_1_0" == "1" ]; then cd gcc-11.1.0;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
            if [ "$BUILD_TRUNK" == "1" ]; then cd gcc-TRUNK;./contrib/download_prerequisites;cd "$HOMEDIR"; fi
        fi
    if [ "$BUILD_NEWLIB" != "0" ]; then tar -zxvf newlib-4.1.0.tar.gz; fi
        if [ "$BUILD_4_6_4" == "1" ] || [ "$BUILD_4_9_4" == "1" ] || [ "$BUILD_5_4_0" == "1" || [ "$BUILD_6_2_0" == "1" || [ "$BUILD_7_1_0" == "1" ] || [ "$BUILD_7_2_0" == "1" ] || [ "$BUILD_7_3_0" == "1" ] || [ "$BUILD_8_1_0" == "1" ]; then
            tar -jxvf binutils-2.27.tar.bz2
        fi
        if [ "$BUILD_8_2_0" == "1" ]; then tar -Jxvf binutils-2.31.tar.xz; fi
        if [ "$BUILD_8_3_0" == "1" ] || [ "$BUILD_9_1_0" == "1" ] || [ "$BUILD_9_2_0" == "1" ] || [ "$BUILD_9_3_0" == "1" ]; then tar -Jxvf binutils-2.32.tar.xz; fi
        if [ "$BUILD_10_1_0" == "1" ]; then tar -Jxvf binutils-2.34.tar.xz; fi
        if [ "$BUILD_10_2_0" == "1" ] || [ "$BUILD_10_3_0" == "1" ]; then tar -Jxvf binutils-2.35.tar.xz; fi
        if [ "$BUILD_11_1_0" == "1" ] || [ "$BUILD_TRUNK" == "1" ] ; then tar -Jxvf binutils-2.36.tar.xz; fi
    fi
   
    # 
    # Start the build
    #

    # This might be needed as gcc 7.2 doesn't seem to build 4.6.4...
    # Note that these exports are ubuntu 17.10 specific, you might need to change them depending on your distro!
    export CC=$CC4
    export CXX=$CXX4
    BINUTILS=2.27
    # Building Fortran for old gcc versions doesn't seem to work so it's disabled for now...
    BUILD_FORTRAN=0
   
    SKIP_464_CF=$GLOBAL_SKIP_464_CF     # Enabled only for 4.6.4
    if [ "$BUILD_4_6_4" == "1" ]; then buildgcc 4.6.4; fi
    SKIP_464_CF=0
    if [ "$BUILD_4_9_4" == "1" ]; then buildgcc 4.9.4; fi
                                       
    export CC=$CC5
    export CXX=$CXX5
                                       
    if [ "$BUILD_5_4_0" == "1" ]; then buildgcc 5.4.0; fi
                                       
    export CC=$CC6
    export CXX=$CXX6
    if [ "$BUILD_6_2_0" == "1" ]; then buildgcc 6.2.0; fi
                                       
    export CC=$CC7
    export CXX=$CXX7
    BUILD_FORTRAN=$GLOBAL_BUILD_FORTRAN
    if [ "$BUILD_7_1_0" == "1" ]; then buildgcc 7.1.0; fi
    if [ "$BUILD_7_2_0" == "1" ]; then buildgcc 7.2.0; fi
    if [ "$BUILD_7_3_0" == "1" ]; then buildgcc 7.3.0; fi

    export CC=$CC8
    export CXX=$CXX8
    BUILD_FORTRAN=$GLOBAL_BUILD_FORTRAN
    if [ "$BUILD_8_1_0" == "1" ]; then buildgcc 8.1.0; fi
    BINUTILS=2.31
    if [ "$BUILD_8_2_0" == "1" ]; then buildgcc 8.2.0; fi
    BINUTILS=2.32
    if [ "$BUILD_8_3_0" == "1" ]; then buildgcc 8.3.0; fi

    export CC=$CC9
    export CXX=$CXX9
    if [ "$BUILD_9_1_0" == "1" ]; then buildgcc 9.1.0; fi
    if [ "$BUILD_9_2_0" == "1" ]; then buildgcc 9.2.0; fi
    if [ "$BUILD_9_3_0" == "1" ]; then buildgcc 9.3.0; fi
    
    BINUTILS=2.34
    export CC=$CC10
    export CXX=$CXX10
    if [ "$BUILD_10_1_0" == "1" ]; then buildgcc 10.1.0; fi
    BINUTILS=2.35
    if [ "$BUILD_10_2_0" == "1" ]; then buildgcc 10.2.0; fi
    if [ "$BUILD_10_3_0" == "1" ]; then buildgcc 10.3.0; fi

    BINUTILS=2.36
    export CC=$CC11
    export CXX=$CXX11
    if [ "$BUILD_11_1_0" == "1" ]; then buildgcc 11.1.0; fi

    if [ "$BUILD_TRUNK" == "1" ]; then buildgcc TRUNK; fi

    echo "All done!"
}

# Build subroutine
# Parameter 1=version

buildgcc()
{
    # Construct compiler vendor name

    VENDOR=atari$1

    case "$1" in    # Brown up the names
    4.6.4)    VENDOR=atarioriginalbrown;;
    4.9.4)    VENDOR=atarioriginalbrowner;;
    5.4.0)    VENDOR=ataribrownish;;
    6.2.0)    VENDOR=ataribrown;;
    7.1.0)    VENDOR=ataribrowner;;
    7.2.0)    VENDOR=ataribrownerer;;
    7.3.0)    VENDOR=ataribrownest;;
    8.1.0)    VENDOR=atariultrabrown;;
    8.2.0)    VENDOR=ataribrownart;;
    8.3.0)    VENDOR=atariultrabrowner;;
    9.1.0)    VENDOR=atarihyperbrown;;
    9.2.0)    VENDOR=atarihyperbrowner;;
    9.3.0)    VENDOR=atarihyperbrownest;;
    10.1.0)   VENDOR=atariextrabrown;;
    10.2.0)   VENDOR=atariextrabrowner;;
    10.3.0)   VENDOR=atariextrabrownest;;
    11.1.0)   VENDOR=atarisuperbrown;;
    TRUNK)    VENDOR=ataribleedingbrown;;
    esac            # Brooooooooown

    # Clean build folders if requested
    if [ "$CLEANUP" == "Y" ]; then rm -rf build-gcc-$1 build-binutils-$1 mintlib-bigbrownbuild-$1 build-newlib-$1; cp -frp mintlib-bigbrownbuild mintlib-bigbrownbuild-$1; fi
    if [ "$BUILD_NEWLIB" != "0" ]; then cp -frp newlib-4.1.0 newlib-4.1.0-$1; fi

    # binutils build dir
    # Configure, build and install binutils for m68k elf
    
    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        REPLY=Y
    else    
        read -p "Configure build, install and package up binutils?" -n 1 -r
        echo
    fi
    if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
        # For gcc 8.x and MinGW, patch some nuisances in the source
        if [ "$machine" == "MinGw" ]; then
            if [ "$BINUTILS" == "2.31" ]; then
                # No MinGW isntall I have knows what ENOTSUP is.
                # Random internet suggestions said to replace this with ENOSYS so here we go
                $SED -i -e "s/ENOTSUP/ENOSYS/gI" $HOMEDIR/binutils-$BINUTILS/libiberty/simple-object-elf.c
            fi
        fi

        mkdir -p "$HOMEDIR"/build-binutils-$1
        cd "$HOMEDIR"/build-binutils-$1
        ../binutils-$BINUTILS/configure --disable-multilib --disable-nls --enable-lto --prefix=$INSTALL_PREFIX --target=m68k-$VENDOR-elf
        make $JMULT
        $SUDO make install $JMULT
        $SUDO strip $INSTALL_PREFIX/bin/*$VENDOR*
        $SUDO strip $INSTALL_PREFIX/m68k-$VENDOR-elf/bin/*
        $SUDO gzip -f -9 $INSTALL_PREFIX/share/man/*/*.1
    
        # Package up binutils
    
        make install DESTDIR=$BINPACKAGE_DIR $JMULT
        cd $BINPACKAGE_DIR
        strip .$INSTALL_PREFIX/bin/*
        strip .$INSTALL_PREFIX/m68k-$VENDOR-elf/bin/*
        gzip -f -9 .$INSTALL_PREFIX/share/man/*/*.1
        $TAR $TAROPTS -jcvf binutils-$BINUTILS-$VENDOR-bin.tar.bz2 .$INSTALL_PREFIX
    fi
    
    # Clean install dir
    rm -rf $BINPACKAGE_DIR/$INSTALL_PREFIX
    
    # home directory
    cd "$HOMEDIR"
    
    #
    # gcc build dir
    # Configure, build and install gcc without any libs for now
    #
    
    # Export flags for target compiler as well as pass them on configuration time.
    # Who knows, maybe one of the two will actually work!
    
    # Fortran is enabled now, but there are still issues when compiling
    # a program with it...
    if [ "$BUILD_FORTRAN" == "1" ]; then
        LANGUAGES=c,c++,fortran
    else
        LANGUAGES=c,c++
    fi
    WL=
    
    if [ "$USE_MIN_RAM" == "1" ]; then
        export CFLAGS="--param ggc-min-expand=10 --param ggc-min-heapsize=32768"
        export CXXFLAGS="--param ggc-min-expand=10 --param ggc-min-heapsize=32768"
        export CFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fleading-underscore --param ggc-min-expand=20 --param ggc-min-heapsize=32768"
        export CXXFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fno-threadsafe-statics -fno-exceptions -fno-rtti -fleading-underscore --param ggc-min-expand=20 --param ggc-min-heapsize=32768"
    else
        export CFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fleading-underscore"
        export CXXFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fno-threadsafe-statics -fno-exceptions -fno-rtti -fleading-underscore"
    fi
    export LDFLAGS_FOR_TARGET="${WL}--emit-relocs -Ttext=0"
    # TODO: This should build all target for all 000/020/040/060 and fpu/softfpu combos but it doesn't.
    #export MULTILIB_OPTIONS="m68000/m68020/m68040/m68060 msoft-float"
    
    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        REPLY=Y
    else    
        read -p "Configure, build and install gcc (without libs)?" -n 1 -r
        echo
    fi
    if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
        # For gcc 8.x and MinGW, patch some nuisances in the source
        if [ "$machine" == "MinGw" ]; then
            if [ "$1" == "8.1.0" ] || [ "$1" == "8.2.0" ] || [ "$1" == "8.3.0" ] || [ "$1" == "9.1.0" ] || [ "$1" == "9.2.0" ] || [ "$1" == "9.3.0" ]; then
                # No MinGW install I have knows what ENOTSUP is.
                # Random internet suggestions said to replace this with ENOSYS so here we go
                $SED -i -e "s/ENOTSUP/ENOSYS/gI" $HOMEDIR/gcc-$1/libiberty/simple-object-elf.c
                # The following two defines appear on most windows.h versions I have here
                # but not on MinGW. Who knows
                $SED -i '1s;^;#define COMMON_LVB_REVERSE_VIDEO   0x4000 \/\/ DBCS: Reverse fore\/back ground attribute.\n#define COMMON_LVB_UNDERSCORE      0x8000 \/\/ DBCS: Underscore.\n;' $HOMEDIR/gcc-$1/gcc/pretty-print.c
            fi
        fi
        mkdir -p "$HOMEDIR"/build-gcc-$1
        cd "$HOMEDIR"/build-gcc-$1
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
            CFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fleading-underscore --param ggc-min-expand=20 --param ggc-min-heapsize=32768" \
            CXXFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fno-threadsafe-statics -fno-exceptions -fno-rtti -fleading-underscore --param ggc-min-expand=20 --param ggc-min-heapsize=32768" \
            LDFLAGS_FOR_TARGET="${WL}--emit-relocs -Ttext=0"
        $NICE make all-gcc $JMULT
        $SUDO make install-gcc $JMULT
    
        # In some linux distros (linux mint for example) it was observed
        # that make install-gcc didn't set the read permission for users
        # so gcc couldn't work properly. No idea how to fix this propery
        # which means - botch time!                                     
        if [ "$machine" != "Cygwin" ] && [ "$machine" != "Mac" ]; then
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
    
    cd "$HOMEDIR"/build-gcc-$1
    
    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        REPLY=Y
    else    
        read -p "Build and install libgcc?" -n 1 -r
        echo
    fi
    if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
        make all-target-libgcc $JMULT
        $SUDO make install-target-libgcc $JMULT
    
        # Some extra permissions
        if [ "$machine" != "Cygwin" ] && [ "$machine" != "Mac" ]; then
            $SUDO chmod 755 -R $INSTALL_PREFIX/libexec/
        fi
    fi
        
    export PATH=${INSTALL_PREFIX}/bin:$PATH
    
    #
    # Newlib
    # This will require building a second version of gcc so we can tell it to use Newlib instead of libgcc.
    # Who knows, maybe this is not super required. But install guides on the internets seem to suggest doing this.
    #

    if [ "$BUILD_NEWLIB" != "0" ]; then
        if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
            REPLY=Y
        else    
            read -p "Build and install newlib (and custom gcc)?" -n 1 -r
            echo
        fi
        if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
            mkdir -p "$HOMEDIR/build-newlib-$1/build"
            cd "$HOMEDIR/build-newlib-$1/build"
            CC=m68k-$VENDOR-elf-gcc $HOMEDIR/newlib-4.1.0-$1/newlib/configure --target=m68k-$VENDOR-elf --build=m68k-$VENDOR-elf --host=m68k-$VENDOR-elf --prefix=${INSTALL_PREFIX}-newlib
            $NICE make $JMULT
            $SUDO make install
   
            # Re-configure and build gcc with "--with-newlib". Exciting.
            mkdir -p "$HOMEDIR"/build-gcc-newlib-$1
            cd "$HOMEDIR"/build-gcc-newlib-$1
            ../gcc-$1/configure \
                --with-newlib \
                --target=m68k-$VENDORnewlib-elf \
                --disable-nls \
                --enable-languages=$LANGUAGES \
                --enable-lto \
                --prefix=${INSTALL_PREFIX}-newlib \
                --disable-libssp \
                --enable-softfloat \
                --disable-libstdcxx-pch \
                --disable-clocale \
                --disable-libstdcxx-threads \
                --disable-libstdcxx-filesystem-ts \
                --disable-libquadmath \
                --enable-cxx-flags='-O2 -fomit-frame-pointer -fno-threadsafe-statics -fno-exceptions -fno-rtti -fleading-underscore' \
                CFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fleading-underscore --param ggc-min-expand=20 --param ggc-min-heapsize=32768" \
                CXXFLAGS_FOR_TARGET="-O2 -fomit-frame-pointer -fno-threadsafe-statics -fno-exceptions -fno-rtti -fleading-underscore --param ggc-min-expand=20 --param ggc-min-heapsize=32768" \
                LDFLAGS_FOR_TARGET="${WL}--emit-relocs -Ttext=0"
            $NICE make all-gcc $JMULT
            $SUDO make install-gcc $JMULT
        fi
    fi

    #
    # Mintlib 
    #

    if [ "$BUILD_MINTLIB" != "0" ]; then

        # Patch mintlib at the source level
        cd "$HOMEDIR"
        
        if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
            REPLY=Y
        else    
            read -p "Source patch and build mintlib?" -n 1 -r
            echo
        fi
        if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
        
            MINTLIBDIR="$HOMEDIR"/mintlib-bigbrownbuild-$1
        
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
            
            # When building using cross-gcc-4.6.4 the compilers ICE with coldfire targets at
            # stdio/printf_fp.c. So let's disable this...
            if [ "$SKIP_464_CF" == "Y" ] || [ "$SKIP_464_CF" == "y" ]; then
                $SED -i -e "s/WITH_V4E_LIB/#WITH_V4E_LIB  #disabled since we get Internal Compiler Error :(/gI" $MINTLIBDIR/configvars
            fi
           
            if [ "$1" == "TRUNK" ] || [ "$1" == "10.1.0" ] || [ "$1" == "10.2.0" ] || [ "$1" == "10.3.0" ] || [ "$1" == "11.1.0" ]; then
                # h_errno is defined in 2 sources of MiNTlib and up till gcc 9 it was
                # fine. But not anymore O_o
                $SED -i -e 's/int h_errno/extern int h_errno/gI' $MINTLIBDIR/socket/res_query.c
            fi

            if [ "$machine" == "MinGw" ]; then
        
            #   Because MinGW/Msys has mixed forward/backward slashs in paths, convert
            #   installdir=`$(CC) --print-search-dirs | awk '{ print $$2; exit; }'`; \
            #   to:
            #   installdir=`$(CC) --print-search-dirs | awk '{ print $$2; exit; }' | sed -e 's/\\\\/\//gI'`; \
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

            if [ "$machine" == "Mac" ]; then
                # MacOS 10.11.6 ("El Capitan") has a slightly different flex installation
                # via macports, so we can't link using -lfl. Instead we need to link
                # against -ll
                $SED -i -e 's/-lfl/-ll/gI' $MINTLIBDIR/syscall/Makefile
            fi
        
            cd $MINTLIBDIR
        
            # can't safely use -j with mintlib due to bison/flex dependency ordering woe
            make SHELL=/bin/bash
        
            # Install the lib.
            # For some reason math.h isn't installed so we do it by hand
            # ¯\_(ツ)_/¯ 
            $SUDO make install
            $SUDO cp include/math.h $INSTALL_PREFIX/m68k-$VENDOR-elf/include
            if [ "$machine" == "Mac" ]; then
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
    
    cd "$HOMEDIR"/gcc-$1
    
    # Some more permissions need to be fixed here
    if [ "$machine" != "Cygwin" ] && [ "$machine" != "MinGw" ] && [ "$machine" != "Mac" ]; then
        if [ "$BUILD_MINTLIB" != "0" ]; then
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
    if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
    
        # edit file gcc-$1/libstdc++-v3/configure - comment out the line:
        ##as_fn_error "No support for this host/target combination." "$LINENO" 5
        # see comment below for gcc 9.1.0
    
        $SED -i -e 's/as_fn_error .* \"No support for this host\/target combination.\" \"\$LINENO\" 5/#ignored/gI' "$HOMEDIR"/gcc-$1/libstdc++-v3/configure
        
        # *** hack configure to remove dlopen stuff
        
        # # Libtool setup.
        # if test "x${with_newlib}" != "xyes"; then
        #-  AC_LIBTOOL_DLOPEN
        #+#  AC_LIBTOOL_DLOPEN
        # fi
        $SED -i -e "s/  AC_LIBTOOL_DLOPEN/#  AC_LIBTOOL_DLOPEN/gI" "$HOMEDIR"/gcc-$1/libstdc++-v3/configure.ac
        
        #libstdc++-v3/configure:
        #
        #*** for every instance of: as_fn_error "Link tests are not allowed after GCC_NO_EXECUTABLES." "$LINENO" 5
        #*** change to as_echo_n so the configure doesn't halt on this error
        #*** as of gcc 9.1.0 a .* was added to the search pattern of sed as they seem to have added the characters $? in there. Hopefully this doesn't break older builds
        #*** (gee, they are full of surprises, aren't they?)
        #
        #  as_echo_n "Link tests are not allowed after GCC_NO_EXECUTABLES." "$LINENO" 5
        $SED -i -e "s/  as_fn_error .* \"Link tests are not allowed after GCC_NO_EXECUTABLES.*/  \$as_echo \"lolol\"/gI" "$HOMEDIR"/gcc-$1/libstdc++-v3/configure

        #libstdc++-v3/configure:
        # From v10.3.0 onwards the c++17 filesystem code will fail to build if _GLIBCXX_USE_ST_MTIM is defined, because some time structs have missing members (ummm, okay)
        # (specifically libstdc++-v3/src/filesystem/ops-common.h is the thing that complains). So let's not enable that
        if [ "$1" == "10.3.0" ] ||[ "$1" == "11.1.0" ] || [ "$1" == "TRUNK" ]; then
            $SED -i -e "s/#define _GLIBCXX_USE_ST_MTIM/#define _GLIBCXX_USE_ST_MTIMLOLOL/gI" "$HOMEDIR"/gcc-$1/libstdc++-v3/configure
        fi

        #libstdc++-v3/src/c++17/floating_to_chars.cc:
        # (11.1.0 onwards)
        # This file uses some FP_* defines that are simply non existent in our case. Even worse, the code that uses these is inside a template.
        # So let's try to convince it to not do that
        if [ "$1" == "11.1.0" ] || [ "$1" == "TRUNK" ]; then
            $SED -i -e "s/switch (__builtin_fpclassify(/\/*switch (__builtin_fpclassify(/gI" "$HOMEDIR"/gcc-$1/libstdc++-v3/src/c++17/floating_to_chars.cc   # start of block
            $SED -i -e "s/return nullopt;/return nullopt;*\/{/gI" "$HOMEDIR"/gcc-$1/libstdc++-v3/src/c++17/floating_to_chars.cc                              # end of block (actually the end of the block is a } at the next line, so we add a { after the comment's end to balance the braces
        fi

        #*** remove the contents of cow-stdexcept.cc
        #
        #gcc-$1\libstdc++-v3\src\c++11\cow_stdexcept.cc
        #
        ##if (0)
        #...everything...
        ##endif
   
        if [ -f "$HOMEDIR"/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc ]; then
            echo "#if (0)" > "$HOMEDIR"/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc.new
            cat "$HOMEDIR"/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc >> "$HOMEDIR"/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc.new
            echo "#endif" >> "$HOMEDIR"/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc.new
            mv "$HOMEDIR"/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc.new "$HOMEDIR"/gcc-$1/libstdc++-v3/src/c++11/cow-stdexcept.cc
        fi

        # Seems that gcc 9.1.0 also doesn't know what ENOTSUP is, which also cascades to std::errc::not_supported
        # The later should be changed to std::errc::function_not_supported which corresponds to ENOSYS
        # files gcc-9.1.0/libstdc++-v3/src/filesystem/ops-common.h
        #       gcc-9.1.0/libstdc++-v3/src/c++17/fs_ops.cc
        if [ "$1" == "9.1.0" ] || [ "$1" == "9.2.0" ] || [ "$1" == "9.3.0" ] || [ "$1" == "10.1.0" ] || [ "$1" == "10.2.0" ] || [ "$1" == "10.3.0" ] || [ "$1" == "11.1.0" ] || [ "$1" == "TRUNK" ]; then
            $SED -i -e "s/ENOTSUP/ENOSYS/gI" $HOMEDIR/gcc-$1/libstdc++-v3/src/filesystem/ops-common.h
            $SED -i -e "s/::not_supported/::function_not_supported/gI" $HOMEDIR/gcc-$1/libstdc++-v3/src/filesystem/ops-common.h
            $SED -i -e "s/::not_supported/::function_not_supported/gI" $HOMEDIR/gcc-$1/libstdc++-v3/src/c++17/fs_ops.cc
        fi
    
    fi
    
    #*** configure libstdc++-v3
    
    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        REPLY=Y
    else
        read -p "Patch libstdc++v3's configure scripts?" -n 1 -r
        echo
    fi
    if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
        #*** remove -std=gnu++98 from the toplevel makefile - it gets combined with the c++11 Makefile and causes problems
        #
        #gcc-$1/build/src/Makefile:
        #
        #AM_CXXFLAGS = \
        #   -std=gnu++98 ******** remove this ********
        #   $(glibcxx_compiler_pic_flag) \
        #   $(XTEMPLATE_FLAGS) $(VTV_CXXFLAGS) \
        #   $(WARN_CXXFLAGS) $(OPTIMIZE_CXXFLAGS) $(CONFIG_CXXFLAGS)
        
        cd "$HOMEDIR"/build-gcc-$1
        $NICE make configure-target-libstdc++-v3 $JMULT
     
        #$SED -i -e "s/-std=gnu++98//gI" "$HOMEDIR"/gcc-$1/build/src/Makefile
        $SED -i -e "s/-std=gnu++98//gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/libstdc++-v3/src/Makefile
    
        
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
        
        #sed -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/gcc-$1/build/include/type_traits
    
        # Patch all multilib instances
        # TODO: replace this with a grep or find command
        #       (yeah right, that will happen soon)
        if [ "$BUILD_MINTLIB" != "0" ]; then
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/softfp/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m68060/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m68060/softfp/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/mcpu32/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/mfidoa/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/mfidoa/softfp/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5407/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m54455/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5475/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5475/softfp/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m68040/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m68040/softfp/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m51qe/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5206/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5206e/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5208/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5307/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5329/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m68000/libstdc++-v3/include/type_traits
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/libstdc++-v3/include/type_traits

            # Tentative: patch the source file as well
            $SED -i -e "s/_CTp/_xCTp/gI" "$HOMEDIR"/gcc-$1/libstdc++-v3/include/std/type_traits
        fi

        #*** fix type_traits to favour <cstdint> over those partially-defined wierd builtin int_leastXX, int_fastXX types
        #*** note: this causes multiply defined std:: or missing :: types depending on _GLIBCXX_USE_C99_STDINT_TR1 1/0
        #
    
        #sed -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/gcc-$1/build/include/type_traits
    
        # Patch all multilib instances
        # TODO: replace this with a grep or find command
        #       (yeah right, that will happen soon)
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/softfp/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m68060/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m68060/softfp/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/mcpu32/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/mfidoa/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/mfidoa/softfp/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5407/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m54455/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5475/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5475/softfp/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m68040/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m68040/softfp/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m51qe/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5206/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5206e/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5208/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5307/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m5329/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/m68000/libstdc++-v3/include/type_traits
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/build-gcc-$1/m68k-$VENDOR-elf/libstdc++-v3/include/type_traits
    
        # Tentative: patch the source file as well
        $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" "$HOMEDIR"/gcc-$1/libstdc++-v3/include/std/type_traits
    fi
    
    # Build Fortran (not guaranteed to work for gccs earlier than 7)
    if [ "$BUILD_FORTRAN" == "1" ]; then
        if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
            REPLY=Y
        else    
            read -p "Configure, source patch and build glibfortran?" -n 1 -r
            echo
        fi
    if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
            # From what I could see libgfortran only has some function re-declarations
            # This might be possible to fix by passing proper configuration options
            # during configuration, but lolwtfwhocares - let's patch some files! 
            $SED -i -e "s/eps = nextafter/eps = __builtin_nextafter/gI" "$HOMEDIR"/gcc-$1/libgfortran/intrinsics/c99_functions.c
            $SED -i -e "s/#ifndef HAVE_GMTIME_R/#if 0/gI" "$HOMEDIR"/gcc-$1/libgfortran/intrinsics/date_and_time.c
            $SED -i -e "s/#ifndef HAVE_LOCALTIME_R/#if 0/gI" "$HOMEDIR"/gcc-$1/libgfortran/intrinsics/time_1.h
            $SED -i -e "s/#ifndef HAVE_STRNLEN/#if 0/gI" "$HOMEDIR"/gcc-$1/libgfortran/runtime/string.c
            $SED -i -e "s/#ifndef HAVE_STRNDUP/#if 0/gI" "$HOMEDIR"/gcc-$1/libgfortran/runtime/string.c
            $SED -i -e "s/${WL}--emit-relocs//gI" "$HOMEDIR"/build-gcc-$1/Makefile
            # Same as libstc++v3
            $SED -i -e "s/  as_fn_error .* \"Link tests are not allowed after GCC_NO_EXECUTABLES.*/  \$as_echo \"lolol\"/gI" "$HOMEDIR"/gcc-$1/libgfortran/configure

            if [ "$1" == "9.1.0" ] || [ "$1" == "9.2.0" ] || [ "$1" == "9.3.0" ] || [ "$1" == "10.1.0" ] || [ "$1" == "10.2.0" ] || [ "$1" == "10.3.0" ] || [ "$1" == "11.1.0" ] || [ "$1" == "TRUNK" ]; then
                # Some weird inconsistency in gf_vsnprintf - let's patch it up
                $SED -i -e "s/written = vsprintf(buffer, format, ap)/written = vsprintf(str, format, ap)/gI" "$HOMEDIR"/gcc-$1/libgfortran/runtime/error.c
                $SED -i -e "s/write (STDERR_FILENO, buffer, size - 1)/write (STDERR_FILENO, str, size - 1)/gI" "$HOMEDIR"/gcc-$1/libgfortran/runtime/error.c
            fi
            if [ "$1" == "9.2.0" ] || [ "$1" == "9.3.0" ] || [ "$1" == "10.1.0" ] || [ "$1" == "10.2.0" ] || [ "$1" == "10.3.0" ] || [ "$1" == "11.1.0" ] || [ "$1" == "TRUNK" ]; then
                # Starting with 9.2.0 onwards, async execution was added. Most likely our capabilities don't allow this
                # so we don't get the define SA_RESTART in our signal.h. So let's just silently define it (its value seems
                # to be uniformally the same) and move on
                $SED -i -e "s/#include <string.h>/#include <string.h>\n#define SA_RESTART        0x10000000/gI" "$HOMEDIR"/gcc-$1/libgfortran/intrinsics/execute_command_line.c
            fi
        
            make configure-target-libgfortran $JMULT
            $NICE make $JMULT all-target-libgfortran
            make install-target-libgfortran $JMULT
        fi
    fi 
    #*** build it
    
    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        REPLY=Y
    else    
        read -p "Build and install libstdc++v3?" -n 1 -r
        echo
    fi
    if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
        cd "$HOMEDIR"/build-gcc-$1
        make all-target-libstdc++-v3 $JMULT
        $SUDO make install-target-libstdc++-v3 $JMULT
    fi
    
    # gcc build dir
    # build everything else
    # (which doesn't amount to much)
    
    cd "$HOMEDIR"/build-gcc-$1
    
    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        REPLY=Y
    else    
        read -p "Build and install the rest?" -n 1 -r
        echo
    fi
    if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]
    then    
        # I dunno why this must be done.
        # It happens on linux mint
        if [ "$machine" != "Cygwin" ] && [ "$machine" != "MinGw" ]; then
            $SUDO chmod 775 "$HOMEDIR"/build-gcc-$1/gcc/b-header-vars
        fi
        # This system include isn't picked up for some reason 
        if [ "$machine" == "Mac" ]; then
            $SED -i -e "s/<gmp.h>/\"\/opt\/local\/include\/gmp.h\"/gI" "$HOMEDIR"/gcc-$1/gcc/system.h 
        fi 
    
        if [ "$1" == "TRUNK" ]; then
            GCCVERSION=$TRUNK_VERSION
        else
            GCCVERSION=$1
        fi

        $NICE make all $JMULT
        $SUDO make install $JMULT
        $SUDO strip $INSTALL_PREFIX/bin/*$VENDOR*
        if [ "$machine" == "Cygwin" ] || [ "$machine" != "MinGw" ] || [ "$machine" != "Mac" ]; then
            $SUDO strip $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/cc1* \
                $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/cc1plus* \
                $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/collect2* \
                $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/lto1* \
                $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/lto-wrapper*
        else
            $SUDO strip $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/cc1* \
                $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/cc1plus* \
                $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/collect2* \
                $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/liblto_plugin.so \
                $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/liblto_plugin.so.0 \
                $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/liblto_plugin.so.0.0.0 \
                $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/lto1 \
                $INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/lto-wrapper
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
    if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]
    then    
        make install DESTDIR=$BINPACKAGE_DIR $JMULT
        if [ "$BUILD_NEWLIB" != "0"]; then
            cd $HOMEDIR/build-gcc-newlib-$1
            make install DESTDIR=${BINPACKAGE_DIR}-newlib
        fi
        cd $BINPACKAGE_DIR
        # Since make install uses the non-patched type_traits file let's patch them here too
        # (yes this could have been done before even configuring stdlib++v3 - anyone wants to try?)
        for i in `find . -name type_traits`; do echo Patching $i; $SED -i -e "s/__UINT_LEAST16_TYPE__/__XXX_UINT_LEAST16_TYPE__/I" $i;done
    
        if [ "$1" == "TRUNK" ]; then
            GCCVERSION=$TRUNK_VERSION
        else
            GCCVERSION=$1
        fi

        strip .$INSTALL_PREFIX/bin/*
        if [ "$machine" == "Cygwin" ] || [ "$machine" != "MinGw" ] || [ "$machine" != "Mac" ]; then
            $SUDO strip .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/cc1* \
                .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/cc1plus* \
                .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/collect2* \
                .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/lto1* \
                .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/lto-wrapper*
        else
            $SUDO strip .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/cc1* \
                .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/cc1plus* \
                .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/collect2* \
                .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/liblto_plugin.so \
                .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/liblto_plugin.so.0 \
                .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/liblto_plugin.so.0.0.0 \
                .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/lto1 \
                .$INSTALL_PREFIX/libexec/gcc/m68k-$VENDOR-elf/$GCCVERSION/lto-wrapper
        fi
    
        find .$INSTALL_PREFIX/m68k-$VENDOR-elf/lib -name '*.a' -print -exec m68k-$VENDOR-elf-strip -S -x '{}' ';'
        find .$INSTALL_PREFIX/lib/gcc/m68k-$VENDOR-elf/* -name '*.a' -print -exec m68k-$VENDOR-elf-strip -S -x '{}' ';'
        $TAR $TAROPTS -jcvf gcc-$VENDOR-bin.tar.bz2 .$INSTALL_PREFIX

    fi

    if [ "$GLOBAL_OVERRIDE" == "A" ] || [ "$GLOBAL_OVERRIDE" == "a" ]; then
        REPLY=Y
    else    
        read -p "Reorganise MiNTlib folders?" -n 1 -r
        echo
    fi
    if [ "$REPLY" == "Y" ] || [ "$REPLY" == "y" ]; then
        # reorganise install dirs to map libs to all processor switches
        #
        # on completion the target:lib variants will be:
        #
        # m68000/       assumes no fpu
        # m68020/       assumes 68881/2
        # m68020/softfp     assumes no fpu
        # m68020-60/        assumes any 0x0 cpu, 68881/2
        # m68020-60/softfp  assumes any 0x0 cpu, no fpu
        # m68040/       assumes internal fpu
        # m68060/       assumes internal fpu
        
        
        LIBGCC=$INSTALL_PREFIX/lib/gcc/m68k-$VENDOR-elf/$GCCVERSION
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
    cd "$HOMEDIR"
}

mainbrown "$@"

