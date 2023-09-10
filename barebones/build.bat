@echo off

setlocal

set PROJROOT=.
set PROJNAME1=lolworld
set PROJNAME2=cpptest
set PROJNAME3=ctest
set OUTPUT_FOLDER=auto

set GCCPATH=c:\msys64\brown
set GPP=%GCCPATH%\bin\m68k-atariturbobrowner-elf-g++
set GCC=%GCCPATH%\bin\m68k-atariturbobrowner-elf-gcc
set COMMONFLAGS=-c -m68000 -Ofast -fomit-frame-pointer -fstrict-aliasing -fcaller-saves -flto -ffunction-sections -fdata-sections -fleading-underscore -D__ATARI__ -D__M68000__ -DELF_CONFIG_STACK=16384 -Wall
set CPPFLAGS=%COMMONFLAGS% -x c++ -std=c++0x -fno-exceptions -fno-rtti -fno-threadsafe-statics -Wno-reorder
set CFLAGS=%COMMONFLAGS%
set INCPATH=-I%GCCPATH%\include 

set PATH=%PATH%;%GCCPATH%\bin

set CPPFILES=^
lolworld ^
cpptest

set CFILES=^
vsnprint ^
printf ^
ctest

set ASMFILES=

set GASFILES=

SETLOCAL EnableDelayedExpansion
for %%I in (%CPPFILES% %CFILES% %ASMFILES% %GASFILES%) do set objfiles=!objfiles! obj\%%I.o
rem echo %objfiles%

if /I "%1"=="clean" goto :cleanup

del %OUTPUT_FOLDER%\%PROJNAME1%.o 2>NUL
del %OUTPUT_FOLDER%\%PROJNAME2%.o 2>NUL
del %OUTPUT_FOLDER%\%PROJNAME3%.o 2>NUL

rem Compile cpp files
for %%I in (%CPPFILES%) do call :checkrun "obj\%%I.o" "%%I.cpp" "%GPP% %CPPFLAGS% %INCPATH% -o obj\%%I.o %%I.cpp"

rem Compile c files
for %%I in (%CFILES%) do call :checkrun "obj\%%I.o" "%%I.c" "%GCC% %CFLAGS% %INCPATH% -o obj\%%I.o %%I.c"

rem Assemble .s files
for %%I in (%ASMFILES%) do call :checkrun "obj\%%I.o" "%%I.s" "%ASM% %ASMFLAGS% -L obj\%%I.o.lst -o obj\%%I.o %%I.s"
for %%I in (%GASFILES%) do call :checkrun "obj\%%I.o" "%%I.gas" "%GCCPATH%\bin\m68k-atariturbobrowner-elf-as -o obj\%%I.o %%I.gas"

rem Link
del %OUTPUT_FOLDER%\%PROJNAME%.tos 2>NUL

%GPP% -o lolworld.elf  libcxx/brownboot.o libcxx/browncrti.o libcxx/browncrt++.o libcxx/zerolibc.o libcxx/zerocrtfini.o obj/vsnprint.o obj/printf.o  obj/lolworld.o -Wl,-Map,lolworld.map -Wl,--emit-relocs -Wl,-e_start -Ttext=0 -nostdlib -nostartfiles -m68000 -Ofast -fomit-frame-pointer -fstrict-aliasing -fcaller-saves -flto -ffunction-sections -fdata-sections -fleading-underscore  libcxx/browncrtn.o
if errorlevel 1 exit /b

%GPP% -o ctest.elf  libcxx/brownboot.o libcxx/browncrti.o libcxx/browncrt++.o libcxx/zerolibc.o libcxx/zerocrtfini.o obj/vsnprint.o obj/printf.o  obj/ctest.o -Wl,-Map,ctest.map -Wl,--emit-relocs -Wl,-e_start -Ttext=0 -nostdlib -nostartfiles -m68000 -Ofast -fomit-frame-pointer -fstrict-aliasing -fcaller-saves -flto -ffunction-sections -fdata-sections -fleading-underscore  libcxx/browncrtn.o
if errorlevel 1 exit /b

%GPP% -o cpptest.elf  libcxx/brownboot.o libcxx/browncrti.o libcxx/browncrt++.o libcxx/zerolibc.o libcxx/zerocrtfini.o obj/vsnprint.o obj/printf.o  obj/cpptest.o -Wl,-Map,cpptest.map -Wl,--emit-relocs -Wl,-e_start -Ttext=0 -nostdlib -nostartfiles -m68000 -Ofast -fomit-frame-pointer -fstrict-aliasing -fcaller-saves -flto -ffunction-sections -fdata-sections -fleading-underscore  libcxx/browncrtn.o
if errorlevel 1 exit /b

rem brown up the elf
brownout -p 0 -i %PROJNAME1%.elf -o %OUTPUT_FOLDER%\%PROJNAME1%.tos
brownout -p 0 -i %PROJNAME2%.elf -o %OUTPUT_FOLDER%\%PROJNAME2%.tos
brownout -p 0 -i %PROJNAME3%.elf -o %OUTPUT_FOLDER%\%PROJNAME3%.tos

exit /b

rem Cleanup files

:cleanup

for %%I in (%objfiles%) do del /q %%I %%I.lst 2>NUL
del obj\%PROJNAME1%.o 2>NUL
del %OUTPUT_FOLDER%\%PROJNAME1%.tos 2>NUL
del obj\%PROJNAME2%.o 2>NUL
del %OUTPUT_FOLDER%\%PROJNAME2%.tos 2>NUL
del obj\%PROJNAME3%.o 2>NUL
del %OUTPUT_FOLDER%\%PROJNAME3%.tos 2>NUL

exit /b

rem checkrun <source_file> <file_to_generate> <command_to_run>
rem will only execute <command_to_run> when <file_to_generate> either
rem doesn't exist or is older than <source_file>
:checkrun
if not exist %1 goto run
for /F %%i IN ('dir /b /OD %1 %2 ^| more +1') DO SET NEWEST=%%i
if "%NEWEST%"==%2 GOTO run

echo File %1 is up to date

exit /b

:run
echo %~3
%~3

exit /b

