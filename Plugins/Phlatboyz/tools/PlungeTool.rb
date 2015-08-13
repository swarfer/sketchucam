
require 'sketchup.rb'
#require 'Phlatboyz/Constants.rb'
require 'Phlatboyz/Tools/PlungeCut.rb'

module PhlatScript

  class PlungeTool < PhlatTool
    @depth = 100
    @dia = 0
    @keyflag = 0
    @cdia = 0.0
    
    def initialize
       super()
       @hspace = 1
       @vspace = 1
       @hcount = 0
       @vcount = 0
       @keyflag = 0 
    end
    
    def reset(view)
#      puts "PlungeTool reset"
      Sketchup.vcb_label = "Plunge Depth %"
      Sketchup.vcb_value = PhlatScript.cutFactor
      @depth = PhlatScript.cutFactor
      @dia = 0.0
      @cdia = 0.0
      super
    end

    def onMouseMove(flags, x, y, view)
      if @ip.pick(view, x, y)
        view.invalidate
      end
    end
    
    def getPattern
      if ((@hcount == 0) || (@vcount == 0))
         if PhlatScript.isMetric
            @hspace = @vspace = 7.mm
         else
            @hspace = @vspace = 0.25.inch
         end
         @hcount = @vcount = 2
      end
      # prompts
      prompts=['Horiz Spacing ',
               'Vert Spacing  ',
               'Horiz Count ',
               'Vert Count  ' ]

      defaults=[
         Sketchup.format_length(@hspace),
         Sketchup.format_length(@vspace),
         @hcount,
         @vcount            ]
      # dropdown options can be added here
      list=["",
         "",
         "",
         ""                ]

      input = UI.inputbox(prompts, defaults, list, 'Drill Hole Pattern')
      # input is nil if user cancelled
      if (input)
         @hspace = Sketchup.parse_length(input[0])
         @vspace = Sketchup.parse_length(input[1])
         @hcount = input[2].to_i            
         @vcount = input[3].to_i            
         return (@hcount > 0) && (@vcount > 0) && (@vspace > 0) && (@hspace > 0)
      else
         return false
      end
    end
    
   def getDia()
      res = UI.inputbox(["Enter Hole Diameter in model units"],[0.to_s],"Bored Hole Diameter entry")
      begin
         dia = Sketchup.parse_length(res[0])
#         .to_f
#         if PhlatScript.isMetric
#            dia = dia.mm # convert to inch
#         end

         if (dia < PhlatScript.bitDiameter)
            dia = PhlatScript.bitDiameter
         end
      rescue  Exception => e
         dia = 0
         UI.messagebox "Exception in PlungeTool:getDia "+$! + e.backtrace.to_s
      end         
      return dia
    end

   def onRButtonDown(flags, x, y, view)
      if (@cdia == 0)
         puts "forcing cdia"
         @cdia = PhlatScript.bitDiameter * 2
      end
 
      puts "onRButtonDown: flags = #{flags}"
      puts "                    x = #{x}"
      puts "                    y = #{y}"
      puts "                 view = #{view}"
      puts "                 cdia = #{@cdia}"
      if ((flags & 4) == 4) # shift
         #prompt for diameter
         @cdia = getDia()
         if (@cdia > PhlatScript.bitDiameter)
            PlungeCut.cut(@ip.position, 100.0, @cdia, 0, 82)   #depth is always 100%
         else
            puts "Ignored cdia <= bitdiameter"
            @cdia = PhlatScript.bitDiameter * 2
         end
      else
         PlungeCut.cut(@ip.position, 100.0, @cdia, 0, 90)
      end
      
   end    

    def onLButtonDown(flags, x, y, view)
#      puts "flags " + sprintf('%08b',flags)
#      if (@keyflag == 2)
      if ((flags & 32) == 32) || ((flags & 8) == 8) # ALT button or CTRL button, alt does not work in Ubuntu
#         puts "placing hole pattern"
         @dia = 0
         if ((flags & 4) == 4)  # want big hole too, SHIFT button down
            @dia = getDia()
#            puts "dia #{@dia}"
         end
         #get params
         if getPattern()
            #place hole pattern, bottom left is clicked point
#            puts "#{@ip.position} #{@hspace}"
            np = @ip.position
            ccnt = 1
            for v in 0..(@vcount - 1)
#               puts "v #{v}"
               for h in 0..(@hcount - 1)
#                  puts "  h #{h}"
                  np.x = @ip.position.x + h * @hspace
                  np.y = @ip.position.y + v * @vspace
#                  puts "#{np}"
                  PlungeCut.cut(np, @depth, @dia, ccnt)
                  ccnt += 1
               end
            end
         end
      else
#         if (@keyflag == 1)
         if ((flags & 4) == 4) # shift
            #prompt for diameter
            @dia = getDia()
            if (@dia > PhlatScript.bitDiameter)
               PlungeCut.cut(@ip.position, @depth, @dia)
               @dia = 0
            else
               puts "Ignored dia <= bitdiameter"
            end
         else
           PlungeCut.cut(@ip.position, @depth, 0)
         end
      end
      reset(view)
    end

    def draw(view)
      PlungeCut.preview(view, @ip.position)
    end

    def cut_class
      return PlungeCut
    end

    def statusText
      return "Select plunge point, [SHIFT] for large hole, set depth in VCB, [ALT] for hole pattern"
    end

    def enableVCB?
      return true
    end
# get user entered number for plunge depth as percentage of material thickness
    def onUserText(text, view)
      parsed = text.to_f #do not use parse_length function
      if (parsed < 1)
        parsed = 1
      end
      if (parsed > (2*PhlatScript.cutFactor))
        parsed = 2*PhlatScript.cutFactor
      end
      if (!parsed.nil?)
        @depth = parsed
        Sketchup::set_status_text("#{@depth.to_s}%", SB_VCB_VALUE)
#        puts "New Plunge Depth " + @depth.to_s
      end
    end

#swarfer: detect keys
    def onKeyDown(key, repeat, flags, view)
       if (key == VK_SHIFT)
          @keyflag = 1
       end
       if (key == VK_ALT)
          @keyflag = 2
       end
    end

    def onKeyUp(key, repeat, flags, view)
       if ((key = VK_SHIFT) || (key = VK_ALT))
          @keyflag = 0
       end
    end


  end

end
# $Id$
