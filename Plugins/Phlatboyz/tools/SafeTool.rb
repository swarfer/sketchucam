
require 'sketchup.rb'
#require 'Phlatboyz/Constants.rb'
require 'Phlatboyz/PhlatTool.rb'

module PhlatScript

  class SafeTool < PhlatTool

    def initialize
      super
      @point_array = Array.new(5)
    end

    def onMouseMove(flags, x, y, view)
      ip = view.inputpoint x, y
      safeArrayFromInputPoint(ip)
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      ip = view.inputpoint x, y
      safeArrayFromInputPoint(ip)
      self.create_geometry(view)
      self.reset(view)
        # Clear any inference lock
        view.lock_inference
    end

    def safeArrayFromInputPoint(inputPoint)
      safe_array = P.get_safe_array()
      w = safe_array[2]
      h = safe_array[3]
      area_point3d_array = P._get_area_point3d_array(inputPoint.position.x, inputPoint.position.y, w, h)
      @point_array = area_point3d_array
      @point_array[4] = @point_array[0]
    end

    def draw(view)
      self.draw_geometry(view)
    end

    # Draw the geometry
    def draw_geometry(view)
      view.drawing_color = Color_safe_drawing
      view.line_stipple = "."
      #@ip.draw view
      view.draw_polyline @point_array
    end

    def create_geometry(view)
      model = view.model
      entities = model.entities

      model.start_operation "Creating Safe Area"

      x0 = @point_array[0].x
      y0 = @point_array[0].y
      w = @point_array[0].distance @point_array[1]
      h = @point_array[0].distance @point_array[3]

      P.set_safe_array(x0, y0, w, h, model)
      P.draw_safe_area(model)

      model.commit_operation
        #Sketchup::set_status_text "Fold Created", SB_VCB_LABEL
      Sketchup.send_action "selectSelectionTool:"

    end

    def statusText
      return "Select position for Safe Area"
    end

  end

end
