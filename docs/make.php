<?php
// make.php - to transform help pages into web manual pages
// replace '../images' with 'icons' in each supplied file
// replace link to releases
// replace help.html with index.html in back links

$files = glob($argv[1]);

foreach($files as $filename)
   {
   print "$filename\n";
   $file = file($filename);
   unlink($filename);   
   $of = fopen($filename,"w");
   foreach($file as $line)
      {
      if (preg_match('/images/',$line))
         $line = preg_replace('/\.\.\/images/','icons',$line);
      if (preg_match('/href=\"help.html/', $line))  // to exclude the machelp.html line
         $line = preg_replace('/help.html/','index.html',$line);
      if (preg_match('/sketchucam-download/', $line))
         $line = str_replace("http://www.phlatforum.com/xenforo/index.php?forums/sketchucam-download/", "https://github.com/swarfer/sketchucam/releases", $line);
      fputs($of,$line);
      }
   fclose($of);
   print "   closed\n";
   }
print "done\n";
?>
