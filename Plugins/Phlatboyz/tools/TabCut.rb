require 'Phlatboyz/PhlatCut.rb'
require 'Phlatboyz/tools/PhlatArc.rb'

module PhlatScript

  class TabCut < PhlatCut
    include PhlatArc
    attr_accessor :edge

    def TabCut.cut_key
      return Key_tab_cut
    end

    def TabCut.load(edge)
      return self.new(edge)
    end

    def TabCut.preview(view, pcut, pt, vtab)
      view.drawing_color = vtab ? Color_vtab_drawing : Color_tab_drawing
      view.line_width = 6.0
      begin
        if (pcut.is_arc?)
          point1 = pcut.edge.start.position
          point2 = pcut.edge.end.position
        else
#          current_tab_width = view.model.get_attribute(Dict_name, Dict_tab_width, Default_tab_width)
          current_tab_width = PhlatScript.tabWidth
          ep1 = pcut.edge.start.position
          ep2 = pcut.edge.end.position
          v = ep1.vector_to ep2
          half = current_tab_width/2
          point1 = pt.offset(v, -half)
          point2 = pt.offset(v, half)
          point1 = ep1 if pt.distance(ep1) < half
          point2 = ep2 if pt.distance(ep2) < half
        end
        view.draw_line(point1, point2)
      rescue
        UI.messagebox "Exception in Tab preview "+$!
      end
    end

    def TabCut.cut(pcut, pt)
      model = Sketchup.active_model
      cut_key = pcut.class.cut_key
      if (pcut.is_arc?)
        point1 = pcut.edge.start.position
        point2 = pcut.edge.end.position
      else
#        current_tab_width = model.get_attribute(Dict_name, Dict_tab_width, Default_tab_width)
        current_tab_width = PhlatScript.tabWidth
        ep1 = pcut.edge.start.position
        ep2 = pcut.edge.end.position
        v = ep1.vector_to ep2
        half = current_tab_width/2
        point1 = pt.offset(v, -half)
        point2 = pt.offset(v, half)
        point1 = ep1 if pt.distance(ep1) < half
        point2 = ep2 if pt.distance(ep2) < half
      end

      cut = self.new
      cut.cUt(point1, point2)
      # propagate the arc settings from the underlying edge to the tab
      if ((pcut.kind_of? PhlatArc) && (pcut.is_arc?))
        cut.radius = pcut.radius
        cut.angle = pcut.angle
        cut.g3 = pcut.g3?
      end
      model.start_operation "Creating Tab", true, true
      cut.edge.set_attribute(Dict_name, Dict_tab_edge_type, cut_key)
      model.commit_operation
      return cut
    end

    def initialize(edge=nil)
      super()
      @edge = edge
    end

    def cUt(pt1, pt2)
      model = Sketchup.active_model
      entities = Sketchup.active_model.entities
      model.start_operation "Creating Tab", true, true
      @edge = entities.add_line(pt1, pt2)
      @edge.set_attribute(Dict_name, Dict_cut_depth_factor, (PhlatScript.tabDepth/100.0))
      @edge.set_attribute(Dict_name, Dict_edge_type, (self.class.cut_key))
      @edge.material = Color_tab_drawing
      model.commit_operation
    end

    def highlight(view)
      view.line_width = 6.0
      view.drawing_color = (self.vtab?) ? Color_vtab_drawing : Color_tab_drawing
      view.draw_line(@edge.vertices[0].position, @edge.vertices[1].position)
    end

    def erase(delete=false)
      return if !@edge.valid?
      if delete then
        Sketchup.active_model.entities.erase_entities @edge
        return
      end

      entities = Sketchup.active_model.entities
      cut_key = @edge.get_attribute(Dict_name, Dict_tab_edge_type, Key_outside_cut)
      if (self.is_arc?)
        radius = self.radius
        angle = self.angle
        center = self.center
        g3 = self.g3?
      end

      ep1 = @edge.start.position
      ep2 = @edge.end.position
      entities.erase_entities @edge
      edge = entities.add_line(ep1, ep2)
      edge.find_faces
      ret_f = nil
      edge.faces.each { |f|
        if (f.outer_loop.edges.include? edge)
          ret_f = f
          break
        end
      }
      ret_f.material = "Hole" if (ret_f)
      ret_f.back_material = "Hole" if (ret_f)
      cut = PhlatCut.by_cutkey(cut_key).cut([edge]).first
      if (radius)
        cut.radius = radius
        cut.angle = angle
        cut.center = center
        cut.g3 = g3
      end
    end
    
   # given the start end and center point of an arccruve, find the midpoint of the arc
   #ps start point
   #pe endpoint
   #pc center point
   #r radius
   def midarc(ps,pe,pc,r)
      x = (ps.x + pe.x) /2
      y = (ps.y + pe.y) /2

      midpoint = Geom::Point3d.new(x,y,0)
      vect = pc.vector_to(midpoint)
      vect.length = r
      p2 = pc.offset(vect)
      return p2
   end   


    def cut_points(reverse=false)
# a couple of conditions that need to be tested to figure out the depth of the start and end point
# 1. If an adjoining edge is not a tab then no additional processing is needed
# 2. If an adjoining edge is a tab then the height for the common vertex needs to be the tab depth
      start_in_tab = false
      end_in_tab = false

      @edge.start.edges.each { |e|
        next if (e == @edge)
        pc = PhlatCut.from_edge(e)
        start_in_tab = pc.kind_of?(PhlatScript::TabCut) if pc
        break if start_in_tab
      }
      @edge.end.edges.each { |e|
        next if (e == @edge)
        pc = PhlatCut.from_edge(e)
        end_in_tab = pc.kind_of?(PhlatScript::TabCut) if pc
        break if end_in_tab
      }

      start_depth = start_in_tab ? PhlatScript.tabDepth : PhlatScript.cutFactor
      end_depth = end_in_tab ? PhlatScript.tabDepth : PhlatScript.cutFactor

      pts = [[@edge.start.position, start_depth]]
      if self.vtab?
         if (self.is_arc?)
            #puts "   arc center #{self.center} #{self.g3?.inspect} #{self.radius.to_mm}\n"
            if (self.center.x != 0.0) and ((self.center.y != 0.0))  # old arcs have no center set
               if self.g3?
                  ptm = midarc(@edge.start.position,@edge.end.position, self.center, self.radius)
               else
                  ptm = midarc(@edge.end.position,@edge.start.position, self.center, self.radius)
               end                  
            else   # old arcs have no center so cannot use midarc()
# todo: might be able to calculate the center
# http://mathforum.org/library/drmath/view/53027.html
# https://rosettacode.org/wiki/Circles_of_given_radius_through_two_points            
# formulas give 2 centers, woudl have to figure out which one to use
# meanwhile - just use the old linear method, this gives funky vtabs but always works
               ptm = Geom.linear_combination(0.50, @edge.start.position, 0.50, @edge.end.position)
            end
         else
            ptm = Geom.linear_combination(0.50, @edge.start.position, 0.50, @edge.end.position)
         end
        pts.push([ptm, PhlatScript.tabDepth])
      else
        pts.push([@edge.start.position, PhlatScript.tabDepth])
        pts.push([@edge.end.position, PhlatScript.tabDepth])
      end
      pts.push([@edge.end.position, end_depth])
      pts.reverse! if reverse
      pts.each { |ar| yield(ar[0], ar[1]) }
    end

    def vtab=(v)
      @edge.set_attribute(Dict_name, Dict_vtab, v)
      @edge.material = (v) ? Color_vtab_drawing : Color_tab_drawing
    end

    def vtab?
      return @edge.get_attribute(Dict_name, Dict_vtab, $phoptions.default_vtabs?)
    end

    def parent_cut
      return @edge.get_attribute($ditc_name, "parent_cut", PhlatScript::PhlatCut)
    end

    def parent_cut=(cut_class)
      @edge.set_attribute($ditc_name, "parent_cut", cut_class)
    end

    # marks all entities as having been milled in gcodeutil
    def processed=(val)
      @edge.set_attribute(Dict_name, Dict_object_mark, val)
    end

    def processed
      return @edge.get_attribute(Dict_name, Dict_object_mark, false)
    end

  end

end
