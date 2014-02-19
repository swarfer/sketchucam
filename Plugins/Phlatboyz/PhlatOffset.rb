
require 'sketchup.rb'

module PhlatScript

  Struct.new("Intersection", :intersection, :distance, :nodea, :nodeb)

  class VertexNode
    attr_accessor :vertex, :ea, :eb, :processed, :va, :vb, :intersection

    def initialize(lav, vertex)
      @vertex = vertex
      @lav = lav
      @processed = false
      @intersection = vertex
      @os_point = false
      @processed_dist = 0
    end

    def bisector(dist=1)
      return [self.position, @os_point] if @os_point

      vta = (@va.nil?) ? @vertex : @va 
      vec1 = self.position.vector_to(ea.other_vertex(vta).position).normalize!
      vtb = (@vb.nil?) ? @vertex : @vb
      vec2 = self.position.vector_to(eb.other_vertex(vtb).position).normalize!
      return false if (!vec1.valid?) || (!vec2.valid?)

      vec3 = (vec1 + vec2).normalize
      if vec3.valid?
        ang = vec1.angle_between(vec2)/2
        ang = Math::PI/2 if vec1.parallel?(vec2)
        vec3.length = dist/Math::sin(ang)
        cross = (vec2.normalize*vec1.normalize)
        if (cross) && (cross[2] < 0)
          if ((dist > 0) && (!@lav.processing_queue)) || (dist < 0)
            vec3.reverse!
#            puts "cross #{cross.to_s} vec3 #{vec3.to_s} reversed to #{vec3.reverse.to_s}"
#            puts "bisector_pt #{self.position.to_s} to #{self.position.offset(vec3).to_s}"
          end
        end
      else
        vec3 = (vec1.cross(Geom::Vector3d.new(0,0,1)))
        vec3.length = dist
      end

      pt = self.position.offset(vec3)
      @os_point = pt
      return [self.position, @os_point]
    end

    def intersect(node, distance)
      bisector1 = self.bisector(distance)
      bisector2 = node.bisector(distance)
      if (bisector1) && (bisector2)
        # get the point where the current bisector intersects
        pt = Geom.intersect_line_line(bisector1, bisector2)
        # ignore the point if the intersection doesn't fall within the offset length of both bisectors
        return (PhlatScript.ptOnBisector?(pt, bisector1) && PhlatScript.ptOnBisector?(pt, bisector2)) ? pt : false
      else
        return false
      end
    end

    def position
      if @vertex.kind_of?(Sketchup::Vertex)
        return @vertex.position
      else
        return @vertex
      end
    end

  end

  def PhlatScript.ptOnBisector?(pt, bisector)
    return false unless (pt) && (bisector)
    return true if pt == bisector[0] || pt == bisector[1]
    return false unless pt.on_line?([bisector[0], bisector[1]])
    bisector[0].vector_to(pt) % bisector[1].vector_to(pt) < 0
  end

  def PhlatScript.ptOnSegment?(pt, line_segment)
    return false unless (pt) && (line_segment)
    return true if pt == line_segment[0] || pt == line_segment[1]
    return false unless pt.on_line?([line_segment[0], line_segment[1]])
    line_segment[0].vector_to(pt) % line_segment[1].vector_to(pt) < 0
  end

  class Offset
    include Enumerable

    attr_accessor :original_vertices, :processing_queue

    Node = Struct.new(:data, :prev, :next)

    def initialize()
      @head = nil
      @original_vertices = []
      @processing_queue = false
    end

    def load(vertices)
     # (1.a) organize given vertices into double connected circular list of active vertices (LAV)
      vertices.each { |vertex| self.append(VertexNode.new(self, vertex), true) }

      # (1.b) for each vertex in the LAV add pointers to two incident edges and compute bisector
      self.each { |node|
        node.data.ea = node.data.vertex.common_edge(node.prev.data.vertex)
        node.data.eb = node.data.vertex.common_edge(node.next.data.vertex)
        # bisector is computed in VertexNode class
      }
    end
    
    def append(vertexNode, initial_vertex = false)
      @original_vertices.push(vertexNode.vertex) if initial_vertex
      if @head.nil?
        newNode = Node.new(vertexNode)
        newNode.prev = newNode
        newNode.next = newNode
        @head = newNode
        return newNode
      else
        return self.insertBefore(@head, vertexNode)
      end
    end
    
    def insertAfter(node, newData)
      newNode = Node.new(newData)
      newNode.next = node.next
      newNode.prev = node
      node.next.prev = newNode
      node.next = newNode
      return newNode
    end

    def insertBefore(node, newData)
      return self.insertAfter(node.prev, newData)
    end

    def remove(node)
      if node.next == node
        @head = nil
      else
        node.next.prev = node.prev
        node.prev.next = node.next
        @head = node.next if node == @head
      end
    end

    def each
      node = @head
      begin
        yield node
        node = node.next
      end while (node != @head)
    end

    def offsetPoints
      pts = []
      self.each { |node|
        bs = node.data.bisector
        pts.push(bs[1]) if bs
      }
      return pts
    end

    def process(dist)
      @processing_queue = false
      @processed_dist = dist
      # (1.b) for each vertex in the LAV add pointers to two incident edges and compute bisector
      self.each { |node|
        node.data.ea = node.data.vertex.common_edge(node.prev.data.vertex)
        node.data.eb = node.data.vertex.common_edge(node.next.data.vertex)
      }

      # (1.c) for each vertex compute the nearer intersection of the bisector with the adjacent vertex bisectors
      # and store in a processing queue
      queue = []
      self.each{ |node|
        prev_int = node.data.intersect(node.prev.data, dist)
        prev_dist = (prev_int) ? prev_int.distance(node.data.vertex.position) : false
        next_int = node.data.intersect(node.next.data, dist)
        next_dist = (next_int) ? next_int.distance(node.data.vertex.position) : false

        # determine which intersection is closer
        if (prev_dist) && (next_dist)
          closer_node = (prev_dist <= next_dist) ? 1 : 2
        elsif (prev_dist)
          closer_node = 1
        elsif (next_dist)
          closer_node = 2
        end

        # store the intersection point and the origin position of the bisectors
        if closer_node == 1
          queue.push(Struct::Intersection.new(prev_int, prev_dist, node.prev, node))
        elsif closer_node == 2
          queue.push(Struct::Intersection.new(next_int, next_dist, node, node.next))
        end
      }
      # (2) while queue is not empty 
      while (queue.length > 0) 
        @processing_queue = true
        # sort the queue by distance to intersection every iteration
        queue = queue.sort { |int1, int2| int1.distance <=> int2.distance }

        # (2.a) pop the intersection point from the front of the priority queue
        int = queue.shift

        # (2.b) if vertices are marked as processed then continue to the next intersection
        next if (int.nodea.data.processed) && (int.nodeb.data.processed)

        # (2.c) if the predecessor of the predecessor of nodea is equal to nodeb then output three skeleton arcs
        if (int.nodea.prev.prev == int.nodeb)
  #        edge1 = (Sketchup.active_model.active_entities.add_line [int.nodea.data.vertex, int.intersection])
  #        edge2 = (Sketchup.active_model.active_entities.add_line [int.nodea.prev.data.vertex, int.intersection])
  #        edge3 = (Sketchup.active_model.active_entities.add_line [int.nodea.prev.prev.data.vertex, int.intersection])
  #        edge1.material = 'Blue'
  #        edge2.material = 'Green'
  #        edge3.material = 'Orange'
          next
        end

        # (2.d) output two skeleton arcs for the nodes to the intersection
#        edge1 = (Sketchup.active_model.active_entities.add_line [int.nodea.data.vertex, int.intersection])
#        edge2 = (Sketchup.active_model.active_entities.add_line [int.nodeb.data.vertex, int.intersection])
#        edge1.material = 'Green' if edge1
#        edge2.material = 'Blue' if edge2

        # (2.e) mark the nodes as processed ...
        int.nodea.data.processed = int.nodeb.data.processed = true
        # ... create a new node with the coordinates of the intersection ...
        int_pt = Geom.intersect_line_line(int.nodea.data.ea.line, int.nodeb.data.eb.line)
        if (!int_pt.nil?)
          # ... insert the new node into the LAV. connect with the predecessor of va and sucessor of vb ...
          vertnode = self.insertBefore(int.nodea, VertexNode.new(self, int_pt))
          self.remove(int.nodea)
          self.remove(int.nodeb)
          # ... link the new node with appropriate edges
          vertnode.data.ea = int.nodea.data.ea
          vertnode.data.eb = int.nodeb.data.eb
          vertnode.data.va = (int.nodea.data.va) ? int.nodea.data.va : int.nodea.data.vertex
          vertnode.data.vb = (int.nodeb.data.vb) ? int.nodeb.data.vb : int.nodeb.data.vertex
          vertnode.data.intersection = int.intersection
#drawBisector(vertnode, dist, "Purple")

          # (2.f) for the new node compute the angle bisector between ea and eb ...
          # bisector computed in VertexNode class
          # ... compute intersection of new bisector with neighbors same as (1.c)
          prev_int = vertnode.data.intersect(vertnode.prev.data, dist)
          prev_dist = (prev_int) ? prev_int.distance(vertnode.data.position) : false
          next_int = vertnode.data.intersect(vertnode.next.data, dist)
          next_dist = (next_int) ? next_int.distance(vertnode.data.position) : false

          # determine which intersection is closer
          if (prev_dist) && (next_dist)
            closer_node = (prev_dist <= next_dist) ? 1 : 2
          elsif (prev_dist)
            closer_node = 1
          elsif (next_dist)
            closer_node = 2
          else
            closer_node = false
          end

          # store the intersection point and the origin position of the bisectors
          if closer_node == 1
            queue.push(Struct::Intersection.new(prev_int, prev_dist, vertnode.prev, vertnode))
          elsif closer_node == 2
            queue.push(Struct::Intersection.new(next_int, next_dist, vertnode, vertnode.next))
          end
        end
      end
#drawBisectors(self, dist, "Green")
      return self
    end

    def Offset.vertices(vertices, dist)
      lav = Offset.new
      lav.load(vertices)
      lav.process(dist)
      return lav
    end

  end

end

=begin debug code
def drawBisectors(lav, dist, color="Black")
  lav.each { |node| drawBisector(node, dist, color) }
end

def drawBisector(node, dist, color="Black")
  bisector = node.data.bisector(dist)
  if (bisector)
    edge = (Sketchup.active_model.active_entities.add_line [node.data.position, bisector[1]])
    edge.material = color if (edge)
  end
end

def drawVector(pt, vector, color="Purple")
  edge = (Sketchup.active_model.active_entities.add_line [pt, pt.offset(vector)])
  edge.material = color if (edge)
end

Sketchup.send_action "showRubyPanel:"
=end