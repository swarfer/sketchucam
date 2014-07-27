
require 'Phlatboyz/PhlatCut.rb'
require 'Phlatboyz/Tools/CenterLineCut.rb'

module PhlatScript

  class FoldCut < CenterLineCut
    attr_accessor :wide_cut, :edge

    def FoldCut.cut_key
      return Key_fold_cut
    end

    def FoldCut.cut(edges, wide=false)
      cuts = []
      edges.each do | e |
        cut = FoldCut.new
        cut.wide_cut = wide
        cut.cut(e)
        cuts.push(cut)
      end
      return cuts
    end

    def FoldCut.preview(view, edges, wide=false)
      view.drawing_color = fold_color(wide)
      view.line_width = 5.0
      begin
        edges.each { |e| view.draw_line(e.start.position, e.end.position) }
      rescue
#        UI.messagebox "Exception in Fold preview "+$!
      end
    end

    def FoldCut.fold_color(wide_cut = false)
      return (wide_cut ? Color_fold_wide_cut : Color_fold_cut)
    end

    def cut(edge)
      model = edge.model
      model.start_operation("Creating Fold Line", true)
      @edge = edge
      if !@wide_cut
        if @edge.length > Fold_shorten_width
          ep1 = @edge.start.position
          ep2 = @edge.end.position
          v = ep1.vector_to ep2
          half = Fold_shorten_width/2
          point1 = ep1.offset(v, half)
          point2 = ep2.offset(v, -half)
          edge.model.entities.erase_entities @edge
          @edge = model.entities.add_line(point1, point2)
          @edge.set_attribute(Dict_name, "fold_shorten", true)
        end
      end
      @edge.material = FoldCut.fold_color(@wide_cut)
      @edge.set_attribute Dict_name, Dict_edge_type, Key_fold_cut
      model.commit_operation
    end

    def erase
      if @edge.get_attribute(Dict_name, "fold_shorten", false)
        # the edge was shortened when cut, restore original length
        entities = Sketchup.active_model.entities
        ep1 = @edge.start.position
        ep2 = @edge.end.position
        v = ep1.vector_to ep2
        half = Fold_shorten_width/2
        point1 = ep1.offset(v, -half)
        point2 = ep2.offset(v, half)
        entities.erase_entities @edge
        @edge = entities.add_line(point1, point2)
      end
      @edge.delete_attribute(Dict_name, Dict_cut_depth_factor)
      @edge.delete_attribute(Dict_name, Dict_edge_type)
      @edge.delete_attribute(Dict_name, "fold_shorten")
      @edge.material = nil
      @edge.find_faces
    end

    # returns the dictionary attribute for cut_depth_factor of the first entity
    def cut_factor
      return @edge.get_attribute(Dict_name, Dict_cut_depth_factor, $phoptions.default_fold_depth_factor)
    end

    # sets the cut_depth_facotr attribute for all entities that are part of this cut
    def cut_factor=(factor)
      f = factor % 1000
      (f = Max_fold_depth_factor) if (f > Max_fold_depth_factor)
      @edge.set_attribute(Dict_name, Dict_cut_depth_factor, f)
    end

  end

end
