

module PhlatScript

  module PhlatArc

    def self.is_arc?(edge)
      return (!edge.get_attribute(Dict_name, Dict_phlatarc_radius, nil).nil?)
    end

    def is_arc?
      return (!@edge.get_attribute(Dict_name, Dict_phlatarc_radius, nil).nil?)
    end

    def define_arc(radius, angle, g3)
      self.radius = radius
      self.angle = angle
      self.g3 = g3
    end

    def angle
      return @edge.get_attribute(Dict_name, Dict_phlatarc_angle, 0)
    end

    def angle=(angle)
      @edge.set_attribute(Dict_name, Dict_phlatarc_angle, angle)
    end

    def radius
      return @edge.get_attribute(Dict_name, Dict_phlatarc_radius, 0)
    end

    def radius=(radius)
      @edge.set_attribute(Dict_name, Dict_phlatarc_radius, radius)
    end

    def g3=(g3)
      @edge.set_attribute(Dict_name, Dict_phlatarc_g3, g3)
    end

    def g3?
      return @edge.get_attribute(Dict_name, Dict_phlatarc_g3, false)
    end

  end

end