require 'sketchup.rb'
require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/utils/SketchupDirectoryUtils.rb'

module PhlatScript

   class ChamferTool < PhlatTool

      def initialize
         super()
         @tooltype=(PB_MENU_MENU)
         @tooltip="Set Chamfer parameters"
         @statusText="Set Chamfer parameters"
         @menuText="Set Chamfer parameters"
      end


      # a wizard to set tool diameter and cut depth that will achieve a chamfer cut with a v bit
      # cut depth must be less than the current material thickness
      # ==== inputs 
      # +A+ included angle of the tool<br>
      # +D+ tool diameter, total diam of sloped part<br>
      # +CD+ cutter depth, tip to widest part<br>
      # +TD+ Tip Diameter, can be 0, must be less than D<br>
      # +WIDTH+    Width of desired chamfer, must be <= D/2
      # ==== outputs
      # +VD+    virtual tool diameter to use for cuts<br>
      # +DD+    cut depth,  < material thickness
      def select
      
      
      
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
           
#cross check, calculate the angle from the height width and tipwidth
            wo = (d - td)/2   # width of half cutter
            h = cd                # height of cutting portion
            theta = 2 * PhlatScript.todeg(Math::atan(wo/h))
            puts "theta #{theta}"
            if ( (theta - angle).abs > 1)
               UI.messagebox("Angle mismatch, please check parameters")
            end
            
            #calculate virtual width and cut depth
            r1 = d/2 - td/2
            a = angle/2
            b = 90.0 -a
            wo = (r1 - width) / 2 # we are centering cut on the cutter
            d0 = wo / Math::tan(PhlatScript.torad(b))
            
            dd = cd - d0               # cut depth
            vd = d - 2*wo - 2*width    # virtual cutter diam

            puts "Virtual diameter #{vd.to_l.to_s}"
            puts "Virtual cut depth #{dd.to_l.to_s}"
            
            PhlatScript.bitDiameter = vd
            PhlatScript.cutFactor = dd / PhlatScript.materialThickness * 100.0
            if (PhlatScript.cutFactor > 100.0)
               UI.messagebox("Cut factor% is too deep! #{PhlatScript.cutFactor}");
            end
            if (dd > cd)
               UI.messagebox("Cut depth is greater than cutter depth!");
            end
            
         end # if input

        
#         UI.messagebox(msg,MB_MULTILINE)
      end #select
   end # class

end
