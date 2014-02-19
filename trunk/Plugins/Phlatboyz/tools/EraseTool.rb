require 'sketchup.rb'
require 'Phlatboyz/Phlatscript.rb'
require 'Phlatboyz/PhlatTool.rb'

module PhlatScript

  class EraseTool < PhlatTool

    def initialize
      super
      @@boldTabs = true
      @tooltype = (PB_MENU_TOOLBAR | PB_MENU_MENU | PB_MENU_CONTEXT)
      @filter_index = 0
      @filter_cuts = ['All'] + PhlatScript.cuts
      @index_max = @filter_cuts.length-1
      @filter_cursor = []
      @filter_cuts.each { |cut|
        cursorPath = Sketchup.find_support_file("cursor_erase_#{cut.to_s.sub('PhlatScript::', '').downcase}.png", Cursor_directory)
        if(cursorPath)
          @filter_cursor.push(UI.create_cursor(cursorPath, 13, 16))
        else
          @filter_cursor.push(@cursor)
        end
      }
      @ph = nil
    end

    def activate
      super
      Sketchup.set_status_text("Filter cut", SB_VCB_LABEL)
      Sketchup.set_status_text(self.filterClass.to_s.sub('PhlatScript::', ''), SB_VCB_VALUE)
      @ph = Sketchup.active_model.active_view.pick_helper
    end

    def filterClass
      return @filter_cuts[@filter_index]
    end

    def onSetCursor()
      cursor = UI.set_cursor(@filter_cursor[@filter_index])# UI.set_cursor(@cursor) if !@cursor.nil?
    end

    def getContextMenuItems
      return ['Erase Selected Phlatedges']
    end

    def onContextMenu(menuItem)
      cut(Sketchup.active_model)
    end

	def onMouseEnter(view)
		view.invalidate
	end

    def onMouseMove(flags, x, y, view)
      if ((@leftButtonDown) && (@ph.do_pick(x, y) > 0))
        @ph.all_picked.each { |e|
          pc = PhlatCut.from_edge(e)
          next if !pc
          if (@filter_index == 0) | ((pc.class) == self.filterClass)
            if pc.kind_of?(PhlatScript::OffsetCut)
              ar = []
              collect_connected_edges(e, ar, true, true)
              view.model.selection.add(ar)
            else
              view.model.selection.add(e)
            end
          end
        }
      end
    end

    def onLButtonDown(flags, x, y, view)
      @leftButtonDown = true
      if @ph.do_pick(x, y) > 0
        @ph.all_picked.each { |e|
          pc = PhlatCut.from_edge(e)
          next if !pc
          if (@filter_index == 0) | ((pc.class) == self.filterClass)
            if pc.kind_of?(PhlatScript::OffsetCut)
              ar = []
              collect_connected_edges(e, ar, true, true)
              view.model.selection.add(ar)
            else
              view.model.selection.add(e)
            end
          end
        }
      else
        view.model.selection.clear
      end
      # Clear any inference lock
      view.lock_inference
    end

    def onLButtonUp(flags, x, y, view)
      @leftButtonDown = false
      cut(view.model)
    end

    def onCancel(reason, view)
      Sketchup.undo if (reason == 2) # user did Undo
      self.reset(view)
    end

    def onKeyDown(key, repeat, flags, view)
      if key == VK_RIGHT    # scroll edge types right        #VK_CONTROL  #if key == 17 # CTRL
        @filter_index+=1
        @filter_index = 0 if (@filter_index > @index_max)
        Sketchup.set_status_text(self.filterClass.to_s.sub('PhlatScript::', ''), SB_VCB_VALUE)
        self.onSetCursor()
      elsif key == VK_LEFT    # scroll edge types left
        @filter_index-=1
        @filter_index = 6 if (@filter_index < 0)
        Sketchup.set_status_text(self.filterClass.to_s.sub('PhlatScript::', ''), SB_VCB_VALUE)
        self.onSetCursor()
      elsif key == VK_DOWN    # jump to default (All edge types)
        @filter_index = 0
        Sketchup.set_status_text(self.filterClass.to_s.sub('PhlatScript::', ''), SB_VCB_VALUE)
        self.onSetCursor()                
      elsif key == VK_HOME   # toogle Bold Tabs                               #(key == 68) # d
        @@boldTabs = !@@boldTabs
        view.invalidate
      end
    end
    
    def draw(view)
      self.highlight_tabs(view) if @@boldTabs
    end
    
    def highlight_tabs(view)
      view.model.entities.each { |e|
        if (e.kind_of?(Sketchup::Edge))
          cut = PhlatCut.from_edge(e)
          cut.highlight(view) if cut.kind_of?(PhlatScript::TabCut)
        end
      }
    end

    def cut(model)
      model.start_operation PhlatScript.getString("operation_erasing_phlatboyz_edges")
      # check if erasing tabs and other cuts or just tabs
      mixed = false
      cuts = []
      model.selection.each { |e| mixed = (mixed || (!PhlatCut.from_edge(e).kind_of?(TabCut))) }
      model.selection.each { | e | 
        cut = PhlatCut.from_edge(e)
        cuts.push(cut) if (cut)
      }
      cuts.uniq!

      cuts.each { | c |
        if (c.kind_of?(TabCut))
          # this forces tabs to completely delete themselves when deleting multiple edges
          c.erase(mixed)
        else
          c.erase 
        end
      }

      model.commit_operation
      model.selection.clear
    end

    def eraseEdge(edge)
      model = Sketchup.active_model
      model.start_operation PhlatScript.getString("operation_erasing_phlatboyz_edges")
      edge.phlatcut.erase if ((!edge.nil?) && (edge.phlatedge?))
      model.active_view.invalidate
      model.commit_operation
    end

    def statusText
      return "Select edges to erase.     [<--][Down][-->] to filter edge type.    [Home] to toggle Bold Tabs."
    end

  end

end
