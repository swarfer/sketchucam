@echo off
rem if exist i:\ goto ido
if exist c:\ goto cdo
goto fail

:ido
I:
cd  "I:\public_html\phlat\plugins"
goto zipit

:cdo
   c:
REM stole this from git-cmd.bat, should set git path for us so we don't have to run gitshell
   @setlocal

REM find the actual Portablegit folder and use it, this means we don't have to keep up with git upgrades in this file   
   for /F %%a in ('dir /b C:\Users\david\AppData\Local\GitHub\Port*') do set PGIT=%%a
REM   echo %PGIT%
   @set git_install_root=C:\Users\david\AppData\Local\GitHub\%PGIT%
   goto spath
   
   @rem Get the absolute path to the current directory, which is assumed to be the
   @rem Git installation root.
REM   if exist C:\Users\david\AppData\Local\GitHub\PortableGit_c2ba306e536fdf878271f7fe636a147ff37326ad goto aa
REM   if exist C:\Users\david\AppData\Local\GitHub\PortableGit_c7e0cbde92ba565cb218a521411d0e854079a28c goto bb
REM   if exist C:\Users\david\AppData\Local\GitHub\PortableGit_25d850739bc178b2eb13c3e2a9faafea2f9143c0 goto cc
REM   :aa
REM   @set git_install_root=C:\Users\david\AppData\Local\GitHub\PortableGit_c2ba306e536fdf878271f7fe636a147ff37326ad
REM   goto spath
REM   
REM   :bb
REM   @set git_install_root=C:\Users\david\AppData\Local\GitHub\PortableGit_c7e0cbde92ba565cb218a521411d0e854079a28c
REM   goto spath
REM
REM   :cc
REM   @set git_install_root=C:\Users\david\AppData\Local\GitHub\PortableGit_25d850739bc178b2eb13c3e2a9faafea2f9143c0
REM   goto spath
   
   
   :spath
   REM refresh the doc for the code
   cd "C:\Program Files (x86)\Google\Google SketchUp 8\Plugins\Phlatboyz"
   call rdoc *.rb *.rb tools\*.rb utils\*.rb
   cd "C:\Program Files (x86)\Google\Google SketchUp 8\"
   
   @set PATH=%git_install_root%\bin;%git_install_root%\mingw\bin;%git_install_root%\cmd;%PATH%

   @set PLINK_PROTOCOL=ssh
   @if not defined TERM set TERM=msys
   git describe --abbrev=4 --dirty --always --tags --contains > plugins\phrev.dat
   
   if exist "C:\Program Files (x86)\Google\Google SketchUp 8" cd "C:\Program Files (x86)\Google\Google SketchUp 8\Plugins"
   if exist "C:\Program Files\Google\Google SketchUp 8\Plugins" cd "C:\Program Files\Google\Google SketchUp 8\Plugins"
   if exist Phlatboyz goto zipit
      echo Phlatboyz not found
      goto fail
   
:zipit
   "c:\program files\7-zip\7z" a  tp.zip *.* -x@..\make.ex -r

rem   del ..\sketchucam-1*.rbz
   cd ..
REM   subwcrev .\ phrev.txt phrev.dat     // git does not support this
   
   php move.php plugins\tp.zip SketchUcam-1_4c.rbz

goto end

:fail
   echo "failed"
:end
