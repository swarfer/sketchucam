<?php 

//argv[1]   source file
//argv[2]   dest file
//plugins folder 'phrev.dat' contains git id of this commit

$rev = file('plugins\phrev.dat');
$rev = trim($rev[0]);

$src = $argv[1];
$dest = preg_replace('/.rbz/',"-$rev.rbz",$argv[2]);
print "Moving  $src to $dest\n ";

rename($argv[1] , $dest);
?>