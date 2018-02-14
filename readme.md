#bigbrownbuild.sh

##What is this

A collection of brown scripts that build brown compilers and libaries for the Atari ST series of computers.

##Notable features

* link-time whole-program optimisation (inter-module calls & inlining)

* improved optimiser

* C++14, C++17 support

* named section support via C and asm

* proper C++ initialise/finalise sequence

* GST extended symbols

* can preview code generation in Godbolt/68k

* path open for future gcc releases

#Requirements

The script will attempt to auto-fetch the required gcc/binutils/mintlib packages. If something goes wrong you'll have to modify the fetch URLs.

Make sure you have installed the following libraries and tools.

##Linux/Windows

* GMP (dev version)

* MPFR (dev version)

* MPC (dev version)

* bison-bin

* flex-bin

* flex-dev

GMP/MPFR/MPC are required for building gcc, flex and bison for building MiNTlib.

##macOS

Use Macports and install:

*gmp

*mpfr

*libmpc

*bison

*flex

*gsed

*gnutar

#Installation

The script will install things to $INSTALL_PREFIX and might need root privileges. Also it'll use $JMULT cores while building. If this is not to your liking then edit this script and change INSTALL_PREFIX to the path you would like to install to (including home folder) and SUDO to nothing if you don't need root rights. Also JMULT for number of build cores. Examples are inside the script's comments

#Post installation

It is recommended to run _postinstall.sh to rename mintlib's install directories to more sane names. Don't forget to edit the paths first before running!

Also, make absolutely sure you run it only once!

#Testing

Inside the folder ```barebones``` there exist test projects to verify that your gcc installation is sane. Just type ```make``` on installations that have make installed or run ```build.bat``` under Windows (especially if you built the toolchain(s) using MinGW).

#bigbrowngemlib.sh

This is a work-in-progress script. Currently it cannot build GEMlib properly. Patches welcome!

#bigbrownlibcmini.sh

This is a work-in-progress script. Currently it cannot build GEMlib properly. Patches welcome!

#Note for MinGW users

Be warned that the compilation can take a very very VERY long time! If you can spare the RAM, we really recommend using a RAM drive! Our tests have shown that imdisk (http://www.ltr-data.se/opencode.html/#ImDisk) works fine. Of course take notice that you're doing this on your own, we won't accept any liability if something goes wrong with that!!!!

#Credits

The bulk of the script was written by George 'GGN' Nakos, with enhancements from:

* Douglas 'DML' Little
* Patrice 'PMANDIN' Mandin
* Troed 'TROED' Sångberg

