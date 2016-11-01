#
# Name:		PocketTool.rb
# Desctiption:	Create a pocket face and zigzag edges
# Author:	Katsuhiko Toba ( http://www.eprcp.com/ )
# Usage:	1. Install into the plugins directory.
#		2. Select "Pocket" from the Plugins menu.
#		3. Click the face to pocket
#		4. Select "CenterLine Tool" from menu or toolbar
#		5. Click the zigzag edge first, the face edge second.
#		NOTE: Do not use Centerline from context menu.
#                     It breaks the zigzag edge.
# Limitations:	Simple convex face only
#
# ** Modified by kyyu 05-29-2010 - rewrote "get_offset_points" method because of a bug          **
#   where the pocket lines were out of the pocket boundaries because of mix direction edges     **
#   -Looks like it works, but not rigorously check so USE AT YOUR OWN RISK!                     **
#
# ** Modified by swarfer 2013-05-20 - press shift to only get zigzag, press ctrl to only get outline
#    This is a step on the way toward integrating it into Sketchucam, and properly handling complex faces
#
# ** Swarfer 2013-08-27 - integrated into Phlatscript toolset
#	default depth is 50% - no support for additional languages yet
#
#  swarfer May 2015 - use fuzzy stepover.  this makes the zigzag start and end at the same offset from the outline
#                   - use the stepover to set the offset.  used to use 0.1 offset of the zigzag from the outline, but   
#                       for larger offsets this does not make the best use of time.  now uses half the stepover for the offset
#                       up to 75%, then 1/3 up to 85%, then 1/4 - the offset cannot be allowed to grow too large, if it does
#                       you get pins left behind in the pocket, especially on curved edges.
#
#  swarfer Jul 2015 - apply pocket to all selected pockets if multiselected
#
#   swarfer Oct 2016 - alternate zigzag routine to fill faces that have holes
# $Id$

require 'sketchup.rb'
#require 'Phlatboyz/Constants.rb'
require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/tools/CenterLineTool.rb'
require 'Phlatboyz/Tools/PhPocketCut.rb'
require 'Phlatboyz/PhlatOffset.rb'

module PhlatScript

   class PocketTool < CenterLineTool

   def initialize
      super()
      @limit = 0
      @flood = false #must we use flood file for zigzags?
      @active_face = nil
      @bit_diameter = PhlatScript.bitDiameter
      #puts "bit diameter #{@bit_diameter.to_mm}mm"
      @ip = nil
      @cells = nil
      @cellxmax = -1
      @cellymax = -1

      # set this to change zigzag stepover, less for hard material, more for soft
      @stepover_percent = PhlatScript.stepover
      #               puts "stepover percent #{@stepover_percent}%"
      if (@stepover_percent <= 100)
         @stepOver = @stepover_percent / 100
      else
         @stepOver = 0.5
         @stepover_percent = 50
      end
      @keyflag = 0

      @tooltype   = 3
      @largeIcon  = "images/pockettool_large.png"
      @smallIcon  = "images/pockettool_small.png"
      @largeIcon  = "images/Pocket_large.png"
      @smallIcon  = "images/Pocket_small.png"
      @statusText = PhlatScript.getString("Pocket Face")
      #PhlatScript.getString("GCode")
      #	 @statusmsg = "Pockettool: [shift] for only zigzag [ctrl] for only boundary, stepover is #{@stepover_percent}%"
      @statusmsgBase  = "Pockettool: [shift] only Zigzag [ctrl] only boundary : [END] toggle direction : [HOME] floodfill ZZ only : "
      @statusmsgBase2  = "Pockettool: FLOOD mode: [CTRL] only boundary : [END] toggle direction : [HOME] floodfill off : "
      @statusmsg = @statusmsgBase
   end

   def enableVCB?
      return true
   end

   def statusText
      return @statusmsg
   end

   def onLButtonDown(flags, x, y, view)
      @ip.pick view, x, y
      @active_face = activeFaceFromInputPoint(@ip)
      if (@active_face)
         self.create_geometry(@active_face, view)
      end
      self.reset(view)
      view.lock_inference
   end

   #SWARFER, want to detect the shift key down, which will prevent drawing an offset line
   #  ie when shift pressed, only do the zigzag inside the current face
   #also detect CTRL, if pressed do not draw offset line, only zigzag
   def onKeyDown(key, repeat, flags, view)
      if key == VK_END    # toggle zig direction
         toggle_direc_flag()
      end
      if key == VK_HOME    # toggle use of flood fill
         @flood = !@flood
         if (@flood)
            @statusmsg = @statusmsgBase2 + "FLOOD #{@stepover_percent}%"
         else
            @statusmsg = @statusmsgBase + "StepOver #{@stepover_percent}%"
         end
         Sketchup::set_status_text(@statusmsg, SB_PROMPT)
      end

      if (key == VK_SHIFT)
         @keyflag = 1
      else
         if (key == VK_CONTROL)
            @keyflag = 2
         else
            super     #process other keys for depth selection
         end
      end
   end

   def onKeyUp(key, repeat, flags, view)
      if key = VK_SHIFT || key = VK_CONTROL
         @keyflag = 0
      end
      #puts "keyup keyflag = #{@keyflag}"
   end

   def draw(view)
      if (@active_face)
         self.draw_geometry(view)
      end
   end

   def onMouseMove(flags, x, y, view)
      @ip.pick view, x, y
      @active_face = activeFaceFromInputPoint(@ip)
      if (@active_face)
         view.tooltip = @ip.tooltip
      end
      view.invalidate if (@ip.display?)
      #reapply status text just in case a tooltip overwrote it
      Sketchup::set_status_text @statusmsg, SB_PROMPT
   end

   # VCB
   def onUserText(text,view)
      super(text,view)

=begin    now uses centerlinetool depth processing, same as foldtool
      begin
         parsed = text.to_f #do not use parse_length function
      rescue
         # Error parsing the text
         UI.beep
         @depth = 50.to_f
         parsed = 50.to_f
         Sketchup::set_status_text("#{@depth} default", SB_VCB_VALUE)
      end
      if (parsed < 1)
         parsed = 1
      end
      if (parsed > (2*PhlatScript.cutFactor))
         parsed = 2*PhlatScript.cutFactor
      end
      if (!parsed.nil?)
         @depth = parsed
         Sketchup::set_status_text("#{@depth} %", SB_VCB_VALUE)
         puts "New Plunge Depth " + @depth.to_s
      end
=end
   end

   def activeFaceFromInputPoint(inputPoint)
      face = inputPoint.face
      # check simple face (outer_loop only)
      if (!@flood)
         if (face)
            if (face.loops.length != 1)
               face = nil
            end
         end
      end
      return face
   end

   def cut_class
      return PocketCut
   end

   def activate
      super()
      @ip = Sketchup::InputPoint.new
      @bit_diameter = PhlatScript.bitDiameter
      @stepover_percent = PhlatScript.stepover
      #puts "activate stepover percent #{@stepover_percent}%"
      if @stepover_percent <= 100
         @stepOver = @stepover_percent.to_f / 100
      else
         @stepover_percent = 50.to_f
         @stepOver = 0.5.to_f
      end
      #if things are selected, try to pocket the faces then deselect
      if (Sketchup.active_model.selection.count > 1)
         view = Sketchup.active_model.active_view       
         sel = Sketchup.active_model.selection
         didit = false
         wasflood = @flood
         sel.each { |thing|
             if (thing.typename == 'Face') 
                #puts "#{thing}"
                @active_face = thing
                self.create_geometry(@active_face, view)
                @flood = wasflood #create_geom will turn it off, turn it back on if it was on
                didit = true
             end
             }
         sel.clear    if (didit)
         self.reset(view)    
         Sketchup.active_model.select_tool(nil) # select select tool since we have already pocketed all selected faces
      else  #if nothing selected, just get ready to pocket the clicked face
         @ip = Sketchup::InputPoint.new
         #puts "activate stepOver = #{@stepOver}  @stepover_percent #{@stepover_percent}"
         if (@flood)
            @statusmsg = @statusmsgBase2 + "FLOOD #{@stepover_percent}%"
         else
            @statusmsg = @statusmsgBase + "StepOver #{@stepover_percent}%"
         end
         Sketchup::set_status_text(@statusmsg, SB_PROMPT)
         self.reset(nil)
      end
   end
   
   #return true if any true values in hash 0..xm,0..ym
   def someleft(hsh, xm, ym)
      y = 0
      while (y <= ym) do
         x = 0
         while (x <= xm) do
            if hsh[[x,y]]
               return true
            end
            x += 1
         end
         y += 1
      end
      return false
   end

   # return true if pc is on the line pa,pb   
   def isonline(pc,pa,pb)
      ac = pa.distance(pc)
      cb = pb.distance(pc)
      ab = pa.distance(pb)
      return (ab -(ac + cb)).abs < 0.0001
   end   
  
   # return true if line [pt1,pt2] crosses any edge in theface
   def iscrossing(pt1,pt2, theface)
      line = [pt1, pt2]
      theface.loops.each { |loop|
         edges = loop.edges
         edges.each { |e|  #check each edge to see if it intersects line inside the edge
            l2 = [e.vertices[0].position, e.vertices[1].position]    # make a line
            point = Geom.intersect_line_line(line, e.vertices)       # find intersection
            if (point != nil)
               online1 = isonline(point, line[0], line[1])           # is the point on the line
               online2 = isonline(point, e.vertices[0].position, e.vertices[1].position)  # is the point on the edge
               #ent.add_cpoint(point)    if (online1 and online2)
               #puts "online1 #{online1} #{online2}"
               return true if (online1 and online2)
               # if (online1 and online2) then we can return true here, no need to process more
            end
         } # edges.each
      }   # loops.each
      return false
   end

   # return point where they cross , if line [pt1,pt2] crosses any edge in theface
   def wherecrossing(pt1,pt2, theface)
      line = [pt1, pt2]
      theface.loops.each { |loop|
         edges = loop.edges
         edges.each { |e|  #check each edge to see if it intersects line inside the edge
            l2 = [e.vertices[0].position, e.vertices[1].position]    # make a line
            point = Geom.intersect_line_line(line, e.vertices)       # find intersection
            if (point != nil)
               online1 = isonline(point, line[0], line[1])           # is the point on the line
               online2 = isonline(point, e.vertices[0].position, e.vertices[1].position)  # is the point on the edge
               #ent.add_cpoint(point)    if (online1 and online2)
               #puts "online1 #{online1} #{online2}"
               return point if (online1 and online2)
               # if (online1 and online2) then we can return true here, no need to process more
            end
         } # edges.each
      }   # loops.each
      return nil
   end
   
   
   def debugfile(line)
      File.open("d:/temp/sketchupdebug.txt", "a+") { |fp| fp.puts(line)  }
   end
   
   # create a raster of 'cells' over the face, cells are spaced at stepOverinuse intervals
   # initialize @cells before calling this
   # make sure there is  a border of false cells around the face
   # use half stepover on X to get the ends of the zigs closer to the borders - suites horizontal zigzags
   def createcells(xstart,xend, ystart,yend, stepOverinuse, aface)
      countx = 0
      xmax = ymax = 0
      x = xstart
      while (x <= xend) do
         y = ystart
         county = 0
         while (y <= yend) do
            #note: using half stepover on the X axis, gets the ends of the zigs closer to the border
            xc = ((x-xstart) / (stepOverinuse/2) + 0.002).round  # x cell index
            yc = ((y-ystart) / stepOverinuse + 0.002).round  # y cell index
            pt = Geom::Point3d.new(x, y,0)
            res = aface.classify_point(pt)
            
            case res
               when Sketchup::Face::PointUnknown #(indicates an error),
                  puts "unknown"    if (@debug)
               when Sketchup::Face::PointInside    #(point is on the face, not in a hole),
                  @cells[[xc,yc]] = true
               when Sketchup::Face::PointOnVertex  #(point touches a vertex),
                  #cells[[xc,yc]] = true
               when Sketchup::Face::PointOnEdge    #(point is on an edge),
                  #cells[[xc,yc]] = true
               when Sketchup::Face::PointOutside   #(point outside the face or in a hole),
                  #puts "outside"      if (@debug)
               when Sketchup::Face::PointNotOnPlane #(point off the face's plane).
                  puts "notonplane"    if (@debug)
            end
            
            xmax = (xmax < xc) ? xc : xmax
            ymax = (ymax < yc) ? yc : ymax
            y += stepOverinuse
            county += 1
            if (county > 5000)   #really for debugging but prevents runaway loops
               puts "county high break"
               break
            end
         end  # while y
         x += (stepOverinuse / 2.0)
         countx += 1
         if (countx > 5000)
            puts "countx high break"
            break
         end
      end # while x
      @cellxmax = xmax
      @cellymax = ymax
   end

   # create a raster of 'cells' over the face, cells are spaced at stepOverinuse intervals
   # initialize @cells before calling this
   # make sure there is  a border of false cells around the face
   # use half stepover on Y to get the ends of the zigs closer to the borders - suites vertical zigzags
   def createcellsX(xstart,xend, ystart,yend, stepOverinuse, aface)
      county = 0
      xmax = ymax = 0
      y = ystart
      while (y <= yend) do
         x = xstart
         countx = 0
         while (x <= xend) do
            #note: using half stepover on the X axis, gets the ends of the zigs closer to the border
            xc = ((x-xstart) / (stepOverinuse) + 0.002).round  # x cell index
            yc = ((y-ystart) / (stepOverinuse/2) + 0.002).round  # y cell index
            pt = Geom::Point3d.new(x, y,0)
            res = aface.classify_point(pt)
            
            case res
               when Sketchup::Face::PointUnknown #(indicates an error),
                  puts "unknown"    if (@debug)
               when Sketchup::Face::PointInside    #(point is on the face, not in a hole),
                  @cells[[xc,yc]] = true
               when Sketchup::Face::PointOnVertex  #(point touches a vertex),
                  #cells[[xc,yc]] = true
               when Sketchup::Face::PointOnEdge    #(point is on an edge),
                  #cells[[xc,yc]] = true
               when Sketchup::Face::PointOutside   #(point outside the face or in a hole),
                  #puts "outside"      if (@debug)
               when Sketchup::Face::PointNotOnPlane #(point off the face's plane).
                  puts "notonplane"    if (@debug)
            end
            
            xmax = (xmax < xc) ? xc : xmax
            ymax = (ymax < yc) ? yc : ymax
            x += stepOverinuse
            countx += 1
            if (countx > 5000)   #really for debugging but prevents runaway loops
               puts "countx high break"
               break
            end
         end  # while x
         y += (stepOverinuse / 2.0)
         county += 1
         if (county > 5000)
            puts "county high break"
            break
         end
      end # while y
      @cellxmax = xmax
      @cellymax = ymax
   end
   
   # this can zigzag a face with holes in it, and also ones with complex concave/convex borders
   # returns an array containing one or more arrays of points, each set of points is a zigzag
   def get_zigzag_flood(aface)
      if PhlatScript.pocketDirection?
         return get_zigzag_flood_x(aface)  # vertical
      else
         return get_zigzag_flood_y(aface)  # horizontal
      end
   end
   
   # step over in X, lines along Y (vertical)
   def get_zigzag_flood_x(aface)
      result = []
#@debug = true      
      # create a 2D array to hold the rasterized shape
      # raster is on stepover boundaries and center of each square is where the zigzags will start and end.
      # set true for each centerpoint that is inside the face
      # raster 0,0 is bottom left of the shape, just outside the boundary
      bb = aface.bounds
      stepOverinuse = @bit_diameter * @stepOver
      ystart = bb.min.y - stepOverinuse / 2  # center of bottom row of cells
      yend = bb.max.y + stepOverinuse + 0.002
      
      xstart = bb.min.x - stepOverinuse / 2  # center of first column of cells
      xend = bb.max.x + stepOverinuse + 0.002  # MUST have a column after end of object else stuff gets skipped
#      if ($phoptions.use_fuzzy_pockets?)  #always uses fuzzy, gives better results
         ylen = yend - ystart - 0.002
         stepOverinuse1 = getfuzzystepover(ylen)
         xlen = xend - xstart - 0.002
         stepOverinuse2 = getfuzzystepover(xlen)
         stepOverinuse = [stepOverinuse1, stepOverinuse2].min  # always use lesser value
#      end
      debugfile("xstart #{xstart.to_mm},#{ystart.to_mm}   #{xend.to_mm},#{yend.to_mm} #{stepOverinuse.to_mm}" )   if (@debug)

      #use a hash as if it were a 2d array of cells rastered over the face
      if (@cells == nil)
         @cells = Hash.new(false)
      else
         @cells.clear
      end   
      # now loop through all cells and test to see if this point is in the face
      pt = Geom::Point3d.new(0, 0, 0)
      xmax = ymax = 0.0
#create the cell array      
      createcellsX(xstart,xend, ystart,yend, stepOverinuse, aface)  #creates cell hash and sets @cellxmax etc
      xmax = @cellxmax
      ymax = @cellymax
      
      entities = Sketchup.active_model.active_entities  if (@debug)
      
      debugfile("xmax #{xmax} ymax #{ymax}")  if (@debug) # max cell index
#      puts "xmax #{xmax} ymax #{ymax}"
#output array for debug      
      if (@debug)
         y = ymax
         debugfile("START")   if (@debug)
         while (y >= 0) do
            x = 0
            s = "y #{y}"
            while (x <= xmax) do
               if (@cells[[x,y]])
                  s += " 1"
               else
                  s += " 0"
               end
               x += 1
            end
            debugfile(s)      if (@debug)
            y -= 1 
         end
      end
      
      # now create the zigzag points from the hash, search along Y for first and last points
      # keep track of 'going DOWN toward 0' or 'going UP' so we can test for a line that would cross the boundary
      # if this line would cross the boundary, start a new array of points
      r = 0
      prevpt = nil
#@debug = true
      while (someleft(@cells,xmax,ymax))  # true if some cells are still not processed
         debugfile("R=#{r}")           if (@debug)
         result[r] = []
         x = 0
         goingright = true  # goingUP
         px = -1  # previous x used, to make sure we do not jump a X level
         countx = 0
         while (x <= xmax) do
            countx += 1
            if (countx > 5000)
               puts " countx break"
               break
            end
         
            lefty = -1  # down
            y = 0
            while (y <= ymax) do # search to the right for a true
               if (@cells[[x,y]] == true)
                  @cells[[x,y]] = false
                  lefty = y
                  break  # found left side X val
               end
               y += 1
            end #while y
            righty = -1
            y += 1
            if y <= ymax 
               while (y <= ymax) do  # search to the right for a false
                  if (@cells[[x,y]] == false)
                     righty = y-1
                     break  # found right  side X val
                  end
                  @cells[[x,y]] = false                # set false after we visit
                  y += 1
               end #while x
            end
            # now we have lefty and righty for this X, if righty > -1 then push these points
            debugfile("   left #{lefty} right #{righty} y #{y}")  if (@debug)
            if (righty > -1)
               #if px,py does not cross any face edges
#               pt1 = Geom::Point3d.new(xstart + leftx*stepOverinuse, ystart + y * stepOverinuse, 0)
#               pt2 = Geom::Point3d.new(0, 0, 0)
               if (goingright)
                  pt1 = Geom::Point3d.new(xstart + x * stepOverinuse, ystart + lefty  * (stepOverinuse/2), 0)
                  pt2 = Geom::Point3d.new(xstart + x * stepOverinuse, ystart + righty * (stepOverinuse/2), 0)
                  #if line from prevpt to pt crosses anything, start new line segment
                  if (prevpt != nil)
                     if (iscrossing(prevpt,pt1,aface) )
                        debugfile("iscrossing goingUP #{x} #{y}")      if (@debug)
                        r += 1
                        result[r] = []
                        debugfile(" R=#{r}")          if (@debug)
                        prevpt = nil
                     else
                        if (px > -1)
                           if ((x - px) > 1)  # do not cross many x rows, start new set instead
                              debugfile("isxrows goingUP #{x} #{y}")       if (@debug)
                              r += 1
                              result[r] = []
                              debugfile(" R=#{r}")       if (@debug)
                              prevpt = nil
                           end
                        end
                     end
                  end
                  #check that this line does not cross something, happens on sharp vertical points
                  if (iscrossing(pt1,pt2,aface))
                     cross = wherecrossing(pt1,pt2,aface)  # point where they cross
                     #going up so create new point below cross
                     np = Geom::Point3d.new(cross.x, cross.y - (stepOverinuse/2), 0)
                     result[r] << pt1
                     result[r] << np
                     #start new line
                     r += 1
                     result[r] = []
                     #create new pt1 to the right of the crossing
                     pt1 = Geom::Point3d.new(cross.x, cross.y + (stepOverinuse/2), 0)
                  end
                  
                  entities.add_cpoint(pt1)       if (@debug)
                  result[r] << pt1
                  pt = pt1
                  if (lefty != righty)
                     #pt = Geom::Point3d.new(xstart + rightx*(stepOverinuse/2), ystart + y * stepOverinuse, 0)
                     result[r] << pt2
                     pt = pt2
                     entities.add_cpoint(pt)       if (@debug)
                  else
                     puts "singleton #{x} #{y}"    if (@debug)
                  end
               else
                  #pt.x = xstart + rightx*stepOverinuse
                  #pt.y = ystart + y * stepOverinuse
                  pt1 = Geom::Point3d.new(xstart + x * stepOverinuse,ystart + righty*(stepOverinuse/2), 0)
                  pt2 = Geom::Point3d.new(xstart + x * stepOverinuse,ystart + lefty *(stepOverinuse/2), 0)
                  #if line from prevpt to pt crosses anything, start new line segment
                  if (prevpt != nil)
                     if (iscrossing(prevpt,pt1,aface) )
                        debugfile("iscrossing goingleft #{x} #{y}")     if (@debug)
                        prevpt = nil
                        r += 1
                        result[r] = []
                        debugfile("iscrossing left  R=#{r}")       if (@debug)
                     else   
                        if (px > -1)
                           if ((x - px) > 1)  # do not cross many X rows
                              debugfile("isyrows goingleft #{x} #{y}")     if (@debug)
                              r += 1
                              result[r] = []
                              prevpt = nil
                              debugfile("isyrows left R=#{r}")                         if (@debug)
                           end
                        end
                     end
                  end
                  
                  #check that this vert line does not cross something, happens on sharp horozontal points
                  if (iscrossing(pt1,pt2,aface))
                     cross = wherecrossing(pt1,pt2,aface)  # point where they cross
                     #going left so create new point to the right of cross
                     np = Geom::Point3d.new( cross.x,cross.y + stepOverinuse/2, 0)
                     result[r] << pt1
                     result[r] << np
                     #start new line on other side of gap
                     r += 1
                     result[r] = []
                     #create new pt1 to the left of the crossing
                     pt1 = Geom::Point3d.new( cross.x, cross.y - stepOverinuse/2, 0)
                  end
                  
                  result[r] << pt1
                  pt = pt1
                  entities.add_cpoint(pt1)    if (@debug)
                  #pt.x = xstart + leftx*stepOverinuse
                  if (lefty != righty)
#                     pt = Geom::Point3d.new(xstart + leftx*(stepOverinuse/2), ystart + y * stepOverinuse, 0)
                     result[r] << pt2
                     pt = pt2
                     entities.add_cpoint(pt2)    if (@debug)
                  else
                     puts "Singleton #{x} #{y}"  if (@debug)
                  end
               end
               prevpt = Geom::Point3d.new(pt.x, pt.y, 0)
               px = x
            end # if rightx valid
            x += 1
            goingright = !goingright
         end # while y
         
         #debug output
         if (@debug)
            if (someleft(@cells,xmax,ymax)  )
               debugfile("someleft #{r}")       if (@debug)
               yc = ymax
               while (yc >= 0) do
                  xc = 0
                  s = "Y #{yc}"
                  while (xc <= xmax) do
                     if (@cells[[xc,yc]])
                        s += " 1"
                     else
                        s += " 0"
                     end
                     xc += 1
                  end
                  debugfile(s)         if (@debug)
                  yc -= 1 
               end
            end
         end
         r += 1
         prevpt = nil
      end # while someleft   
@debug = false
      puts " result #{result.length}  #{result[0].length}  "   if (@debug)
      debugfile("result #{result.length}")      if (@debug)
      result.each { |rs|
         debugfile("   #{rs.length}")           if (@debug)
         }
      return result
   end

   # stepover in Y, lines along X (horizontal)
   def get_zigzag_flood_y(aface)
      result = []
#@debug = true      
      # create a 2D array to hold the rasterized shape
      # raster is on stepover boundaries and center of each square is where the zigzags will start and end.
      # set true for each centerpoint that is inside the face
      # raster 0,0 is bottom left of the shape, just outside the boundary
      bb = aface.bounds
      stepOverinuse = @bit_diameter * @stepOver
      ystart = bb.min.y - stepOverinuse / 2  # center of bottom row of cells
      yend = bb.max.y + stepOverinuse / 2 + 0.002
      
      xstart = bb.min.x - stepOverinuse / 2  # center of first column of cells
      xend = bb.max.x + stepOverinuse + 0.002  # MUST have a column after end of object else stuff gets skipped
#      if ($phoptions.use_fuzzy_pockets?)  #always uses fuzzy, gives better results
         ylen = yend - ystart - 0.002
         stepOverinuse1 = getfuzzystepover(ylen)
         xlen = xend - xstart - 0.002
         stepOverinuse2 = getfuzzystepover(xlen)
         stepOverinuse = [stepOverinuse1, stepOverinuse2].min  # always use lesser value
#      end
      debugfile("xstart #{xstart.to_mm},#{ystart.to_mm}   #{xend.to_mm},#{yend.to_mm} #{stepOverinuse.to_mm}" )   if (@debug)

      #use a hash as if it were a 2d array of cells rastered over the face
      if (@cells == nil)
         @cells = Hash.new(false)
      else
         @cells.clear
      end   
      # now loop through all cells and test to see if this point is in the face
      pt = Geom::Point3d.new(0, 0, 0)
      xmax = ymax = 0.0
#create the cell array      
      createcells(xstart,xend, ystart,yend, stepOverinuse, aface)  #creates cell has and sets @cellxmax etc
      xmax = @cellxmax
      ymax = @cellymax
      
      entities = Sketchup.active_model.active_entities  if (@debug)
      
      debugfile("xmax #{xmax} ymax #{ymax}")  if (@debug) # max cell index
#      puts "xmax #{xmax} ymax #{ymax}"
#output array for debug      
      if (@debug)
         y = ymax
         debugfile("START")   if (@debug)
         while (y >= 0) do
            x = 0
            s = "y #{y}"
            while (x <= xmax) do
               if (@cells[[x,y]])
                  s += " 1"
               else
                  s += " 0"
               end
               x += 1
            end
            debugfile(s)      if (@debug)
            y -= 1 
         end
      end

      # now create the zigzag points from the hash, search along X for first and last points
      # keep track of 'going left' or 'going right' so we can test for a line that would cross the boundary
      # if this line would cross the boundary, start a new array of points
      r = 0
      prevpt = nil
#@debug = true
      while (someleft(@cells,xmax,ymax))  # true if some cells are still not processed
         debugfile("R=#{r}")           if (@debug)
         result[r] = []
         y = 0
         goingright = true
         py = -1  # previous y used, to make sure we do not jump a Y level
         county = 0
         while (y <= ymax) do
            county += 1
            if (county > 500)
               puts " county break"
               break
            end
         
            leftx = -1
            x = 0
            while (x <= xmax) do # search to the right for a true
               if (@cells[[x,y]] == true)
                  @cells[[x,y]] = false
                  leftx = x
                  break  # found left side X val
               end
               x += 1
            end #while x
            rightx = -1
            x += 1
            if x <= xmax 
               while (x <= xmax) do  # search to the right for a false
                  if (@cells[[x,y]] == false)
                     rightx = x-1
                     break  # found right  side X val
                  end
                  @cells[[x,y]] = false                # set false after we visit
                  x += 1
               end #while x
            end
            # now we have leftx and rightx for this Y, if rightx > -1 then push these points
            debugfile("   left #{leftx} right #{rightx} y #{y}")  if (@debug)
            if (rightx > -1)
               #if px,py does not cross any face edges
#               pt1 = Geom::Point3d.new(xstart + leftx*stepOverinuse, ystart + y * stepOverinuse, 0)
#               pt2 = Geom::Point3d.new(0, 0, 0)
               if (goingright)
                  pt1 = Geom::Point3d.new(xstart + leftx*(stepOverinuse/2), ystart + y * stepOverinuse, 0)
                  pt2 = Geom::Point3d.new(xstart + rightx*(stepOverinuse/2), ystart + y * stepOverinuse, 0)
                  #if line from prevpt to pt crosses anything, start new line segment
                  if (prevpt != nil)
                     if (iscrossing(prevpt,pt1,aface) )
                        debugfile("iscrossing goingright #{x} #{y}")      if (@debug)
                        r += 1
                        result[r] = []
                        debugfile(" R=#{r}")          if (@debug)
                        prevpt = nil
                     else
                        if (py > -1)
                           if ((y - py) > 1)  # do not cross many y rows, start new set instead
                              debugfile("isyrows goingright #{x} #{y}")       if (@debug)
                              r += 1
                              result[r] = []
                              debugfile(" R=#{r}")       if (@debug)
                              prevpt = nil
                           end
                        end
                     end
                  end
                  #check that this line does not cross something, happens on sharp vertical points
                  if (iscrossing(pt1,pt2,aface))
                     cross = wherecrossing(pt1,pt2,aface)  # point where they cross
                     #going right so create new point to the left of cross
                     np = Geom::Point3d.new(cross.x - (stepOverinuse/2), cross.y, 0)
                     result[r] << pt1
                     result[r] << np
                     #start new line
                     r += 1
                     result[r] = []
                     #create new pt1 to the right of the crossing
                     pt1 = Geom::Point3d.new(cross.x + (stepOverinuse/2), cross.y, 0)
                  end
                  
                  entities.add_cpoint(pt1)       if (@debug)
                  result[r] << pt1
                  pt = pt1
                  if (leftx != rightx)
                     #pt = Geom::Point3d.new(xstart + rightx*(stepOverinuse/2), ystart + y * stepOverinuse, 0)
                     result[r] << pt2
                     pt = pt2
                     entities.add_cpoint(pt)       if (@debug)
                  else
                     puts "singleton #{x} #{y}"    if (@debug)
                  end
               else
                  #pt.x = xstart + rightx*stepOverinuse
                  #pt.y = ystart + y * stepOverinuse
                  pt1 = Geom::Point3d.new(xstart + rightx*(stepOverinuse/2), ystart + y * stepOverinuse, 0)
                  pt2 = Geom::Point3d.new(xstart + leftx*(stepOverinuse/2), ystart + y * stepOverinuse, 0)
                  #if line from prevpt to pt crosses anything, start new line segment
                  if (prevpt != nil)
                     if (iscrossing(prevpt,pt1,aface) )
                        debugfile("iscrossing goingleft #{x} #{y}")     if (@debug)
                        prevpt = nil
                        r += 1
                        result[r] = []
                        debugfile("iscrossing left  R=#{r}")       if (@debug)
                     else   
                        if (py > -1)
                           if ((y - py) > 1)  # do not cross many y rows
                              debugfile("isyrows goingleft #{x} #{y}")     if (@debug)
                              r += 1
                              result[r] = []
                              prevpt = nil
                              debugfile("isyrows left R=#{r}")                         if (@debug)
                           end
                        end
                     end
                  end
                  
                  #check that this horiz line does not cross something, happens on sharp vertical points
                  if (iscrossing(pt1,pt2,aface))
                     cross = wherecrossing(pt1,pt2,aface)  # point where they cross
                     #going left so create new point to the right of cross
                     np = Geom::Point3d.new(cross.x + stepOverinuse/2, cross.y, 0)
                     result[r] << pt1
                     result[r] << np
                     #start new line on other side of gap
                     r += 1
                     result[r] = []
                     #create new pt1 to the left of the crossing
                     pt1 = Geom::Point3d.new(cross.x - stepOverinuse/2, cross.y, 0)
                  end
                  
                  result[r] << pt1
                  pt = pt1
                  entities.add_cpoint(pt1)    if (@debug)
                  #pt.x = xstart + leftx*stepOverinuse
                  if (leftx != rightx)
#                     pt = Geom::Point3d.new(xstart + leftx*(stepOverinuse/2), ystart + y * stepOverinuse, 0)
                     result[r] << pt2
                     pt = pt2
                     entities.add_cpoint(pt2)    if (@debug)
                  else
                     puts "Singleton #{x} #{y}"  if (@debug)
                  end
               end
               prevpt = Geom::Point3d.new(pt.x, pt.y, 0)
               py = y
            end # if rightx valid
            y += 1
            goingright = !goingright
         end # while y
         
         #debug output
         if (@debug)
            if (someleft(@cells,xmax,ymax)  )
               debugfile("someleft #{r}")       if (@debug)
               yc = ymax
               while (yc >= 0) do
                  xc = 0
                  s = "Y #{yc}"
                  while (xc <= xmax) do
                     if (@cells[[xc,yc]])
                        s += " 1"
                     else
                        s += " 0"
                     end
                     xc += 1
                  end
                  debugfile(s)         if (@debug)
                  yc -= 1 
               end
            end
         end
         r += 1
         prevpt = nil
      end # while someleft   
@debug = false
      puts " result #{result.length}  #{result[0].length}  "   if (@debug)
      debugfile("result #{result.length}")      if (@debug)
      result.each { |rs|
         debugfile("   #{rs.length}")           if (@debug)
         }
      return result
   end
   
   
#-------------------------------------------------------------
   def draw_geometry(view)
      view.drawing_color = Color_pocket_cut
      #view.line_width = 3.0

      #use the flood zigzag if @flood is true  
      if (!@flood)   #normal zigzag, works well for simple faces, and works with contour
         if (@keyflag == 1) || (@keyflag == 0)
            zigzag_points = get_zigzag_points(@active_face.outer_loop) if (!@active_face.deleted?)
         else
            zigzag_points = nil
         end

         if (@keyflag == 2) || (@keyflag == 0)
            contour_points = get_contour_points(@active_face.outer_loop) if (!@active_face.deleted?)
         else
            contour_points = nil
         end
         
         if (zigzag_points != nil)
            if (zigzag_points.length >= 2)
               view.draw(GL_LINE_STRIP, zigzag_points)
            end
         end
         if (contour_points != nil)
            if (contour_points.length >= 3)
               view.draw( GL_LINE_LOOP, contour_points)
            end
         end
      else  # do floodfill only, contour must pre-exist because we need the face
         if (@keyflag == 2) # do advanced contours
            contour_points = get_contour_points_adv()       if (!@active_face.deleted?)
            if (contour_points != nil)
               if (contour_points.length >= 1)  # at least 1 array of points
                  contour_points.each { |cp|   
                     if (cp.length > 2)
                        view.draw( GL_LINE_LOOP, cp)   
                     else
                        puts "did not draw"
                     end
                     }
               end
            end
            
         else  # do zigzag
            puts "  #{@active_face.loops.length} loops"  if (@debug)
            zigzag_points = get_zigzag_flood(@active_face)      # returns array of arrays of points
            
            if (zigzag_points != nil)
               zigzag_points.each { |zpoints|
                  puts "draw #{zpoints.length}" if (@debug)
   #               debugfile("drawing #{zpoints.length}")
   #               zpoints.each { |pt|
   #                  debugfile("#{pt.x}  #{pt.y}")
   #                  }
                  view.draw(GL_LINE_STRIP, zpoints) if (zpoints.length > 1)
                  }
            sleep(1)      if (@debug)
            end
         end
      end

   end

   def create_geometry(face, view)
      #puts "create geometry"
      model = view.model
      model.start_operation("Create Pocket",true,true)
      
      if (@flood)
         if (@keyflag == 2)  # CTRL held down in flood mode
            contour_points = get_contour_points_adv()
            if (contour_points.length >= 1)
               contour_points.each { |cp|
                  cp.push(cp[0])  #close the loop for add_curve
                  #use add_curve instead of add_face so that the entire outline can be selected easily for delete
                  if PhlatScript.usePocketcw?
                     cedges = model.entities.add_curve(cp)
                  else
                     cedges = model.entities.add_curve(cp.reverse!)             # reverse points for counter clockwize loop
                  end
                  cuts = PocketCut.cut(cedges)
                  cuts.each { |cut| cut.cut_factor = compute_fold_depth_factor }
                  }
            end
         else
            zigzag_points = get_zigzag_flood(@active_face)      # returns array of arrays of points
            if (zigzag_points != nil)
               zigzag_points.each { |zpoints|
                  if (zpoints.length > 1)
                     zedges = model.entities.add_curve(zpoints)
                     cuts = PocketCut.cut(zedges)
                     cuts.each { |cut| cut.cut_factor = compute_fold_depth_factor }
                  end
                  }
               @flood = false   # turn off flood to save time during debugging, might turn this off
            end
         end
      else
         if @keyflag == 1 || @keyflag == 0
            zigzag_points = get_zigzag_points(@active_face.outer_loop)
         else
            zigzag_points = nil
         end

         if (@keyflag == 2) || (@keyflag == 0)
            contour_points = get_contour_points(@active_face.outer_loop)
         else
            contour_points = nil
         end

         if zigzag_points != nil
            if (zigzag_points.length >= 2)
               zedges = model.entities.add_curve(zigzag_points)
               cuts = PocketCut.cut(zedges)
               cuts.each { |cut| cut.cut_factor = compute_fold_depth_factor }
            end
         end
         if (contour_points != nil)
            if (contour_points.length >= 3)
               contour_points.push(contour_points[0])  #close the loop for add_curve
   #use add_curve instead of add_face so that the entire outline can be selected easily for delete
               if PhlatScript.usePocketcw?
                  cedges = model.entities.add_curve(contour_points)
               else
                  cedges = model.entities.add_curve(contour_points.reverse!)             # reverse points for counter clockwize loop
               end
               cuts = PocketCut.cut(cedges)
               cuts.each { |cut| cut.cut_factor = compute_fold_depth_factor }
            end
         end
      end

      model.commit_operation
   end

#----------------------------------------------------------------------
# generic offset points routine
#----------------------------------------------------------------------
=begin
   def get_intersect_points(lines)
      #               puts "Get intersect points"
      pts = []
      for i in 0..lines.length-1 do
         line1 = lines[i-1]      # array[-1] is equal to array[array.length-2]
         line2 = lines[i]
         pt = Geom::intersect_line_line(line1, line2)
         if (pt)
            pts << pt
         end
      end
      return pts
   end

   def get_offset_points(loop, offset)
      #               puts "get offset points"
      normal_vector = Geom::Vector3d.new(0,0,-1)
      lines = []
      r = []
      notr = []
      for edge in loop.edges
         if edge.reversed_in? @active_face then
            r.push edge
         else
            notr.push edge
         end
      end

      for edge in loop.edges
         pt1 = edge.start.position
         pt2 = edge.end.position

         line_vector = edge.line[1]
         line_vector.normalize!
         move_vector = line_vector * normal_vector
         move_vector.length = offset

         if r.length != 0 and notr.length != 0
            if edge.reversed_in? @active_face
               lines <<  [pt1.offset(move_vector.reverse), pt2.offset(move_vector.reverse)]
            else
               lines <<  [pt1.offset(move_vector), pt2.offset(move_vector)]
            end
         elsif r.length == 0
            lines <<  [pt1.offset(move_vector), pt2.offset(move_vector)]
         elsif notr.length == 0
            lines <<  [pt1.offset(move_vector.reverse), pt2.offset(move_vector.reverse)]
         end
      end #for

      points = get_intersect_points(lines)
      return points
   end
=end
#----------------------------------------------------------------------
# contour
#----------------------------------------------------------------------

def get_contour_points(loop)
#               puts "get contour points"
#   return get_offset_points(loop, -(@bit_diameter * 0.5))
   return Offset.vertices(@active_face.outer_loop.vertices, -(@bit_diameter * 0.5)).offsetPoints
end

# advanced contour points, attempt to do both 'inside the outer loop' and 'outside the inner loops'
# must return an array of loops
def get_contour_points_adv()
   result = []
   idx = 0
   result[idx] = Offset.vertices(@active_face.outer_loop.vertices, -(@bit_diameter * 0.5)).offsetPoints
#   puts "   outer #{result[idx].length}  #{result[idx]} "
   @active_face.loops.each { |lp|
      if (!lp.outer?)
         idx += 1
         result[idx] = Offset.vertices(lp.vertices, -(@bit_diameter * 0.5) ).offsetPoints   
#         puts "   inner[#{idx}] #{result[idx]}"         
      end
      }
   return result   
end


#----------------------------------------------------------------------
# zigzag
#----------------------------------------------------------------------
   # the old way, zigs along X axis
   def get_hatch_points_y(points, y)
      plane = [Geom::Point3d.new(0, y, 0), Geom::Vector3d.new(0,1,0)]
      pts = []
      for i in 0..points.length-1 do
         y1 = points[i-1].y
         y2 = points[i].y
         # very small differences in Y values will cause the following tests to 'next' when they should not
         # ie Y might display as 2.9mm but be 1e-17 different than the point.y, and y < y1 so you get no point
         # where you want a point
         # rather use signed differences
#         next if (y1 == y2)
#         next if ((y1 > y2) && ((y > y1) || (y < y2)))
#         next if ((y1 < y2) && ((y < y1) || (y > y2)))
#puts "y1 #{y1} y2 #{y2}"         
#         dif = (y1-y2).abs
         if ((y1 - y2).abs < 0.001)   #  small enough?
            next
         end
         d1 = y - y1
         d2 = y - y2
         if ((y1 > y2) && ((d1 > 0.0001) || (d2 < -0.0001)))
            next
         end
         if ((y1 < y2) && ((d1 < -0.0001) || (d2 > 0.0001)))
            next
         end

         line = [points[i-1], points[i]]
         pt = Geom::intersect_line_plane(line, plane)
#         if ((pt.x < 237.0) || (pt.x > 366.0))
#            puts "y1#{y1} y2#{y2} dif#{dif.to_mm} pt #{pt}  Y #{y.to_mm}  line #{line}"
#         end
         if (pt)
            pts << pt
         end
      end #for
      pts.uniq!
      return pts.sort{|a,b| a.x <=> b.x}
   end

   # the alternate way, zigs along Y axis - better for phlatprinters
   def get_hatch_points_x(points, x)
      plane = [Geom::Point3d.new(x, 0, 0), Geom::Vector3d.new(1,0,0)]
      pts = []
      for i in 0..points.length-1 do
         x1 = points[i-1].x
         x2 = points[i].x

#         next if (x1 == x2)
#         next if ((x1 > x2) && ((x > x1) || (x < x2)))
#         next if ((x1 < x2) && ((x < x1) || (x > x2)))
         if ((x1 - x2).abs < 0.001)
            next
         end
         d1 = x - x1
         d2 = x - x2
         if ((x1 > x2) && ((d1 > 0.0001) || (d2 < -0.0001)))  # the signs are important
            next
         end
         if ((x1 < x2) && ((d1 < -0.0001) || (d2 > 0.0001)))
            next
         end

         line = [points[i-1], points[i]]
#         puts "#{line} #{x.to_mm}"
         pt = Geom::intersect_line_plane(line, plane)
         if (pt)
            pts << pt
         end
      end #for
      pts.uniq!
      return pts.sort{|a,b| a.y <=> b.y}
   end
   
   #get the offset from the main loop for the zigzag lines
   def getOffset
      #as stepover get bigger, so the chance of missing bits around the edge inscreases, 
      #so make the offset smaller for large stepovers
      div = (@stepOver >= 0.75) ? 3 : 2
      if (@stepOver >= 0.85)
         div = 4
      end
      if @keyflag == 1
         offset = @bit_diameter * @stepOver / div
      else
         offset = @bit_diameter * 0.5 + @bit_diameter * @stepOver / div
      end
#      if @keyflag == 1   # then only zigzag
#         offset = @bit_diameter * 0.1
#      else
#         offset = @bit_diameter * 0.6  #zigzag plus outline so leave space for outline
#      end
      return offset
   end

   def get_zigzag_points_y(loop)
#      puts "get zigzag Y points #{@stepOver}"
      dir = 1
      zigzag_points = []
      offset = getOffset()
      #puts "   offset #{offset}"

#      offset_points = get_offset_points(loop, -(offset))
#      puts "old offset_points #{offset_points}"

      offset_points = Offset.vertices(@active_face.outer_loop.vertices, -(offset)).offsetPoints

#      puts "new offset_points #{offset_points}"

      bb = loop.face.bounds
      y = bb.min.y + offset + 0.0005
      
      stepOverinuse = @bit_diameter * @stepOver
      if ($phoptions.use_fuzzy_pockets?)
         if (@stepOver != 0.5)
            ylen = bb.max.y - bb.min.y - (2 * offset) - 0.002
            stepOverinuse = getfuzzystepover(ylen)
         end
      end
      yend = bb.max.y + 0.0005
      while (y < yend) do
         pts = get_hatch_points_y(offset_points, y)
         if (pts.length >= 2)
            if (dir == 1)
               zigzag_points << pts[0]
               zigzag_points << pts[1]
               dir = -1
            else
               zigzag_points << pts[1]
               zigzag_points << pts[0]
               dir = 1
            end
         end
         #puts "@stepOver #{@stepOver}  @stepover_percent #{@stepover_percent}"
         y = y + stepOverinuse
         if (stepOverinuse <= 0) # prevent infinite loop
            print "stepOver <= 0, #{@stepOver} #{@bit_diameter}"
            break;
         end
      end #while
      return zigzag_points
   end

   def get_zigzag_points_x(loop)
      #puts "get X zigzag points #{@stepOver}"
      dir = 1
      zigzag_points = []
      #if @keyflag == 1   # do only zigzag
      #   offset = @bit_diameter * 0.1
      #else
      #   offset = @bit_diameter * 0.6
      #end
      offset =  getOffset()
#      puts "offset #{offset.to_mm}"

      #offset_points = get_offset_points(loop, -(offset))
      offset_points = Offset.vertices(@active_face.outer_loop.vertices, -(offset)).offsetPoints      
      #puts "offset_points #{offset_points}"

      bb = loop.face.bounds
      x = bb.min.x + offset + 0.0005
      
      #fuzzy stepover
      stepOverinuse = @bit_diameter * @stepOver
      if ($phoptions.use_fuzzy_pockets?)
         if (@stepOver != 0.5)
            xlen = bb.max.x - bb.min.x - (2 * offset) - 0.002
            stepOverinuse = getfuzzystepover(xlen)
         end
      end
      
      xend = bb.max.x + 0.0005
      while (x < xend) do
         pts = get_hatch_points_x(offset_points, x)
#         puts "x #{x.to_mm} pts#{pts}"
         if (pts.length >= 2)
            if (dir == 1)
               zigzag_points << pts[0]
               zigzag_points << pts[1]
               dir = -1
            else
               zigzag_points << pts[1]
               zigzag_points << pts[0]
               dir = 1
            end
         end
         #puts "@stepOver #{@stepOver}  @stepover_percent #{@stepover_percent}"
         x = x + stepOverinuse
         if (stepOverinuse <= 0) # prevent infinite loop
            puts "stepOver <= 0, #{stepOverinuse} #{@bit_diameter}"
            break;
         end
      end #while
      return zigzag_points
   end
  
   
   # select between the options
   def get_zigzag_points(loop)
      if PhlatScript.pocketDirection?
         return get_zigzag_points_x(loop)  # zigs along Y - suites phlatprinter
      else
         return get_zigzag_points_y(loop)  # zigs along x - suites gantries
      end
   end
#=============================================================
   def getfuzzystepover(len)
      len = len.abs
      stepOverinuse = curstep = @bit_diameter * @stepOver
      
      steps = len / curstep
#      puts "steps #{steps} curstep #{curstep.to_mm} len #{len.to_mm}\n"
      if (@stepOver < 0.5)
         newsteps = (steps + 0.5).round   # step size gets smaller  
      else
         newsteps = (steps - 0.5).round  # step size gets bigger
      end   
      if (newsteps < 1)
#         puts " small newsteps #{newsteps}"
         newsteps = 2
      end
      newstep = len / newsteps
      newstepover = newstep / @bit_diameter
      
      while (newstepover > 1.0)  #this might never happen, but justincase
#         puts "  increasing steps #{newsteps}"
         newsteps += 1
         newstep = len / newsteps
         newstepover = newstep / @bit_diameter
      end
#      puts "   newstep #{newstep}"
      newstep = (newstep * 10000.0).floor / 10000.0   # floor to 1/10000"
      newstep = 1.mm if (newstep.abs < 0.001)
      
#      puts "    newsteps #{newsteps} newstep #{newstep.to_mm} newstepover #{newstepover}%\n"
      if (newstepover > 0)
         stepOverinuse = newstep
      end
      #puts ""
      return stepOverinuse           
   end   


   def toggle_direc_flag(model=Sketchup.active_model)
      val = model.get_attribute(Dict_name, Dict_pocket_direction, $phoptions.default_pocket_direction?)
      model.set_attribute(Dict_name, Dict_pocket_direction, !val)
   end


end #class

end #module
