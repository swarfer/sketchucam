<?php 

//argv[1]   source file
//argv[2]   dest file
//plugins folder 'phrev.dat' contains git id of this commit

$rev = file('plugins\phrev.dat');
$rev = trim($rev[0]);

$src = str_replace('\\','/',$argv[1]);
$dest = preg_replace('/.rbz/',"-$rev.rbz",$argv[2]);
if (file_exists($src))
   {
   print "Moving  $src to $dest\n ";
   $cmd = "move \"$src\"  \"$dest\"";
   system($cmd);
   }
else
   print "source file $src not found for move\n";
?>