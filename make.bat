@echo off
goto rbz

do not do trueplunge pack
I:
cd  "I:\public_html\phlat\Tools\PhlatBoyz"
"c:\program files\7-zip\7z" a    tp.zip ..\..\TRUEPLUNGE.TXT
"c:\program files\7-zip\7z" a    tp.zip Constants.rb
"c:\program files\7-zip\7z" a    tp.zip MyConstants-example.rb
"c:\program files\7-zip\7z" a    tp.zip Phlat3D.rb
"c:\program files\7-zip\7z" a    tp.zip PhlatCut.rb
"c:\program files\7-zip\7z" a    tp.zip PhlatMill.rb
"c:\program files\7-zip\7z" a    tp.zip PhlatboyzMethods.rb
"c:\program files\7-zip\7z" a    tp.zip Phlatscript.rb
"c:\program files\7-zip\7z" a    tp.zip PhlatTool.rb

"c:\program files\7-zip\7z" a  tp.zip Tools\GcodeUtil.rb
"c:\program files\7-zip\7z" a  tp.zip Tools\PlungeCut.rb
"c:\program files\7-zip\7z" a  tp.zip Tools\PlungeTool.rb
"c:\program files\7-zip\7z" a  tp.zip Tools\Ky_Reorder_Groups.rb
"c:\program files\7-zip\7z" a  tp.zip Tools\CenterLineTool.rb
"c:\program files\7-zip\7z" a  tp.zip Tools\PhPocketCut.rb
"c:\program files\7-zip\7z" a  tp.zip Tools\PhPocketTool.rb

"c:\program files\7-zip\7z" a  tp.zip images\reorder_large.png
"c:\program files\7-zip\7z" a  tp.zip images\reorder_small.png
"c:\program files\7-zip\7z" a  tp.zip images\pockettool_large.png
"c:\program files\7-zip\7z" a  tp.zip images\pockettool_small.png

"c:\program files\7-zip\7z" a  tp.zip Resources\en-US\*.*

del ..\..\sketchucam-trueplunge*.zip
move tp.zip ..\..\sketchucam-trueplunge3_3.zip

cd ..\..

:rbz
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
   move tp.zip ..\SketchUcam-1_1c.rbz

   cd ..
goto end

:fail
   echo "failed"
:end
