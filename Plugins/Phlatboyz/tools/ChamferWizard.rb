require 'sketchup.rb'
require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/utils/SketchupDirectoryUtils.rb'

module PhlatScript

   class ChamferTool < PhlatTool

      def initialize
         @tooltype=(PB_MENU_MENU)
         @tooltip="Set Chamfer parameters"
         @statusText="Set Chamfer parameters"
         @menuItem="Set Chamfer parameters"
         @menuText="Set Chamfer parameters"
      end

      def torad(deg)
         #puts deg
         deg * Math::PI / 180
      end  

      def select
      
      #a wizard to set tool diameter and cut depth that will achieve a chamfer cut with a v bit
      # cut depth must be less than the current material thickness
      # inputs 
      #  A included angle of the tool
      #  D tool diameter, total diam of sloped part
      #  CD cutter depth, tip to widest part
      #  TD Tip Diameter, can be 0, must be less than D
      #  WIDTH    Width of desired chamfer, must be <= D/2
      
      #outputs
      #  VD    virtual tool diameter to use for cuts
      #  DD    cut depth,  < material thickness
      
      prompts=[
            'Included angle ',
            'Tool diameter ',
            'Tip Diameter ',
            'Cutter Depth ',
            'Width of chamfer '
            ];
         defaults=[
            90.0,
            12.mm,
            2.mm,
            5.mm,
            1.mm
            ];
         list=[
            '',
            '',
            '',
            '',
            ''
            ];

         input=UI.inputbox(prompts, defaults, list, 'Chamfer Wizard (read the help!)')
         # input is nil if user cancelled
         if (input)
            angle = input[0]  #float
            d     = input[1]  #lengths
            td    = input[2]
            cd    = input[3]
            width = input[4]
            
            r1 = d/2 - td/2
            a = angle/2
            b = 90.0 -a
            wo = (r1 - width) / 2
            d0 = wo / Math::tan(torad(b))
            
            dd = cd - d0               # cut depth
            vd = d - 2*wo - 2*width    # virtual cutter diam
            
            
            PhlatScript.bitDiameter = vd
            PhlatScript.cutFactor = dd / PhlatScript.materialThickness * 100.0
            
         end # if input

        
#         UI.messagebox(msg,MB_MULTILINE)
      end #select
   end # class

end
