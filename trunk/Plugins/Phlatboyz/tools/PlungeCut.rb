require 'Phlatboyz/PhlatCut.rb'

module PhlatScript

  class PlungeCut < PhlatCut

    attr_accessor :edge

    def PlungeCut.radius
#      return (Sketchup.active_model.get_attribute Dict_name, Dict_bit_diameter, Default_bit_diameter) / 2.0
      return (PhlatScript.bitDiameter) / 2.0
    end

    def PlungeCut.cut_key
      return Key_plunge_cut
    end

    def PlungeCut.load(edge)
      return self.new(edge)
    end

    def PlungeCut.cut(pt, dfact, diam)
      plungecut = PlungeCut.new
      plungecut.cut(pt, dfact, diam.to_f)
      return plungecut
    end

    def PlungeCut.preview(view, pt)
      view.drawing_color = Color_plunge_cut
      view.line_width = 3.0
      begin
        n_angles = 16
        delta = 360.0 / n_angles
        dr = Math::PI/180.0
        angle = 0.0
        pt_arr = Array.new
        for i in 0..n_angles
          radians = angle * dr
          pt_arr << Geom::Point3d.new(pt.x + radius*Math.sin(radians), pt.y + radius*Math.cos(radians), 0)
          angle += delta
        end
        status = view.draw_polyline(pt_arr)
      rescue
        UI.messagebox "Exception in PlungeTool.draw_geometry "+$!
      end
    end

    def initialize(edge=nil)
      super()
      @edge = edge
    end

    def cut(pt, dfactor, diam)
      Sketchup.active_model.start_operation "Cutting Plunge", true
      rad = PlungeCut.radius
      if (diam > 0)
         puts "PlungeCut cutting #{diam}"
         rad = diam / 2
      end
      entities = Sketchup.active_model.entities
      
      group = entities.add_group   # the hole will be a group, usually without a name
#      if (group)
#         puts "#{group}\n"
#      else
#         puts "Failed to add hole group"
#      end
      
#      group.name = "";
      
      end_pt = Geom::Point3d.new(pt.x + rad, pt.y, 0)
      newedges = group.entities.add_edges(pt, end_pt)
      vectz = Geom::Vector3d.new(0,0,-1)
      circleInner = group.entities.add_circle(pt, vectz, rad, 12)
      #group.entities.add_face(circleInner)
#      group.description = "Hole"

      newedges[0].set_attribute Dict_name, Dict_edge_type, Key_plunge_cut
      if diam > 0 # if exists set the attribute
        newedges[0].set_attribute(Dict_name, Dict_plunge_diameter, diam)
        if (PhlatScript.isMetric)  # add diam to group name
           group.name = group.name + "_diam_#{diam.to_mm}mm"
        else
           group.name = group.name + "_diam_#{diam}"
        end
      end
      if dfactor != PhlatScript.cutFactor # if different set the attribute and color
        newedges[0].set_attribute Dict_name, Dict_plunge_depth_factor, dfactor.to_s
        newedges[0].material = Color_plunge_cutd
        if (PhlatScript.isMetric)      # add depth factor to group name
           group.name = group.name + "_depth_#{dfactor}"
        else
           group.name = group.name + "_depth_#{dfactor}"           
        end
      else
        newedges[0].material = Color_plunge_cut
      end
      @edge = newedges[0]
      Sketchup.active_model.commit_operation
    end

    def x
      return self.position.x
    end

    def y
      return self.position.y
    end

    def erase
      dele = [@edge]
      @edge.vertices.each { |v|
        v.loops.each { |l|
          l.edges.each { |e|
            # make sure the connected edge is part of an arc where the center
            # is the same as the plunge
            c = e.curve
            if ((c) && (c.kind_of? Sketchup::ArcCurve) && (c.center == self.position))
              dele.push(e)
            end
          }
        }
      }
      Sketchup.active_model.entities.erase_entities dele
    end

    def cut_points(reverse=false)
      yield(self.position, self.cut_factor)
    end

    def cut_factor
      cf = @edge.get_attribute(Dict_name, Dict_plunge_depth_factor, -1)
      if cf != -1 # if set then use it for the plunge depth in gcodeutil
        if cf != PhlatScript.cutFactor
#          puts "PlungeCut.cutfactor " + cf.to_s
          return cf
        end
      else
        return PhlatScript.cutFactor
      end
    end

  #swarfer: if the attribute is set gcodeutil will know what to do with it
    def diameter
      diam = @edge.get_attribute(Dict_name, Dict_plunge_diameter, -1)
      return diam
    end

    # marks all entities as having been milled in gcodeutil
    def processed=(val)
      @edge.set_attribute(Dict_name, Dict_object_mark, val)
    end

    def processed
      return @edge.get_attribute(Dict_name, Dict_object_mark, false)
    end

    def position
      return @edge.vertices.first.position
    end

  end

end
# $Id$
# $Log: PlungeCut.rb $
# Revision 1.1  2013/05/22 16:02:40  david
# Initial revision
#
# Revision 1.2  2013/05/20 14:59:06  david
# change color when plunge cut not full depth
#
# Revision 1.1  2013/05/17 13:15:35  david
# Initial revision
#
