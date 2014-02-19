

require 'Phlatboyz/PhlatCut.rb'
require 'Phlatboyz/tools/PhlatArc.rb'

module PhlatScript

  class OffsetCut < PhlatCut
    include PhlatArc
    attr_accessor :edge

    def OffsetCut.load(edge)
      return self.new(edge)
    end

    def OffsetCut.preview(view, pts)
      view.drawing_color = Color_cut_drawing
      view.draw(GL_LINE_LOOP, pts)
    end

    def OffsetCut.cut(edges)
      cuts = []
      edges.each do | e |
        cut = self.new
        cut.cut(e)
        cuts.push(cut)
      end
      return cuts
    end

    def cut(edge)
      @edge = edge
      Sketchup.active_model.start_operation "Assigning Offset Cut", true
      @edge.set_attribute(Dict_name, Dict_edge_type, self.class.cut_key)
      @edge.material = edge_material
      Sketchup.active_model.commit_operation
    end

    def erase
      Sketchup.active_model.entities.erase_entities @edge
    end

    def initialize(edge=nil)
      super()
      @edge = edge
    end

    # marks all entities as having been milled in gcodeutil
    def processed=(val)
      @edge.set_attribute(Dict_name, Dict_object_mark, val)
    end

    def processed
      return @edge.get_attribute(Dict_name, Dict_object_mark, false)
    end

    def cut_points(reverse=false)
      cf = self.cut_factor
      if reverse
        yield(@edge.end.position, cf)
        yield(@edge.start.position, cf)
      else
        yield(@edge.start.position, cf)
        yield(@edge.end.position, cf)
      end
    end

  end

  class InsideCut < OffsetCut
    def edge_material
      return Color_inside_cut
    end

    def InsideCut.cut_key
      return Key_inside_cut
    end

    # returns the dictionary attribute for cut_depth_factor of the first entity
    def cut_factor
      return @edge.get_attribute(Dict_name, Dict_cut_depth_factor, PhlatScript.cutFactor)
    end

  end

  class OutsideCut < OffsetCut
    def edge_material
      return Color_outside_cut
    end

    def OutsideCut.cut_key
      return Key_outside_cut
    end

    # returns the dictionary attribute for cut_depth_factor of the first entity
    def cut_factor
      return @edge.get_attribute(Dict_name, Dict_cut_depth_factor, PhlatScript.cutFactor)
    end

  end

end