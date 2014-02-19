
require 'sketchup.rb'
require 'Phlatboyz/Constants.rb'
require 'Phlatboyz/Tools/PlungeCut.rb'

module PhlatScript

  class PlungeTool < PhlatTool
    @depth = 100
    @dia = 0
    @keyflag = 0

    def reset(view)
#      puts "PlungeTool reset"
      Sketchup.vcb_label = "Plunge Depth %"
      Sketchup.vcb_value = PhlatScript.cutFactor
      @depth = PhlatScript.cutFactor
      @dia = 0.0
      super
    end

    def onMouseMove(flags, x, y, view)
      if @ip.pick(view, x, y)
        view.invalidate
      end
    end

    def onLButtonDown(flags, x, y, view)
      if (@keyflag == 1)
        #prompt for diameter
        res = UI.inputbox(["Enter Hole Diameter in model units"],[0.to_s],"Bored Hole Diameter entry")
        begin
          @dia = res[0].to_f
          if PhlatScript.isMetric
            @dia  = @dia.mm # convert to inch
          end

          if (@dia > PhlatScript.bitDiameter)
             PlungeCut.cut(@ip.position, @depth, @dia)
             @dia = 0
          else
             puts "Ignored dia < bitdiameter"
          end
        rescue  Exception => e
          @dia = 0
          UI.messagebox "Exception in PlungeTool:onLbuttondown "+$! + e.backtrace.to_s
        end
      else
        PlungeCut.cut(@ip.position, @depth, 0)
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
      return "Select plunge point, [SHIFT] for large hole"
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

#swarfer: detect ALT key
    def onKeyDown(key, repeat, flags, view)
       if (key == VK_SHIFT)
          @keyflag = 1
       end
    end
    def onKeyUp(key, repeat, flags, view)
       if (key = VK_SHIFT)
          @keyflag = 0
       end
    end


  end

end
# $Id$
