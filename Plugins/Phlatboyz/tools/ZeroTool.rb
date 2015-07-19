
require 'sketchup.rb'
require 'Phlatboyz/PhlatTool.rb'


module PhlatScript

   class ZeroTool < PhlatTool
    
      def initialize
         super()
         toolname = 'Zero tool'
         @tooltype=(PB_MENU_TOOLBAR)
         @tooltip="Set 0,0 offset"
         @statusText= "pick point within safe area for 0,0" 
         @menuItem="Zero Offset"
         @menuText="Zero Offset Pick"
         @largeIcon = "images/zerotool_large.png"
         @smallIcon = "images/zerotool_small.png"         
         
      end

      def reset(view)
         super
      end

      def onMouseMove(flags, x, y, view)
         if @ip.pick(view, x, y)
            view.invalidate
         end
      end
       
      def onLButtonDown(flags, x, y, view)
         puts "#{@ip.position}"
         safe_point3d_array = P.get_safe_area_point3d_array(Sketchup.active_model)
         x = @ip.position.x - safe_point3d_array[0].x
         y = @ip.position.y - safe_point3d_array[0].y
         puts "offset #{x.to_mm} #{y.to_mm}"
         PhlatScript.zerooffsetx = x
         PhlatScript.zerooffsety = y
#         np.y = @ip.position.y + v * @vspace
         P.draw_safe_area(Sketchup.active_model)
         reset(view)
      end

      def draw(view)
         preview(view, @ip.position)
      end

      def preview(v, point)
         #draw something at the point
         pts = Array.new
         pts << Geom::Point3d.new(point.x + 0.1 , point.y + 0.1, 0)
         pts << Geom::Point3d.new(point.x - 0.1 , point.y + 0.1, 0)
         pts << Geom::Point3d.new(point.x + 0.1 , point.y - 0.1, 0)
         pts << Geom::Point3d.new(point.x - 0.1 , point.y - 0.1, 0)
         pts << Geom::Point3d.new(point.x + 0.1 , point.y + 0.1, 0)
         v.draw_polyline(pts)
      end
      
      def statusText
      return "Select point for X0,Y0 position"
      end

   end

end
# $Id$
