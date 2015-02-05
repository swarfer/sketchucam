require 'Phlatboyz/PhlatTool.rb'

# $Id$
module PhlatScript

  module WebDialogX

    # Module used to extend UI::WebDialog base class to a local instance only.
    # Use:  webdialog_instance.extend(WebDialogX)
    def setCaption(id, caption)
      self.execute_script("setFormCaption('#{id}','#{caption}')")
    end

    def setValue(id, value)
      self.execute_script("setFormValue('#{id}','#{value}')")
    end
  end

  class ParametersTool < PhlatTool
    @dialogIsOpen = false
    # taken from ActionScript
    JS_ESCAPE_MAP  	=  	{ '\\' => '\\\\', '</' => '<\/', "\r\n" => '\n', "\n" => '\n', "\r" => '\n', '"' => '\\"', "'" => "\\'" }

    def escape_javascript(s)
      if s
        s.gsub(/(\\|<\/|\r\n|[\n\r"'])/) { JS_ESCAPE_MAP[$1] }
      else
        ''
      end
    end

    def format_length(s)
      escape_javascript(Sketchup.format_length(s))
    end

    def setValues(wd) # set values from ruby into java for given web_dialog(wd)
      wd.setCaption('spindlespeed_id', PhlatScript.getString("Spindle Speed"))
      wd.setValue('spindlespeed', PhlatScript.spindleSpeed)

      wd.setCaption('feedrate_id', PhlatScript.getString("Feed Rate"))
      wd.setValue('feedrate', format_length(PhlatScript.feedRate))

      wd.setCaption('plungerate_id', PhlatScript.getString("Plunge Rate"))
      wd.setValue('plungerate', format_length(PhlatScript.plungeRate))

      wd.setCaption('materialthickness_id', PhlatScript.getString("Material Thickness"))
      wd.setValue('materialthickness', format_length(PhlatScript.materialThickness))

      wd.setCaption('tabletop_id', PhlatScript.getString("Table top is Z-Zero"))
      wd.execute_script("setCheckbox('tabletop','"+PhlatScript.tabletop?.inspect()+"')")
      #ramping
      wd.setCaption('mustramp_id', PhlatScript.getString("Ramp in Z"))
      wd.execute_script("setCheckbox('mustramp','"+PhlatScript.mustramp?.inspect()+"')")
      wd.setCaption('rampangle_id', PhlatScript.getString("Ramp angle limit"))
      wd.setValue('rampangle', PhlatScript.rampangle)
      

      wd.setCaption('cutfactor_id', PhlatScript.getString("In/Outside Overcut Percentage"))
      wd.setValue('cutfactor', PhlatScript.cutFactor)

      wd.setCaption('bitdiameter_id', PhlatScript.getString("Bit Diameter"))
      wd.setValue('bitdiameter', format_length(PhlatScript.bitDiameter))

      wd.setCaption('tabwidth_id', PhlatScript.getString("Tab Width"))
      wd.setValue('tabwidth', format_length(PhlatScript.tabWidth))

      wd.setCaption('tabdepthfactor_id', PhlatScript.getString("Tab Depth Factor"))
      wd.setValue('tabdepthfactor', PhlatScript.tabDepth)

      wd.setCaption('safetravel_id', PhlatScript.getString("Safe Travel"))
      wd.setValue('safetravel', format_length(PhlatScript.safeTravel))

      wd.setCaption('safewidth_id', PhlatScript.getString("Safe Length"))
      wd.setValue('safewidth', format_length(PhlatScript.safeWidth))

      wd.setCaption('safeheight_id', PhlatScript.getString("Safe Width"))
      wd.setValue('safeheight', format_length(PhlatScript.safeHeight))

      wd.setCaption('overheadgantry_id', PhlatScript.getString("Overhead Gantry"))
      wd.execute_script("setCheckbox('overheadgantry','"+PhlatScript.useOverheadGantry?.inspect()+"')")

      wd.setCaption('multipass_id', PhlatScript.getString("Generate Multipass"))
      wd.execute_script("setCheckbox('multipass','"+PhlatScript.useMultipass?.inspect()+"')")

      wd.setCaption('multipassdepth_id', PhlatScript.getString("Multipass Depth"))
      wd.setValue('multipassdepth', format_length(PhlatScript.multipassDepth))
      if !PhlatScript.multipassEnabled?
        wd.execute_script("hideMultipass()")
      end

      wd.setCaption('gen3D_id', PhlatScript.getString("Generate 3D GCode"))
      wd.execute_script("setCheckbox('gen3D','"+PhlatScript.gen3D.inspect()+"')")

      wd.setCaption('stepover_id', PhlatScript.getString("StepOver Percentage"))
      wd.setValue('stepover', PhlatScript.stepover)

      wd.setCaption('showgplot_id', PhlatScript.getString("Show gplot"))
      wd.execute_script("setCheckbox('showgplot','"+PhlatScript.showGplot?.inspect()+"')")

      wd.setCaption('commenttext_id', PhlatScript.getString("Comment Remarks"))
      wd.execute_script("setEncodedFormValue('commenttext','"+PhlatScript.commentText+"','$/')")

      wd.setCaption('version_id', 'SketchUcam V' + $PhlatScriptExtension.version)
    end

    def saveValues(wd)  # put values from webdialog into phlatscript variables
      PhlatScript.spindleSpeed = wd.get_element_value("spindlespeed") # don't use parse_length for rpm
      PhlatScript.feedRate = Sketchup.parse_length(wd.get_element_value("feedrate"))
      PhlatScript.plungeRate = Sketchup.parse_length(wd.get_element_value("plungerate"))
      PhlatScript.materialThickness = Sketchup.parse_length(wd.get_element_value("materialthickness"))
      PhlatScript.cutFactor = wd.get_element_value("cutfactor") # don't use parse_length for percentages
      PhlatScript.bitDiameter = Sketchup.parse_length(wd.get_element_value("bitdiameter"))
      PhlatScript.tabWidth = Sketchup.parse_length(wd.get_element_value("tabwidth"))
      PhlatScript.tabDepth = wd.get_element_value("tabdepthfactor")
      PhlatScript.safeTravel = Sketchup.parse_length(wd.get_element_value("safetravel"))
      PhlatScript.safeWidth = Sketchup.parse_length(wd.get_element_value("safewidth"))
      PhlatScript.safeHeight = Sketchup.parse_length(wd.get_element_value("safeheight"))
      wd.execute_script("isChecked('overheadgantry')")
      PhlatScript.useOverheadGantry = (wd.get_element_value('checkbox_hidden') == "true") ? true : false

      if PhlatScript.multipassEnabled?
        wd.execute_script("isChecked('multipass')")
        PhlatScript.useMultipass = (wd.get_element_value('checkbox_hidden') == "true") ? true : false
        PhlatScript.multipassDepth = Sketchup.parse_length(wd.get_element_value("multipassdepth"))
      end
      wd.execute_script("isChecked('gen3D')")
      PhlatScript.gen3D = (wd.get_element_value('checkbox_hidden') == "true") ? true : false
      PhlatScript.stepover = wd.get_element_value("stepover")

      wd.execute_script("isChecked('showgplot')")
      PhlatScript.showGplot = (wd.get_element_value('checkbox_hidden') == "true") ? true : false

      wd.execute_script("isChecked('tabletop')")
      PhlatScript.tabletop = (wd.get_element_value('checkbox_hidden') == "true") ? true : false
#ramping
      wd.execute_script("isChecked('mustramp')")
      PhlatScript.mustramp = (wd.get_element_value('checkbox_hidden') == "true") ? true : false
      PhlatScript.rampangle = wd.get_element_value("rampangle")
      
      comment_text = wd.get_element_value("commenttext").delete("'\"")
      encoded_comment_text = ""
      comment_text.each_line { |line| encoded_comment_text += line.chomp()+"$/"}
      PhlatScript.commentText = encoded_comment_text.chop().chop()
    end #saveValues

   def select

      model = Sketchup.active_model

      if $phoptions.use_compatible_dialogs?
        # prompts
         prompts = [PhlatScript.getString("Spindle Speed"),
               PhlatScript.getString("Feed Rate"),
               PhlatScript.getString("Plunge Rate"),
               PhlatScript.getString("Material Thickness"),
               PhlatScript.getString("In/Outside Overcut Percentage") + " ",
               PhlatScript.getString("Bit Diameter"),
               PhlatScript.getString("Tab Width"),
               PhlatScript.getString("Tab Depth Factor"),
               PhlatScript.getString("Safe Travel"),
               PhlatScript.getString("Safe Length"),
               PhlatScript.getString("Safe Width"),
               PhlatScript.getString("Overhead Gantry")]

         if PhlatScript.multipassEnabled?
            prompts.push(PhlatScript.getString("Generate Multipass"))
            prompts.push(PhlatScript.getString("Multipass Depth"))
         end
         prompts.push(PhlatScript.getString("Generate 3D GCode"))
         prompts.push(PhlatScript.getString("StepOver Percentage"))
         prompts.push(PhlatScript.getString("Show Gcode"))
         prompts.push("Table top is Z Zero")
         prompts.push("Comment Remarks")

        # default values
         encoded_comment_text = PhlatScript.commentText.to_s

         defaults = [PhlatScript.spindleSpeed.to_s,
             Sketchup.format_length(PhlatScript.feedRate),
             Sketchup.format_length(PhlatScript.plungeRate),
             Sketchup.format_length(PhlatScript.materialThickness),
             PhlatScript.cutFactor.to_s,
             Sketchup.format_length(PhlatScript.bitDiameter),
             Sketchup.format_length(PhlatScript.tabWidth),
             PhlatScript.tabDepth.to_s,
             Sketchup.format_length(PhlatScript.safeTravel),
             Sketchup.format_length(PhlatScript.safeWidth),
             Sketchup.format_length(PhlatScript.safeHeight),
             PhlatScript.useOverheadGantry?.inspect()]

         if PhlatScript.multipassEnabled?
            defaults.push(PhlatScript.useMultipass?.inspect())
            defaults.push(Sketchup.format_length(PhlatScript.multipassDepth))
         end
         defaults.push(PhlatScript.gen3D.inspect())
         defaults.push(PhlatScript.stepover)
         defaults.push(PhlatScript.showGplot?.inspect())
         defaults.push(PhlatScript.tabletop?.inspect())
         defaults.push(encoded_comment_text)

         # dropdown options can be added here
         if PhlatScript.multipassEnabled?
            list = ["","","","","","","","","","","","false|true","false|true","","false|true","","false|true","false|true",""]
         else
            list = ["","","","","","","","","","","","false|true","false|true","","false|true","false|true",""]
         end

         input = UI.inputbox(prompts, defaults, list, PhlatScript.getString("Parameters"))
         # input is nil if user cancelled
         if (input)
            PhlatScript.spindleSpeed = input[0].to_i
            PhlatScript.feedRate    = Sketchup.parse_length(input[1]).to_f
            PhlatScript.plungeRate  = Sketchup.parse_length(input[2]).to_f
            PhlatScript.materialThickness = Sketchup.parse_length(input[3]).to_f
            PhlatScript.cutFactor = input[4].to_i
            PhlatScript.bitDiameter = Sketchup.parse_length(input[5]).to_f
            PhlatScript.tabWidth = Sketchup.parse_length(input[6]).to_f
            PhlatScript.tabDepth = input[7].to_i
            PhlatScript.safeTravel = Sketchup.parse_length(input[8]).to_f
            PhlatScript.safeWidth = Sketchup.parse_length(input[9])
            PhlatScript.safeHeight = Sketchup.parse_length(input[10])
            PhlatScript.useOverheadGantry = (input[11] == 'true')

            if PhlatScript.multipassEnabled?
               PhlatScript.useMultipass = (input[12] == 'true')
               PhlatScript.multipassDepth = Sketchup.parse_length(input[13]).to_f
               PhlatScript.gen3D = (input[14] == 'true')
               PhlatScript.stepover = input[15].to_f
               PhlatScript.showGplot = (input[16] == 'true')
               PhlatScript.tabletop = (input[17] == 'true')
               PhlatScript.commentText = input[18].to_s
            else
               PhlatScript.gen3D = (input[12] == 'true')
               PhlatScript.stepover = input[13].to_f
               PhlatScript.showGplot = (input[14] == 'true')
               PhlatScript.tabletop = (input[15] == 'true')
               PhlatScript.commentText = input[16].to_s
            end
         end # if input
      else #---------------------------webdialog--------------------------------------------
        view = model.active_view
        width = 550
        height = 715
        x = (view.vpwidth - width)/2
        y = (view.vpheight - height)/2
        x = 0 if x < 0
        y = 0 if y < 0
        params_dialog = UI::WebDialog.new(PhlatScript.getString("Parameters"), false, "Parameters", width, height, x, y, false)
        params_dialog.extend(WebDialogX)
        params_dialog.set_position(x, y)
        params_dialog.set_size(width, height)
        params_dialog.add_action_callback("phlatboyz_action_callback") do | web_dialog, action_name |
          model = Sketchup.active_model
          if(action_name == 'load_params')
            setValues(web_dialog)
          elsif(action_name == 'save')
            saveValues(web_dialog)
            params_dialog.close()
          elsif(action_name == 'cancel')
            params_dialog.close()
          elsif(action_name =='restore_defaults')
            web_dialog.setValue('spindlespeed', $phoptions.default_spindle_speed)
            web_dialog.setValue('feedrate', $phoptions.default_feed_rate)
            web_dialog.setValue('plungerate', $phoptions.default_plunge_rate)
            web_dialog.setValue('materialthickness', $phoptions.default_material_thickness)
            web_dialog.setValue('cutfactor', $phoptions.default_cut_depth_factor)
            web_dialog.setValue('bitdiameter', $phoptions.default_bit_diameter)
            web_dialog.setValue('tabwidth', $phoptions.default_tab_width)
            web_dialog.setValue('tabdepthfactor', $phoptions.default_tab_depth_factor)
            web_dialog.setValue('safetravel', $phoptions.default_safe_travel)
            web_dialog.setValue('safewidth', $phoptions.default_safe_width)
            web_dialog.setValue('safeheight', $phoptions.default_safe_height)
            web_dialog.setValue('commenttext', $phoptions.default_comment_remark)
            web_dialog.setValue('multipassdepth', $phoptions.default_multipass_depth)
            #web_dialog.setValue('gen3D',Default_gen3d)
            web_dialog.setValue('stepover',$phoptions.default_stepover)
            #web_dialog.setValue('showgplot',Default_show_gplot)

            web_dialog.execute_script("setCheckbox('overheadgantry','"+ $phoptions.default_overhead_gantry?.inspect()+"')")
            web_dialog.execute_script("setCheckbox('multipass','"+      $phoptions.default_multipass?.inspect()+"')")
            web_dialog.execute_script("setCheckbox('showgplot','"+      $phoptions.default_show_gplot?.inspect()+"')")
            web_dialog.execute_script("setCheckbox('gen3D','"+          $phoptions.default_gen3d?.inspect()+"')")
            web_dialog.execute_script("setCheckbox('tabletop','"+       $phoptions.default_tabletop?.inspect()+"')")

          elsif(action_name == 'pload')   # profile load
            ptool = ProfilesLoadTool.new()   # in ProfilesTool.rb
            ptool.select()                # gets the values into PhlatScript
            setValues(web_dialog)         # display them on the dialog
          elsif(action_name == 'psave')      # profile save
            saveValues(web_dialog)
            ptool = ProfilesSaveTool.new()
            ptool.select()
          elsif(action_name == 'pdelete')    # profile delete
            ptool = ProfilesDeleteTool.new()
            ptool.select()
          end #if actionname
        end  # webdialog actions

        params_dialog.set_on_close {
          @dialogIsOpen = false
        }

        set_param_web_dialog_file = Sketchup.find_support_file "setParamsWebDialog.html", "Plugins/Phlatboyz/html"
        if (set_param_web_dialog_file and (not @dialogIsOpen))
          params_dialog.set_file(set_param_web_dialog_file)
          @dialogIsOpen = true
          params_dialog.show()
        end
      end # if old dialog
    end # select

  end # class

end #module
