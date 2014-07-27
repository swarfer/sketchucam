
require 'sketchup.rb'
#require 'Phlatboyz/Constants.rb'
require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/tools/CenterLineTool.rb'
require 'Phlatboyz/Tools/FoldCut.rb'

module PhlatScript

  class FoldTool < CenterLineTool
    @@wide_cut = false

    def onLButtonUp(flags, x, y, view)
      @leftButtonDown = false
      edges = view.model.selection
      cuts = FoldCut.cut(edges, @@wide_cut)
      cuts.each { |cut| cut.cut_factor = compute_fold_depth_factor }
      view.model.selection.clear
      view.lock_inference
    end

    def onKeyDown(key, repeat, flags, view)
      if key == VK_END    # togle Wide Mode                             #87 # W key
        @@wide_cut = !@@wide_cut
        #self.compute_fold_depth_factor()
        #PhlatScript.display_fold_depth_factor()
        Sketchup.status_text = statusText
        view.invalidate
      else
        super
      end
    end

    def draw(view)
      @ph.all_picked.each { |e|
        if (e.kind_of?(Sketchup::Edge))
          next if PhlatCut.from_edge(e)
          FoldCut.preview(view, collect_edges(e), @@wide_cut)
        end
      }
#      FoldCut.preview(view, collect_edges(@ip.edge), @@wide_cut) if !@ip.edge.nil?
    end

    def cut_class
      return FoldCut
    end

    def statusText
      if @@wide_cut
        return "Select edges.  [Shift]select connected edges.  [End]toggle Wide Mode.  [<--][-->]scroll preset depths.     ** Wide Mode **"
      else
        return "Select edges.  [Shift]select connected edges.  [End]toggle Wide Mode.  [<--][-->]scroll preset depths.     ** Short Mode **"
      end
    end

    def selectConnectedEdges?
      return !@connected_edges
    end

  end

end
