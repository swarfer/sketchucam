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
# $Id: PhPocketTool.rb 86 2014-02-03 13:55:38Z swarfer $

require 'sketchup.rb'
require 'Phlatboyz/Constants.rb'
require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/tools/CenterLineTool.rb'
require 'Phlatboyz/Tools/PhPocketCut.rb'

module PhlatScript

   class PocketTool < CenterLineTool

   def initialize
      @active_face = nil
      @bit_diameter = PhlatScript.bitDiameter
      #puts "bit diameter #{@bit_diameter.to_mm}mm"
      @ip = nil

      # set this to change zigzag setover, less for hard material, more for soft
      @setover_percent = PhlatScript.stepover
      #               puts "setover percent #{@setover_percent}%"
      if (@setover_percent < 100)
         @setOver = @setover_percent / 100
      else
         @setOver = 0.5
         @setover_percent = 50
      end
      @keyflag = 0

      @tooltype   = 3
      @tooltip    = PhlatScript.getString("Pocket Face")
      @largeIcon  = "images/pockettool_large.png"
      @smallIcon  = "images/pockettool_small.png"
      @largeIcon  = "images/Pocket_large.png"
      @smallIcon  = "images/Pocket_small.png"
      @statusText = PhlatScript.getString("Pocket Face")
      @menuItem   = PhlatScript.getString("Pocket")
      @menuText   = PhlatScript.getString("Pocket a face")
      #PhlatScript.getString("GCode")
      #	 @statusmsg = "Pockettool: [shift] for only zigzag [ctrl] for only boundary, setover is #{@setover_percent}%"
      @statusmsgBase  = "Pockettool: [shift] for only Zigzag [ctrl] for only boundary : [END] to toggle zigzag direction : "
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
      if (face)
         if (face.loops.length != 1)
            face = nil
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
      @setover_percent = PhlatScript.stepover
      #puts "activate setover percent #{@setover_percent}%"
      if @setover_percent <= 100
         @setOver = @setover_percent.to_f / 100
      else
         @setover_percent = 50.to_f
         @setOver = 0.5.to_f
      end
      #puts "activate setOver = #{@setOver}  @setover_percent #{@setover_percent}"
      @statusmsg = @statusmsgBase + "StepOver is #{@setover_percent}%"
      Sketchup::set_status_text(@statusmsg, SB_PROMPT)
      self.reset(nil)
   end

   def draw_geometry(view)
      view.drawing_color = Color_pocket_cut
      #view.line_width = 3.0
      if (@keyflag == 1) || (@keyflag == 0)
         zigzag_points = get_zigzag_points(@active_face.outer_loop)
      else
         zigzag_points = nil
      end

      if (@keyflag == 2) || (@keyflag == 0)
         contour_points = get_contour_points(@active_face.outer_loop)
      else
         contour_points = nil
      end

      if (zigzag_points != nil)
         if (zigzag_points.length >= 2)
            view.draw GL_LINE_STRIP, zigzag_points
         end
      end
      if (contour_points != nil)
         if (contour_points.length >= 3)
            view.draw GL_LINE_LOOP, contour_points
         end
      end
   end

   def create_geometry(face, view)
      #puts "create geometry"
      model = view.model
      model.start_operation "Creating Pocket"

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
            # reverse points for counter clockwize loop
            if PhlatScript.usePocketcw?
#               print "pocket CW"
               cface = model.entities.add_face(contour_points)
            else
#               puts "pocket CCW"
               cface = model.entities.add_face(contour_points.reverse!)
            end
            
            cedges = cface.edges
            cuts = PocketCut.cut(cedges)
            cuts.each { |cut| cut.cut_factor = compute_fold_depth_factor }
         end
      end

      model.commit_operation
   end

#----------------------------------------------------------------------
# generic offset points routine
#----------------------------------------------------------------------

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

#----------------------------------------------------------------------
# contour
#----------------------------------------------------------------------

def get_contour_points(loop)
#               puts "get contour points"
   return get_offset_points(loop, -(@bit_diameter * 0.5))
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
         next if (y1 == y2)
         next if ((y1 > y2) && ((y > y1) || (y < y2)))
         next if ((y1 < y2) && ((y < y1) || (y > y2)))

         line = [points[i-1], points[i]]
         pt = Geom::intersect_line_plane(line, plane)
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
         next if (x1 == x2)
         next if ((x1 > x2) && ((x > x1) || (x < x2)))
         next if ((x1 < x2) && ((x < x1) || (x > x2)))

         line = [points[i-1], points[i]]
         pt = Geom::intersect_line_plane(line, plane)
         if (pt)
            pts << pt
         end
      end #for
      pts.uniq!
      return pts.sort{|a,b| a.y <=> b.y}
   end
   
   def get_zigzag_points_y(loop)
      #puts "get zigzag points #{@setOver}"
      dir = 1
      zigzag_points = []
      if @keyflag == 1
         offset = @bit_diameter * 0.1
      else
         offset = @bit_diameter * 0.6
      end
      #puts "   offset #{offset}"

      offset_points = get_offset_points(loop, -(offset))

      #puts "offset_points #{offset_points}"

      bb = loop.face.bounds
      if @keyflag == 0
         y = bb.min.y + offset
      else
         y = bb.min.y + offset
      end

      while (y < bb.max.y) do
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
         #puts "@setover #{@setOver}  @setover_percent #{@setover_percent}"
         y = y + @bit_diameter * @setOver
         if (@setOver <= 0) # prevent infinite loop
            puts "setOver <= 0, #{@setOver} #{@bit_diameter}"
            break;
            #code
         end
      end #while
      return zigzag_points
   end

   # select between the options   
   def get_zigzag_points(loop)   
      if PhlatScript.PocketDirection?
         return get_zigzag_points_x(loop)  # zigs along Y - suites phlatprinter
      else
         return get_zigzag_points_y(loop)  # zigs along x - suites gantries
      end
   end
   
def get_zigzag_points_x(loop)
      #puts "get zigzag points #{@setOver}"
      dir = 1
      zigzag_points = []
      if @keyflag == 1
         offset = @bit_diameter * 0.1
      else
         offset = @bit_diameter * 0.6
      end
      #puts "   offset #{offset}"

      offset_points = get_offset_points(loop, -(offset))

      #puts "offset_points #{offset_points}"

      bb = loop.face.bounds
      if @keyflag == 0
         x = bb.min.x + offset
      else
         x = bb.min.x + offset
      end
      while (x < bb.max.x) do
         pts = get_hatch_points_x(offset_points, x)
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
         #puts "@setover #{@setOver}  @setover_percent #{@setover_percent}"
         x = x + @bit_diameter * @setOver
         if (@setOver <= 0) # prevent infinite loop
            puts "setOver <= 0, #{@setOver} #{@bit_diameter}"
            break;
            #code
         end
      end #while
      return zigzag_points
   end

   def toggle_direc_flag(model=Sketchup.active_model)
      val = model.get_attribute(Dict_name, Dict_pocket_direction, Default_pocket_direction)
      model.set_attribute(Dict_name, Dict_pocket_direction, !val)
   end
   

end #class

end #module
