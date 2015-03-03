#-----------------------------------------------------------------------------
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------
# $Id$
#-----------------------------------------------------------------------------
# Name:             phlatBone.rb
# Version:          1.10
# Description:      Makes 'rad-bone/t-bone' corners.
# Parameters:       The tool diameter.
# Usage:            Select a tool diameter first, then units - mm or decimal inches - this is saved automatically as a preference.
#                   For multi, select an inside or outside tool, click a corner of the face to bone.
#                   For single, select a single tool then click a corner of the face to bone.
#                   The edges MUST be at 90 deg - however, the 90 deg corner can now be rotated.
#                   The edges to bone MUST meet at a vertex that DOES NOT intersect other edges.
#                   Bone corners are now highlighted.
# swarfer:          Integrated with PhlatScript, if detected it will use the bit diameter+0.254.mm as the default in the dialog
#
# Menu Item :       Tool -> PhlatBone...
# Context Menu:     None
# Type:             Tool
# Date:             2011-02-17 09:28  29-08-2013
# Author:           Neil Gillies, Kwok, swarfer
# Needs:            "phlatBone.rb" to be in plugins folder plus a folder called ""phlatBone" containing ...
#                   Cursor files     "cursor_radbone.png", "cursor_tbone.png", "cursor_radboneMulti.png", "cursor_tbone_multi.png"
#                   Toolbar files    "toolDiameter.png", "radBoneMultiIn.png", "radBoneMultiOut.png", "radBoneSingle.png"
#                                    "tBoneMultiIn.png", "tBoneMultiOut.png", "tBoneSingle.png"
#                   Preferences file "phlatBone_prefs"
#-----------------------------------------------------------------------------

require 'sketchup.rb'
#require "Phlatboyz/PhlatboyzMethods.rb"
require 'Phlatboyz/utils/SketchupDirectoryUtils.rb'

module PhlatBoner

   unless file_loaded?("phlatBone.rb")

      # Toolbar Stuff...

      boneBar = UI::Toolbar.new "PhlatBone"
      $keyMsg = " : Press SHIFT key to select other edge"

      cmd1 = UI::Command.new("Tool Diameter...") { setToolDiameter }
      cmd1.large_icon = cmd1.small_icon = "phlatBone/toolDiameter.png"
      cmd1.tooltip = "Set Tool Diameter"
      cmd1.status_bar_text = "Setting Tool Diameter"
      cmd1.menu_text = "Tool Diameter"
      boneBar = boneBar.add_item cmd1

      boneBar.add_separator

      cmd2 = UI::Command.new("Rad Bone Multi Inside") { Sketchup.active_model.select_tool BoneMulti.new(1, true) }
      cmd2.large_icon = cmd2.small_icon = "phlatBone/radBoneMultiIn.png"
      cmd2.tooltip = "Rad Bone Multi Inside"
      cmd2.status_bar_text = "Multiple Inside Rad Bones"
      cmd2.menu_text = "Rad Bone"
      boneBar = boneBar.add_item cmd2

      cmd3 = UI::Command.new("Rad Bone Multi Outside") { Sketchup.active_model.select_tool BoneMulti.new(1, false) }
      cmd3.large_icon = cmd3.small_icon = "phlatBone/radBoneMultiOut.png"
      cmd3.tooltip = "Rad Bone Multi Outside"
      cmd3.status_bar_text = "Multiple Outside Rad Bones"
      cmd3.menu_text = "Rad Bone"
      boneBar = boneBar.add_item cmd3

      cmd4 = UI::Command.new("Rad Bone Single") { Sketchup.active_model.select_tool BoneSingle.new(1, true) }
      cmd4.large_icon = cmd4.small_icon = "phlatBone/radBoneSingle.png"
      cmd4.tooltip = "Rad Bone Single"
      cmd4.status_bar_text = "Single Rad Bone"
      cmd4.menu_text = "Rad Bone"
      boneBar = boneBar.add_item cmd4

      boneBar.add_separator

      cmd5 = UI::Command.new("T Bone Multi Inside") { Sketchup.active_model.select_tool BoneMulti.new(2, true) }
      cmd5.large_icon = cmd5.small_icon = "phlatBone/tBoneMultiIn.png"
      cmd5.tooltip = "T Bone Multi Inside"
      cmd5.status_bar_text = "Multiple Inside T Bones"
      cmd5.menu_text = "T Bone"
      boneBar = boneBar.add_item cmd5

      cmd6 = UI::Command.new("T Bone Multi Outside") { Sketchup.active_model.select_tool BoneMulti.new(2, false) }
      cmd6.large_icon = cmd6.small_icon = "phlatBone/tBoneMultiOut.png"
      cmd6.tooltip = "T Bone Multi Outside"
      cmd6.status_bar_text = "Multiple Outside T Bones"
      cmd6.menu_text = "T Bones"
      boneBar = boneBar.add_item cmd6

      cmd7 = UI::Command.new("T Bone Single") { Sketchup.active_model.select_tool BoneSingle.new(2, false) }
      cmd7.large_icon = cmd7.small_icon = "phlatBone/tBoneSingle.png"
      cmd7.tooltip = "T Bone Single"
      cmd7.status_bar_text = "Single T Bone"
      cmd7.menu_text = "T Bone"
      boneBar = boneBar.add_item cmd7

      boneBar.show

      # Menu Stuff...
      add_separator_to_menu("Tools")
      # Add item to the Tools menu
      subMenu=UI.menu("Tools").add_submenu("PhlatBone") { }
      # Add sub-items to the PhlatBone menu
      subMenu.add_item cmd1
      subMenu.add_item cmd2
      subMenu.add_item cmd3
      subMenu.add_item cmd4
      subMenu.add_item cmd5
      subMenu.add_item cmd6
      subMenu.add_item cmd7
   end #unless

file_loaded("phlatBone.rb")

# Global Defaults - if all else fails :-)
#-----------------------------------------------------------------------------
$PhlatBoner_toolDiameter = 3.2  # default value
$PhlatBoner_units = "mm"    # "mm" or "inches"
#-----------------------------------------------------------------------------

# retrieve a constant value from the str, observing units of measurement
#   def self.getvalue(str)
#      value = 0
#      if str
#         if str.index('.mm')
#            value = str.gsub('.mm','').to_f / 25.4    # to_l does not get it right when drawing is metric
#            #puts "mm to inch #{value}"
#         else
#            if str.index('.inch')
#               value = str.gsub('.inch','').to_f
#            else
#               value = str.to_f
#            end
#         end
#      end
#      return value
#   end

#   def self.conformat(inp)
#      #replace mm with .mm
#      if PhlatScript.isMetric
#         out = inp.to_mm.to_s + '.mm'
#      else
#	 #replace trailing " with .inch
#	 out = inp.to_inch.to_s + '.inch'
#      end
#      out = out.gsub("~ ",'')
#      return out
#   end #


def self.getSavePrefs(reading)
   path = PhlatScript.toolsProfilesPath() #by using this path we prevent folder permission problems when writing the file
   if not File.exist?(path)
      Dir.mkdir(path)
   end
   #   theFile = "#{Sketchup.find_support_file("Plugins")}/phlatBone/phlatBone_prefs"
   theFile = File.join(path , 'phlatBone_prefs')
   if File::exists?(theFile)
      if reading
         # Read to a prefsArray
         prefsData = IO.readlines(theFile)
         $PhlatBoner_toolDiameter = prefsData[0].to_f
         $PhlatBoner_units = prefsData[1].chomp
         puts "read #{$PhlatBoner_toolDiameter}  #{$PhlatBoner_units}"
      else
         # Write prefs
         File.open(theFile, "w") { |f|
            puts "write tool diam #{$PhlatBoner_toolDiameter}"
            f.puts( $PhlatBoner_toolDiameter)
            f.puts($PhlatBoner_units)
            }
      end
   else
      # Prefs file missing
      # UI.messagebox("Can't find the prefs file for PhlatBone, I'm creating a new one.")
      # Write default to the new prefs
      puts "creating new file"
      if !File::exists?(path)    # try to create it if it does not exist, for SK8?
         Dir.mkdir(path)
      end
      File.open(theFile, "w") {|f|
         f.puts( $PhlatBoner_toolDiameter )
         f.puts($PhlatBoner_units)
         }
   end
end

#--- swarfer - integrate with phlatscript -- add 0.254 0.01" automatically to prevent missed inside corners

def self.cangetdiam?
   if Sketchup.version.split('.')[0].to_i < 8 #sketchup7 does not have .extensions so assume we can load from phlatscript
      return true
   else
      return Sketchup.extensions['Phlatboyz Tools']
   end
end

getSavePrefs(true) # Load the prefs file at startup

def self.setToolDiameter
   if (self.cangetdiam?)
      $PhlatBoner_toolDiameter = PhlatScript.bitDiameter.to_mm + 0.255
      if PhlatScript.isMetric
         $PhlatBoner_units = 'mm'
      else
         $PhlatBoner_units = 'inches'
         $PhlatBoner_toolDiameter = $PhlatBoner_toolDiameter / 25.4
      end
      $PhlatBoner_toolDiameter = ($PhlatBoner_toolDiameter.to_f * 1000).round() / 1000.0

      # puts "tool diam from phlatscript = #{$PhlatBoner_toolDiameter}mm"
      phstr = " (PhlatScript default) "
   else
      phstr = ""
   end
   prompts = ["Tool Diameter?" + phstr,"Units? "]
   defaults = ["#{$PhlatBoner_toolDiameter}","#{$PhlatBoner_units}"]
   list = "","mm|inches"
   input = UI.inputbox(prompts, defaults, list, "Phlatbone Tool #{phstr}")

   unless input==false # Cancelled
      $PhlatBoner_toolDiameter = input[0].to_f
      $PhlatBoner_units = input[1]
      getSavePrefs(false) # Write the prefs
   end

   Sketchup.active_model.select_tool nil # Return control to select tool
end

#-----------------------------------------------------------------------------

module NorthSouthEastWest

   def nsew(v, q)      # v = picked vertex, q = quadrant vector

      @centre = v.position
      @normal = Geom::Vector3d.new 0,0,1  # normal vector

      if @boneType == 1 # Rad bone
	 offset = Math::sqrt(@toolRadius**2/2)
	 @centre = offsetPoint(@centre, @toolRadius, q)   # point, offset distance, vector direction
	 @vector2 = rotateVector(q, @normal, 135)   # vector, normal, angle in degrees

	 # Create arcs
	 if !@preview
	    arc = makeArc3
	    deleteSubtention(arc)
	    arc.each {|e|		# swarfer - true arcs are very small and generate errors in the Gcode, explode em
	       e.explode_curve
	    }
	    @vector2 = rotateVector(q, @normal, 45)
	    arc = makeArc3
	    deleteSubtention(arc)
	    arc.each {|e|
	       e.explode_curve
	    }
	 else
	    previewArc(45, 135)
	    @vector2 = rotateVector(q, @normal, 45)
	    previewArc(45, 135)
	 end
      end

      if @boneType==2 # T Bone
	 @centre = offsetPoint(@centre, @toolRadius, tb_Cdir(q))
	 @vector2 = rotateVector(q, @normal, tb_v2_angle(q))

	 # Create arc
	 if !@preview
	    arc = makeArc
	    deleteSubtention(arc)
	    arc.each {|e|
	       e.explode_curve
	    }
	 else
	    previewArc(0, 180)
	 end
      end

      @preview = false
      faceRepair(v)
   end


    #-----------------------------------------------------------------------------
#swarfer, set to 6 segments per arc, makes cut generation better
   def makeArc
      @entities.add_arc @centre, @vector2, @normal, @toolRadius, 0, Math::PI, 6
   end

   def makeArc3
      @entities.add_arc @centre, @vector2, @normal, @toolRadius, Math::PI/4, (Math::PI/4)*3, 4
   end

   def previewArc(angle1, angle2)          # draw arc for preview  (start angle, end angle in degrees)
      arc = []
      @vector2.normalize!
      v = Geom::Vector3d.linear_combination(0, @vector2, @toolRadius, @vector2)
      v = rotateVector(v, @normal, angle1)
      pt1 = @centre.offset v
      arc.push pt1
      n = ((angle2-angle1)/7)
      for i in 1..n do
	 v = rotateVector(v, @normal, 7)
	 pt2 = @centre.offset v
	 arc.push pt2
      end
      Sketchup.active_model.active_view.draw_polyline arc
   end

   def faceRepair(aVertex)
      @aVertexEdges=aVertex.edges
      @aVertexEdges[0].find_faces
   end

   def offsetPoint(point, offset, vector)  # offset is distance, vector is direction
      vector.normalize!
      newVector = Geom::Vector3d.linear_combination(0, vector, offset, vector)
      newpoint = point.offset newVector
   end

   def rotateVector(vector, normal, angle)  # normal = normal vector, angle = angle in degrees
      point = Geom::Point3d.new
      tr = Geom::Transformation.rotation(point, normal, angle.degrees)
      newVector = vector.transform tr
   end

   def deleteSubtention(arc)       # delete edge under arc
      aEdge1 = arc[0]; aEdgeLast = arc[arc.length - 1]
      aVer1 = aEdge1.start; aVer2 = aEdgeLast.end;
      edges = aVer1.edges
      edges.each do |e|
	 if (((e.start == aVer1) or (e.start == aVer2)) and ((e.end == aVer1) or (e.end == aVer2))) then
	    e.erase!
	 end
      end
   end

    def tb_Cdir(q)      # direction to move centre for Tbone
        if forwardDiag?(q) then a = -45 else a = 45 end
        if @tBoneTop == false then a = -a end
        c = rotateVector(q, @normal, a)
    end

    def forwardDiag?(q)     # check if corner is on forward diagonal (ie southwest or northeast)
        if (((q.x > 0) and (q.y > 0)) or ((q.x < 0) and (q.y < 0))) then fd = true else fd = false end
        return fd
    end

    def tb_v2_angle(q)      # angle to start Tbone
        if @tBoneTop == true
            if forwardDiag?(q) then a = 135 else a = 45 end
        elsif forwardDiag?(q) then a = 45 else a = 135
        end
        return a
    end

end # NorthSouthEastWest

#-----------------------------------------------------------------------------

class BoneMulti

   include NorthSouthEastWest

   def initialize(type, boneDirection)
      @boneType = type                                    # 1 = rad-bone,   2 = T-bone
      @boneDirection = boneDirection                      # true = inside bone
      @tBoneTop = false                                   # Default T-Bone direction false=horiz
      if $PhlatBoner_units=="mm"
	      @toolDiameter = $PhlatBoner_toolDiameter/25.4 # Convert to internal inches
      else
	      @toolDiameter = $PhlatBoner_toolDiameter
      end
      @toolRadius = @toolDiameter/2
      @model = Sketchup.active_model
      @entities = @model.active_entities
      @ip1 = nil
      @xdown = 0
      @ydown = 0

      # Cursor data
      cursor_path = Sketchup.find_support_file("cursor_radbone.png", "Plugins/phlatBone/")
      if cursor_path
	      @radboneCursor = UI.create_cursor(cursor_path, 2, 15)
      end

      cursor_path = Sketchup.find_support_file("cursor_tbone.png", "Plugins/phlatBone/")
      if cursor_path
	      @tboneCursor = UI.create_cursor(cursor_path, 2, 15)
      end

      cursor_path = Sketchup.find_support_file("cursor_radbone_multi.png", "Plugins/phlatBone/")
      if cursor_path
	      @radboneMultiCursor = UI.create_cursor(cursor_path, 2, 15)
      end

      cursor_path = Sketchup.find_support_file("cursor_tbone_multi.png", "Plugins/phlatBone/")
      if cursor_path
	      @tboneMultiCursor = UI.create_cursor(cursor_path, 2, 15)
      end

      if @boneType==1
	      UI.set_cursor(@radboneMultiCursor)
      else
	      UI.set_cursor(@tboneMultiCursor)
      end
   end

   def activate
      @ip1 = Sketchup::InputPoint.new
      @ip = Sketchup::InputPoint.new
      @drawn = false
      self.reset(nil)
   end # activate

   def deactivate(view)
      view.invalidate if @drawn
   end

   def onMouseMove(flags, x, y, view)
      if( @state == 0 )
	 @ip.pick view, x, y
	 if( @ip != @ip1 )
	    view.invalidate if( @ip.display? or @ip1.display? )
	    @ip1.copy! @ip
	    # Set tooltip
	    view.tooltip = @ip1.tooltip
	    if @boneType==1
	       UI.set_cursor(@radboneMultiCursor)
	     else
	       UI.set_cursor(@tboneMultiCursor)
	    end
	 end
      end
   end

   def onLButtonDown(flags, x, y, view)
      if( @state == 0 )
	 @ip1.pick view, x, y
	 if( @ip1.valid? )
	    @state = 1
	    result = Sketchup.set_status_text "Select point for auto boning", SB_PROMPT
	    @xdown = x
	    @ydown = y
	 end
      end
      # Clear inference lock (if any)
      view.lock_inference
   end

   def onLButtonUp(flags, x, y, view)
      unless @ip1.vertex==nil
	 @noOfEdges=@ip1.vertex.edges.length
	 if @noOfEdges==2
	    @model.start_operation "Create auto bones"
	    create_bones(false)
	    @model.commit_operation
	 end
      end
      self.reset(view)
   end

   # Shift Key
   def onKeyDown(key, repeat, flags, view)
      if( key == CONSTRAIN_MODIFIER_KEY )
         @tBoneTop=true
         view.invalidate
      end
   end

# Shift Key Up
   def onKeyUp(key, repeat, flags, view)
      if( key == CONSTRAIN_MODIFIER_KEY )
         @tBoneTop=false
         view.invalidate
      end
   end

   def reset(view)
      @state = 0

      # Status bar prompt
      result = Sketchup.set_status_text "Select corner for auto boning" + $keyMsg, SB_PROMPT

      # Clear InputPoints
      @ip1.clear

      if( view )
         view.tooltip = nil
         view.invalidate if @drawn
      end
      @drawn = false
   end

def resume(view)
   end

   def draw(view)
      unless @ip1==nil
	 if( @ip1.valid? )
	    if( @ip1.display? )
	       @ip1.draw(view)
	       @drawn = true
	    end
	 end
      end
      view.drawing_color = "red"
      view.line_width = 2
      v = @ip1.vertex
      if v
         create_bones(true)
      end
   end

   def create_bones(preview)
      savePreview = preview
      # Where v is the corner vertex ...
      v=@ip1.vertex

      # Faces only
      faces=v.faces

      if faces.length > 1
	 # Is v inside the other poly? (no border hits)
	 if Geom.point_in_polygon_2D(v, faces[0].outer_loop.vertices, false)==true and Geom.point_in_polygon_2D(v, faces[1].outer_loop.vertices, false)==false
	    @@myVertices=faces[1].outer_loop.vertices
	    theFace=faces[1]
	 else
	    @@myVertices=faces[0].outer_loop.vertices
	    theFace=faces[0]
	 end
      else
	 @@myVertices=faces[0].outer_loop.vertices
	 theFace=faces[0]
      end

      @@myVertices = theFace.outer_loop.vertices

      # inside=reverse=true
      if @boneDirection==true
	 @@myVertices.reverse!
      end

      vLength=@@myVertices.length

      for n in 1...vLength-1
	 # Edges attached to each vertex
	 e1 = @@myVertices[n].edges[0] # previous edge - CCW
	 e2 = @@myVertices[n].edges[1] # next edge - CCW

	 # Set unit vector
	 @@u1 = (e1.other_vertex @@myVertices[n]).position - @@myVertices[n].position
	 @@u1.normalize!
	 @@u2 = (e2.other_vertex @@myVertices[n]).position - @@myVertices[n].position
	 @@u2.normalize!

	 currentVertex=@@myVertices[n]
	 previousVertex=@@myVertices[n-1]
	 nextVertex=@@myVertices[n+1]

	 theDirection=direction(previousVertex,currentVertex,nextVertex)

	 @preview = savePreview
	 plotBone(n,theDirection)
      end

      # Roll-over to edges attached to first & last vertices

      e1 = @@myVertices[0].edges[0] # previous edge - CCW
      e2 = @@myVertices[0].edges[1] # next edge - CCW

      # Set unit vector
      @@u1 = (e1.other_vertex @@myVertices[0]).position - @@myVertices[0].position
      @@u1.normalize!
      @@u2 = (e2.other_vertex @@myVertices[0]).position - @@myVertices[0].position
      @@u2.normalize!

      currentVertex=@@myVertices[0]
      previousVertex=@@myVertices[vLength-1]
      nextVertex=@@myVertices[1]

      theDirection=direction(previousVertex,currentVertex,nextVertex)

      @preview = savePreview
      plotBone(0,theDirection)

      e1 = @@myVertices[vLength-1].edges[0] # previous edge - CCW
      e2 = @@myVertices[vLength-1].edges[1] # next edge - CCW

      # Set unit vector
      @@u1 = (e1.other_vertex @@myVertices[vLength-1]).position - @@myVertices[vLength-1].position
      @@u1.normalize!
      @@u2 = (e2.other_vertex @@myVertices[vLength-1]).position - @@myVertices[vLength-1].position
      @@u2.normalize!

      currentVertex=@@myVertices[vLength-1]
      previousVertex=@@myVertices[vLength-2]
      nextVertex=@@myVertices[0]

      theDirection=direction(previousVertex,currentVertex,nextVertex)

      @preview = savePreview
      plotBone(vLength-1,theDirection)
      #-----------------------------------------------------------------------------
   end

   #-----------------------------------------------------------------------------

   def plotBone(n,theDirection)
      if theDirection < 0         # inside corner when CCW
	 quadrant = Geom::Vector3d.linear_combination(0.5, @@u1, 0.5, @@u2)
	 if @@u1.to_a.dot(@@u2).abs < 0.000001 then
	    nsew(@@myVertices[n], quadrant)
	 end
      end
   end

   #-----------------------------------------------------------------------------

   def direction(pV,cV,nV)         # find corner turn direction, returns cross product, neg is inside assuming CCW
      pP = pV.position
      cP = cV.position
      nP = nV.position

      u1 = [(cP.x - pP.x), (cP.y - pP.y), (cP.z - pP.z)]      # pevious vector
      u2 = [(nP.x - cP.x), (nP.y - cP.y), (nP.z - cP.z)]      # next vector

      return u1.cross(u2).z
   end


end # BoneMulti

#-----------------------------------------------------------------------------

class BoneSingle

   include NorthSouthEastWest

   def initialize(type, boneDirection)
      @boneType = type                                    # 1 = rad-bone,   2 = T-bone
      @boneDirection = boneDirection                      # true = inside bone
      @tBoneTop = false                                   # Default T-Bone direction false=horiz
      if $PhlatBoner_units=="mm"
	 @toolDiameter = $PhlatBoner_toolDiameter/25.4 # Convert to internal inches
      else
	 @toolDiameter = $PhlatBoner_toolDiameter
      end
      @toolRadius = @toolDiameter/2
      @model = Sketchup.active_model
      @entities = @model.active_entities
      @ip1 = nil
      @xdown = 0
      @ydown = 0

      # Cursor data
      cursor_path = Sketchup.find_support_file("cursor_radbone.png", "Plugins/phlatBone/")
      if cursor_path
	 @radboneCursor = UI.create_cursor(cursor_path, 2, 15)
      end

      cursor_path = Sketchup.find_support_file("cursor_tbone.png", "Plugins/phlatBone/")
      if cursor_path
         @tboneCursor = UI.create_cursor(cursor_path, 2, 15)
      end

      if @boneType==1
	 UI.set_cursor(@radboneCursor)
      else
	 UI.set_cursor(@tboneCursor)
      end
   end

   def activate
      @ip1 = Sketchup::InputPoint.new
      @ip = Sketchup::InputPoint.new
      @drawn = false
      self.reset(nil)
   end

   def deactivate(view)
      view.invalidate if @drawn
   end

   def onMouseMove(flags, x, y, view)
      if( @state == 0 )
	 @ip.pick view, x, y
	 if( @ip != @ip1 )
	    view.invalidate if( @ip.display? or @ip1.display? )
	    @ip1.copy! @ip
	    # Set tooltip
	    view.tooltip = @ip1.tooltip
	    if @boneType==1
	       UI.set_cursor(@radboneCursor)
	    else
	       UI.set_cursor(@tboneCursor)
	    end
	 end
      end
   end

   def onLButtonDown(flags, x, y, view)
      if( @state == 0 )
	 @ip1.pick view, x, y
	 if( @ip1.valid? )
	    @state = 1
	    result = Sketchup.set_status_text "Select corner for boning" + $keyMsg, SB_PROMPT
	    @xdown = x
	    @ydown = y
	 end
      end
      # Clear inference lock (if any)
      view.lock_inference
   end

   def onLButtonUp(flags, x, y, view)
      unless @ip1.vertex==nil
	 @noOfEdges=@ip1.vertex.edges.length
	 if @noOfEdges==2
	    @model.start_operation "Create Bone Corner"
	    create_bones(false)
	    @model.commit_operation
	 end
      end
      self.reset(view)
   end

    # Shift Key
   def onKeyDown(key, repeat, flags, view)
      if( key == CONSTRAIN_MODIFIER_KEY )
	 @tBoneTop=true
	 view.invalidate
      end
   end

    # Shift Key Up
   def onKeyUp(key, repeat, flags, view)
      if( key == CONSTRAIN_MODIFIER_KEY )
	 @tBoneTop=false
	 view.invalidate
      end
   end

   def reset(view)
      @state = 0

      # Status bar prompt
      result = Sketchup.set_status_text "Select corner for boning" + $keyMsg, SB_PROMPT

      # Clear InputPoints
      @ip1.clear

      if( view )
	 view.tooltip = nil
	 view.invalidate if @drawn
      end
      @drawn = false
   end

   def resume(view)
   end

   def draw(view)
      unless @ip1==nil
	 if( @ip1.valid? )
	    if( @ip1.display? )
	       @ip1.draw(view)
	       @drawn = true
	    end
	 end
      end
      view.drawing_color = "red"
      view.line_width = 2
      v = @ip1.vertex
      if v
	 create_bones(true)
      end
   end

   def create_bones(preview)
      @preview = preview
      # Where v is a vertex ...
      v=@ip1.vertex

      # Adjacent edges
      e1 = v.edges[0]
      e2 = v.edges[1]

      # Set unit vector length to 1 in place
      u1 = (e1.other_vertex v).position - v.position
      u1.normalize!
      u2 = (e2.other_vertex v).position - v.position
      u2.normalize!

      quadrant = Geom::Vector3d.linear_combination(0.5, u1, 0.5, u2)

   # Single bones now works for any right angle, instead of just those aligned with the primary axis
      if u1.to_a.dot(u2).abs < 0.000001 then
	 nsew(v, quadrant)
      end
   end

        #-----------------------------------------------------------------------------

end # RadBoneSingle

end # module PhlatBoner
