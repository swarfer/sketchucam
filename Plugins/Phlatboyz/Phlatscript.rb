# $Id: Phlatscript.rb 97 2014-02-14 13:49:00Z swarfer $
require('sketchup.rb')
require('extensions.rb')
require('langhandler.rb')
require('Phlatboyz/Observers.rb')

module PhlatScript

  @@AppChangeObserver = AppChangeObserver.new
  @@ModelChangeObserver = ModelChangeObserver.new

   #place a copy of the distributed strings file into Resources
   def PhlatScript.copyStrings(from)
      #this line generates the name even if the file does not exist
      ofile = Sketchup.find_support_file("en-US", "Resources" ) + "/PhlatBoyz.strings"
      out_file = File.new(ofile, "w")
      in_file = File.open(from)
      in_file.each_line { |line|
         out_file.puts(line)
         }
      out_file.close
      in_file.close
   end

#make sure we have the strings file in the right place, sketchup/resources/en-US
   myc = Sketchup.find_support_file("en-US/PhlatBoyz.strings", "Resources" )  #fails if it doesn't exist
   thefile = Sketchup.find_support_file("Phlatboyz/Resources/PhlatBoyz.strings", "Plugins" )
   if (myc == nil)  #file does nt exist
      if thefile != nil
         PhlatScript.copyStrings(thefile)
      end
   else
         #file exists, check for correct version
      correctversion = "1.03"  #this must match the version string in the file!
      result = open(myc) { |f| f.grep(/stringversion/) }
      if result != []  #found the string, check version
         if !result[0].match(correctversion)  #version mismatch
            PhlatScript.copyStrings(thefile)
         end
      else  #not found, copy the new file
         PhlatScript.copyStrings(thefile)
      end
   end

  @@phlatboyzStrings = LanguageHandler.new("PhlatBoyz.strings")
  @@phlatboyz_tools_submenu = nil
  @@Loaded = false
  @@tools = []
  @@cuts = []

  Sketchup.add_observer(@@AppChangeObserver)

  def PhlatScript.setModelOptions(model)
    model.start_operation "PhlatscripT Properties", true
    begin
      model.rendering_options["EdgeColorMode"] = Rendering_edge_color_mode

      # Define "Hole" material
      addHole = true
      model.materials.each { |material| addHole = false if material.name == "Hole" }
      if (addHole)
        m = model.materials.add "Hole"
        m.alpha = 0.5
        m.color = "white"
      end
    rescue
      model.abort_operation
    end
    model.commit_operation
  end

  def PhlatScript.doSave(model)
      setModelOptions(model)
  end

  def PhlatScript.modelChangeObserver
    return @@ModelChangeObserver
  end

  def PhlatScript.getString(s)
    return @@phlatboyzStrings.GetString(s)
  end

  def PhlatScript.load
    Sketchup.active_model.add_observer(PhlatScript.modelChangeObserver)
    return if @@Loaded
    loadTools
      UI.add_context_menu_handler do | menu | contextMenuHandler(menu) end
    setModelOptions(Sketchup.active_model)
    @@Loaded = true
  end

  def PhlatScript.contextMenuHandler(menu)
    submenu = menu.add_submenu(PhlatScript.getString("Phlat Edge"))
    @@tools.each { |tool|
      # don't process the tool if it doesn't advertise context menus
      next if ((tool.tooltype & PB_MENU_CONTEXT) != PB_MENU_CONTEXT)
      items = tool.getContextMenuItems
      next if !items
      items = [items] if (!items.kind_of?(Array))
      return if (items.length < 0)
      items.each { |item|
        if item.to_s.eql? '--'
          submenu.add_separator
        else
          submenu.add_item(PhlatScript.getString(item.to_s)) { tool.onContextMenu(item.to_s) }
        end
      }
    }
   # add new context menu item to apply "Hole" face texture
   submenu.add_item('Hole Texture') { PhlatScript.apply_hole_texture(Sketchup.active_model.selection) }
  end

  def PhlatScript.get_fold_depth_factor(model=Sketchup.active_model)
    return model.get_attribute(Dict_name, Dict_fold_depth_factor, Default_fold_depth_factor)
  end

  def PhlatScript.set_fold_depth_factor(in_factor, model=Sketchup.active_model)
    f = in_factor % 1000
    (f = Max_fold_depth_factor) if (f > Max_fold_depth_factor)
    model.set_attribute Dict_name, Dict_fold_depth_factor, f
  end

  def PhlatScript.display_fold_depth_factor
    #Sketchup::set_status_text "depth percent", SB_VCB_LABEL
    Sketchup::set_status_text(PhlatScript.getString("depth percent"), SB_VCB_LABEL)
    fold_factor = get_fold_depth_factor()
    Sketchup::set_status_text("#{fold_factor.to_s}%", SB_VCB_VALUE)
  end

  def PhlatScript.tools
    @@tools
  end

  def PhlatScript.cuts
    @@cuts
  end

  def PhlatScript.sketchup_file
    p = Sketchup.active_model.path
    if p.empty?
      return nil
    else
      return File.basename(p)
    end
  end

  def PhlatScript.cncFileName
    model=Sketchup.active_model
    begin
      p = Sketchup.active_model.path
      if p.empty?
        default_filename = Default_file_name
      else
        default_filename = File.basename(p, ".skp")+ Default_file_ext
      end
    rescue
      UI.messagebox "Exception in PhlatScript.cncFileName "+$!
    end
    filename = model.get_attribute(Dict_name, Dict_output_file_name, default_filename)
    filename = (filename == Default_file_name) ? default_filename : filename
    #UI.messagebox("default_filename: #{default_filename} filename: #{filename}")
    return filename
  end

  def PhlatScript.cncFileName=(filename)
    Sketchup.active_model.set_attribute(Dict_name, Dict_output_file_name, filename)
  end

  def PhlatScript.cncFileDir
    return Sketchup.active_model.get_attribute(Dict_name, Dict_output_directory_name, Default_directory_name)
  end

  def PhlatScript.cncFileDir=(dir)
    output_directory_name = Sketchup.active_model.set_attribute Dict_name, Dict_output_directory_name, dir
  end

  def PhlatScript.cncFile=(full_filename)
    begin
      file_basename = nil
      file_dirname = nil
      status = (full_filename != nil)
      if(status)
        file_basename = File.basename(full_filename)
        status = Sketchup.is_valid_filename?(file_basename)
        if(status)
          file_dirname = File.dirname(full_filename)
          status = File.directory?(file_dirname)
        end
      end
      if(status)
        result_array = Array.new
        self.cncFileDir = file_dirname + File::SEPARATOR
        self.cncFileName = file_basename
      else
        UI.messagebox(@@phlatboyzStrings.GetString("Filename Error") + ": " + ((full_filename == nil) ? "nil" : full_filename))
      end
    rescue
      UI.messagebox "Exception retrieving GCode file name "+$!
      nil
    end
  end


  # Parameters

  def PhlatScript.spindleSpeed
    Sketchup.active_model.get_attribute(Dict_name, Dict_spindle_speed, Default_spindle_speed)
  end

  def PhlatScript.spindleSpeed=(sspeed)
    Sketchup.active_model.set_attribute(Dict_name, Dict_spindle_speed, sspeed.to_i)
  end

  def PhlatScript.feedRate
    Sketchup.active_model.get_attribute(Dict_name, Dict_feed_rate, Default_feed_rate)
  end

  def PhlatScript.feedRate=(frate)
    Sketchup.active_model.set_attribute(Dict_name, Dict_feed_rate, frate)
  end

  def PhlatScript.plungeRate
    Sketchup.active_model.get_attribute(Dict_name, Dict_plunge_rate, Default_plunge_rate)
  end

  def PhlatScript.plungeRate=(prate)
    Sketchup.active_model.set_attribute(Dict_name, Dict_plunge_rate, prate)
  end

  def PhlatScript.safeTravel        # Safe Travel Height
        Sketchup.active_model.get_attribute(Dict_name, Dict_safe_travel, Default_safe_travel)
  end

  def PhlatScript.safeTravel=(st)
    Sketchup.active_model.set_attribute(Dict_name, Dict_safe_travel, st)
  end

  def PhlatScript.materialThickness
    Sketchup.active_model.get_attribute(Dict_name, Dict_material_thickness, Default_material_thickness)
  end

  def PhlatScript.materialThickness=(mthickness)
    Sketchup.active_model.set_attribute(Dict_name, Dict_material_thickness, mthickness)
  end

  def PhlatScript.cutFactor     # Inside/Outside Overcut %
    Sketchup.active_model.get_attribute(Dict_name, Dict_cut_depth_factor, Default_cut_depth_factor)
  end

  def PhlatScript.cutFactor=(cfactor)
    Sketchup.active_model.set_attribute(Dict_name, Dict_cut_depth_factor, cfactor.to_i)
  end

  def PhlatScript.bitDiameter
    Sketchup.active_model.get_attribute(Dict_name, Dict_bit_diameter, Default_bit_diameter)
  end

  def PhlatScript.bitDiameter=(bdiameter)
    Sketchup.active_model.set_attribute(Dict_name, Dict_bit_diameter, bdiameter)
  end

  def PhlatScript.tabWidth
    Sketchup.active_model.get_attribute(Dict_name, Dict_tab_width, Default_tab_width)
  end

  def PhlatScript.tabWidth=(twidth)
    Sketchup.active_model.set_attribute(Dict_name, Dict_tab_width, twidth)
  end

  def PhlatScript.tabDepth     # Tab Depth (% of what is cut away)
    Sketchup.active_model.get_attribute(Dict_name, Dict_tab_depth_factor, Default_tab_depth_factor)
  end

  def PhlatScript.tabDepth=(tdepth)
    Sketchup.active_model.set_attribute(Dict_name, Dict_tab_depth_factor, [tdepth.to_i, 80].min)
  end

  def PhlatScript.safeWidth      # Safe Area Length (Phlatprinter X axis)
    Sketchup.active_model.get_attribute(Dict_name, Dict_safe_width, Default_safe_width)
  end

  def PhlatScript.safeWidth=(swidth)
    if swidth != PhlatScript.safeWidth then
      changed = true
    end
    Sketchup.active_model.set_attribute(Dict_name, Dict_safe_width, swidth)
    if Always_show_safearea then
      draw_safe_area(Sketchup.active_model)
    elsif changed == true then
      draw_safe_area(Sketchup.active_model)
    end
  end

  def PhlatScript.safeHeight      # Safe Area Width (Phlatprinter Y axis)
    Sketchup.active_model.get_attribute(Dict_name, Dict_safe_height, Default_safe_height)
  end

  def PhlatScript.safeHeight=(sheight)
                if sheight != PhlatScript.safeHeight then changed = true end
    Sketchup.active_model.set_attribute(Dict_name, Dict_safe_height, sheight)
                if Always_show_safearea then draw_safe_area(Sketchup.active_model)
                elsif changed == true then draw_safe_area(Sketchup.active_model) end
  end

  def PhlatScript.useOverheadGantry?
    Sketchup.active_model.get_attribute(Dict_name, Dict_overhead_gantry, Default_overhead_gantry)
  end

  def PhlatScript.useOverheadGantry=(og)
    Sketchup.active_model.set_attribute(Dict_name, Dict_overhead_gantry, og)
  end
  
  def PhlatScript.PocketDirection?
    Sketchup.active_model.get_attribute(Dict_name, Dict_pocket_direction, Default_pocket_direction)
  end
  
  def PhlatScript.PocketDirection=(newd)
    Sketchup.active_model.set_attribute(Dict_name, Dict_pocket_direction, newd)
  end
  
  def PhlatScript.multipassEnabled?
    Use_multipass
  end

  #swarfer, Phlat3d needs to know
  def PhlatScript.useexactpath?
    Use_exact_path
  end
  
  # pockettool needs to know, normally false
  def PhlatScript.usePocketcw?
    Use_pocket_CW
  end
  
  # used in phlatmill
   def PhlatScript.usePlungeCW?
      Use_plunge_CW
   end
   
   def PhlatScript.UseOutfeed?
      Use_outfeed
   end
   
  #swarfer - if true gplot will be called after gcode generation
  def PhlatScript.showGplot?
    Sketchup.active_model.get_attribute(Dict_name, Dict_show_gplot, Default_show_gplot)
  end

  def PhlatScript.showGplot=(state)
    Sketchup.active_model.set_attribute(Dict_name, Dict_show_gplot, state)
  end

  def PhlatScript.useMultipass?
    Use_multipass ? Sketchup.active_model.get_attribute(Dict_name, Dict_multipass, Default_multipass) : false
  end

  def PhlatScript.useMultipass=(mp)
    Sketchup.active_model.set_attribute(Dict_name, Dict_multipass, mp)
  end

  def PhlatScript.multipassDepth
    Sketchup.active_model.get_attribute(Dict_name, Dict_multipass_depth, Default_multipass_depth)
  end

  def PhlatScript.multipassDepth=(mdepth)
    Sketchup.active_model.set_attribute(Dict_name, Dict_multipass_depth, mdepth)
  end

  def PhlatScript.commentText
    Sketchup.active_model.get_attribute(Dict_name, Dict_comment_text, Default_comment_remark).to_s
  end

  def PhlatScript.commentText=(ctext)
    Sketchup.active_model.set_attribute(Dict_name, Dict_comment_text, ctext)
  end

  def PhlatScript.gen3D
    Sketchup.active_model.get_attribute(Dict_name, Dict_gen3d, Default_gen3d)
        end

  def PhlatScript.gen3D=(gen3D)
    Sketchup.active_model.set_attribute(Dict_name, Dict_gen3d, gen3D)
  end

        def PhlatScript.stepover
                Sketchup.active_model.get_attribute(Dict_name, Dict_stepover, Default_stepover)
  end

  def PhlatScript.stepover=(stepover)
                Sketchup.active_model.set_attribute(Dict_name, Dict_stepover, stepover.to_i)
  end

  def PhlatScript.safeAreaArray=(sarea)
    safe_x = Sketchup.active_model.get_attribute(Dict_name, Dict_safe_origin_x, Default_safe_origin_x).to_f
    safe_y = Sketchup.active_model.get_attribute(Dict_name, Dict_safe_origin_y, Default_safe_origin_y).to_f
    safe_w = Sketchup.parse_length(params_dialog.get_element_value("safewidth")).to_f
    safe_h = Sketchup.parse_length(params_dialog.get_element_value("safeheight")).to_f
    Sketchup.active_model.set_attribute(Dict_name, Dict_safe_origin_x, safe_x)
    Sketchup.active_model.set_attribute(Dict_name, Dict_safe_origin_y, safe_y)
  end

  def PhlatScript.checkParens(text, field)
    if ((text.include? "(") || (text.include? ")")) then
      UI.messagebox(PhlatScript.getString("error_parens") % field)
      return true
    else
      return false
    end
  end

  private

  def PhlatScript.loadTools
    @@commandToolbar = UI::Toolbar.new(getString("Phlatboyz"))
    add_separator_to_menu("Tools")
    @@phlatboyz_tools_submenu = UI.menu("Tools").add_submenu(getString("Phlatboyz"))

    require 'Phlatboyz/tools/ParametersTool.rb'
    addToolItem(ParametersTool.new())
   
    require 'Phlatboyz/tools/ProfilesTool.rb'
    addToolItem(ProfilesSaveTool.new())
    addToolItem(ProfilesLoadTool.new() )
    addToolItem(ProfilesDeleteTool.new() )

    @@phlatboyz_tools_submenu.add_separator

    require 'Phlatboyz/tools/CutTool.rb'
    addToolItem(OutsideCutTool.new)
    addToolItem(InsideCutTool.new)

    require 'Phlatboyz/tools/TabTool.rb'
    addToolItem(TabTool.new())

    require 'Phlatboyz/tools/FoldTool.rb'
    addToolItem(FoldTool.new())

    require 'Phlatboyz/tools/PlungeTool.rb'
    addToolItem(PlungeTool.new())

    require 'Phlatboyz/tools/CenterLineTool.rb'
    addToolItem(CenterLineTool.new())

    require 'Phlatboyz/tools/PhPocketTool.rb'
    addToolItem(PocketTool.new())


    require 'Phlatboyz/tools/EraseTool.rb'
    addToolItem(EraseTool.new())

    require 'Phlatboyz/tools/PhlattenTool.rb'
    addToolItem(PhlattenTool.new())

    require 'Phlatboyz/tools/SafeTool.rb'
    addToolItem(SafeTool.new())

    require 'Phlatboyz/tools/Ky_Reorder_Groups.rb'
    addToolItem(Ky_Reorder_Groups.new())
         #also add this to the Plugins menu
    label = 'Kyyu Reorder Groups'
    if $PhlatScript_PlugName
      $PhlatScript_PlugName.add_item(label) { Sketchup.active_model.select_tool Ky_Reorder_Groups.new }
    else
      $PhlatScript_PlugName = UI.menu('Plugins').add_submenu('PhlatPlugins')
      $PhlatScript_PlugName.add_item(label) { Sketchup.active_model.select_tool Ky_Reorder_Groups.new }
    end

    require 'Phlatboyz/tools/GcodeUtil.rb'
    addToolItem(GcodeUtil.new())

        @@phlatboyz_tools_submenu.add_separator
    require 'Phlatboyz/tools/HomepageTool.rb'
    addToolItem(HomepageTool.new())

    require 'Phlatboyz/tools/HelpTool.rb'
    addToolItem(HelpTool.new())
    addToolItem( SummaryTool.new() )
    addToolItem( DisplayProfileFolderTool.new() )

#    require 'Phlatboyz/tools/TestTool.rb'
#    addToolItem(TestTool.new())
    @@commandToolbar.show
  end

   def PhlatScript.addToolItem(tool)
      cmd = UI::Command.new(tool.menuItem) { tool.select }
      cmd.tooltip = tool.tooltip
      cmd.status_bar_text = tool.statusText
      cmd.menu_text = tool.menuText
      @@phlatboyz_tools_submenu.add_item(cmd) if ((tool.tooltype & PB_MENU_MENU) == PB_MENU_MENU)
      if ((tool.tooltype & PB_MENU_TOOLBAR) == PB_MENU_TOOLBAR)
         cmd.large_icon = tool.largeIcon  # only need these for a toolbar item
         cmd.small_icon = tool.smallIcon
         @@commandToolbar.add_item(cmd) 
      end   
      @@tools.push(tool)
      @@cuts.push(tool.cut_class) if tool.cut_class
   end

end
