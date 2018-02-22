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

#wget http://arnaud.bercegeay.free.fr/gemlib/gemlib-0.44.0-src.tgz
tar -zxvf gemlib-0.44.0-src.tgz
cd gemlib-0.44.0
sed -i -e "s/CROSS = no/CROSS = yes/gI" -e "s/m68k-atari-mint/m68k-ataribrownest-elf/gI" CONFIGVARS
fixregs gemlib/gem_vdiP.h
fixregs gemlib/gem_vdiP.h
fixregs gemlib/_gc_asm_aes.S
fixregs gemlib/_gc_asm_vdi.S
fixregs gemlib/_gc_asm_vq_gdos.S
fixregs gemlib/_gc_asm_vq_vgdos.S
make

