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


LIBGCC=/lib/gcc/m68k-ataribrownerer-elf/7.2.0
LIBCXX=/usr/m68k-ataribrownerer-elf/lib

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

# make subdir for gcc default cpu (020)
mkdir -p $LIBGCC/m68020
cp -r $LIBGCC/*.o $LIBGCC/m68020/.
cp -r $LIBGCC/*.a $LIBGCC/m68020/.
cp -r $LIBGCC/softfp $LIBGCC/m68020

#-------------------------------------------------------------------------------

# make subdir for gcc cpu (020-60)
# we aren't generating 060-clean versions yet so we use the
# soft-float 020 version as a safe compromise
mkdir -p $LIBGCC/m68020-60
cp -r $LIBGCC/softfp/*.o $LIBGCC/m68020-60/.
cp -r $LIBGCC/softfp/*.a $LIBGCC/m68020-60/.
cp -r $LIBGCC/softfp $LIBGCC/m68020-60

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

# make subdir for libc++ default cpu (020)
mkdir -p $LIBCXX/m68020
mkdir -p $LIBCXX/m68020/softfp
cp -r $LIBCXX/libstdc++.* $LIBCXX/m68020/.
cp -r $LIBCXX/libsupc++.* $LIBCXX/m68020/.
cp -r $LIBCXX/softfp/libstdc++.* $LIBCXX/m68020/softfp/.
cp -r $LIBCXX/softfp/libsupc++.* $LIBCXX/m68020/softfp/.

#-------------------------------------------------------------------------------

# transfer libc to correct subdirs (68k)
mv $LIBCXX/libc.a $LIBCXX/m68000/.
mv $LIBCXX/libiio.a $LIBCXX/m68000/.
mv $LIBCXX/librpcsvc.a $LIBCXX/m68000/.

# publish 020/fpu version of libc as default
cp -r $LIBCXX/m68020/libc.a $LIBCXX/.
cp -r $LIBCXX/m68020/libiio.a $LIBCXX/.
cp -r $LIBCXX/m68020/librpcsvc.a $LIBCXX/.

# publish 020/softfp version of libc as default softfp
cp $LIBCXX/m68020-20_soft/*.a $LIBCXX/softfp/.
cp $LIBCXX/m68020-20_soft/*.a $LIBCXX/m68020/softfp/.
rm -rf $LIBCXX/m68020-20_soft

# transfer libc to correct subdirs (020-60)
mv $LIBCXX/m68020-60_soft $LIBCXX/m68020-60/softfp

cp -r $LIBCXX/softfp/libstdc++.* $LIBCXX/m68020-60/softfp/.
cp -r $LIBCXX/softfp/libsupc++.* $LIBCXX/m68020-60/softfp/.

#-------------------------------------------------------------------------------
# 68040,060

# we prefer not to transfer transfer 020/fpu libs to 040-060 because emulated 
# fpu ops may be generated. better to build a 040/060 variant of libstdc++
# as a safe compromise for now we use the 020/softfp variant
cp -r $LIBCXX/m68020/softfp/libstdc++.* $LIBCXX/m68020-60/.
cp -r $LIBCXX/m68020/softfp/libsupc++.* $LIBCXX/m68020-60/.

# we don't bother with LC versions of 040/060 so...
rm -rf $LIBCXX/m68040/softfp 
rm -rf $LIBCXX/m68060/softfp 
rm -rf $LIBGCC/m68040/softfp 
rm -rf $LIBGCC/m68060/softfp 

# crt0.o, gcrt0.o are 68k asm and don't need relocated

