@Echo off
Cd /D %~dp0

:: Set the PureBasic home directory to a real x64 PureBasic installation
:: Warning:
::   Use a Path Without Space
::   When compiling, the IDE will be Overwriten with the new one
::   If you use C:\PROGRA~1\PureBasic short path (C:\Program Files\PureBasic). You Must run this batch as Administrator to have full control
Set PUREBASIC_HOME=C:\PROGRA~1\PureBasic
::Set PUREBASIC_HOME=E:\PureBasic\Portable\PureBasic_5.71_x64

Echo. > "%PUREBASIC_HOME%\Tmp_FullAccess"
If Exist "%PUREBASIC_HOME%\Tmp_FullAccess" (Del /q /f "%PUREBASIC_HOME%\Tmp_FullAccess") Else (Echo Run this batch as Admin to have full control on PUREBASIC_HOME path && Echo. && Pause && Goto End)

:: USE_SDK10=True for using Microsoft 10 SDK (Check SDK10_VERSION) / USE_SDK10=False for using Microsoft 7.1 SDK
Set USE_SDK10=True

Set PB_PLATEFORM_SDK=%ProgramFiles%\Microsoft SDKs\Windows\v7.1
Set PB_PLATEFORM_SDK10=%ProgramFiles(x86)%\Windows Kits\10
Set SDK10_VERSION=10.0.18362.0

Set PB_VS8=%ProgramFiles(x86)%\Microsoft Visual Studio 12.0
Set PATH=%PB_VS8%\VC\bin;%PATH%
Set PATH=%PB_VS8%\VC\bin\x86_amd64;%PATH%

:: Path to Make and dependencies from UnxUtil (cp.exe,make.exe,pwd.exe,rm.exe,touch.exe,zip.exe)
:: or Path to Make and dependencies from Gnuwin32 (bzip2.dll,cp.exe,libiconv2.dll,libintl3.dll,make.exe,pwd.exe,rm.exe,touch.exe,zip.exe). Here extracted, in Bin subfolder
::Set MAKE_PATH=%~dp0\UnxUtils\usr\local\wbin
Set MAKE_PATH=%~dp0\Bin
Set PATH=%MAKE_PATH%;%PATH%

Set PB_LIBRARIES=%~dp0\Libraries
Set PB_BUILDTARGET=%~dp0\Build\x64

Set PB_PROCESSOR=X64

Set PATH=%PUREBASIC_HOME%\Compilers;%PATH%

:: Check Path Variables
If Not Exist "%PUREBASIC_HOME%\SDK\LibraryMaker.exe" (Echo PureBasic Home Folder not found && Echo Check PUREBASIC_HOME variable) && Echo. && Pause && Goto End)
If Not Exist "%PB_VS8%\VC\include" (Echo Microsoft Visual Studio 12.0 ^(2013^) Folder not found && Echo Check PB_VS8 variable) && Echo. && Pause && Goto End)
If Not Exist "%MAKE_PATH%\make.exe" (Echo Path to Make and dependencies Folder not found && Echo Check PB_VS8 variable) && Echo. && Pause && Goto End)
If %USE_SDK10%==False (
  If Not Exist "%PB_PLATEFORM_SDK%\Include" (Echo Microsoft 7.1 SDK Folder not found && Echo Check PB_PLATEFORM_SDK variable) && Echo. && Pause && Goto End)
)
If %USE_SDK10%==True (
  If Not Exist "%PB_PLATEFORM_SDK10%\Lib\%SDK10_VERSION%" (Echo Microsoft 10 SDK Folder not found && Echo Check PB_PLATEFORM_SDK10 and SDK10_VERSION variables) && Echo. && Pause && Goto End)
)


If %USE_SDK10%==False (
  Set PB_VC8_ANSI=cl.exe -I"%PB_VS8%\VC\include" -I"%PB_LIBRARIES%" -DWINDOWS -DVISUALC -DX64 -DPB_64 -D_USING_V110_SDK71_ -I"%PB_PLATEFORM_SDK%\Include" -I"%PB_PLATEFORM_SDK%\Include\crt" -I. /nologo /GS- /D_CRT_NOFORCE_MANIFEST
  Set PB_LINKER=link /LIBPATH:"%PB_PLATEFORM_SDK%\Lib\x64" /LIBPATH:"%PB_VS8%\VC\Lib\amd64"
)
If %USE_SDK10%==True (
  Set PB_VC8_ANSI=cl.exe -I"%PB_VS8%\VC\include" -I"%PB_LIBRARIES%" -DWINDOWS -DVISUALC -DX64 -DPB_64 -I"%PB_PLATEFORM_SDK10%\Include\%SDK10_VERSION%\ucrt" -I"%PB_PLATEFORM_SDK10%\Include\%SDK10_VERSION%\shared" -I"%PB_PLATEFORM_SDK10%\Include\%SDK10_VERSION%\um" -I. /nologo /GS- /D_CRT_NOFORCE_MANIFEST
  Set PB_LINKER=link /LIBPATH:"%PB_PLATEFORM_SDK10%\Lib\%SDK10_VERSION%\ucrt\x64" /LIBPATH:"%PB_VS8%\VC\Lib\amd64"
)

Set PB_VC8=%PB_VC8_ANSI% -DUNICODE
Set PB_NASM=nasm.exe -DWINDOWS -fwin64 -O3
Set PB_LIBRARIAN=lib /nologo
Set PB_LIBRARYMAKER="%PUREBASIC_HOME%\SDK\LibraryMaker.exe" /NOLOG /COMPRESSED /CONSTANT WINDOWS /CONSTANT %PB_PROCESSOR%
Set PB_IOFIX=
Set PB_OGREFLAGS=/MT /O2

Set PB_OGRELIBRARIAN=lib /NOLOGO
Set PB_WINDOWS=1
Set PB_OBJ=obj
Set PB_LIB=lib

:: Set a default subsystem
Set PB_SUBSYSTEM=purelibraries/

Echo.
Echo Setting Environment for PureBasic %PB_PROCESSOR%
Echo.
Echo Type: Make to Compile all the Dependencies and the IDE
Echo.

Cd PureBasicIDE
:: If we don't specify any args, we want to open a CMD. Else we can use this script to setup an env for batching
If [%1]==[] Goto OpenCmd

Goto End

:OpenCmd
cmd

:End