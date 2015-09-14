require 'Phlatboyz/PhlatCut.rb'

module PhlatScript
  @sqnc = 1
  class PlungeCut < PhlatCut

    attr_accessor :edge
    
    def PlungeCut.radius
#      return (Sketchup.active_model.get_attribute Dict_name, Dict_bit_diameter, Default_bit_diameter) / 2.0
      return (PhlatScript.bitDiameter) / 2.0
    end

    def PlungeCut.cut_key
      return Key_plunge_cut
    end

    def PlungeCut.load(edge)
      return self.new(edge)
    end

    def PlungeCut.cut(pt, dfact, diam, knt = 0, ang = 0, cdiam = 0.to_l, cdepth = 0.to_l)
      plungecut = PlungeCut.new
      plungecut.cut(pt, dfact, diam, knt, ang, cdiam, cdepth)
      return plungecut
    end

    def PlungeCut.preview(view, pt)
      view.drawing_color = Color_plunge_cut
      view.line_width = 3.0
      begin
        n_angles = 16
        delta = 360.0 / n_angles
        dr = Math::PI/180.0
        angle = 0.0
        pt_arr = Array.new
        for i in 0..n_angles
          radians = angle * dr
          pt_arr << Geom::Point3d.new(pt.x + radius*Math.sin(radians), pt.y + radius*Math.cos(radians), 0)
          angle += delta
        end
        status = view.draw_polyline(pt_arr)
      rescue
        UI.messagebox "Exception in PlungeTool.draw_geometry "+$!
      end
    end

    def initialize(edge=nil)
      super()
      @edge = edge
    end

#if cnt is > 0 then it is used in the groupname
#if ang > 0 then it is used for the countersink angle
# cdia is the countersink diam, 'diam' is used for the actual hole as usual
    def cut(pt, dfactor, diam, cnt, ang, cdia, cdepth)
      Sketchup.active_model.start_operation "Cutting Plunge", true
      
      #puts "dfactor #{dfactor}"
      #puts " diam #{diam} #{diam.class}"
      #puts " cnt #{cnt}"
      #puts " ang #{ang}  #{ang.class}"
      #puts " cdia #{cdia}   #{cdia.class}"
      #puts " cdepth #{cdepth}   #{cdepth.class}"
      rad = PlungeCut.radius
      if (diam > 0)
         #puts "PlungeCut cutting #{diam}"
         rad = diam / 2
      end
      entities = Sketchup.active_model.entities
      
      group = entities.add_group   # the hole will be a group, usually without a name
#      if (group)
#         puts "#{group}\n"
#      else
#         puts "Failed to add hole group"
#      end
      
#      group.name = "";
      if (cnt > 0)
         group.name = "PB" + cnt.to_s
      end
      
      end_pt = Geom::Point3d.new(pt.x + rad, pt.y, 0)
      newedges = group.entities.add_edges(pt, end_pt)
      vectz = Geom::Vector3d.new(0,0,-1)
      circleInner = group.entities.add_circle(pt, vectz, rad, 12)
      #group.entities.add_face(circleInner)
#      group.description = "Hole"
      if (ang > 0.0)
         group.description = 'countersink'
      end

      newedges[0].set_attribute(Dict_name, Dict_edge_type, Key_plunge_cut)
      if diam > 0 # if exists set the attribute
        #puts "set diam #{diam} #{diam.to_inch} #{diam.to_f} #{diam.class}"
        newedges[0].set_attribute(Dict_name, Dict_plunge_diameter, diam.to_f)
        if (PhlatScript.isMetric)  # add diam to group name
           group.name = group.name + "_diam_#{diam.to_mm}mm"
        else
           group.name = group.name + "_diam_#{diam}"
        end
      end
      if (ang > 0.0)
         #puts "angle > #{ang}"
         circleInner = group.entities.add_circle(pt, vectz, cdia/2, 8)
         #puts "set ang #{ang} #{ang.to_inch} #{ang.to_f} #{ang.class}"
         newedges[0].set_attribute(Dict_name, Dict_csink_angle, ang.to_f)  #if this exists, then cut countersink
         #puts "set cdia #{cdia} #{cdia.to_inch} #{cdia.to_f} #{cdia.class}"
         newedges[0].set_attribute(Dict_name, Dict_csink_diam,  cdia.to_f)  #if this exists, then cut countersink
         newedges[0].material = Color_plunge_csink
         group.name = group.name + "_ca_#{ang.to_s}"
         group.name = group.name + "_cd_#{cdia.to_s}"
         dfactor = [PhlatScript.cutFactor, 100.0].max   #always at least 100% deep
      end   
      if (ang < 0.0)
         #puts "angle < #{ang}"
         circleInner = group.entities.add_circle(pt, vectz, cdia/2, 9)
         circleInner.each { |e|
            e.material = Color_plunge_cbore
            }
         newedges[0].set_attribute(Dict_name, Dict_csink_angle, ang.to_f)  #if this < 0 , then cut counterbore
         newedges[0].set_attribute(Dict_name, Dict_csink_diam,  cdia.to_f)  
         newedges[0].set_attribute(Dict_name, Dict_cbore_depth,  cdepth.to_f)  
         newedges[0].material = Color_plunge_cbore
         group.name = group.name + "_cb_#{cdepth.to_s}"
         group.name = group.name + "_cd_#{cdia.to_s}"
         dfactor = [PhlatScript.cutFactor,100].max   #always at least 100% deep
      end   

      if (dfactor != PhlatScript.cutFactor) # if different set the attribute and color
         newedges[0].set_attribute(Dict_name, Dict_plunge_depth_factor, dfactor.to_s)  # class is float
         newedges[0].material = Color_plunge_cutd   if (ang == 0.0)
         if (PhlatScript.isMetric)      # add depth factor to group name
           group.name = group.name + "_depth_#{dfactor}"
         else
           group.name = group.name + "_depth_#{dfactor}"           
         end
      else
         newedges[0].material = Color_plunge_cut      if (ang == 0.0)
      end
      
      @edge = newedges[0]
      Sketchup.active_model.commit_operation
    end

    def x
      return self.position.x
    end

    def y
      return self.position.y
    end

    def erase
      dele = [@edge]
      @edge.vertices.each { |v|
        v.loops.each { |l|
          l.edges.each { |e|
            # make sure the connected edge is part of an arc where the center
            # is the same as the plunge
            c = e.curve
            if ((c) && (c.kind_of? Sketchup::ArcCurve) && (c.center == self.position))
              dele.push(e)
            end
          }
        }
      }
      Sketchup.active_model.entities.erase_entities dele
    end

    def cut_points(reverse=false)
      yield(self.position, self.cut_factor)
    end

    def cut_factor
      cf = @edge.get_attribute(Dict_name, Dict_plunge_depth_factor, -1).to_f
      #puts "cf #{cf} #{cf.class}"
      if (cf > -1.0) && (cf != PhlatScript.cutFactor)
         return cf
      else
         return PhlatScript.cutFactor
      end
    end

  #swarfer: if the attribute is set gcodeutil will know what to do with it
  # note that the .to_l in these functions will cause gcode generation to fail when 
  # regional settings has a comma for decimal separator, user has been warned!
  # since 1.3b this is stored as a float, but must return a length object
  # older code stored a string
    def diameter
      diam = @edge.get_attribute(Dict_name, Dict_plunge_diameter, -1.0)
      #puts "diam #{diam} #{diam.class}"
      if diam.class.to_s == 'Float'
         diam = diam.to_s + '"'    # force it to decimal inch string
         begin
            diam.to_l      # try to convert
         rescue
            if diam.match('.')
               diam = diam.gsub(/\./,',')   #swap separators if it failed
            else
               diam = diam.gsub(/,/,'.')
            end
         end
         #puts diam.to_l
      end
      return diam.to_l
    end

    def cdiameter   #return countersink diameter as a Length, stored as a decimal inch float, older code has strings
      diam = @edge.get_attribute(Dict_name, Dict_csink_diam, -1.0)
      #puts "cdiam #{diam} #{diam.class}"
      if diam.class.to_s == 'Float'
         diam = diam.to_s + '"'
      end   
      if !diam.match(/"|mm/)
         diam += '"'
      end
      begin
         diam.to_l
      rescue
         if diam.match('.')
            diam = diam.gsub(/\./,',')
         else
            diam = diam.gsub(/,/,'.')
         end
         #puts diam.to_l
      end
      #puts "   cdiam #{diam} #{diam.class}"
      return diam.to_l
    end

    def cdepth   #return counterbore depth as a Length
      depth = @edge.get_attribute(Dict_name, Dict_cbore_depth,  -1.0)  
      #puts " cdepth #{depth} #{depth.class}"
      depth = depth.to_s + '"'      if depth.class.to_s == 'Float'
      depth += '"'                  if !depth.match(/"|mm/)
      begin
         depth.to_l
      rescue
         if depth.match('.')
            depth = depth.gsub(/\./,',')
         else
            depth = depth.gsub(/,/,'.')
         end
      end
      return depth.to_l
    end
    
#if angle is set it will return > 0 - use it for countersink in gcodeutil.plungebore
   def angle
      ang = @edge.get_attribute(Dict_name, Dict_csink_angle, 0.0)  #yes, really 0 to indicate 'not set'
#      puts " ang #{ang} #{ang.class}"
      if ang.class.to_s == 'String'
         return ang.to_f  # should return a float
      else
         return ang
      end
   end

    # marks all entities as having been milled in gcodeutil
    def processed=(val)
      @edge.set_attribute(Dict_name, Dict_object_mark, val)
    end

    def processed
      return @edge.get_attribute(Dict_name, Dict_object_mark, false)
    end

    def position
      return @edge.vertices.first.position
    end

  end

end
# $Id$
# $Log: PlungeCut.rb $
# Revision 1.1  2013/05/22 16:02:40  david
# Initial revision
#
# Revision 1.2  2013/05/20 14:59:06  david
# change color when plunge cut not full depth
#
# Revision 1.1  2013/05/17 13:15:35  david
# Initial revision
#
