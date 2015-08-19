require 'sketchup.rb'
require 'Phlatboyz/PhlatTool.rb'

module PhlatScript

  class PhlattenTool < PhlatTool

    def initialize
      super
      @tooltype = (PB_MENU_CONTEXT)
    end

    def getContextMenuItems
      return ['Phlatten Selected Edges']
    end

    def onContextMenu(menuItem)
      # For now this will just project the lines along Z to 0 
      # TODO: Find a plane that intersects the selected edges and transform them to Z0 to keep existing line lengths
      del_edges = []
      new_edges = []
      edges = []
      faces = []
      Sketchup.active_model.start_operation "Phlattening selected edges", true
      Sketchup.active_model.selection.each { |entity| 
         edges.push(entity) if entity.kind_of?(Sketchup::Edge)  
         faces.push(entity) if entity.kind_of?(Sketchup::Face)
         }
         # for Sketchup > 2014 we have to delete the faces seperately
      faces.each { |entity| 
         entity.erase! if entity.kind_of?(Sketchup::Face)
         }
         
      Sketchup.active_model.selection.clear
      edges.each { |edge|
         edge.faces.each { |face|
            face.erase! if face.valid?
            }
         pos1 = edge.vertices.first.position
         pos2 = edge.vertices.last.position
         pt1 = Geom::Point3d.new(pos1.x, pos1.y, 0)
         pt2 = Geom::Point3d.new(pos2.x, pos2.y, 0)
         del_edges.push(edge)
         new_edges.push([pt1,pt2])
         }

      Sketchup.active_model.entities.erase_entities(del_edges)

      new_edges.each { |pts| 
         edges = Sketchup.active_model.entities.add_edges(pts[0], pts[1])
         edges.each {|e| e.find_faces} if edges
         }

      Sketchup.active_model.commit_operation
    end

  end

end
