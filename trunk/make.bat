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
   cd "C:\Program Files\Google\Google SketchUp 8\Plugins"
:zipit
   "c:\program files\7-zip\7z" a  tp.zip *.* -x@..\make.ex -r

rem   del ..\sketchucam-1*.rbz
   move tp.zip ..\SketchUcam-1_1e-beta4.rbz

   cd ..
goto end

:fail
   echo "failed"
:end
