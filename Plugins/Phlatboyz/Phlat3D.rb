# Copyright 2010 by Nicholas Peshman

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

# Name :          GCode Gen 3D 1.0
# Description :   Creates GCode conforming to the contour of a model for 3 Axis machines
# Author :        Nicholas Peshman makingfoamfly@gmail.com
# Usage :         Move Group or groups to within the safe area starting from 0,0 and on the 0 plane then run the contour script
# Date :          23.Nov.2010
# Type :          tool
# History :       Metricated by swarfer May 2013 $Id$
#						Fix multipass bug, plunges to fulldepth before each pass, should only plunge to pass depth

require 'sketchup.rb'
require 'Phlatboyz/PhlatProgress.rb'

module PhlatScript


class GCodeGen3D

        def initialize
                @mod = Sketchup.active_model
                @ents = @mod.entities

                # the starting values
                @spindle = PhlatScript.spindleSpeed #8000
                @feedRate = PhlatScript.feedRate #100
                @bitDiam = PhlatScript.bitDiameter.to_f #0.125
                @matThick = PhlatScript.materialThickness.to_f #2.0
                @safeLength = PhlatScript.safeWidth.to_f  #42.0
                @safeWidth = PhlatScript.safeHeight.to_f #22.0
                @multiPass = PhlatScript.useMultipass? # PhlatScript.multipassEnabled #false
                @multiPassDepth = PhlatScript.multipassDepth.to_f #0.1
                @overcutPercent = PhlatScript.cutFactor #1.40
                @phlat_SafeHeight = PhlatScript.safeTravel.to_f #2.50
                @safeHeight = (@phlat_SafeHeight.to_f) # + @matThick.to_f)

                @safeXOffset = 0.0
                @safeYOffset = 0.0
                @modelMaxX = 0.0
                @modelMaxY = 0.0
                @modelMaxZ = 0.0
                @modelMinX = 99999.0
                @modelMinY = 99999.0
                @modelMinZ = 99999.0

                @sileToSave = "D:/test.cnc"

                #Calculated Values
                @bitOffset = @bitDiam/2
                @stepOver = @bitOffset
                @modelgrid = Array.new
                @gCodegrid = Array.new
                @verticalgrid = Array.new
                @optimizedgrid = Array.new

                @optgrid2 = Array.new
#                @gCodeOffset = 50

                #metric by swarfer - this does the basic setting up from the drawing units
                if PhlatScript.isMetric
                   @unit_cmd, @precision, @is_metric = ["G21", 3, true]
                else
                   @unit_cmd, @precision, @is_metric = ["G20", 4, false]
                end

        end

        def modelgrid
                @modelgrid
        end
        def gCodegrid
                @gCodegrid
        end
        def vgrid
                @verticalgrid
        end

    def format_measure(axis, measure)
      m2 = @is_metric ? measure.to_mm : measure.to_inch
      sprintf(" #{axis}%-10.*f", @precision, m2)
    end

    def format_feed(f)
      feed = @is_metric ? f.to_mm : f.to_inch
      sprintf(" F%-4i", feed)
    end

  def generate
    #Get stepover as a parameter in percent of BitDiameter
    #prompts = ["Enter StepOver as Percentage of Bit Diameter"]
    #defaults = ["30"]
    #results = inputbox prompts, defaults, "StepOver Percentage"
    #@stepOver = @bitDiam * ( results[0].to_f/100)
    @stepOver = @bitDiam * ( PhlatScript.stepover.to_f/100)


    #need to Cycle through all entities finding the minimum and max points if inside the safe area
    #Save the max X,Y, and Z
    if(enter_file_dialog(@mod))

      Sketchup.status_text = "Starting Phlat 3D script"
      puts "(A 3D Contour)"
      puts "(StepOver: #@stepOver)"
      puts "(Spindle speed: #@spindle)"
      puts "(FeedRate: #@feedRate)"
      puts "(Bit Diameter: #@bitDiam)"
      puts "(BitOffset: #@bitOffset)"
      puts "(Material Thickness: #@matThick)"
      puts "(Safe Length: #@safeLength)"
      puts "(Safe Width: #@safeWidth)"
      puts "(Multipass: #@multiPass)"
      puts "(Multipass Depth: #@multiPassDepth)"
      puts "(OverCut: #@overcutPercent)" if (@overcutPercent > 100)
      puts "(SafeHeight: #@safeHeight)"

      for ent in @ents
        if (@safeXOffset < ent.bounds.min.x) and (@safeYOffset < ent.bounds.min.y) and (@safeXOffset+@safeLength > ent.bounds.max.x) and (@safeYOffset + @safeWidth > ent.bounds.max.y)
          @modelMaxX = ent.bounds.max.x if ent.bounds.max.x > @modelMaxX
          @modelMaxY = ent.bounds.max.y if ent.bounds.max.y > @modelMaxY
          @modelMaxZ = ent.bounds.max.z if ent.bounds.max.z > @modelMaxZ
          @modelMinX = ent.bounds.min.x if ent.bounds.min.x  < @modelMinX
          @modelMinY = ent.bounds.min.y if ent.bounds.min.y  < @modelMinY
          @modelMinZ = ent.bounds.min.z if ent.bounds.min.z  < @modelMinZ
        end
      end

      outsideSafe = false

      if !outsideSafe
        #Now Get the model values at the grid points
        generateModelGrid

        #Do Vertical analysis and manip
        generateVerticals

        #now determine any interference with the model and adjust grid with appropriate offset
        generateGCodeGrid

        #optimize GCode
        optimizeGCodeGrid(@gCodegrid)
        @optgrid2 = optimizeGrid2(@optimizedgrid)

        #output the GCode
        if @multiPass
          printGCodeInterval(@optgrid2) #@gCodegrid) @optimizedgrid)
        else
          printGCode(@optgrid2)
        end
        @basefloor.erase!
      end
    end

    UI::messagebox("3D GCode Generation Finished")
  end

  def optimizeGCodeGrid(grid)
    puts "Starting to Optimize GCode"
    Sketchup.status_text = "Starting to Optimize GCode"
    i = 1
    pt = grid[0]
    @optimizedgrid += [pt]
    removedpt = false
    rise = 0
    run = 0
   
   prog = PhProgressBar.new( grid.length, "Starting to Optimize GCode")
   prog.symbols("d","D")

    while i < (grid.length-1)
      prog.update(i)
      if removedpt
      else
        prevpt = grid[i-1]
      end

      curpt = grid[i]
      nextpt = grid[i+1]

      if curpt != grid[i-1] and curpt != nextpt
        if curpt != nil and prevpt != nil and nextpt != nil
          if (curpt.x == prevpt.x) and (curpt.x == nextpt.x)

            if not removedpt
              rise = curpt.z - prevpt.z
              run = curpt.y - prevpt.y
            end

            if run != 0
              slope = rise/run
              const = prevpt.z - (slope*prevpt.y)

              if nextpt.z != (slope * nextpt.y) + const
                @optimizedgrid+= [curpt]
                removedpt = false
              else
                removedpt = true
              end
            else
              if prevpt.y != nextpt.y
                @optimizedgrid+= [curpt]
                removedpt = false
              end
            end
          else
            if curpt != nil
              @optimizedgrid += [curpt]
              removedpt = false
            end
          end
        else
          if curpt != nil
            @optimizedgrid += [curpt]
            removedpt = false
          end
        end
      else
        if curpt != nil and curpt != grid[i-1]
          @optimizedgrid += [curpt]
          removedpt = false
        end
      end
      i += 1
    end # while
    @optimizedgrid += [grid[grid.length-1]]
    puts "Finished Optimize GCode"
    Sketchup.status_text = "Finished Optimize GCode"
  end

  def optimizeGrid2 (grid)
    puts "Starting to Optimize GCode"
    Sketchup.status_text = "Starting to Optimize GCode"
    optgrid = Array.new
    i = 0
    while i < grid.length-4

      if grid[i] != nil
        if (grid[i].z == 0.0) and (grid[i+1].z == 0.0) and (grid[i+2].z == 0.0) and (grid[i+3].z == 0.0)
          if grid[i+1].z == 0.0 and grid[i].x == grid[i+1].x
            if (grid[i].x != grid[i+2].x) and (grid[i+2].x == grid[i+3].x)
              i += 3
            elsif
              optgrid += [grid[i]]
            end
          elsif
            optgrid += [grid[i]]
          end
        elsif
          optgrid += [grid[i]]
        end
      end
      i+=1
    end

    return optgrid
  end


  def generateVerticals

   puts "Starting to generate Verticals"
   Sketchup.status_text = "Starting to generate Verticals"
   i = 0
   prevpt = @modelgrid[0]
   curpt = @modelgrid[0]
   nextpt = @modelgrid[1]

   prog = PhProgressBar.new( @modelgrid.length, "Starting to generate Verticals")
   prog.symbols("b","B")

   while i < @modelgrid.length
      prog.update(i)
      if i == 0
         curpt = @modelgrid[i]
         nextpt = @modelgrid[i+1]
      elsif i == (@modelgrid.length) -1
         prevpt = @modelgrid[i-1]
         curpt = @modelgrid[i]
         nextpt = @modelgrid[i]
      else
         prevpt = @modelgrid[i-1]
         curpt = @modelgrid[i]
         nextpt = @modelgrid[i+1]
      end

      if curpt != nil
         if nextpt != nil
            if curpt.x == nextpt.x

            zdelta = nextpt.z - curpt.z

            if zdelta.abs > @stepOver
               #puts "Adding in a vertical at #{curpt}"

               @verticalgrid += [curpt]

               if zdelta > 0
                  zpos = curpt.z
                  while zpos <= nextpt.z
                     testpt = Geom::Point3d.new(curpt.x, curpt.y , zpos)
                     vector = Geom::Vector3d.new(0,1,0)
                     if nextpt.y < curpt.y
                        #puts "Increase Z with decrease y"
                        vector = Geom::Vector3d.new(0,-1,0)
                        #puts "#{testpt}, #{vector}"
                     end
                     newpt = findModelIntersection(testpt, vector)
                     #puts "#{newpt}"
                     if newpt != nil
                        if (newpt.y - curpt.y).abs < @stepOver
                           @verticalgrid += [newpt]
                        end
                     end
                     zpos += @stepOver
                  end # while zpos
                  testpt = Geom::Point3d.new(curpt.x, curpt.y , nextpt.z)
                  vector = Geom::Vector3d.new(0,1,0)
                  if nextpt.y < curpt.y
                     #puts "Increase Z with decrease y"
                     vector = Geom::Vector3d.new(0,-1,0)
                     #puts "#{testpt}, #{vector}"
                  end
                  newpt = findModelIntersection(testpt, vector)
                  #puts "#{newpt}"
                  if newpt != nil
                     if (newpt.y - curpt.y).abs < @stepOver
                        @verticalgrid += [newpt]
                     end
                  end
                  zpos += @stepOver
               elsif zdelta < 0
                  zpos = curpt.z
                  while zpos >= nextpt.z
                     testpt = Geom::Point3d.new(nextpt.x, nextpt.y , zpos)
                     vector = Geom::Vector3d.new(0,-1,0)
                     if nextpt.y < curpt.y
                        vector = Geom::Vector3d.new(0,1,0)
                     end
                     newpt = findModelIntersection(testpt, vector)

                     if newpt != nil
                        if (newpt.y - curpt.y).abs < @stepOver
                           @verticalgrid += [newpt]
                        end
                     end
                     zpos -= @stepOver
                  end # while
                  testpt = Geom::Point3d.new(nextpt.x, nextpt.y , nextpt.z)
                  vector = Geom::Vector3d.new(0,-1,0)
                  if nextpt.y < curpt.y
                     vector = Geom::Vector3d.new(0,1,0)
                  end
                  newpt = findModelIntersection(testpt, vector)

                  if newpt != nil
                     if (newpt.y - curpt.y).abs < @stepOver
                        @verticalgrid += [newpt]
                     end
                  end
               else
                  #zdelta == 0
                  puts " zdelta #{zdelta}"
               end  # zdelta < 0

            else
               @verticalgrid += [curpt]
            end

         else
            @verticalgrid += [curpt]
         end

      else
         @verticalgrid += [curpt]
      end
      end

      i+=1

   end  # while i
   puts "Finished generating Verticals"
   Sketchup.status_text = "Finished generating Verticals"

   end

#spit out the gcode header, used by both versions of the generator
   def putHeader(nf)
#      ver = "debug"
      vs1 = PhlatScript.getString('PhlatboyzGcodeTrailer')
      vs2 = $PhlatScriptExtension.version
      ver = "#{vs1%vs2}"
      nf.puts PhlatScript.gcomment("A 3D Contour : #{ver}")
      nf.puts PhlatScript.gcomment("Bit Diameter: #{Sketchup.format_length(@bitDiam)}")
      nf.puts PhlatScript.gcomment("StepOver: #{Sketchup.format_length(@stepOver)}  #{PhlatScript.stepover.to_f}%")
      nf.puts PhlatScript.gcomment("Spindle speed: #{@spindle}")
      nf.puts PhlatScript.gcomment("FeedRate: #{Sketchup.format_length(@feedRate)}")
      nf.puts PhlatScript.gcomment("Material Thickness: #{Sketchup.format_length(@matThick)}")
      nf.puts PhlatScript.gcomment("Safe Length: #{Sketchup.format_length(@safeLength)}")
      nf.puts PhlatScript.gcomment("Safe Width: #{Sketchup.format_length(@safeWidth)}")
      if (@multiPass)
         nf.puts PhlatScript.gcomment("Multipass: #@multiPass")
         nf.puts PhlatScript.gcomment("Multipass Depth: #{Sketchup.format_length(@multiPassDepth)}")
      end
      #                nf.puts "(OverCut: #@overcutPercent)"
      nf.puts PhlatScript.gcomment("SafeHeight: #{Sketchup.format_length(@safeHeight)}")
      nf.puts PhlatScript.gcomment("NOTE: Z zero is top of material")

      exact = PhlatScript.useexactpath? ? "G61" : ""         # G61 - Exact Path Mode
      nf.puts "G90 #{@unit_cmd} G49 #{exact}"
   end

	def findModelIntersection(point, vector)
		if point != nil and vector != nil
			ray = [point, vector]
			colpt = @mod.raytest ray
			if colpt != nil
				return colpt[0]
			else
				return nil
			end
		else
			return nil
		end
	end

#       def round_to(value, x)
#               (value * 10**x).round.to_f / 10**x
#       end

   def printGCodeInterval(grid)
      puts "Writing File #@sileToSave"
      Sketchup.status_text = "Writing File #@sileToSave"
      nf = File.new @sileToSave, "w+"
      nf.puts "%"
      putHeader(nf)

      #               nf.puts "G90 #{@unit_cmd} G49"
      curz = 0.0 - @multiPassDepth
      zsafe = format_measure('Z',@phlat_SafeHeight)
      nf.puts "M3 S#@spindle"
      
#find the lowest Z value so we can stop when that level has been cut      
      minz = 2000
      for point in grid
         zv = point.to_a[2]      
         if zv < minz
            minz = zv
         end
      end
      puts "minz #{zv}  #{zv.to_mm}mm"
      
      pass = 1
      stopnexttime = false
      startxs = format_measure('X',grid[0].to_a[0])
      startys = format_measure('Y',grid[0].to_a[1])
      
      prog = PhProgressBar.new( (@matThick / @multiPassDepth).round, "Writing File #@sileToSave" )
      prog.symbols("g","G")

      while curz >= (-@matThick)
         prog.update(pass)
         nf.puts PhlatScript.gcomment("Pass #{pass} curz #{curz}")
         if pass == 1
            nf.puts "G0 #{zsafe}"
            xs = format_measure('X',grid[0].to_a[0])
            ys = format_measure('Y',grid[0].to_a[1])
            nf.puts "  #{xs} #{ys}"
         end

#                       xval = sprintf("%f",round_to(grid[0].to_a[0],5))
#                       yval = sprintf("%f",round_to(grid[0].to_a[1],5))
#                       zval = sprintf("%f",round_to(grid[0].to_a[2],5))
         zs = format_measure('Z',curz)
#                       nf.puts "X#{xval} Y#{yval}"
         fs = format_feed(@feedRate)
         cmd = "G1 #{fs}"      # output this for the first point

         for point in grid
#            xval = sprintf("%f",round_to(point.to_a[0], 5))
#            yval = sprintf("%f",round_to(point.to_a[1], 5))
#            zval = sprintf("%f",round_to(point.to_a[2], 5))
            zv = point.to_a[2]
            xs = format_measure('X',point.to_a[0])
            ys = format_measure('Y',point.to_a[1])
            zs = format_measure('Z',point.to_a[2])

#                          if zval.to_f > curz
            if zv > curz   # remember curz is negative, so zv > curz  is zv above curz
               #zval = round_to(point.to_a[2], 5)
#                             nf.puts "X#{xval} Y#{yval} Z#{zval}"
               nf.puts "#{cmd} #{xs} #{ys} #{zs}"
               cmd = ""
            else
#              scurz = sprintf("%f",round_to(curz,5))
#              nf.puts "X#{xval} Y#{yval} Z#{scurz}"
               zs = format_measure('Z',curz)
               nf.puts "#{cmd} #{xs} #{ys} #{zs}"
               cmd = ""
            end
         end  # for points
         nf.puts "G0 #{zsafe}"
         if stopnexttime
#            nf.puts "(stopnexttime true)"
            nf.puts "G0 X0.0 Y0.0"
            break
         end
         curz -= @multiPassDepth
         # check for exceeding minz and stop early if we need to
         if curz < (minz - @multiPassDepth)
            puts "pass #{pass} curz #{curz} < minz #{minz}"
            nf.puts PhlatScript.gcomment("minz exceeded, stopping early, nothing more to cut")
            nf.puts "G0 X0.0 Y0.0"
            break
         else
            nf.puts "   #{startxs} #{startys}"   # back to start position (not 0,0)
         end
         
#         puts "#{pass} #{curz} #{-@matThick} #{(curz - (-@matThick)).abs}"
         if ((curz - (-@matThick)).abs < 0.001) || (curz < -@matThick)                         #if lower than bottom of material, clamp to table top, and stop next time
#            puts "clamped"
            curz = -@matThick
            stopnexttime = true
         end
         pass += 1
         if pass > 100
            nf.puts PhlatScript.gcomment("multipass too great, limiting to 100")
            break
         end
      end # while
      nf.puts "M05"

      nf.puts "M30"
      nf.puts "%"
      nf.close
      puts "File finished writing #{pass} passes"
      Sketchup.status_text = "File finished writing"
   end

  def printGCode(grid)
	 puts "Writing File #@sileToSave"
	 Sketchup.status_text = "Writing File #@sileToSave"
	 nf = File.new @sileToSave, "w+"
	 nf.puts "%"
	 putHeader(nf)
	 nf.puts "M3 S#{@spindle}"
	 zsafe = format_measure('Z',@phlat_SafeHeight)
	 nf.puts "G0 #{zsafe}"
#               xval = sprintf("%f",round_to(grid[0].to_a[0],5))
#               yval = sprintf("%f",round_to(grid[0].to_a[1],5))
#               zval = sprintf("%f",round_to(grid[0].to_a[2],5))
	 xs = format_measure('X',grid[0].to_a[0])
	 ys = format_measure('Y',grid[0].to_a[1])
	 zs = format_measure('Z',grid[0].to_a[2])
#               nf.puts "X#{xval} Y#{yval}"
	 nf.puts "   #{xs} #{ys}"   # still part of G00 move
	 
    fs = format_feed(@feedRate)
	 nf.puts "G1 #{zs} #{fs}"
	 
    prog = PhProgressBar.new( grid.length, "Writing File #@sileToSave" )
    prog.symbols("g","G")
    progcnt = 0
	 
	 for point in grid
	    prog.update(progcnt)
	    progcnt += 1
   	xs = format_measure('X',point.to_a[0])
   	ys = format_measure('Y',point.to_a[1])
   	zs = format_measure('Z',point.to_a[2])
   	nf.puts "   #{xs} #{ys} #{zs}"
	 end
	 nf.puts "M05"
	 nf.puts "G0 #{zsafe}"
	 nf.puts "G0 X0 Y0"
	 nf.puts "M30"
	 nf.puts "%"
	 nf.close
	 puts "File finished writing"
	 Sketchup.status_text = "File finished writing"
  end

def generateGCodeGrid

   #need to cycle through the modelgrid for each point
   puts "Started generating G Code"
   Sketchup.status_text = "Started generating G Code"
   #oldpoint = @verticalgrid[0]
   i = 0
    
   prog = PhProgressBar.new( @verticalgrid.length,"Started generating G Code"  )
   prog.symbols("c","C")
    
   while i < @verticalgrid.length
      prog.update(i)
      if i == 0
         prevpt = nil
         curpt = @verticalgrid[i]
         nextpt = @verticalgrid[i+1]
      elsif i == (@verticalgrid.length) -1
         prevpt = @verticalgrid[i-1]
         curpt = @verticalgrid[i]
         nextpt = nil
      else
         prevpt = @verticalgrid[i-1]
         curpt = @verticalgrid[i]
         nextpt = @verticalgrid[i+1]
      end
      #for point in @verticalgrid
      #if oldpoint != point
         #hitarray = Array.new
         #alreadyAdjusted = Array.new
         #point = adjustpoint2(point, hitarray, alreadyAdjusted, false)
      
        #point = curpt
        #puts "#{curpt}"
      
      newpt = nil
      if prevpt != curpt and curpt != nextpt and prevpt != nextpt
         if prevpt != nil and curpt != nil and nextpt != nil
            #newpt = adjustpoint3(prevpt, curpt, nextpt)
            newpt = curpt
         end
      end
      
      if newpt != nil
         newpt.z -= @matThick
         @gCodegrid += [(Geom::Point3d.new [newpt.x, newpt.y, newpt.z])]
      end
      
      #end
      #oldpoint = point
      i += 1
   end # while
   
   puts "Finished generating G Code"
   Sketchup.status_text = "Finished generating G Code"
end #generateGcodeGrid

        def adjustpoint3(prevpt, curpt, nextpt)
puts "#{@bitOffset.to_mm}"
                #there are 13 possible point conditions (H - High, M - Middle, L - Low, N-Not existing)

                #                       Direction of travel
                #       North is to the right   |       ->      (A)     |               <- (B)
                #1 MMM  | do nil        | do Nil
                #2  All vertical coming down | +y 1/2 bit       | -y 1/2 bit
                #3 All vertical going up | -y 1/2 bit   | +y 1/2 bit
                #4 HMH  | +z til bit fit | +z til bit fit
                #5 LML  | do nil        | do Nil
                #6 MML  | +y 1/2 bit    | +y 1/2 bit
                #7 MMH  | -y 1/2 bit    | -y 1/2 bit
                #8 HMM  | +y 1/2 bit    | +y 1/2 bit
                #9 LMM  | -y 1/2 bit    | -y 1/2 bit
                #10 HML | +y 1/2 bit    | +y 1/2 bit
                #11 LMH | -y 1/2 bit    | -y 1/2 bit
                #12 NMM | do nil        | do Nil
                #13 MMN | do nil        | do Nil
                #14 MNM | do nil        | do Nil

                # approach is to use the given three point to determine the condition
                # and blindly make corrections depending on the direction of travel
                #puts "----------------------------------------------"
                #puts "curpoint #{curpt}"
                if prevpt != nil and curpt != nil and nextpt != nil

            newpt = Geom::Point3d.new [curpt.x, curpt.y, curpt.z]

                        #Determine the Direction of travel
                        #The reassignment of the previous and next pts is to unravel the zigzag of the datamodel
                        if (nextpt.y - curpt.y) > 0
                          travel = 1
                          north = nextpt
                          south = prevpt
                        else
                                travel = -1
                                north = prevpt
                                south = nextpt
                        end

                        #puts "Start #{newpt}"
                        #determine the condition
                        con = ""
                        if south.z < newpt.z
                                con += "L"
                        elsif south.z == newpt.z
                                con += "M"
                        else
                                con += "H"
                        end
                        con +="M"
                        if north.z < newpt.z
                                con += "L"
                        elsif north.z == newpt.z
                                con += "M"
                        else
                                con += "H"
                        end
                        #puts "#{south.z} #{newpt.z} #{north.z} #{con}"
                        if north.x == south.x and south.x == curpt.x

                                #detects Conditions 2 or 3
                                if south.y == newpt.y and newpt.y == north.y
                                        if con == "HML"
                                                if travel > 0

                                                        #Condition 2A
                                                        #Detect if moving bit will create a collision if so make pt nil
                                                        #collide = determineBitCollisionFull newpt, Geom::Vector3d.new(0,-1*travel,0)
                                                        #if collide[0]
                                                        #       newpt = nil
                                                        #else

                                                                newpt.y -= @bitOffset
                                                        #end
                                                else
                                                        #Condition 2B
                                                        #collide = determineBitCollisionFull newpt, Geom::Vector3d.new(0,1*travel,0)
                                                        #if collide[0]
                                                        #       newpt = nil
                                                        #else

                                                                newpt.y -= @bitOffset
                                                        #end
                                                end
                                        elsif con == "LMH"
                                                if travel > 0
                                                        #Condition 3A
                                                        #collide = determineBitCollisionFull newpt, Geom::Vector3d.new(0, 1*travel,0)
                                                        #if collide[0]
                                                        #       newpt = nil
                                                        #       else

                                                                newpt.y += @bitOffset
                                                        #end
                                                else
                                                        #Condition 3B
                                                        #Detect if moving bit will create a collision if so make pt nil
                                                        #collide = determineBitCollisionFull newpt, Geom::Vector3d.new(0,-1*travel,0)
                                                        #if collide[0]
                                                        #       newpt = nil
                                                        #       else

                                                                newpt.y += @bitOffset
                                                        #end
                                                end
                                        end

                                else
                                        #all other conditions are determined here
                                        case con
                                                when "MMM","LML"
                                                        #conditions 1, 5 so do nothing
                                                        #Do Nothing
                                                when "HMH"
                                                        #conditions 4 need to ray test until bit fits slowly raising height
                                                        newpt = nil
                                                when "MML", "HMM", "HML"
                                                        #conditions 6,8,10 move the bit north
                                                        #Detect if moving bit will create a collision if so make pt nil
                                                        collide = determineBitCollisionFull newpt, Geom::Vector3d.new(0,1,0)
                                                        if collide[0]
                                                                newpt = nil
                                                                else

                                                                newpt.y += @bitOffset
                                                        end
                                                when "MMH", "LMM", "LMH"
                                                        #conditions 7,9,11 move the bit south
                                                        #Detect if moving bit will create a collision if so make pt nil
                                                        collide = determineBitCollisionFull newpt, Geom::Vector3d.new(0,-1,0)
                                                        if collide[0]
                                                                newpt = nil
                                                                else

                                                                newpt.y -= @bitOffset
                                                        end
                                        end

                                end

                        else
                                #Conditions 12, 13 or 14 exist
                                #Do nothing
                        end

                        #if newpt != nil
                                #now test in the x Direction
                                #east = determineBitCollision newpt, Geom::Vector3d.new(1,0,0)
                                #west = determineBitCollision newpt, Geom::Vector3d.new(-1,0,0)

                                #if east[0] and west[0]
                                #       newpt.z += @stepOver
                                #       adjustpoint3(prevpt, newpt, nextpt)
                                #elsif east[0]
                                #       newpt.x -= (@bitOffset - east[1].abs)
                                #elsif west[0]
                                #       newpt.x += (@bitOffset - west[1].abs)
                                #end
                        #end

                end
                #puts "End #{newpt}"
                #puts "----------------------------------------------"
                return newpt
        end


   def adjustpoint2(point, hitarray, alreadyAdjusted, retest)
    if point != nil
      if point.z < @matThick
        acollision = false
        hitarray.clear
        north = determineBitCollision point, Geom::Vector3d.new(0,1,0)
        south = determineBitCollision point, Geom::Vector3d.new(0,-1,0)
        east = determineBitCollision point, Geom::Vector3d.new(1,0,0)
        west = determineBitCollision point, Geom::Vector3d.new(-1,0,0)
        #fill out array with hit points then get the unique ones
        if north[0]
          hitarray += ["North"]
          acollision = true
        end
        if south[0]
          hitarray += ["South"]
          acollision = true
        end
        if east[0]
          hitarray += ["East"]
          acollision = true
        end
        if west[0]
          hitarray += ["West"]
          acollision = true
        end

        if acollision

          hitarray = hitarray.uniq
          operatedOn = false
          #puts "#{hitarray}"

          #Now move point based on collisoins in the hit array
          if hitarray.include?("North") and hitarray.include?("South")
            #puts "prior #{hitarray}"
            point.z += @stepOver
            hitarray.clear
            alreadyAdjusted.clear
            #puts "post #{hitarray}"
            operatedOn = false
            adjustpoint2(point, hitarray,alreadyAdjusted, true)

          elsif hitarray.include?("North")
            if not alreadyAdjusted.include?("North")
              point.y -= (@bitOffset - north[1].abs)
              alreadyAdjusted += ["North"]
              operatedOn = true
              adjustpoint2(point, hitarray,alreadyAdjusted, true)
            end
          elsif hitarray.include?("South")
            #puts "#{point} #{south}"
            if not alreadyAdjusted.include?("South")
              point.y += (@bitOffset - south[1].abs)
              alreadyAdjusted += ["South"]
              operatedOn = true
              adjustpoint2(point, hitarray,alreadyAdjusted, true)
            end
          end


          if hitarray.include?("West") and hitarray.include?("East")
            point.z += @stepOver
            hitarray.clear
            alreadyAdjusted.clear
            operatedOn = false
            adjustpoint2(point, hitarray,alreadyAdjusted, true)
          elsif hitarray.include?("East")
            if not alreadyAdjusted.include?("East")
              point.x -= (@bitOffset - east[1].abs)
              alreadyAdjusted += ["East"]
              operatedOn = true
              adjustpoint2(point, hitarray,alreadyAdjusted, true)
            end
          elsif hitarray.include?("West")
            if not alreadyAdjusted.include?("West")
              point.x += (@bitOffset - west[1].abs)
              alreadyAdjusted += ["West"]
              operatedOn = true
              adjustpoint2(point, hitarray,alreadyAdjusted, true)
            end
          end

          #colpt = findModelIntersection(point, Geom::Vector3d.new(0,0,1))
          #if colpt != nil
          #       point.z = colpt.z
          #end
          if not operatedOn
             return point
          end
        else
          #puts "No Collision Found"
          return point
        end
      else
        puts "point higher than thickness"
        return point
      end
    else
            puts "Nil encounered"
    end
   end

   def determineBitCollisionFull (point, vector)
      #determines if the bit used will eat out a chunk of the physical model. Done by a ray test and then returning if a collision occures
      #ray = [point, vector]
      colpt = findModelIntersection(point, vector)
      if colpt == nil
         return [false,0]
      else
         distance = colpt.distance point
         if distance > (@bitOffset*2) #The reduction in bit offset is needed so that we don't always return nil after a retest
            return [false,distance]
         else
            #if distance < 0.001
            #return [false,distance]
            #else
            return [true, distance]
            #end
         end
      end
   end

   def determineBitCollision (point, vector)
      #determines if the bit used will eat out a chunk of the physical model. Done by a ray test and then returning if a collision occures
      #ray = [point, vector]
      colpt = findModelIntersection(point, vector)
      if colpt == nil
         return [false,0]
      else
         distance = colpt.distance point
         if distance > (@bitOffset - 0.001) #The reduction in bit offset is needed so that we don't always return nil after a retest
            return [false,distance]
         else
            #if distance < 0.001
            #return [false,distance]
            #else
            return [true, distance]
            #end
         end
      end
   end


  def generateModelGrid
    currposx = @modelMinX
    currposy = @modelMinY
    ydir = 1
    Sketchup.status_text = "Starting Generate Model Grid"
    puts "Starting Generate Model Grid"
    puts " BitOffset: #@bitOffset"
    puts " modelMaxX: #@modelMaxX"
    puts " modelMaxY: #@modelMaxY"
    puts " modelMaxZ: #@modelMaxZ"
    puts " modelMinX: #@modelMinX"
    puts " modelMinY: #@modelMinY"
    puts " modelMinZ: #@modelMinZ"
    planval =0 #  @bitDiam * @overcutPercent

    @basefloor = Sketchup.active_model.entities.add_group
    @basefloor.entities.add_face [@modelMinX-5,@modelMinY-5,-planval], [@modelMaxX +5 , @modelMinY-5,-planval], [@modelMaxX+5, @modelMaxY+5,-planval], [@modelMinX-5, @modelMaxY+5,-planval]
#progress bar to indicate activity    
    progcnt = ((@modelMaxX - @modelMinX) / @stepOver).round
    
    prog = PhProgressBar.new( progcnt,"Starting Generate Model Grid" )
    prog.symbols("a","A")
    progcnt = 0
    while currposx < @modelMaxX
       prog.update(progcnt)
       progcnt += 1
      #puts " currposx #{currposx}"
      #The y axis is done this way so the items in the array follow the tool path
      ystarted = true
      #puts "#{ydir}"

      while ystarted #currposy < @modelMaxY
        ray = [Geom::Point3d.new(currposx, currposy, 10), Geom::Vector3d.new(0,0,-1)]
        modelpt = @mod.raytest ray
        if modelpt != nil
          @modelgrid += [modelpt[0]]
        end
        currposy += (ydir * @stepOver)
#        puts "#{currposx} , #{currposy}"
        if ydir == 1
          if currposy > @modelMaxY
            ray = [Geom::Point3d.new(currposx, @modelMaxY, 10), Geom::Vector3d.new(0,0,-1)]
            modelpt = @mod.raytest ray
            if modelpt != nil
              @modelgrid += [modelpt[0]]
            end
            ystarted = false
          end
        end
        if ydir == -1
          if currposy < @modelMinY
            ray = [Geom::Point3d.new(currposx, @modelMinY, 10), Geom::Vector3d.new(0,0,-1)]
            modelpt = @mod.raytest ray
            if modelpt != nil
              @modelgrid += [modelpt[0]]
            end
            ystarted = false
          end
        end
      end # while

      currposx += @stepOver
      #currposy = @modelMinY
      #need to flip the y direction for every row
      if ydir == 1
        currposy = @modelMaxY
        ydir = -1
      else
        currposy = @modelMinY
        ydir = 1
      end
    end

    puts "Finished generating model grid"
    Sketchup.status_text = "Finished generating model grid"
  end

  def enter_file_dialog(model=Sketchup.active_model)
    output_directory_name = PhlatScript.cncFileDir
    output_filename = PhlatScript.cncFileName
    status = false
    result = UI.savepanel(PhlatScript.getString("Save CNC File"), output_directory_name, output_filename)
    if(result != nil)
      # if there isn't a file extension set it to the default
      result += $phoptions.default_file_ext if (File.extname(result).empty?)
      PhlatScript.cncFile = result
      @sileToSave = result
      #PhlatScript.checkParens(result, "Output File")
      status = true
    end
    status
  end
end

#-----------------------------------------------------------------------------
if( not file_loaded?("Phlat3D.rb") )
  label = 'Phlat 3D'
    if $PhlatScript_PlugName
      $PhlatScript_PlugName.add_item(label) { GCodeGen3D.new.generate }
    else
      $PhlatScript_PlugName=UI.menu('Plugins').add_submenu('PhlatPlugins')
      $PhlatScript_PlugName.add_item(label) { GCodeGen3D.new.generate }
    end
end
#-----------------------------------------------------------------------------
file_loaded("Phlat3D.rb")
end #module