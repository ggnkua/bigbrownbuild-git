# Minimal example for interoperation between C and assembly

This is a small example that demonstrates how one can mix C and assembly language with the gcc toolchain. It uses no library calls, and the little libc functions needed are provided as assembly replacements.

The sample program does the following:

- Detects type of ST machine (ST/STE/Falcon/etc)
- Saves video
- Sets up video
- Fades a picture in
- Plays a PCM sample (on STE/Falcon/TT)
- Waits for a keypress
- Fades out the colours
- Restores video
- Exits to the desktop

# How to build

The following items are required:

- A working gcc-elf
- Brownout (https://github.com/ggnkua/brownout-git / https://bitbucket.org/ggnkua/brownout-git/)
- Fastbuild (https://www.fastbuild.org/docs/download.html)
- rmac (http://rmac.is-slick.com/download/download/)
- ncovnert (https://www.xnview.com/en/nconvert/)
- sox (http://sox.sourceforge.net)

The above tools are portable, so they can be all exist inside a single folder (or, if you prefer, a single directory tree). Everything is cross platform, so they should work fine under Windows, Linux and MacOS at least.

Open ```fbuild.bff``` and edit the paths to each tool. The default locations expected for tools are under a ```tools``` folder inside this directory, and the gcc under ```toolchains```

Then, type ```fbuild``` in a console from within the directory this readme exists to build the example. ```test.prg``` should appear in the same directory.

(If things don't work, try ```fbuild -showcmds -j1``` to try to diagnose the problem)

