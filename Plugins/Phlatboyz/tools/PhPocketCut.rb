#
# Name:		PocketTool.rb
# Desctiption:	Create a pocket face and zigzag edges
# Author:	Katsuhiko Toba ( http://www.eprcp.com/ )
# Usage:	1. Install into the plugins directory.
#		2. Select "Pocket" from the Plugins menu.
#		3. Click the face to pocket
#		4. Select "CenterLine Tool" from menu or toolbar
#		5. Click the zigzag edge first, the face edge second.
#		NOTE: Do not use Centerline from context menu.
#                     It breaks the zigzag edge.
# Limitations:	Simple convex face only
#
# ** Modified by kyyu 05-29-2010 - rewrote "get_offset_points" method because of a bug          **
#   where the pocket lines were out of the pocket boundaries because of mix direction edges     **
#   -Looks like it works, but not rigorously check so USE AT YOUR OWN RISK!                     **
#
# ** Modified by swarfer 2013-05-20 - press shift to only get zigzag, press ctrl to only get outline
#    This is a step on the way toward integrating it into Sketchucam, and properly handling complex faces
#
# ** Swarfer 2013-08-27 - create PocketCut type edges, mostly just copied from one of the other cut types
# $Id$

require 'sketchup.rb'
require 'Phlatboyz/PhlatCut.rb'
require 'Phlatboyz/Tools/CenterLineCut.rb'

module PhlatScript

class PocketCut < CenterLineCut
   attr_accessor :edge

   def initialize(edge=nil)
      super
   end

   def PocketCut.load(edge)
      return self.new(edge)
   end

   def PocketCut.cut_key
      return Key_pocket_cut
   end

    def PocketCut.cut(edges)
      cuts = []
      edges.each do | e |
        cut = PocketCut.new
        cut.cut(e)
        cuts.push(cut)
      end
      return cuts
    end

    def cut(edge)
#	    puts "cut #{edge}"
      model = edge.model
#      model.start_operation("Creating Pocket Line", true, true)
      @edge = edge
      @edge.material = Color_pocket_cut
      @edge.set_attribute(Dict_name, Dict_edge_type, Key_pocket_cut)
#      model.commit_operation
    end

   def reset(view)
      if (view)
         view.tooltip = nil
         view.invalidate
      end
   end

    # returns the dictionary attribute for cut_depth_factor of the first entity
   def cut_factor
      return @edge.get_attribute(Dict_name, Dict_pocket_depth_factor, $phoptions.default_pocket_depth_factor)
   end

   # sets the cut_depth_factor attribute for all entities that are part of this cut
   def cut_factor=(factor)
      f = factor % 1000
      (f = 100) if (f > 100)
      @edge.set_attribute(Dict_name, Dict_pocket_depth_factor, f)
   end

   end
end

