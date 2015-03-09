#phlat joiner
#select a bunch of gcode files and join them together in the order selected
#
#select files
#join them
#output new file to new name

require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/utils/SketchupDirectoryUtils.rb'
# $Id$
module PhlatScript
   class JoinerTool < PhlatTool

      def initialize
         @tooltype=(PB_MENU_MENU)
         @tooltip="1Gcode Joiner"
         @statusText="2Gcode Joiner"
         @menuItem="3Gcode joiner"
         @menuText="GCode Joiner"
      end

      def select
      
   # get multiple file names
         directory_name = PhlatScript.cncFileDir
         filename = PhlatScript.cncFileName
         status = false
         filenames = Array.new
         wildcard = "Select|\*.#{$phoptions.default_file_ext}||"
         result = UI.openpanel("Select first gcode file", directory_name, wildcard)
         while (result != nil)
            filenames += [result]
            result = UI.openpanel("Select next Gcode file, cancel to end", directory_name, wildcard)
         end

         if filenames.length <= 1
            UI.messagebox("Not enough files selected, exiting")
            return
         end
         
         #get output file name
         UI.messagebox("Now you will be promted for the OUTPUT file name")
         outputfile = UI.savepanel("Select OUTPUT file name", directory_name, "joined#{$phoptions.default_file_ext}" )
         if (outputfile == nil)
            UI.messagebox("No output file selected, exiting")
            return
         end
         
         outf = File.new(outputfile, "w+")
         
         outf.puts("%")
         idx = 0
         outf.puts(PhlatScript.gcomment("joined files"))
         while(idx < filenames.length)
#            outf.puts(PhlatScript.gcomment("   #{File.basename(filenames[idx])}") )
            comms = PhlatScript.gcomments("   #{File.basename(filenames[idx])}")
            comms.each { |cm|
               outf.puts(cm)
               }
            idx += 1
         end
         idx = 0
         lastfile = filenames.length - 1  #last file
         while (idx < filenames.length)
            puts "output file #{idx}"
            inf = File.new(filenames[idx],"r")
            ff = filenames[idx]
            
            #output first file till 'G0 X0 Y0 (home)'
            #output file 2 to N-1 from 'G90 G21 G49 G61' till 'G0 X0 Y0 (home)'
            #output file N from 'G90 G21 G49 G61' till end
            if (idx > 0)  # then skip header
               line = inf.readline
               while (line.match('G90') == nil)
                  if (line.match('File|Bit') != nil)
                     outf.puts(line)
                  end
                  line = inf.readline
               end
               puts "header skipped #{idx}"
               comms = PhlatScript.gcomments("Join   #{File.basename(filenames[idx])}")
               comms.each { |cm|
                  outf.puts(cm)
                  }
               outf.puts(line)
               end
            #output till footer
            line = inf.readline
            while !inf.eof and (line.match('G0 X0 Y0|M30|Outfeed|EndPosition') == nil)
               outf.puts(line)   if !line.match('Outfeed|EndPosition|M30|%')  #do not output leading % etc
               line = inf.readline
            end
            puts "output till footer done #{idx}  #{line}"
            
            if (idx == lastfile)
               #output footer
               puts "writing footer #{idx}"
               outf.puts(line)
               while !inf.eof
                  line = inf.readline
                  outf.puts(line)
               end #while
            end
            
            inf.close
            puts "closed #{idx}"
            idx += 1
         end # while   
         outf.close
         puts "finished writing joined files"
         if PhlatScript.usecommentbracket?
            if (UI.messagebox("All files joined into file #{outputfile}, do you want to preview the Gcode?",MB_YESNO) == IDYES)
               GPlot.new.plot(outputfile)
            end
         else   # dont try to open previewer with semicolon comments
            UI.messagebox("All files joined into file #{outputfile}")
         end
      end #select
   end # class

end # module