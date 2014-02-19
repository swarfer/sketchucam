# $Id$
require 'Phlatboyz/Phlatscript.rb'

module PhlatScript

  # base class for any cut marks made by phlatboyz tools
  class PhlatCut

    attr_accessor :cut_reversed

    def PhlatCut.from_edge(edge)
      cutkey = edge.get_attribute(Dict_name, Dict_edge_type, false)
      cut = nil
      if cutkey
        PhlatScript.cuts.each { |cut_class|
          next if !cut.nil?
          if cut_class.cut_key == cutkey
            cut = cut_class.load(edge)
          end
        }
      end
      return cut
    end

    def PhlatCut.by_cutkey(cut_key)
      PhlatScript.cuts.each { |cut_class|
        if cut_class.cut_key == cut_key
          return cut_class
          break
        end
      }
    end

    def processed=(val)
    end

    def processed
      return false
    end

    def erase
    end

    def self.cut_key
      return false
    end

    def can_tab?
      return false
    end

    def cut_points(reverse=false)
    end

    def in_polygon?(vertices)
      ret = false
      self.cut_points { |cp, cut_factor| ret = (ret || Geom.point_in_polygon_2D(cp, vertices, false)) }
      return ret
    end

    # returns the dictionary attribute for cut_depth_factor of the first entity
    def cut_factor
      return 0.0
    end

    # sets the cut_depth_factor attribute for all entities that are part of this cut
    def cut_factor=(factor)
    end

    def vertices
      self.edge.vertices if (self.edge)
    end

  end

end
