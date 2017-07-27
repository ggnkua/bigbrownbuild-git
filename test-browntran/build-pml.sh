set -x
set -e

echo Get the PML archive from http://d-bug.mooo.com/releases/pml-2.03-ataribrown.tar.gz !!

tar -zxvf pml-2.03-ataribrown.tar.gz
cd pml-2.03-ataribrown/pmlsrc

INSTALL_DIR=/usr

# 1st pass for compiling m68000 libraries
make
make install CROSSDIR=build-pml$INSTALL_DIR

# 2nd pass for compiling m68020-60 libraries
make clean
sed -i "s:^\(CFLAGS =.*\):\1 -m68020-60:g" Makefile.32 Makefile.16
sed -i "s:^\(CROSSLIB =.*\):\1/m68020-60:g" Makefile
make
make install CROSSDIR=build-pml$INSTALL_DIR

# 3rd pass for compiling ColdFire V4e libraries
#make clean
#sed -i "s:-m68020-60:-mcpu=5475:g" Makefile.32 Makefile.16
#sed -i "s:m68020-60:m5475:g" Makefile
#make
#make install CROSSDIR=$PWD/binary-package$INSTALL_DIR

cd build-pml
find . -name '*.a' -print -exec m68k-ataribrowner-elf-strip -S -x '{}' ';'

