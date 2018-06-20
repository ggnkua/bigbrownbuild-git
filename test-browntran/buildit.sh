# You need libpml for this to even begin to link!
# Run build-pml.sh first (make sure you grab the pml archive too)
# and copy libpml.a from the appropriate folders here
# (notice that both 68000 and 68020+ libraries are named libm.a O_o)

# Brownboot.s needs vasm to build for now...
# vasmm68k_mot -Felf brownboot.s -o brownboot.o

# 68020 build compiles and links without error but gives 4 bombs when running.
# Looks like some symbol isn't getting relocated....
~/brown/bin/m68k-atariultrabrown-elf-gfortran -c -fleading-underscore heron.f -fomit-frame-pointer -L. -Ttext=0
~/brown/bin/m68k-atariultrabrown-elf-gfortran brownboot.o heron.o -o heron.elf -L.

# 68000 build doesn't compile yet - it gives:
# /usr/lib/gcc/m68k-atariultrabrown-elf/7.1.0/../../../../m68k-atariultrabrown-elf/lib/libgfortran.a(c99_functions.o): In function `_lgamma':
# (.text.lgamma+0x11c): undefined reference to `_nextafter`
# although libgfortran is somehow patched during building to fix that symbol...
~/brown/bin/m68k-atariultrabrown-elf-gfortran -c -fleading-underscore heron.f -fomit-frame-pointer -L. -Ttext=0
~/brown/bin/m68k-atariultrabrown-elf-gfortran brownboot.o heron.o -o heron00.elf -L.
