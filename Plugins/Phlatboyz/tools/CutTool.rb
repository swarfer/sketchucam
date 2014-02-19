
require 'sketchup.rb'
require 'Phlatboyz/Constants.rb'
require 'Phlatboyz/PhlatEdge.rb'
require 'Phlatboyz/PhlatOffset.rb'
require 'Phlatboyz/tools/OffsetCut.rb'

module PhlatScript

  class CutTool < PhlatTool
    @switch_edge_side = false
    @preview_pts = nil
    @preview_face = false

    def initialize
      super()
      @tooltype = (PB_MENU_MENU | PB_MENU_TOOLBAR | PB_MENU_CONTEXT)
      @@N = 0
      @active_face = nil
      @bit_diameter = Sketchup.active_model.get_attribute Dict_name, Dict_bit_diameter, Default_bit_diameter
    end

    def activate
      super
      @bit_diameter = Sketchup.active_model.get_attribute Dict_name, Dict_bit_diameter, Default_bit_diameter
    end

    def onContextMenu(menuItem)
      cut_class.cut(Sketchup.active_model.selection) 
    end

    def onMouseMove(flags, x, y, view)
      @ip.pick view, x, y
      view.invalidate 
    end

    def onLButtonDown(flags, x, y, view)
      cut_face(@preview_face, self.offset) if(@preview_face)
      self.reset(view)
      view.lock_inference
    end

    def calcPreviewPoints(inputpoint, force=false)
      cur_face = activeFaceFromInputPoint(inputpoint)
      if (cur_face.nil?)
        @preview_face = @preview_pts = nil
      else
        if (cur_face != @preview_face) || (force)
          @preview_face = cur_face
          @preview_pts = Offset.vertices(cur_face.outer_loop.vertices, self.offset).offsetPoints
        end
      end
      return (!@preview_pts.nil?)
    end

    def onKeyDown(key, repeat, flags, view)
      if key == VK_SHIFT
        @switch_edge_side = true
        @preview_face = nil
        view.invalidate
      elsif key == VK_END   # select next face, when on edge                       #78 # N key
        @@N += 1
        view.invalidate
      end
    end

    def onKeyUp(key, repeat, flags, view)
      if key == VK_SHIFT
        @switch_edge_side = false
        @preview_face = nil
        view.invalidate
      end
    end
    
    def draw(view)
      self.calcPreviewPoints(@ip)
      OffsetCut.preview(view, @preview_pts) if @preview_pts
    end

    def activeFaceFromInputPoint(in_inputPoint)
      #Sketchup::set_status_text "active N="+@N.to_s, SB_VCB_LABEL
      face = nil
      edge_from_input_point = in_inputPoint.edge
      face_from_input_point = in_inputPoint.face
      
      # check edge for non-phlatboyz edge
      if edge_from_input_point and not (edge_from_input_point.phlatedge?)
        faces = edge_from_input_point.faces
        if(faces)
          face = faces[@@N % faces.length] if faces.length != 0
        end
      elsif face_from_input_point
        edges = face_from_input_point.edges
        edges_are_phlatboyz = false
        edges.each do | edge |
          edges_are_phlatboyz = (edges_are_phlatboyz or (edge.phlatedge?))
        end
        if not edges_are_phlatboyz
          face = face_from_input_point
        end
      end
      return face
    end

    def offset
      @switch_edge_side ? -offset_distance : offset_distance
    end

    def statusText
      return "Select face.    [Shift] to invert offset.    [End] to select next face, when on edge."
    end

    private

    def cut_face(face, dist=0)
      Sketchup.active_model.start_operation "Creating Offset Face", true
      new_edges=[] # holds all the new edges created throughout
      cur_pt = nil
      last_pt = nil
      verts = face.outer_loop.vertices

      lav = Offset.new
      lav.load(verts)
      lav.process(dist)
      lav.each { |node|
        ne = (face.parent.entities.add_edges node.prev.data.bisector[1], node.data.bisector[1])
        next if ne.nil?
        new_edges += ne
        phlatcuts = cut_class.cut([ne[0]])

        e_last = node.data.ea
        if ((!e_last.nil?) && (!e_last.curve.nil?) && (e_last.curve.kind_of? Sketchup::ArcCurve))
          c = e_last.curve

          pt1 = c.first_edge.vertices.first.position
          pt2 = c.last_edge.vertices.last.position
          if pt1 == pt2 then #it's a circle
            g3 = false
          else
            pt3 = Geom::Point3d.new [((pt1.x+pt2.x)/2), ((pt1.y+pt2.y)/2), 0]
            g3 = !(Geom.point_in_polygon_2D(pt3, face.outer_loop.vertices, false))
          end
          phlatcuts.each { |phlatcut| phlatcut.define_arc((c.radius + dist), (c.end_angle - c.start_angle), g3) }
        end
      }
      ret_f = nil
      new_edges.each { |e| e.find_faces }
      if new_edges.length > 0
        new_edges.first.faces.each { |f|
          ret_f = f if (f.outer_loop.edges.include? new_edges.first)
        }
      end
      if (ret_f)
        Sketchup.active_model.start_operation "Setting face material", true, false
        ret_f.material = "Hole"
        ret_f.back_material = "Hole"
        Sketchup.active_model.commit_operation
        return ret_f.outer_loop.edges
      else
        return new_edges
      end
    end

  end

  class InsideCutTool < CutTool
    def getContextMenuItems
      return PhlatScript.getString("Inside Edge")
    end

    def offset_distance
      return -@bit_diameter/2
    end

    def cut_class
      return InsideCut
    end
  end

  class OutsideCutTool < CutTool
    def getContextMenuItems
      return PhlatScript.getString("Outside Edge")
    end

    def offset_distance
      return @bit_diameter/2
    end

    def cut_class
      return OutsideCut
    end
  end
	
	def PhlatScript.apply_hole_texture(sel)			# new context menu item to apply "Hole" face texture
		face = sel[0]
		if sel[0].class == Sketchup::Face
        Sketchup.active_model.start_operation "Setting face material"
			face.material = "Hole"
			face.back_material = "Hole"
        Sketchup.active_model.commit_operation				
		else
			UI.messagebox 'Error: You must select a Face.'
		end
	
	end

end