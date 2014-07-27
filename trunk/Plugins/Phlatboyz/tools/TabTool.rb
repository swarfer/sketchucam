
require 'sketchup.rb'
#require 'Phlatboyz/Constants.rb'
require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/tools/TabCut.rb'

module PhlatScript

  class TabTool < PhlatTool
    @@nCursor = 0
    @@vCursor = 0

    def initialize
      super
      @@boldTabs = true
      @ph = nil
      @loop_length = 0
      @auto = false
      @auto_pts = nil
      @pcut = nil
      @pt = nil

      if(@@nCursor == 0)
        cursorPath = Sketchup.find_support_file(Cursor_tab_tool, Cursor_directory)
        if(cursorPath)
          @@nCursor = UI.create_cursor(cursorPath, 13, 16)
        end
      end
      if(@@vCursor == 0)
        cursorPath = Sketchup.find_support_file(Cursor_vtab_tool, Cursor_directory)
        if(cursorPath)
          @@vCursor = UI.create_cursor(cursorPath, 13, 16)
        end
      end
    end

    def onSetCursor()
      @cursor = (get_vtab_flag() ? @@vCursor : @@nCursor)
      super
    end

    def onCancel(reason, view)
      if (reason == 0) && (@auto)# escape pressed
      end
    end

    def onMouseMove(flags, x, y, view)
      res, @pcut, @pt = pick_point(x, y, view)
      if @leftButtonDown == true
        # create the tab cut
        TabCut.cut(@pcut, @pt).vtab = get_vtab_flag(view.model) if (@pcut && @pt)
        view.model.selection.clear
        view.lock_inference
        self.reset(view)
        Sketchup::set_status_text("Tab complete", SB_VCB_LABEL)
      end
      if (@auto)
      end
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      added = false
      @leftButtonDown = true
      res, @pcut, @pt = pick_point(x, y, view)
      if (@auto)
        # store the point where the auto tab starts
        @loop_length = 0
        @pcut.loop.edges.each { |le| @loop_length += le.length } if (@pcut.loop)
      end
    end

    def onLButtonUp(flags, x, y, view)
      @leftButtonDown = false
        # create the tab cut
        TabCut.cut(@pcut, @pt).vtab = get_vtab_flag(view.model) if (@pcut && @pt)
        view.model.selection.clear
        view.lock_inference
      self.reset(view)
      Sketchup::set_status_text("Tab complete", SB_VCB_LABEL)
    end

    def onKeyDown(key, repeat, flags, view)
      if key == VK_END    # toggle V-Tab                              #86 # v key
        toggle_vtab_flag()
        self.reset(view)
        onSetCursor()
      elsif key == VK_HOME    # toogle Bold Tabs                      #68 # d key
        @@boldTabs = !@@boldTabs
        view.invalidate
      #elsif (key == 17) # CTRL
        # @auto = !@auto
      end
    end

    def draw(view)
      TabCut.preview(view, @pcut, @pt, get_vtab_flag(view.model)) if (@pcut && @pt)
      self.highlight_tabs(view) if @@boldTabs
    end

    def highlight_tabs(view)
      view.line_width = 6.0
      view.model.entities.each { |e|
        if (e.kind_of?(Sketchup::Edge))
          cut = PhlatCut.from_edge(e)
          cut.highlight(view) if cut.kind_of?(PhlatScript::TabCut)
        end
      }
    end

    def statusText
      return "Select edge to create tab.   [End] to toggle V-Tabs.   [Home] to toggle Bold Tabs."
    end

    def cut_class
      return TabCut
    end

    private

    def get_vtab_flag(model=Sketchup.active_model)
    	return model.get_attribute(Dict_name, Dict_vtabs, $phoptions.default_vtabs?)
    end

    def toggle_vtab_flag(model=Sketchup.active_model)
    	val = model.get_attribute(Dict_name, Dict_vtabs, $phoptions.default_vtabs?)
    	model.set_attribute(Dict_name, Dict_vtabs, !val)
    end

    def pick_point(x, y, view)
      @ph = view.pick_helper if !@ph
      os_cut = nil
      proj_pt = nil
      if (@ph.do_pick(x, y) > 0)
        @ph.all_picked.each { |e|
          os_cut = PhlatCut.from_edge(e)
          if os_cut.kind_of?(PhlatScript::OffsetCut)
            @ip.pick view, x, y
            proj_pt = @ip.position.project_to_line(os_cut.edge.line)
            break
          end
        }
      end
      os_cut = nil if !proj_pt
      return [!os_cut.nil?, os_cut, proj_pt]
    end

  end

end
