# $Id: CenterLineTool.rb 70 2013-10-25 12:33:58Z swarfer $
require 'sketchup.rb'
require 'Phlatboyz/Constants.rb'
require 'Phlatboyz/Tools/CenterLineCut.rb'

module PhlatScript

  class CenterLineTool < PhlatTool
    @@D = 1 # Depth Factor Index
    @@override_factor = 0
    @cut_edges = []
    @connected_edges = true

    def initialize
      super
      @connected_edges = true
      @@override_factor = PhlatScript.get_fold_depth_factor() #  TODO change to centerline depth factor ?
      @ph = nil
    end

    def activate
      super
      @ph = Sketchup.active_model.active_view.pick_helper
    end

    def reset(view)
      self.compute_fold_depth_factor()
      PhlatScript.display_fold_depth_factor()
      @connected_edges = true
      @cut_edges = []
      super
    end

    def onMouseMove(flags, x, y, view)
      @ph.do_pick(x, y)
      if ((@leftButtonDown) && (@ph.count > 0))
        @ph.all_picked.each { |e|
          if (e.kind_of?(Sketchup::Edge))
            next if PhlatCut.from_edge(e)
            addEdges(collect_edges(e))
            added = true
          end
        }
      end
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      added = false
      @leftButtonDown = true
      if @ph.do_pick(x, y) > 0
        @ph.all_picked.each { |e|
          if (e.kind_of?(Sketchup::Edge))
            next if PhlatCut.from_edge(e)
            addEdges(collect_edges(e))
            added = true
          end
        }
      end
      view.model.selection.clear if !added
    end

    def onLButtonUp(flags, x, y, view)
      @leftButtonDown = false
      cuts = CenterLineCut.cut(view.model.selection)
      cuts.each { |cut| cut.cut_factor = compute_fold_depth_factor }
      view.model.selection.clear
      view.lock_inference
      process_depth(view)
    end

    def onKeyDown(key, repeat, flags, view)
      refresh = false
=begin
      if(key > 47 && key < 58) # number keys
        @@override_factor *= 10
        @@override_factor += (key - 48)
        #@@override_factor %= 100
        refresh = true
      elsif key == 13 # enter key
        @@override_factor = 0
        refresh = true
=end
      if key == VK_RIGHT   # scroll preset depth right              #68 # D key
        @@D += 1
        @@override_factor = 0
        refresh = true
      elsif key == VK_LEFT   # scroll preset depth left
        @@D -= 1
        if @@D == -1 then @@D = 3 end
        @@override_factor = 0
        refresh = true
      elsif key == VK_DOWN   # go to preset depth 50
        @@D = 1
        @@override_factor = 0
        refresh = true
      elsif key == VK_SHIFT   # single edge instead of all connected
        @connected_edges = false
        refresh = true
      end
      if refresh then process_depth(view) end
    end

    def onKeyUp(key, repeat, flags, view)
      if key == VK_SHIFT
        @connected_edges = true
        view.invalidate
      end
    end

     # VCB
    def onUserText(text,view)
      begin
         value = text.to_i
      rescue
         # Error parsing the text
         UI.beep
         value = nil
         Sketchup::set_status_text "", SB_VCB_VALUE
      end
      return if !value

      @@override_factor = value
      process_depth(view)
    end

    def onCancel(reason, view)
      Sketchup.undo if (reason == 2) # user did Undo
      self.reset(view)
    end

    def draw(view)
      @ph.all_picked.each { |e|
        if (e.kind_of?(Sketchup::Edge))
          next if PhlatCut.from_edge(e)
          CenterLineCut.preview(view, collect_edges(e))
        end
      }
    end

    def addEdge(edge)
      if ((Sketchup.active_model.selection.contains?(edge)) || (edge.nil?))
        return false
      else
        Sketchup.active_model.selection.add(edge)
        return true
      end
    end

    def addEdges(edges=[])
      edges.each{ |e| addEdge(e) }
    end

    def process_depth(view)
      PhlatScript.set_fold_depth_factor(self.compute_fold_depth_factor())
      PhlatScript.display_fold_depth_factor()
      view.invalidate
    end

    def compute_fold_depth_factor
      if @@override_factor != 0
        fold_depth = @@override_factor
      else
        fold_depth = Fold_depth_factor_array[@@D % Fold_depth_factor_array.length]
      end
      return fold_depth
    end

    def cut_class
      return CenterLineCut
    end

    def statusText
      return "Select connected edges.   [Shift] to select single edge.   [<--][Down][-->] to scroll preset depths."
    end

    def selectConnectedEdges?
      return @connected_edges
    end

    private

    def collect_edges(edge)
      ar = []
      if !self.selectConnectedEdges?
        # if not getting connected edges just add the passed in edge
        ar.push(edge) if (!edge.phlatedge?)
      else
        collect_connected_edges(edge, ar, false)
      end
      return ar
    end

  end

end
