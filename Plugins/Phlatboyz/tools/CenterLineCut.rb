

require 'Phlatboyz/PhlatCut.rb'

module PhlatScript

  class CenterLineCut < PhlatCut
    attr_accessor :edge

    def CenterLineCut.cut_key
      return Key_centerline_cut
    end

    def CenterLineCut.load(edge)
      return self.new(edge)
    end

    def CenterLineCut.cut(edges)
      cuts = []
      edges.each do | e |
        cut = CenterLineCut.new
        cut.cut(e)
        cuts.push(cut)
      end
      return cuts
    end

    def CenterLineCut.preview(view, edges)
      view.drawing_color = Color_centerline_cut
      view.line_width = 5.0
      begin
        edges.each { |e| view.draw_line(e.start.position, e.end.position) }
      rescue
        UI.messagebox "Exception in CenterLine preview "+$!
      end
    end

    def cut(edge)
      model = Sketchup.active_model
      model.start_operation "Creating Center Line", true
      @edge = edge
      @edge.material = Color_centerline_cut
      @edge.set_attribute Dict_name, Dict_edge_type, Key_centerline_cut
      model.commit_operation
    end

    def erase
      @edge.delete_attribute Dict_name, Dict_cut_depth_factor
      @edge.delete_attribute Dict_name, Dict_edge_type
      @edge.material = nil
    end

    def initialize(edge=nil)
      super()
      @edge = edge
    end

    def cut_points(reverse=false)
      cf = self.cut_factor
#      puts "cut_points reverse #{reverse} cut_reversed#{@cut_reversed}"
      if @cut_reversed
#      if reverse  #cut_reversed and reverse don't always match for centerline cuts, messes up ramping
        yield(@edge.end.position, cf)
        yield(@edge.start.position, cf)
      else
        yield(@edge.start.position, cf)
        yield(@edge.end.position, cf)
      end
    end
    
    def cut_reversed?
       @cut_reversed
    end

    # returns whether the first entity has been marked as milled in gcodeutil.rb
    def processed?
      return @edge.get_attribute(Dict_name, Dict_object_mark, false)
    end

    # marks all entities as having been milled in gcodeutil
    def processed=(val)
      @edge.set_attribute(Dict_name, Dict_object_mark, val)
    end

    def processed
      return @edge.get_attribute(Dict_name, Dict_object_mark, false)
    end

    # returns the dictionary attribute for cut_depth_factor of the first entity
    def cut_factor
      return @edge.get_attribute(Dict_name, Dict_cut_depth_factor, $phoptions.default_fold_depth_factor).to_f
    end

    # sets the cut_depth_facotr attribute for all entities that are part of this cut
    def cut_factor=(factor)
      f = factor % 1000
      (f = Max_fold_depth_factor) if (f > Max_fold_depth_factor)
      @edge.set_attribute(Dict_name, Dict_cut_depth_factor, f.to_f)
    end

  end

end
