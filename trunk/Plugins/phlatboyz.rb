#-----------------------------------------------------------------------------
# Name        :   PhlatBoyzTools
# Description :   A set of tools for marking up Phlatland Sketchup drawings and generating Phlatprinter g-code.
# Menu Item   :   
# Context Menu:   
# Usage       :   install in plugins folder
# Date        :   Feb 2014
# Type        :   
# Version     :   SketchUcam 1.1 
# $Id$
#-----------------------------------------------------------------------------

require('sketchup.rb')
require('extensions.rb')
require('langhandler.rb')

module PhlatScript

   #place a copy of the distributed strings file into Resources
   def PhlatScript.copyStrings(from)
      #this line generates the name even if the file does not exist
      ofile = Sketchup.find_support_file("en-US", "Resources" ) + "/PhlatBoyz.strings"
      out_file = File.new(ofile, "w")
      if out_file
         in_file = File.open(from)
         in_file.each_line { |line|
            out_file.puts(line)
            }
         out_file.close
         in_file.close
      end
   end
   
   if (Sketchup.version.split('.')[0].to_i < 13)
      #v8 does not find resources within the plugins folder
      #but installer does not put resources files into resources, so we have to move them
      #make sure we have the strings file in the right place, sketchup/resources/en-US

      myc = Sketchup.find_support_file("en-US/PhlatBoyz.strings", "Resources" )  #fails if it doesn't exist
      #   ofl = File.new('d:\temp\debug.log', "w")
      #   ofl.write(myc)
      #   ofl.write(Sketchup.version)
      #   ofl.close()
      
      thefile = Sketchup.find_support_file("Phlatboyz/Resources/en-US/PhlatBoyz.strings", "Plugins" )
      if (myc == nil)  #file does not exist
         if thefile != nil
            PhlatScript.copyStrings(thefile)
         end
      else
            #file exists, check for correct version
         correctversion = "1.03"  #this must match the version string in the file!
         result = open(myc) { |f| f.grep(/stringversion/) }
         if result != []  #found the string, check version
            if !result[0].match(correctversion)  #version mismatch
               PhlatScript.copyStrings(thefile)
            end
         else  #not found, copy the new file
            PhlatScript.copyStrings(thefile)
         end
      end
   end # if version

   @@phlatboyzStrings = LanguageHandler.new('PhlatBoyz.strings')
   
   class PhlatScriptExtention < SketchupExtension 
     def initialize
       super 'Phlatboyz Tools', 'Phlatboyz/Phlatscript.rb' 
       self.description = 'A set of tools for marking up Phlatland Sketchup drawings and generating Phlatprinter g-code.' 
       self.version = '1.2a4' 
       self.creator = 'Phlatboyz' 
       self.copyright = '2014, Phlatboyz' 
     end

     def load
       require 'Phlatboyz/Phlatscript.rb'
       PhlatScript.load
     end 

   end
   $PhlatScriptExtension = PhlatScriptExtention.new
   Sketchup.register_extension($PhlatScriptExtension, true)

end