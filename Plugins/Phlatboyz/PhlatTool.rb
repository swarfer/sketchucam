# $Id$
require 'sketchup.rb'
#require 'Phlatboyz/Constants.rb'

module PhlatScript

  class PhlatTool
    attr_reader :tooltype, :tooltip, :largeIcon, :smallIcon, :statusText, :menuItem, :menuText

    def initialize
      toolname = self.class.to_s.sub('PhlatScript::', '')
      @tooltype = (PB_MENU_TOOLBAR | PB_MENU_MENU)
      @tooltip = PhlatScript.getString("Phlatboyz #{toolname}")
      @largeIcon = "images/#{toolname.downcase}_large.png"
      @smallIcon = "images/#{toolname.downcase}_small.png"
      @statusText = PhlatScript.getString("Phlatboyz #{toolname}")
      @menuItem = PhlatScript.getString(toolname)
      @menuText = PhlatScript.getString(toolname)
      @ip = nil
      cursorPath = Sketchup.find_support_file("cursor_#{toolname.downcase}.png", Cursor_directory)
      if(cursorPath)
        @cursor = UI.create_cursor(cursorPath, 13, 16)
      end
    end

    def cut_class
      return false
    end

    def select
      Sketchup.active_model.select_tool self
    end

    def getContextMenuItems
      return false
    end

    def onContextMenu(menuItem)
      puts "onContextMenu is not defined for #{self.class.to_s}"
    end

    def activate
      @ip = Sketchup::InputPoint.new
      self.reset(nil)
    end

    def deactivate(view)
      view.invalidate
    end

    def resume(view)
      Sketchup.status_text = self.statusText
    end

    def reset(view)
      if(view)
        view.model.selection.clear
        view.tooltip = nil
        view.invalidate
      end
      Sketchup.status_text = self.statusText
    end

    def onSetCursor()
      cursor = UI.set_cursor(@cursor) if !@cursor.nil?
    end

    def statusText
      return "#{self.class.to_s} selected"
    end

    protected

    # utility method for collecting all edges connected to edge and adding them
    # to edge_array
    def collect_connected_edges(edge, edge_array, include_phlat=false, only_phlat=false)
      edges = []
      # if the edge is on the outside of a face we can just grab all the
      # edges in the face outer loop
      edge.faces.each { |face|
        next if !edges.empty?
        edges = face.outer_loop.edges if (face.outer_loop.edges.include?(edge))
      }

      if edges.empty?
        check = [edge]
        while (!check.empty?)
          cur_edge = check.pop
          edges.push(cur_edge)
          cur_edge.vertices.each { |v|
            v.edges.each { |e|
              check.push(e) if (!edges.include?(e))
            }
          }
        end
        edges.compact!
        edges.uniq!
      end

      # not part of a face so just get all_connected
      edges = edge.all_connected if edges.empty?

      # check if any of the edges meet the criteria
      edges.each { |e|
        if ((e.kind_of?(Sketchup::Edge)) && (include_phlat || !e.phlatedge?) && (!only_phlat || e.phlatedge?))
          edge_array.push(e)
        end
       }
    end

  end

end
