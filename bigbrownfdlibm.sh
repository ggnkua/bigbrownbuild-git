# TODO eventually this will be incorporated to the main script

set -e          #stop on any error encountered
#set -x         #echo all commands

# Edit to taste
COMPILER=~/brown-crosstemp-16.1.0/bin/m68k-atariexaltedbrown-elf-gcc

git clone https://github.com/freemint/fdlibm.git

cd fdlibm
#CC=${COMPILER} ./configure

sed -i -e "/^CFLAGS = /s/$/ -fleading-underscore -Wno-shift-count-overflow -Wno-error=overflow/" Makefile.in
CC=${COMPILER} ./configure --host=x86_64-unknown-linux-gnu


make -j16
cd ..
