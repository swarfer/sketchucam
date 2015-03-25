@echo off
if exist i:\ goto ido
if exist c:\ goto cdo
goto fail

:ido
I:
cd  "I:\public_html\phlat\plugins"
goto zipit

:cdo
   c:
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
   echo RELa > phrev.dat
   php move.php plugins\tp.zip SketchUcam-1_2b.rbz

goto end

:fail
   echo "failed"
:end
