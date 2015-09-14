#plungeTool and CSinkTool
require 'sketchup.rb'
#require 'Phlatboyz/Constants.rb'
require 'Phlatboyz/Tools/PlungeCut.rb'

module PhlatScript

  class PlungeTool < PhlatTool
    @depth = '100.0'.to_f
    begin
       @dia = "0.0".to_l
    rescue
       @dia = 0.to_l
    end
    @keyflag = 0
    @statusMsg = "Plunge Tool"
    
    def initialize
       super()
       @hspace = 1
       @vspace = 1
       @hcount = 0
       @vcount = 0
       @keyflag = 0 
       @dia = 0.0
    end
    
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
      Sketchup::status_text = @statusMsg      
    end
    
    def getPattern
      if ((@hcount == 0) || (@vcount == 0))
         if PhlatScript.isMetric
            @hspace = @vspace = '7.mm'.to_l
         else
            @hspace = @vspace = '0.25.inch'.to_l
         end
         @hcount = @vcount = 2.to_i
      end
      # prompts
      prompts=['Horiz Spacing ',
               'Vert Spacing  ',
               'Horiz Count ',
               'Vert Count  ' ]

      defaults=[
         @hspace,
         @vspace,
         @hcount,
         @vcount            ]
      # dropdown options can be added here
      list=["",
         "",
         "",
         ""                ]
      begin
         input = UI.inputbox(prompts, defaults, list, 'Drill Hole Pattern')
         # input is nil if user cancelled
         if (input)
            @hspace = input[0]
            @vspace = input[1]
            @hcount = input[2].to_i            
            @vcount = input[3].to_i            
            return (@hcount > 0) && (@vcount > 0) && (@vspace > 0) && (@hspace > 0)
         else
            return false
         end
      rescue ArgumentError => error
         UI.messagebox(error.message)
         retry
      end
    end

   def getDia()
      begin
         res = UI.inputbox(["Enter Hole Diameter in model units"],['0'.to_l],"Bored Hole Diameter entry")
         dia = res[0]  # will be a length

         if (dia < PhlatScript.bitDiameter)
            dia = 0.to_l
         end
      rescue ArgumentError => error
         UI.messagebox(error.message)
         retry
      end         
      return dia
    end

    def onLButtonDown(flags, x, y, view)
#      puts "flags " + sprintf('%08b',flags)
#      if (@keyflag == 2)
      if ((flags & 32) == 32) || ((flags & 8) == 8) # ALT button or CTRL button, alt does not work in Ubuntu
#         puts "placing hole pattern"
         @dia = '0'.to_l
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
      @statusMsg = "Select plunge point, [SHIFT] for large hole, set depth in VCB, [ALT] for hole pattern"
      return @statusMsg
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
#-----------------------------------------------------------------------------------
# counter sink and counterbore together
   class CsinkTool < PlungeTool

   def initialize
       super()
       @cdia = 0.to_l
       @angle = 0.0
       @cdepth = (PhlatScript.materialThickness / 2).to_l
       @mode = 'CounterSink'
       @statusMsg = "CounterSink|CounterBore"
   end
   
   def reset(view)
      Sketchup.vcb_label = "n/a"
      Sketchup.vcb_value = "not used"
      @depth = PhlatScript.cutFactor
   end
   
   def enableVCB?
      return false
   end

   def getCounterSink
      # prompts
      prompts=['CounterSink or CounterBore?',
               'Countersink/bore diam ( > bit!)',
               '(CounterSINK only) Set Angle (70..179)',
               '(CounterBORE only) Set depth ( < material thickness!)',
               'Hole Diameter (0 for current bit)' 
               ]
      if (@angle < 70.0)
         @angle = 90.0
      end
      #puts @cdia
      @cdia = (@cdia == 0.0) ? PhlatScript.bitDiameter.to_l * 2 : @cdia
      #puts @cdia
      defaults=[
         @mode,
         @cdia.to_l,
         @angle.to_f,
         @cdepth.to_l,
         @dia.to_l
         ]
      # dropdown options can be added here
      list=["CounterSink|CounterBore",
         "",
         "",
         "",
         ""                ]
      begin
         input = UI.inputbox(prompts, defaults, list, 'Counter Sink options')
      rescue ArgumentError => error
         UI.messagebox(error.message)
         retry
      end
        
      # input is nil if user cancelled
      if (input)
         @mode = input[0]
         if (input[0] == 'CounterSink')
            @cdia = input[1]
            begin
               @angle = input[2]          # float
            rescue 
               UI.messagebox("Invalid angle #{@angle}, setting to 90")
               @angle = 90.0
            end
            @angle = 70.0 if (@angle < 70.0)
            @angle = 179.0 if (@angle > 179.0)
            @dia = input[4]
            if (@dia < PhlatScript.bitDiameter)
               @dia = 0.to_l
            end
            if !((@cdia > PhlatScript.bitDiameter) && (@cdia > @dia) && (@angle >= 70))
               UI.messagebox('Error: values make no sense')
            end
            return (@cdia > PhlatScript.bitDiameter) && (@cdia > @dia) && (@angle >= 70)
         else
            @cdia = input[1]
            @angle = -90  #indicates counterbore
            @cdepth = input[3]
            #puts @cdepth.to_mm
            @depth = PhlatScript.cutFactor
            @dia = input[4]
            if (@dia < PhlatScript.bitDiameter)
               @dia = 0.to_l
            end
            if !((@cdia > PhlatScript.bitDiameter) && (@cdia > @dia) && (@cdepth < PhlatScript.materialThickness))
               UI.messagebox('Error: values make no sense')
            end
            return (@cdia > PhlatScript.bitDiameter) && (@cdia > @dia) && (@cdepth < PhlatScript.materialThickness)
         end
      else
         return false
      end
    end
    
   def activate
      super
      if getCounterSink 
         if (@angle > 0)
            @statusMsg = "Select CounterSINK plunge point, [SHIFT] for large hole, [ALT] for hole pattern: diam:#{@cdia.to_s} angle:#{sprintf('%0.3f°',@angle)}"
         else
            @statusMsg = "Select CounterBORE plunge point, [SHIFT] for large hole, [ALT] for hole pattern: diam:#{@cdia.to_s} depth:#{@cdepth.to_s}"
         end
         Sketchup::status_text = @statusMsg
      else
         puts "getcountersink cancelled"
         @dia = @cdia = 0.to_l
         #deselect the tool?
         Sketchup.active_model.select_tool(nil)
      end
   end

#countersink and bore version
   def onLButtonDown(flags, x, y, view)
#      puts "flags " + sprintf('%08b',flags)
      if ((flags & 32) == 32) || ((flags & 8) == 8) # ALT button or CTRL button, alt does not work in Ubuntu
#         puts "placing hole pattern"
         
         if ((flags & 4) == 4)  # want big hole too, SHIFT button down
            @dia = getDia()
            @dia = @dia < @cdia ? @dia :  0.0
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

                  #PlungeCut.cut(np, @depth, @dia, ccnt,@angle, @cdia)
                  if @mode == 'CounterSink'
                     PlungeCut.cut(np, @depth, @dia, ccnt,@angle,@cdia)
                  else
                     PlungeCut.cut(np, @depth, @dia, ccnt,@angle,@cdia, @cdepth)            
                  end
                  
                  ccnt += 1
               end
            end
         end
      else
#         if (@keyflag == 1)
         if ((flags & 4) == 4) # shift
            #prompt for diameter
            @dia = getDia()
            @dia = @dia < @cdia ? @dia :  PhlatScript.bitDiameter + 0.1
            if (@dia > PhlatScript.bitDiameter)
               if @mode == 'CounterSink'
                  PlungeCut.cut(@ip.position, @depth, @dia, 0,@angle,@cdia)
               else # mode is CounterBore
                  PlungeCut.cut(@ip.position, @depth, @dia, 0,@angle,@cdia, @cdepth)            
               end
            else
               puts "Ignored dia <= bitdiameter"
            end
         else
            if @mode == 'CounterSink'
               PlungeCut.cut(@ip.position, @depth, @dia, 0,@angle,@cdia)
            else
               PlungeCut.cut(@ip.position, @depth, @dia, 0,@angle,@cdia, @cdepth)            
            end
         end
      end
      reset(view)
   end
   
   def statusText
      return "CounterSink | CounterBore tool"
   end

   end # class

#-----------------------------------------------------------------------------------
=begin
   class CboreTool < PlungeTool

   def initialize
       super()
       @cdia = 0.0
       @angle = 0.0
       @cdepth = PhlatScript.materialThickness / 2
   end
   
   def reset(view)
      Sketchup.vcb_label = "Plunge Depth %"
      Sketchup.vcb_value = PhlatScript.cutFactor
      @depth = PhlatScript.cutFactor
   end

   def getCounterBore
      # prompts
      prompts=['Counter bore diam ( > bit!)',
               'Counter bore depth ( < material)',
               'Hole Diam (0 for current bit)' 
               ]
      @angle = -90.0  # this tells gcodeutil what to do!

      #puts @cdia
      @cdia = (@cdia == 0.0) ? PhlatScript.bitDiameter * 2 : @cdia
      #puts @cdia
      defaults=[
         Sketchup.format_length(@cdia),
         Sketchup.format_length(@cdepth),
         Sketchup.format_length(@dia)
         ]
      # dropdown options can be added here
      list=["",
         "",
         ""                ]
must do begin rescue here
      input = UI.inputbox(prompts, defaults, list, 'Counter Bore Options')
      # input is nil if user cancelled
      if (input)
         @cdia = Sketchup.parse_length(input[0])
         @cdepth = Sketchup.parse_length(input[1])
         @dia = Sketchup.parse_length(input[2])
         if (@dia < PhlatScript.bitDiameter)
            @dia = 0
         end
                     
         return (@cdia > PhlatScript.bitDiameter) && (@cdia > @dia) && (@cdepth < PhlatScript.materialThickness)
      else
         return false
      end
    end
    
   def activate
      super
      if getCounterBore
      else
         puts "getcounterbore cancelled"
         @dia = @cdia = 0
         #deselect the tool?
         Sketchup.active_model.select_tool(nil)
      end
   end

#counterbore version
   def onLButtonDown(flags, x, y, view)
      if ((flags & 32) == 32) || ((flags & 8) == 8) # ALT button or CTRL button, alt does not work in Ubuntu
         
         if ((flags & 4) == 4)  # want big hole too, SHIFT button down
            @dia = getDia()
         end
         #get params
         if getPattern()
            #place hole pattern, bottom left is clicked point
            np = @ip.position
            ccnt = 1
            for v in 0..(@vcount - 1)
               for h in 0..(@hcount - 1)
                  np.x = @ip.position.x + h * @hspace
                  np.y = @ip.position.y + v * @vspace
                  PlungeCut.cut(np, @depth, @dia, ccnt,@angle, @cdia, @cdepth)
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
               PlungeCut.cut(@ip.position, @depth, @dia,0, @angle, @cdia, @cdepth)
            else
               puts "Ignored dia <= bitdiameter"
            end
         else
            PlungeCut.cut(@ip.position, @depth, @dia, 0,@angle,@cdia, @cdepth)
         end
      end
      reset(view)
   end
   
   def statusText
      return "Select CounterBore plunge point, [SHIFT] for large hole, [ALT] for hole pattern"
   end

   end # class
=end   
  
end
# $Id$
