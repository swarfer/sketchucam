<?php 

//argv[1]   source file
//argv[2]   dest file
//current folder 'phrev.dat' contains

$rev = file('phrev.dat');
$rev = trim($rev[0]);

$src = $argv[1];
$dest = preg_replace('/.rbz/',"-$rev.rbz",$argv[2]);
print "Moving  $src to $dest\n ";

rename($argv[1] , $dest);
?>