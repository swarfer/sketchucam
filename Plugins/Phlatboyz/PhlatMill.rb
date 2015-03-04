require 'sketchup.rb'
#require 'Phlatboyz/Constants.rb'
#see note at end of file
module PhlatScript

  class PhlatMill

    def initialize(output_file_name=nil, min_max_array=nil)
      #current_Feed_Rate = model.get_attribute Dict_name, $dict_Feed_Rate , nil
      #current_Plunge_Feed = model.get_attribute Dict_name, $dict_Plunge_Feed , nil
      @cz = 0.0
      @cx = 0.0
      @cy = 0.0
      @cs = 0.0
      @cc = ""
      @debug = false   # if true then a LOT of stuff will appear in the ruby console
      @debugramp = false
      puts "debug true in PhlatMill.rb\n" if (@debug || @debugramp)
      @max_x = 48.0
      @min_x = -48.0
      @max_y = 22.0
      @min_y = -22.0
      @max_z = 1.0
      @min_z = -1.0
      if(min_max_array != nil)
        @min_x = min_max_array[0]
        @max_x = min_max_array[1]
        @min_y = min_max_array[2]
        @max_y = min_max_array[3]
        @min_z = min_max_array[4]
        @max_z = min_max_array[5]
      end
      @no_move_count = 0
      @spindle_speed = PhlatScript.spindleSpeed
      @retract_depth = PhlatScript.safeTravel.to_f
      @table_flag = false # true if tabletop is zZero
      @mill_depth  = -0.35
      @speed_curr  = PhlatScript.feedRate
      @speed_plung = PhlatScript.plungeRate
      @material_w = PhlatScript.safeWidth
      @material_h = PhlatScript.safeHeight
      @material_thickness = PhlatScript.materialThickness
      @multidepth = PhlatScript.multipassDepth
      @bit_diameter = 0  #swarfer: need it often enough to be global

      @comment = PhlatScript.commentText
      @extr = "-"
      @cmd_linear = "G1" # Linear interpolation
      @cmd_rapid = "G0" # Rapid positioning - do not change this to G00 as G00 is used elsewhere for forcing mode change
      @cmd_arc = "G02" # coordinated helical motion about Z axis
      @cmd_arc_rev = "G03" # counterclockwise helical motion about Z axis
      @output_file_name = output_file_name
      @mill_out_file = nil

      @Limit_up_feed = false #swarfer: set this to true to use @speed_plung for Z up moves
      @cw =  PhlatScript.usePlungeCW?           #swarfer: spiral cut direction
    end

   def set_retract_depth(newdepth, tableflag)
      @retract_depth = newdepth
      @table_flag = tableflag
   end

    def set_bit_diam(diameter)
      #@curr_bit.diam = diameter
      @bit_diameter = diameter
    end

    def cncPrint(*args)
      if(@mill_out_file)
        args.each {|string| @mill_out_file.print(string)}
      else
        args.each {|string| print string}
        #print arg
      end
    end
   
   #returns array of strings of length size 
   def chunk(string, size)
      string.scan(/.{1,#{size}}/)
   end 
    
    #print a commment using current comment options
   def cncPrintC(string)
      string = string.gsub("\n","")
      string = string.gsub(/\(|\)/,"")
      if (string.length > 48)
         chunks = chunk(string,45)
         chunks.each { |bit|
            bb = PhlatScript.gcomment(bit)
            cncPrint(bb + "\n")
            }
      else
         string = PhlatScript.gcomment(string)
         cncPrint(string + "\n")
      end
   end

    def format_measure(axis, measure)
      #UI.messagebox("in #{measure}")
      m2 = @is_metric ? measure.to_mm : measure.to_inch
      #UI.messagebox(sprintf("  #{axis}%-10.*f", @precision, m2))
      #UI.messagebox("out mm: #{measure.to_mm} inch: #{measure.to_inch}")
      sprintf(" #{axis}%-5.*f", @precision, m2)
    end

    def format_feed(f)
      feed = @is_metric ? f.to_mm : f.to_inch
      sprintf(" F%-4d", feed.to_i)
    end

    def job_start(optim, extra=@extr)
      if(@output_file_name)
        done = false
        while !done do
          begin
            @mill_out_file = File.new(@output_file_name, "w")
            done = true
          rescue
            button_pressed = UI.messagebox "Exception in PhlatMill.job_start "+$!, 5 #, RETRYCANCEL , "title"
            done = (button_pressed != 4) # 4 = RETRY ; 2 = CANCEL
            # TODO still need to handle the CANCEL case ie. return success or failure
          end
        end
      end
#      @bit_diameter = Sketchup.active_model.get_attribute Dict_name, Dict_bit_diameter, Default_bit_diameter
      @bit_diameter = PhlatScript.bitDiameter

      cncPrint("%\n")
#do a little jig to prevent the code highlighter getting confused by the bracket constructs      
      vs1 = PhlatScript.getString("PhlatboyzGcodeTrailer")
      vs2 = $PhlatScriptExtension.version
      verstr = "#{vs1%vs2}" + "\n"
      cncPrintC(verstr)
      cncPrintC("File: #{PhlatScript.sketchup_file}") if PhlatScript.sketchup_file
      cncPrintC("Bit diameter: #{Sketchup.format_length(@bit_diameter)}")
      cncPrintC("Feed rate: #{Sketchup.format_length(@speed_curr)}/min")
      if (@speed_curr != @speed_plung)
         cncPrintC("Plunge Feed rate: #{Sketchup.format_length(@speed_plung)}/min")
      end
      cncPrintC("Material Thickness: #{Sketchup.format_length(@material_thickness)}")
      cncPrintC("Material length: #{Sketchup.format_length(@material_h)} X width: #{Sketchup.format_length(@material_w)}")
      cncPrintC("Overhead Gantry: #{PhlatScript.useOverheadGantry?}")
      if (@Limit_up_feed)
        cncPrintC("Retract feed LIMITED to plunge feed rate")
      end
      if (PhlatScript.useMultipass?)
        cncPrintC("Multipass enabled, Depth = #{Sketchup.format_length(@multidepth)}")
      end
      if (PhlatScript.mustramp?)
         if (PhlatScript.rampangle == 0)
            cncPrintC("RAMPING with no angle limit")
         else
            cncPrintC("RAMPING at #{PhlatScript.rampangle} degrees")
         end
      end

      if (optim)    # swarfer - display optimize status as part of header
        cncPrintC("Optimization is ON")
      else
        cncPrintC("Optimization is OFF")
      end
      if (extra != "-")
         cncPrintC("#{extra}")
      end

      cncPrintC("www.PhlatBoyz.com")
      PhlatScript.checkParens(@comment, "Comment")
      @comment.split("$/").each{|line| cncPrintC(line)} if !@comment.empty?

      #adapted from swarfer's metric code
      #metric by SWARFER - this does the basic setting up from the drawing units
      if PhlatScript.isMetric
        unit_cmd, @precision, @is_metric = ["G21", 3, true]
        else
        unit_cmd, @precision, @is_metric = ["G20", 4, false]
        end

      stop_code = $phoptions.use_exact_path? ? "G61" : "" # G61 - Exact Path Mode
      cncPrint("G90 #{unit_cmd} G49 #{stop_code} G17\n") # G90 - Absolute programming (type B and C systems)
      #cncPrint("G20\n") # G20 - Programming in inches
      #cncPrint("G49\n") # G49 - Tool offset compensation cancel
      cncPrint("M3 S", @spindle_speed, "\n") # M3 - Spindle on (CW rotation)   S spindle speed
    end

    def job_finish
      cncPrint("M05\n") # M05 - Spindle off
      cncPrint("M30\n") # M30 - End of program/rewind tape
      cncPrint("%\n")
      if(@mill_out_file)
        begin
          @mill_out_file.close()
          @mill_out_file = nil
          UI.messagebox("Output file stored: "+@output_file_name)
        rescue
          UI.messagebox "Exception in PhlatMill.job_finish "+$!
        end
      else
        UI.messagebox("Failed to store output file. (File may be opened by another application.)")
      end
    end

   def move(xo, yo=@cy, zo=@cz, so=@speed_curr, cmd=@cmd_linear)
     #cncPrintC("(move ", sprintf("%10.6f",xo), ", ", sprintf("%10.6f",yo), ", ", sprintf("%10.6f",zo),", ", sprintf("feed %10.6f",so), ", cmd=", cmd,")\n")
     #puts "(move ", sprintf("%10.6f",xo), ", ", sprintf("%10.6f",yo), ", ", sprintf("%10.6f",zo),", ", sprintf("feed %10.6f",so), ", cmd=", cmd,")\n"
      if cmd != @cmd_rapid
         if @retract_depth == zo
            cmd=@cmd_rapid
            so=0
            @cs=0
         else
            cmd=@cmd_linear
         end
      end

      #print "( move xo=", xo, " yo=",yo,  " zo=", zo,  " so=", so,")\n"
      if (xo == @cx) && (yo == @cy) && (zo == @cz)
         #print "(move - already positioned)\n"
         @no_move_count += 1
      else
         if (xo > @max_x)
            #puts "xo big"
            cncPrintC("move x=" + sprintf("%10.6f",xo) + " GT max of " + @max_x.to_s + "\n")
            xo = @max_x
         elsif (xo < @min_x)
            #puts "xo small"
            cncPrintC("move x="+ sprintf("%10.6f",xo)+ " LT min of "+ @min_x.to_s+ "\n")
            xo = @min_x
         end

         if (yo > @max_y)
            #puts "yo big"
            cncPrintC("move y="+ sprintf("%10.6f",yo)+ " GT max of "+ @max_y.to_s+ "\n")
            yo = @max_y
         elsif (yo < @min_y)
            #puts "yo small"
            cncPrintC("move y="+ sprintf("%10.6f",yo)+ " LT min of ", @min_y.to_s+ "\n")
            yo = @min_y
         end

         if (zo > @max_z)
            cncPrintC("(move z="+ sprintf("%10.6f",zo)+ " GT max of "+ @max_z.to_s+ ")\n")
            zo = @max_z
         elsif (zo < @min_z)
            cncPrintC("(move ="+ sprintf("%8.3f",zo)+ " LT min of "+ @min_z.to_s+ ")\n")
            zo = @min_z
         end
         command_out = ""
         command_out += cmd if (cmd != @cc)
         hasz = hasx = hasy = false
         if (xo != @cx)
            command_out += (format_measure('X', xo))
            hasx = true
         end
         if (yo != @cy)
            command_out += (format_measure('Y', yo))
            hasy = true
         end
         if (zo != @cz)
            hasz = true
            command_out += (format_measure('Z', zo))
         end

         if (!hasx && !hasy && hasz) # if only have a Z motion
            if (zo < @cz) || (@Limit_up_feed)  # if going down, or if overridden
               so = PhlatScript.plungeRate
            #            cncPrintC("(move only Z, force plungerate)\n")
            end
         end
         #          cncPrintC("(   #{hasx} #{hasy} #{hasz})\n")
         command_out += (format_feed(so)) if (so != @cs)
         command_out += "\n"
         cncPrint(command_out)
         @cx = xo
         @cy = yo
         @cz = zo
         @cs = so
         @cc = cmd
      end
   end

   def retract(zo=@retract_depth, cmd=@cmd_rapid)
      #      cncPrintC("(retract ", sprintf("%10.6f",zo), ", cmd=", cmd,")\n")
      #      if (zo == nil)
      #        zo = @retract_depth
      #      end
      if (@cz == zo)
         @no_move_count += 1
      else
         if (zo > @max_z)
            cncPrintC("(RETRACT limiting Z to @max_z)\n")
            zo = @max_z
         elsif (zo < @min_z)
            cncPrintC("(RETRACT limiting Z to @min_z)\n")
            zo = @min_z
         end
         command_out = ""
         if (@Limit_up_feed) && (cmd="G0") && (zo > 0) && (@cz < 0)
            cncPrintC("(RETRACT G1 to material thickness at plunge rate)\n")
            command_out += (format_measure(' G1 Z', 0))
            command_out += (format_feed(@speed_plung))
            command_out += "\n"
            $cs = @speed_plung
            #          G0 to zo
            command_out += "G0" + (format_measure('Z', zo))
         else
            #          cncPrintC("(RETRACT normal #{@cz} to #{zo} )\n")
            command_out += cmd    if (cmd != @cc)
            command_out += (format_measure('Z', zo))
         end
         command_out += "\n"
         cncPrint(command_out)
         @cz = zo
         @cc = cmd
      end
   end

   def plung(zo=@mill_depth, so=@speed_plung, cmd=@cmd_linear)
      #      cncPrintC("(plung ", sprintf("%10.6f",zo), ", so=", so, " cmd=", cmd,")\n")
      if (zo == @cz)
         @no_move_count += 1
      else
         if (zo > @max_z)
            cncPrintC("(PLUNGE limiting Z to max_z @max_z)\n")
            zo = @max_z
         elsif (zo < @min_z)
            cncPrintC("(PLUNGE limiting Z to min_z @min_z)\n")
            zo = @min_z
         end
         command_out = ""
         command_out += cmd if (cmd != @cc)
         command_out += (format_measure('Z', zo))
         so = @speed_plung  # force using plunge rate for vertical moves
         #        sox = @is_metric ? so.to_mm : so.to_inch
         #        cncPrintC("(plunge rate #{sox})\n")
         command_out += (format_feed(so)) if (so != @cs)
         command_out += "\n"
         cncPrint(command_out)
         @cz = zo
         @cs = so
         @cc = cmd
      end
   end

# convert degrees to radians   
   def torad(deg)
       deg * Math::PI / 180
   end     

   def todeg(rad)
      rad * 180 / Math::PI 
   end
   
   def ramp(limitangle, op, zo=@mill_depth, so=@speed_plung, cmd=@cmd_linear)   
      if limitangle > 0
         ramplimit(limitangle, op, zo, so, cmd)
      else
         rampnolimit(op, zo, so, cmd)
      end
   end

## this ramp is limited to limitangle, so it will do multiple ramps to satisfy this angle   
   def ramplimit(limitangle, op, zo=@mill_depth, so=@speed_plung, cmd=@cmd_linear)
      cncPrintC("(ramp limit #{limitangle}deg zo="+ sprintf("%10.6f",zo)+ ", so="+ so.to_s+ " cmd="+ cmd+"  op="+op.to_s.delete('()')+")\n") if (@debugramp) 
      if (zo == @cz)
         @no_move_count += 1
      else
         # we are at a point @cx,@cy,@cz and need to ramp to op.x,op.y, limiting angle to rampangle ending at @cx,@cy,zo
         if (zo > @max_z)
            cncPrintC("(RAMP limiting Z to max_z @max_z)\n")
            zo = @max_z
         elsif (zo < @min_z)
            cncPrintC("(RAMP limiting Z to min_z @min_z)\n")
            zo = @min_z
         end
      
         command_out = ""
         # if above material, G0 to near surface to save time
         if (@cz == @retract_depth)
            if (@table_flag)
               @cz = @material_thickness + 0.1.mm
            else
               @cz = 0.0 + 0.1.mm
            end
            command_out += "G0 " + format_measure('Z',@cz) +"\n"
            @cc = @cmd_rapid
         end
         
         command_out += cmd if (cmd != @cc)
         # find halfway point
         # is the angle exceeded?
         point1 = Geom::Point3d.new(@cx,@cy,0)  # current point
         point2 = Geom::Point3d.new(op.x,op.y,0) # the other point
         distance = point1.distance(point2)   # this is 'adjacent' edge in the triangle, bz is opposite
         
         if (distance < 0.02)  # dont need to ramp really since not going anywhere far, just plunge
            puts "distance=#{distance.to_mm} so just plunging"  if(@debugramp)
            plung(zo, so, cmd)
            cncPrintC("(ramplimit end, translated to plunge, distance very short)\n")
            return
         end
         
         bz = ((@cz-zo)/2).abs   #half distance from @cz to zo, not height to cut to
         
         anglerad = Math::atan(bz/distance)
         angledeg = todeg(anglerad)
         
         if (angledeg > limitangle)  # then need to calculate a new bz value
            puts "limit exceeded  #{angledeg} > #{limitangle}  old bz=#{bz}" if(@debugramp)
            bz = distance * Math::tan( torad(limitangle) )
            if (bz == 0)
               puts "distance=#{distance} bz=#{bz}"
               passes =4
            else
               passes = ((zo-@cz)/bz).abs
            end   
            puts "   new bz=#{bz.to_mm} passes #{passes}"                  if(@debugramp) # should always be even number of passes?
            passes = passes.floor
            if passes.modulo(2).zero?
               passes += 2
            else
               passes += 1
            end
            if (passes > 100)
               cncPrintC("clamping ramp passes to 100, segment very short")
               puts "clamping ramp passes to 100"
               passes = 100
            end
            bz = (zo-@cz).abs / passes
            puts "   rounded new bz=#{bz.to_mm} passes #{passes}"        if(@debugramp)  # now an even number
         else
            puts "bz is half distance"    if(@debugramp)
            #bz = (zo-@cz)/2 + @cz
         end  
         puts "bz=#{bz.to_mm}" if(@debugramp)

         so = @speed_plung  # force using plunge rate for ramp moves
         
         curdepth = @cz
         cnt = 0
         while ( (curdepth - zo).abs > 0.0001) do
            cnt += 1
            if cnt > 100
               puts "high count break #{curdepth.to_mm}  #{zo.to_mm}" 
               command_out += "ramp loop high count break, do not cut this code\n"
               break
            end
            puts "curdepth #{curdepth.to_mm}"            if(@debugramp)
            # cut to Xop.x Yop.y Z (zo-@cz)/2 + @cz
            command_out += format_measure('x',op.x)
            command_out += format_measure('y',op.y)
# for the last pass, make sure we do equal legs - this is mostyl circumvented by the passes adjustment
            if (zo-curdepth).abs < (bz*2)
               puts "last pass smaller bz"               if(@debugramp)
               bz = (zo-curdepth).abs / 2
            end
            
            curdepth -= bz
            if (curdepth < zo)
               curdepth = zo
            end   
            command_out += format_measure('z',curdepth)
            command_out += (format_feed(so)) if (so != @cs)
            @cs = so
            command_out += "\n";

            # cut to @cx,@cy, curdepth
            curdepth -= bz
            if (curdepth < zo)
               curdepth = zo
            end   
            command_out += format_measure('X',@cx)
            command_out += format_measure('y',@cy)
            command_out += format_measure('z',curdepth)
            command_out += "\n"
         end  # while
         
         cncPrint(command_out)
         cncPrintC("(ramplimit end)\n")             if(@debugramp)
         @cz = zo
         @cs = so
         @cc = cmd
      end
   end

## this ramps down to half the depth at otherpoint, and back to cut_depth at start point
## this may end up being quite a steep ramp if the distance is short
   def rampnolimit(op, zo=@mill_depth, so=@speed_plung, cmd=@cmd_linear)
      cncPrintC("(ramp "+ sprintf("%10.6f",zo)+ ", so="+ so.to_mm.to_s+ " cmd="+ cmd+"  op="+op.to_s.delete('()')+")\n") if (@debugramp) 
      if (zo == @cz)
         @no_move_count += 1
      else
         # we are at a point @cx,@cy and need to ramp to op.x,op.y,zo/2 then back to @cx,@cy,zo
         if (zo > @max_z)
            cncPrintC("(RAMP limiting Z to max_z @max_z)\n")
            zo = @max_z
         elsif (zo < @min_z)
            cncPrintC("(RAMP limiting Z to min_z @min_z)\n")
            zo = @min_z
         end
         command_out = ""
         # if above material, G0 to surface
         if (@cz == @retract_depth)
            if (@table_flag)
               command_out += "G0 Z#{@material_thickness}\n"
               @cz = @material_thickness
            else
               command_out += "G0 Z0\n"
               @cz = 0
            end
            @cc = @cmd_rapid
         end
         
         command_out += cmd if (cmd != @cc)
         
         # cut to Xop.x Yop.y Z (zo-@cz)/2 + @cz
         command_out += format_measure('x',op.x)
         command_out += format_measure('y',op.y)
         bz = (zo-@cz)/2 + @cz
         command_out += format_measure('z',bz)
         command_out += (format_feed(so)) if (so != @cs)
         command_out += "\n";
         # cut to @cx,@cy,zo
         command_out += format_measure('X',@cx)
         command_out += format_measure('y',@cy)
         command_out += format_measure('z',zo)
         
         command_out += "\n"
         cncPrint(command_out)
         @cz = zo
         @cs = so
         @cc = cmd
      end
   end

#If you mean the angle that P1 is the vertex of then this should work:
#    arcos((P12^2 + P13^2 - P23^2) / (2 * P12 * P13))
#where P12 is the length of the segment from P1 to P2, calculated by
#    sqrt((P1x - P2x)^2 + (P1y - P2y)^2)

# cunning bit of code found online, find the angle between 3 points, in radians
#just give it the three points as arrays
# p1 is the center point; result is in radians
   def angle_between_points( p0, p1, p2 )
     a = (p1[0]-p0[0])**2 + (p1[1]-p0[1])**2
     b = (p1[0]-p2[0])**2 + (p1[1]-p2[1])**2
     c = (p2[0]-p0[0])**2 + (p2[1]-p0[1])**2
     Math.acos( (a+b-c) / Math.sqrt(4*a*b) ) 
   end
   
## this ramp is limited to limitangle, so it will do multiple ramps to satisfy this angle   
## not going to write an unlimited version, always limited to at least 45 degrees
## though some of these arguments are defaulted, they must always all be given by the caller
   def ramplimitArc(limitangle, op, rad, cent, zo=@mill_depth, so=@speed_plung, cmd=@cmd_linear)
      if (limitangle == 0)
         limitangle = 45   # always limit to something
      end
      cncPrintC("ramplimitArc")  if (@debugramparc)
      cncPrintC("(ramp arc limit #{limitangle}deg zo="+ sprintf("%10.6f",zo)+ ", so="+ so.to_s+ " cmd="+ cmd+"  op="+op.to_s.delete('()')+")\n") if (@debugramparc) 
      if (zo == @cz)
         @no_move_count += 1
      else
         # we are at a point @cx,@cy,@cz and need to arcramp to op.x,op.y, limiting angle to rampangle ending at @cx,@cy,zo
         # cmd will be the initial direction, need to reverse for the backtrack
         if (zo > @max_z)
            cncPrintC("(RAMParc limiting Z to max_z @max_z)\n")
            zo = @max_z
         elsif (zo < @min_z)
            cncPrintC("(RAMParc limiting Z to min_z @min_z)\n")
            zo = @min_z
         end
      
         command_out = ""
         # if above material, G0 to near surface to save time
         if (@cz == @retract_depth)
            if (@table_flag)
               @cz = @material_thickness + 0.1.mm
            else
               @cz = 0.0 + 0.1.mm
            end
            command_out += "G0 " + format_measure('Z',@cz) +"\n"
            cncPrint(command_out)
            @cc = @cmd_rapid
         end
         
	
         angle = angle_between_points([@cx,@cy], [cent.x,cent.y] , [op.x,op.y])
         arclength = angle * rad
         puts "angle #{angle} arclength #{arclength.to_mm}"    if (@debugramp)
#with the angle we can find the arc length
#angle*radius   (radians)
         
         if (cmd.include?('3'))  # find the 'other' command for the return stroke
            ocmd = 'G2'
         else
            ocmd = 'G3'
         end
         # find halfway point
         # is the angle exceeded?
#         point1 = Geom::Point3d.new(@cx,@cy,0)  # current point
#         point2 = Geom::Point3d.new(op.x,op.y,0) # the other point
#         distance = point1.distance(point2)   # this is 'adjacent' edge in the triangle, bz is opposite
         distance =  arclength
         if (distance < 0.02)  # dont need to ramp really since not going anywhere, just plunge
            puts "arcramp distance=#{distance.to_mm} so just plunging"  if(@debugramp)
            plung(zo, so, cmd)
            cncPrintC("(ramplimitarc end, translated to plunge)\n")
            return
         end
         
         bz = ((@cz-zo)/2).abs   #half distance from @cz to zo, not height to cut to
         
         anglerad = Math::atan(bz/distance)
         angledeg = todeg(anglerad)
         
         if (angledeg > limitangle)  # then need to calculate a new bz value
            puts "arcramp limit exceeded  #{angledeg} > #{limitangle}  old bz=#{bz}" if(@debugramp)
            bz = distance * Math::tan( torad(limitangle) )
            if (bz == 0)
               puts "distance=#{distance} bz=#{bz}"                        if (@debugramp)
               passes = 4
            else
               passes = ((zo-@cz)/bz).abs
            end   
            puts "   new bz=#{bz.to_mm} passes #{passes}"                  if(@debugramp) # should always be even number of passes?
            passes = passes.floor
            if passes.modulo(2).zero?
               passes += 2
            else
               passes += 1
            end
            bz = (zo-@cz).abs / passes
            puts "   rounded new bz=#{bz.to_mm} passes #{passes}"          if(@debugramp) # now an even number
         else
            puts "bz is half distance"          if(@debugramp)
            #bz = (zo-@cz)/2 + @cz
         end
         puts "bz=#{bz.to_mm}" if(@debugramp)

         so = @speed_plung  # force using plunge rate for ramp moves
         
         curdepth = @cz
         cnt = 0
         command_out = ''
         while ( (curdepth - zo).abs > 0.0001) do
            command_out += cmd
            cnt += 1
            if cnt > 100
               puts "high count break" 
               command_out += "ramp arc loop high count break, do not cut this code\n"
               break
            end
            puts "   curdepth #{curdepth.to_mm}"            if(@debugramp)
            # cut to Xop.x Yop.y Z (zo-@cz)/2 + @cz
            command_out += format_measure('x',op.x)
            command_out += format_measure('y',op.y)
# for the last pass, make sure we do equal legs - this is mostly circumvented by the passes adjustment
            if (zo-curdepth).abs < (bz*2)
               puts "   last pass smaller bz"               if(@debugramp)
               bz = (zo-curdepth).abs / 2
            end
            
            curdepth -= bz
            if (curdepth < zo)
               curdepth = zo
            end   
            command_out += format_measure('z',curdepth)
            command_out += format_measure('r',rad)
            command_out += (format_feed(so)) if (so != @cs)
            @cs = so
            command_out += "\n";

            # cut to @cx,@cy, curdepth
            curdepth -= bz
            if (curdepth < zo)
               curdepth = zo
            end   
            command_out += ocmd
            command_out += format_measure('X',@cx)
            command_out += format_measure('Y',@cy)
            command_out += format_measure('Z',curdepth)
            command_out += format_measure('R',rad)
            command_out += "\n"
         end  # while
         
         cncPrint(command_out)
         cncPrintC("(ramplimitarc end)\n")             if(@debugramp)
         @cz = zo
         @cs = so
         @cc = cmd
      end
   end
   

# generate code for a spiral bore and return the command string
   def SpiralAt(xo,yo,zstart,zend,yoff)
      @precision += 1
      cwstr = @cw ? 'CW' : 'CCW';
      cmd =   @cw ? 'G02': 'G03';
      command_out = ""
      command_out += "   (SPIRAL #{xo.to_mm},#{yo.to_mm},#{(zstart-zend).to_mm},#{yoff.to_mm},#{cwstr})\n" if @debugramp
      command_out += "G00" + format_measure("Y",yo-yoff)
      command_out += "\n"
      command_out += "G01"
      command_out += format_measure(" Z",zstart)
      command_out += format_feed(@speed_curr)    if (@speed_curr != @cs)
      command_out += "\n"
      #if ramping with limit use plunge feed rate
      @cs = (PhlatScript.mustramp? && (PhlatScript.rampangle > 0)) ? @speed_plung : @speed_curr

      #// now output spiral cut
      #//G02 X10 Y18.5 Z-3 I0 J1.5 F100
      if (PhlatScript.mustramp? && (PhlatScript.rampangle > 0))
         #calculate step for this diameter
         #calculate lead for this angle spiral
         circ = Math::PI * yoff.abs * 2   # yoff is radius
         step = -Math::tan(torad(PhlatScript.rampangle)) * circ
         puts "(SpiralAt z step = #{step.to_mm} for ramp circ #{circ.to_mm}"         if (@debugramp)
         # now limit it to multipass depth or half bitdiam because it can get pretty steep for small diameters
         if PhlatScript.useMultipass?
            if step.abs > PhlatScript.multipassDepth
               step = -PhlatScript.multipassDepth
               puts " step #{step.to_mm} limited to multipass"       if (@debugramp)
            end
         else
            if step.abs > (@bit_diameter/2)
               s = ((zstart-zend) / (@bit_diameter/2)).ceil #;  // each spiral Z feed will be bit diameter/2 or slightly less
               step = -(zstart-zend) / s
               puts " step #{step.to_mm} limited to fuzzybitdiam/2"       if (@debugramp)
            end
         end
      else
         if PhlatScript.useMultipass?
            step = -PhlatScript.multipassDepth
         else
            s = ((zstart-zend) / (@bit_diameter/2)).ceil #;  // each spiral Z feed will be bit diameter/2 or slightly less
            step = -(zstart-zend) / s     # ensures every step down is the same size
         end
      end
      d = zstart-zend
      puts("Spiralat: step #{step.to_mm} zstart #{zstart.to_mm} zend #{zend.to_mm}  depth #{d.to_mm}" )   if @debug
      command_out += "   (Z step #{step.to_mm})\n"          if @debug
      now = zstart
      while now > zend do
         now += step;
         if (now < zend)
            now = zend
         else
            if ( (zend - now).abs < (@bit_diameter / 8) )
               df = zend - now;
               if (df.abs > 0)
                  command_out += "   (SpiralAt: forced depth as very close " if @debug
                  command_out += format_measure("",df) + ")\n"                if @debug
               end
               now = zend
            end
         end
         command_out += "#{cmd} "
         command_out += format_measure(" X",xo)
         command_out += format_measure(" Y",yo-yoff)
         command_out += format_measure(" Z",now)
         command_out += " I0"
         command_out += format_measure(" J",yoff)
#         command_out += format_feed(@speed_curr) if (@speed_curr != @cs)
#         @cs = @speed_curr
         command_out += "\n"
      end # while
    # now the bottom needs to be flat at $depth
      command_out += "#{cmd} "
      command_out += format_measure(" X",xo)
      command_out += format_measure(" Y",yo-yoff)
      command_out += " I0.0"
      command_out += format_measure(" J",yoff)
      command_out += "\n";
      command_out += "   (SPIRAL END)\n" if @debug
      @precision -= 1
      return command_out
    end # SpiralAt

#swarfer: instead of a plunged hole, spiral bore to depth
#handles multipass by itself
    def plungebore(xo,yo,zStart,zo,diam)
      zos = format_measure("depth=",zStart-zo)
      ds = format_measure(" diam=", diam)
      cncPrintC("(plungebore #{zos} #{ds})\n")
      if (zo > @max_z)
        zo = @max_z
      elsif (zo < @min_z)
        zo = @min_z
      end
      command_out = ""

      cncPrintC("HOLE #{diam.to_mm} dia at #{xo.to_mm},#{yo.to_mm} DEPTH #{(zStart-zo).to_mm}\n")       if @debug
      puts     " (HOLE #{diam.to_mm} dia at #{xo.to_mm},#{yo.to_mm} DEPTH #{(zStart-zo).to_mm})\n"       if @debug

#      xs = format_measure('X', xo)
#      ys = format_measure('Y', yo)
#      command_out += "G00 #{xs} #{ys}\n";
#swarfer: a little optimization, approach the surface faster
      if $phoptions.use_reduced_safe_height?
         sh = (@retract_depth - zStart) / 3 # use reduced safe height
         if zStart > 0
            sh += zStart.to_f
         end
         puts "  reduced safe height #{sh.to_mm}\n"                     if @debug
         command_out += "G00" + format_measure("Z", sh)    # fast feed down to 1/3 safe height
         command_out += "\n"
      else
         sh = @retract_depth
      end

      so = @speed_plung                     # force using plunge rate for vertical moves
      if PhlatScript.useMultipass?
         if ( (PhlatScript.mustramp?) && (diam > @bit_diameter) )
            if (diam > (@bit_diameter*2))
               yoff = @bit_diameter / 2
            else
               yoff = (diam/2 - @bit_diameter/2) * 0.75
            end
            command_out += SpiralAt(xo,yo,zStart,zo, yoff )
            command_out += "G0 " + format_measure("Z" , sh)
            command_out += "\n"
         else
            zonow = PhlatScript.tabletop? ? @material_thickness : 0
            while (zonow - zo).abs > 0.0001 do
               zonow -= PhlatScript.multipassDepth
               if zonow < zo
                  zonow = zo
               end
               command_out += "G01" + format_measure("Z",zonow)  # plunge the center hole
               command_out += (format_feed(so)) if (so != @cs)
               command_out += "\n"
               @cs = so
               command_out += "G00" + format_measure("z",sh)    # retract to reduced safe
               command_out += "\n"
            end #while
         end
      else
#todo - if ramping, then do not plunge this, rather do a spiralat with yoff = bit/2      
#more optimizing, only bore the center if the hole is big, assuming soft material anyway
         if ((diam > @bit_diameter) && (PhlatScript.mustramp?))
            if (diam > (@bit_diameter*2))
               yoff = @bit_diameter / 2
            else
               yoff = (diam/2 - @bit_diameter/2) * 0.75
            end
            cncPrintC("!multi && ramp yoff #{yoff.to_mm}")
            command_out += SpiralAt(xo,yo,zStart,zo, yoff )
            command_out += "G0 " + format_measure("Z" , sh)
            command_out += "\n"
         else
            command_out += "G01" + format_measure("Z",zo)  # plunge the center hole
            command_out += (format_feed(so)) if (so != @cs)
            command_out += "\n"
            @cs = so
            command_out += "g00" + format_measure("z",sh)    # retract to reduced safe
            command_out += "\n"
         end
      end

    # if DIA is > 2*BITDIA then we need multiple cuts
      yoff = (diam/2 - @bit_diameter/2)      # offset to start point for final cut
      if (diam > (@bit_diameter*2) )
         command_out += "  (MULTI spirals)\n"            if @debug
# if regular step         
#         ystep = @bit_diameter / 2
# else use stepover
         ystep = PhlatScript.stepover * @bit_diameter / 100

#########################
# if fuzzy stepping, calc new ystep from optimized step count
# find number of steps to complete hole
         if ($phoptions.use_fuzzy_holes?)
            rem = (diam / 2) - (@bit_diameter/2)  # still to be cut
            temp = ((diam / 2) - (@bit_diameter/2)) / ystep   # number of steps to do it
            puts " temp steps = #{temp}\n" if @debug
            puts " ystep old #{ystep.to_mm}\n" if @debug

            flag = false
            if (PhlatScript.stepover < 50)               #round temp up to create more steps
               temp = (temp + 0.5).round
               flag = true
            else
               if (PhlatScript.stepover > 50)            #round temp down to create fewer steps
                  temp = (temp - 0.5).round
                  flag = true
               end
            end
            if (flag)                                    # only adjust if we need to
               temp = (temp < 1) ? 1 : temp
               puts "   temp steps = #{temp}\n" if @debug
            #   calc new ystep
               ystep = rem / temp
               if (ystep > @bit_diameter ) # limit to stepover
                  ystep = PhlatScript.stepover * @bit_diameter / 100
                  puts " ystep was > bit, limited to stepover\n"         if @debug
               end
               puts " ystep new #{ystep.to_mm}\n" if @debug
            end
         end
#######################

         puts "Ystep #{ystep.to_mm}\n" if @debug
         
         
         
         nowyoffset = (PhlatScript.mustramp?) ? @bit_diameter/2 :  0
#         while (nowyoffset < yoff)
         while ( (nowyoffset - yoff).abs > 0.001)         
            nowyoffset += ystep
            if (nowyoffset > yoff)
               nowyoffset = yoff
               command_out += "  (offset clamped)\n"                 if @debug
               puts "   nowyoffset #{nowyoffset.to_mm} clamped\n"    if @debug
            else
               puts "   nowyoffset #{nowyoffset.to_mm}\n"            if @debug
            end
            command_out += SpiralAt(xo,yo,zStart,zo,nowyoffset)
#            if (nowyoffset != yoff) # then retract to reduced safe
            if ( (nowyoffset - yoff).abs > 0.0001) # then retract to reduced safe            
               command_out += "G0 " + format_measure("Z" , sh)
               command_out += "\n"
            end
         end # while
      else
         if (diam > @bit_diameter) # only need a spiral bore if desired hole is bigger than the drill bit
            puts " (SINGLE spiral)\n"                    if @debug
            command_out += SpiralAt(xo,yo,zStart,zo,yoff);
         end
         if (diam < @bit_diameter)
            cncPrintC("NOTE: requested dia #{diam} is smaller than bit diameter #{@bit_diameter}")
         end
      end # if diam >

      # return to center at safe height
#      command_out += format_measure(" G1 Y",yo)
#      command_out += "\n";
      command_out += "G00" + format_measure("Y",yo)      # back to circle center
      command_out += format_measure(" Z",@retract_depth) # retract to real safe height
      command_out += "\n"
      cncPrint(command_out)
      
      cncPrintC("plungebore end")

      @cx = xo
      @cy = yo
      @cz = @retract_depth
      @cs = so
      @cc = '' #resetting command here so next one is forced to be correct
    end

# use R format arc movement, suffers from accuracy and occasional reversal by CNC controllers
   def arcmove(xo, yo=@cy, radius=0, g3=false, zo=@cz, so=@speed_curr, cmd=@cmd_arc)
      cmd = @cmd_arc_rev if g3
      #puts "g3: #{g3} cmd #{cmd}"
      #G17 G2 x 10 y 16 i 3 j 4 z 9
      #G17 G2 x 10 y 15 r 20 z 5
      command_out = ""
      command_out += cmd if (cmd != @cc)
      @precision +=1  # circles like a bit of extra precision so output an extra digit
      command_out += (format_measure("X", xo)) #if (xo != @cx) x and y must be specified in G2/3 codes
      command_out += (format_measure("Y", yo)) #if (yo != @cy)
      command_out += (format_measure("Z", zo)) if (zo != @cz)
      command_out += (format_measure("R", radius))
      @precision -=1
      command_out += (format_feed(so)) if (so != @cs)
      command_out += "\n"
      cncPrint(command_out)
      @cx = xo
      @cy = yo
      @cz = zo
      @cs = so
      @cc = cmd
   end

# use IJ format arc movement, more accurate, definitive direction
   def arcmoveij(xo, yo, centerx,centery, g3=false, zo=@cz, so=@speed_curr, cmd=@cmd_arc)
      cmd = @cmd_arc_rev if g3
      #puts "g3: #{g3} cmd #{cmd}"
      #G17 G2 x 10 y 16 i 3 j 4 z 9
      #G17 G2 x 10 y 15 r 20 z 5
      command_out = ""
      command_out += cmd if (cmd != @cc)
      @precision +=1  # circles like a bit of extra precision so output an extra digit
      command_out += (format_measure("X", xo)) #if (xo != @cx) x and y must be specified in G2/3 codes
      command_out += (format_measure("Y", yo)) #if (yo != @cy)
      command_out += (format_measure("Z", zo)) if (zo != @cz)
      i = centerx - @cx
      j = centery - @cy
      command_out += (format_measure("I", i))
      command_out += (format_measure("J", j))
      @precision -=1
      command_out += (format_feed(so)) if (so != @cs)
      command_out += "\n"
      cncPrint(command_out)
      @cx = xo
      @cy = yo
      @cz = zo
      @cs = so
      @cc = cmd
   end


    def home
      if (@cz == @retract_depth) && (@cy == 0) && (@cx == 0)
        @no_move_count += 1
      else
        retract(@retract_depth)
        cncPrint("G0 X0 Y0 " , PhlatScript.gcomment("home") , "\n")
        @cx = 0
        @cy = 0
        @cz = @retract_depth
        @cs = 0
        @cc = ""
      end
    end

  end # class PhlatMill

end # module PhlatScript
# A forum member was struggling with a 1mm bit cutting 1mm hard material in that
# the plunge cuts after tabs were at full speed not plunge speed
# This file solves that, and is different from the first version published in that
# all upward Z moves are at fullspeed, only downward cuts are at plunge speed
# Vtabs are at full speed as usual.
# $Id$
