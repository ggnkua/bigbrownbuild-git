# bigbrownbuild.sh

## What is this

A collection of brown scripts that build brown compilers and libaries for the Atari ST series of computers.

## Notable features

* link-time whole-program optimisation (inter-module calls & inlining)

* improved optimiser

* C++14, C++17 support

* named section support via C and asm

* proper C++ initialise/finalise sequence

* GST extended symbols

* can preview code generation in Godbolt/68k (try it live at http://brownbot.mooo.com)

* path open for future gcc releases

# Requirements

The script will attempt to auto-fetch the required gcc/binutils/mintlib packages. If something goes wrong you'll have to modify the fetch URLs.

Make sure you have installed the following libraries and tools.

### Linux/Windows

* GMP (dev) (if you don't download prerequisites, see [GLOBAL_DOWNLOAD_PREREQUISITES](#GLOBAL_DOWNLOAD_PREREQUISITES))

* MPFR (dev) (if you don't download prerequisites, see [GLOBAL_DOWNLOAD_PREREQUISITES](#GLOBAL_DOWNLOAD_PREREQUISITES))

* MPC (dev) (if you don't download prerequisites, see [GLOBAL_DOWNLOAD_PREREQUISITES](#GLOBAL_DOWNLOAD_PREREQUISITES))

* bison-bin

* flex-bin

* flex-dev

GMP/MPFR/MPC are required for building gcc (if you don't download prerequisites, see [GLOBAL_DOWNLOAD_PREREQUISITES](#GLOBAL_DOWNLOAD_PREREQUISITES)), flex and bison for building MiNTlib.

### macOS

Use Macports and install:

* gmp (if you don't download prerequisites, see [GLOBAL_DOWNLOAD_PREREQUISITES](#GLOBAL_DOWNLOAD_PREREQUISITES))

* mpfr (if you don't download prerequisites, see [GLOBAL_DOWNLOAD_PREREQUISITES](#GLOBAL_DOWNLOAD_PREREQUISITES))

* libmpc (if you don't download prerequisites, see [GLOBAL_DOWNLOAD_PREREQUISITES](#GLOBAL_DOWNLOAD_PREREQUISITES))

* bison

* flex

* gsed

* gnutar

* wget

# Installation

Before running the script it is advised to open it and go through the "User definable stuff" settings. In brief they are:

### GLOBAL_OVERRIDE

Set this to A if you want a completely automated run.
    
### GLOBAL_BUILD_FORTRAN

Set this to 1 to build Fortran, anything else to skip building Fortran.

### GLOBAL_DOWNLOAD_PREREQUISITES

Set this to 1 to download prerequisite libs such as MPC and MPFR automatically (without having to install them on the host machine) via the contrib/download_prerequisites script inside each gcc. Not tested extensively but it seems to work with gcc 4.6.4.

### BUILD_X_Y_Z

Which gccs to build. 1=Build, anything else=Don't build. Can be toggled individually.

### RUN_MODE

Should we run this as an administrator or user? Administrator mode will install the compiler in the system's folders and will require root priviledges.

### BUILD_MINTLIB

Only set this to nonzero when you do want to build mintlib. Note that if you don't build mintlib then libstdc++v3 will also fail to build, so you are advised to keep this on.
    
### CC?/CXX?

The actual names of the compilers used to build our set of gccs. The names aretuned for ubuntu 17.10 so your mileage may vary!

Also you might be able to build all gcc versions using one compiler. In Ubuntu 17.10 so many problems were encountered in Ubuntu (including Internal Compiler Errors) that this is now in full pendantic mode. Again, your mileage may vary!

### CROSS_COMPILING

At first this sounds redundant given that the script produces a cross compiler to begin with. This setting should be enabled if the cross compiler is not going to be executed in a different platform than it is built.

For example: We want to build a 68k cross compiler on a x86 PC that will execute on an ARM processor.

### Other notes
The script will install things to ```$INSTALL_PREFIX``` and might need root privileges. Also it'll use ```$JMULT``` cores while building. If this is not to your liking then edit this script and change ```INSTALL_PREFIX``` to the path you would like to install to (including home folder) and ```SUDO``` to nothing if you don't need root rights. Also ```JMULT``` for number of build cores. Examples are inside the script's comments. Log files are written inside each build folder for each version of gcc built. So for example there's ```build-binutils-2.38/binutils_configure.log``, ```build-gcc-12.1.0/gcc_build.log``` and so on.

# Testing

Inside the folder ```barebones``` there exist test projects to verify that your gcc installation is sane. Just type ```make``` on installations that have make installed or run ```build.bat``` under Windows (especially if you built the toolchain(s) using MinGW).

There is also a different example in the folder ```barebones-interop```. This illustrates how to set up a project to work with C and assembly. Consult the ```readme.md``` inside that folder for more information.

# bigbrowngemlib.sh

This is a work-in-progress script. Currently it cannot build GEMlib properly. Patches welcome!

# bigbrownlibcmini.sh

This is a work-in-progress script. Currently it cannot build GEMlib properly. Patches welcome!

# Note for MinGW users

Be warned that the compilation can take a very very VERY long time! If you can spare the RAM, we really recommend using a RAM drive! Our tests have shown that imdisk (http://www.ltr-data.se/opencode.html/#ImDisk) works fine. Of course take notice that you're doing this on your own, we won't accept any liability if something goes wrong with that!!!!

# Building the "barebones" examples

Download and build Brownout (https://github.com/ggnkua/brownout-git / https://bitbucket.org/ggnkua/brownout-git/) and place it in the ```barebones``` directory.

If you have a command prompt that is able to run ```make``` (e.g. Linux, Cygwin, MinGW etc) then just type ```make``` (make sure your build cross gcc is in the PATH). Otherwise on Windows you can just run ```build.bat``` (edit ```GCCPATH``` to point to your toolchain path first).

Note that this will build only for the latest supported cross gcc version. For older versions, some simple find and replaces should be enough.

# Credits

The bulk of the script was written by George 'GGN' Nakos, with enhancements from:

* Douglas 'DML' Little
* Patrice 'PMANDIN' Mandin
* Troed 'TROED' Sångberg

