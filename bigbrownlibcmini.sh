set -e			#stop on any error encountered
#set -x         #echo all commands

fixregs()
{
    sed -i -e "s/sp/%sp/gI" \
           -e "s/a0/%a0/gI" \
           -e "s/a1/%a1/gI" \
           -e "s/a2/%a2/gI" \
           -e "s/a3/%a3/gI" \
           -e "s/a4/%a4/gI" \
           -e "s/a5/%a5/gI" \
           -e "s/a6/%a6/gI" \
           -e "s/a7/%a7/gI" \
           -e "s/d0/%d0/gI" \
           -e "s/d1/%d1/gI" \
           -e "s/d2/%d2/gI" \
           -e "s/d3/%d3/gI" \
           -e "s/d4/%d4/gI" \
           -e "s/d5/%d5/gI" \
           -e "s/d6/%d6/gI" \
           -e "s/d7/%d7/gI" -i $1
}
echo Run me inside libcmini/trunk/libcmini
sed -i -e "s/m68k-elf-/m68k-ataribrownest-elf-/gI" -e "s/COMPILE_ELF=N/COMPILE_ELF=Y/gI" Makefile 
fixregs sources/_normdf.S
fixregs sources/checkcpu.S
fixregs sources/frexp.S
fixregs sources/getcookie.S
sed -i "s/0x5%a0/0x5a0/gI" sources/getcookie.S
fixregs sources/getsysvar.S
fixregs sources/ldexp.S
fixregs sources/modf.S
fixregs sources/setstack.S
fixregs sources/startup.S
fixregs sources/setjmp.c
fixregs sources/setjmp.c
# This is wrong. gcc 6.2 will crash if a6 is added to the clobber list
# so we remove it. No idea what will happen though.
sed -i -e 's/, "%%a6"//gI' sources/setjmp.c
sed -i -e "s/m68k-atari-mint-/m68k-ataribrownest-elf-/gI" tests/acctest/Makefile 
make
