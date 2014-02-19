
require "sketchup.rb"
require 'Phlatboyz/Tools/GcodeUtil.rb'
require 'Phlatboyz/PhlatCut.rb'

module PhlatScript    

  class Sketchup::Edge
    @phlatcut = nil

    def phlatcut
      @phlatcut = PhlatCut.from_edge(self) #if @phlatcut == nil
      return @phlatcut
    end

    def phlatedge?
      return !self.phlatcut.nil?
    end

    def phlatarc?
      return self.phlatcut.is_a?(PhlatArc)
    end

    # def cut(type)
      # @phlatcut = PhlatCut.new_cut(self, type)
    # end

  end

=begin
module PhlatEdge

  attr_reader :edge
  @edge = nil

  def self.phlatedge? (edge)
    return !(edge.get_attribute(Dict_name, Dict_edge_type, nil)).nil?
  end

  # returns the dictionary attribute for cut_depth_factor of the first entity
  def cut_factor
    return self.get_attribute Dict_cut_depth_factor, 0.0
  end

  # sets the cut_depth_facotr attribute for all entities that are part of this cut
  def cut_factor=(factor)
    self.set_attribute(Dict_cut_depth_factor, factor)
  end

  def set_attribute (key, value)
    entities.each{ |e| 
      e.set_attribute Dict_name, key, value 
    }
  end

  def get_attribute (key, default_value=nil)
    (entities.length > 0) ? (entities.first.get_attribute Dict_name, key, default_value) : default_value
  end

  # erases attributes on all entities identifying them as a phlatcut
  def erase
    entities.each{ |e|
      next if !e.valid?
      if (e.phlatcut.is_type? Key_reg_cut_arr) || (e.phlatcut.is_type? Key_plunge_cut)
        Sketchup.active_model.entities.erase_entities(e)
      else
        e.delete_attribute Dict_name, Dict_cut_depth_factor
        e.delete_attribute Dict_name, Dict_edge_type
        e.material = nil
      end
    }
  end

  # tests the vertices of all entities to make sure they are within the safe cutting area
  def in_safe_area?
    safe_point3d_array = get_safe_area_point3d_array()
    safe = false
    entities.each{ |e|
      e.vertices.each { |v|
        safe = safe || (Geom::point_in_polygon_2D(v.position, safe_point3d_array, true))
      }
    }
    return safe
  end

  # returns the type of cut (outside, inside, plunge, etc..) of the first entity
  def type
    return self.get_attribute(Dict_edge_type, nil)
  end

  # takes a single or array of cut types (outside, inside, plunge, etc..) and tests if this cut
  # is one of those types
  def is_type? (match_type)
    if (match_type.kind_of? Array )
      match = false
      match_type.each { |mt| match = true if (match || ((!mt.nil?) && (type.to_s.eql? mt))) }
      return match
    else
      return (!match_type.nil?) && (type.to_s.eql? match_type) 
    end
  end

	def startPosition(in_transform = nil)
    point = @edge.vertices.first.position
    point = point.transform in_transform if(in_transform != nil)
		return point
	end

	def endPosition(in_transform = nil)
    point = @edge.vertices.last.position
		point = point.transform in_transform if(in_transform != nil)
		return point
	end

end

module PhlatArc

  def self.is_arc? (edge)
    b = (!edge.get_attribute(Dict_name, Dict_phlatarc_radius, nil).nil?) && 
      (!edge.get_attribute(Dict_name, Dict_phlatarc_center, nil).nil?)
    return b
  end

  def self.define_arc(phlatedges, center, radius, angle, g3)
    phlatedges.each { |e|
      pe = e.is_a?(PhlatCut) ? e : e.phlatcut
      if !pe.nil?
        pe.extend PhlatArc
        pe.center = center
        pe.radius= radius
        pe.angle = angle
        pe.g3 = g3
      end
    }
  end
 
  def center(in_transform = nil)
    return self.get_attribute(Dict_phlatarc_center, (Geom::Point3d.new [0,0,0]))
  end

  def center=(pt_center)
    self.set_attribute(Dict_phlatarc_center, pt_center)
  end

  def angle
    return self.get_attribute(Dict_phlatarc_angle, 0)
  end

  def angle=(angle)
    self.set_attribute(Dict_phlatarc_angle, angle)
  end

  def radius
    return self.get_attribute(Dict_phlatarc_radius, 0)
  end

  def radius=(radius)
    self.set_attribute(Dict_phlatarc_radius, radius)
  end

  def g3=(g3)
    self.set_attribute(Dict_phlatarc_g3, g3)
  end

  def g3?
    return self.get_attribute(Dict_phlatarc_g3, false)
  end

end

class PhlatCut

  include PhlatEdge

  def self.new_cut(entity, type)
    obj = PhlatCut.new(entity)
    obj.type=type if !obj.nil?
    return obj
  end

  def self.from_edge(edge)
    obj = (PhlatEdge.phlatedge?(edge)) ? PhlatCut.new(edge) : nil
    obj.extend(PhlatArc) if PhlatArc.is_arc?(edge)
    return obj
  end

  def initialize(entity)
   if entity.kind_of? (Sketchup::Edge)
      @edge = entity
   else
      return nil
    end
  end

  # returns the Sketchup entities that belong to this cut
  def entities
    if self.respond_to?(:edge)
      result = [self.edge]
    elsif self.respond_to?(:edges)
      result = self.edges
    else
      result = []
    end
  end

end
=end

class LoopNode

  attr_reader :children, :loop, :fold_cuts, :centerline_cuts, :plunge_cuts, :loop_start, :sorted_cuts

  def initialize(loop)
    @loop = loop
    @children = []
    @fold_cuts = []
    @centerline_cuts = []
    @plunge_cuts = []
    @sorted_cuts = []
    @loop_start = 0
  end

  def loop_pt
    @loop.nil? ? nil : @loop.vertices[@loop_start].position
  end

  def find_container(phlatcut)
    # test if the phlatedge vertices are bound by self.loop
    if (@loop.nil?) || (PhlatScript::GcodeUtil::points_in_points(phlatcut.vertices, @loop.vertices))
      child_contained = false
      # this loop bounds the vertices (or doesn't exist) so try narrowing it down to a child loop
      @children.each { |child| child_contained = (child_contained || child.find_container(phlatcut)) }
      # if a child didn't contain the phlatedge then we must do it ourself
      if !child_contained
        if phlatcut.kind_of? PhlatScript::FoldCut
          @fold_cuts.push(phlatcut)
        elsif phlatcut.kind_of? PhlatScript::CenterLineCut
          @centerline_cuts.push(phlatcut) 
        elsif phlatcut.kind_of? PhlatScript::PlungeCut
          @plunge_cuts.push(phlatcut)
        elsif phlatcut.kind_of? Sketchup::Loop
          # create a new child node for the loop
          node = LoopNode.new(phlatcut)
          # test all the cuts and children to see of they fit in the new loop
          @fold_cuts.collect! { |fc| node.find_container(fc) ? nil : fc }
          @fold_cuts.compact!
          @centerline_cuts.collect! { |cc| node.find_container(cc) ? nil : cc }
          @centerline_cuts.compact!
          @plunge_cuts.collect! { |pc| node.find_container(pc) ? nil : pc }
          @plunge_cuts.compact!
          @children.collect! { |child| node.place_loopnode(child) ? nil : child }
          @children.compact!
          @children.push(node)
        end
      end
      return true
    else
      # if the current loop doesn't bound the vertices then no way a child can
      return false
    end
  end

  def place_loopnode(loopnode)
    # test if the phlatedge vertices are bound by self.loop
    if (@loop.nil?) || (PhlatScript::GcodeUtil::points_in_points(loopnode.loop.vertices, @loop.vertices))
      child_contained = false
      # this loop bounds the vertices (or doesn't exist) so try narrowing it down to a child loop
      @children.each { |child| child_contained = (child_contained || child.place_loopnode(loopnode)) }
      # if a child didn't contain the phlatedge then we must do it ourself
      if !child_contained
        @fold_cuts.collect! { |fc| loopnode.find_container(fc) ? nil : fc }
        @fold_cuts.compact!
        @centerline_cuts.collect! { |cc| loopnode.find_container(cc) ? nil : cc }
        @centerline_cuts.compact!
        @plunge_cuts.collect! { |pc| loopnode.find_container(pc) ? nil : pc }
        @plunge_cuts.compact!
#        @children.collect! { |child| loopnode.place_loopnode(child) ? nil : child }
#        @children.compact!
        @children.push(loopnode) 
      end
      return true
    else
      # if the current loop doesn't bound the vertices then no way a child can
      return false
    end
  end

  def sort
    last_pt = Geom::Point3d.new(0,0,0) 
    # sort all the interior cuts
    cuts = @fold_cuts + @centerline_cuts + @plunge_cuts
    cuts, last_pt = self.sort_cuts(cuts, last_pt)
    @sorted_cuts = cuts

    # make sure that all children nodes are sorted first
    children = []
    @children.each { |child| 
      child.sort
      children.push(child) if child.loop
    }

    @children = []
    last_pt = Geom::Point3d.new(0,0,0) if last_pt.nil?
    while (children.length > 0)
      picked = 0
      i = 0
      dist = nil
      pt = nil
      children.each { |child|
        pt = child.loop_pt
        cdist = pt.distance(last_pt)
        if (dist.nil?) or (cdist < dist)
          dist = cdist
          picked = i
        end
        i += 1
      }
      @children.push(children.delete_at(picked))
      last_pt = @children.last.loop_pt
    end

    # find the vertex of the @loop that is closest to the end cut
    if !@loop.nil?
      last_pt = Geom::Point3d.new(0,0,0) if !last_pt
      dist = nil
      i = 0
      @loop.vertices.each { |v|
        cdist = last_pt.distance(v.position)
        if (dist.nil?) or (cdist < dist)
          dist = cdist
          @loop_start = i
        end
        i += 1
      }
    end
  end

  def sort_cuts(edges, ref_pt=nil)
    ref_pt = Geom::Point3d.new(0,0,0) if (!ref_pt)
    return [edges, ref_pt] if (edges.length == 0)

    # let's try and order the edges ... good luck
    cuts = []
    while edges.length > 0
      pc = edges.shift
      start_pt = nil
      end_pt = nil
      # have to keep the curves together
      if pc.edge.curve
        curve = pc.edge.curve
        pcs = []

        # loop the edges in the curve and push each pc where the pc.edge matches the curve edge
        curve.edges.each { |ce|
          pcs.push(pc) if pc.edge == ce
          edges.each { |pc1| pcs.push(pc1) if pc1.edge == ce }
        }

        # locate an end vertex
        startEdge = startVert = nil
        verts = pcs.collect{|pc| pc.edge.vertices}.flatten
        vertsShort=[]
        vertsLong=[]
        verts.each { |v| vertsLong.include?(v) ? vertsShort.push(v) : vertsLong.push(v) }
        closed = false
        if (startVert=(vertsLong-vertsShort).first)==nil
          startVert=vertsLong.first
          closed=true
        end
        # get the start and end points for the curve
        pcs.first.cut_points(false) { |cp, cut_factor| start_pt = cp if start_pt.nil? }
        pcs.last.cut_points(false) { |cp, cut_factor| end_pt = cp }

        cuts.push([pcs, start_pt, end_pt])
        pcs.each { |pc| edges.delete(pc) }
      else
        pc.cut_points(false) { |cp, cut_factor|
          start_pt = cp if start_pt.nil?
          end_pt = cp
        }
        cuts.push([[pc], start_pt, end_pt])
      end
    end

    ordered = []
    # the initial reference point is the origin
    dist = ref_pt.distance(cuts[0][1])
    test_dist1 = nil
    test_dist2 = nil
    while (cuts.length > 0 )
      reversed = false
      # find the edge with the closest start point to the reference point
      i = 0
      next_cut = i
      dist = ref_pt.distance(cuts[0][1])

      cuts.each { |cut|
        test_dist1 = ref_pt.distance(cut[1])
        test_dist2 = ref_pt.distance(cut[2])
        if (test_dist1 < dist)
          next_cut = i
          dist = test_dist1
          if ((test_dist2) && (test_dist2 < test_dist1))
            reversed = true
            dist = test_dist2
          else
            dist = test_dist1
            reversed = false
          end
        elsif (test_dist2) && (test_dist2 < dist)
          next_cut = i
          reversed = true
          dist = test_dist2
        end
        i += 1
      }

      # the next reference point is the end point for the selected cut
      cut_group = []
      if reversed
        ref_pt = cuts[next_cut][1] 
        cut_group = cuts[next_cut][0].reverse
        cut_group.each { |c| c.cut_reversed = true }
      else
        ref_pt = cuts[next_cut][2]
        cut_group = cuts[next_cut][0]
        cut_group.each { |c| c.cut_reversed = false }
      end

      # store the actual cut
      ordered.push(cut_group)
      ordered.flatten!
      # remove the resulting cut from the array
      cuts.delete_at(next_cut)
    end
    return [ordered, ref_pt]
  end

end # class LoopNode

end # module PhlatScript
