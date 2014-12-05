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
         UI.messagebox("test joiner",MB_MULTILINE)
      
         #output first file till 'G0 X0 Y0 (home)'
         #output file 2 to N-1 from 'G90 G21 G49 G61' till 'G0 X0 Y0 (home)'
         #output file N from 'G90 G21 G49 G61' till end
       
       
        end #select
   end # class

end # module