#module to allow user to change default options without needing to edit any file.
# this will read Constants.rb and use those values to populate the options class
# then, if MyOptions.ini exists it will read that and override the settings in the options class
# everywhere that the old Default globals are used must be changed to use the options class values
# $Id$

require 'PhlatBoyz/Constants.rb'

require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/utils/SketchupDirectoryUtils.rb'
require('Phlatboyz/utils/IniParser.rb')


module PhlatScript

   class OptionsWriter < Hashable  # sets the values in the right format for reading back units

      def initialize(phoptions)
         #file
         @default_file_name = phoptions.default_file_name.to_s
         @default_file_ext = phoptions.default_file_ext.to_s
         @default_directory_name = phoptions.default_directory_name.to_s

         #misc
         @default_comment_remark = phoptions.default_comment_remark.to_s

         @default_gen3d =        (phoptions.default_gen3d? ? '1' : '0')
         @default_show_gplot =   (phoptions.default_show_gplot? ? '1' : '0')
         @default_tabletop =     (phoptions.default_tabletop? ? '1' : '0')
         @use_compatible_dialogs = (phoptions.use_compatible_dialogs? ? '1' : '0')
         #tools
         @default_spindle_speed = phoptions.default_spindle_speed.to_i.to_s
         @default_feed_rate =     PhlatScript.conformat(phoptions.default_feed_rate)
         @default_plunge_rate =   PhlatScript.conformat(phoptions.default_plunge_rate)
         @default_safe_travel =   PhlatScript.conformat(phoptions.default_safe_travel)
         @default_material_thickness = PhlatScript.conformat(phoptions.default_material_thickness)
         @default_cut_depth_factor   = phoptions.default_cut_depth_factor.to_i.to_s
         @default_bit_diameter      = PhlatScript.conformat(phoptions.default_bit_diameter)
         @default_tab_width         = PhlatScript.conformat(phoptions.default_tab_width)
         @default_tab_depth_factor  = phoptions.default_tab_depth_factor.to_i.to_s
         @default_vtabs             = (phoptions.default_vtabs? ? '1' : '0')
         @default_fold_depth_factor = phoptions.default_fold_depth_factor.to_i.to_s
         @default_pocket_depth_factor = phoptions.default_pocket_depth_factor.to_i.to_s
         @default_pocket_direction  = (phoptions.default_pocket_direction? ? '1' : '0')
      #machine
         @default_safe_origin_x  =  PhlatScript.conformat(phoptions.default_safe_origin_x)
         @default_safe_origin_y  =  PhlatScript.conformat(phoptions.default_safe_origin_y)
         @default_safe_width     =  PhlatScript.conformat(phoptions.default_safe_width)
         @default_safe_height    =  PhlatScript.conformat(phoptions.default_safe_height)
         @default_overhead_gantry =  (phoptions.default_overhead_gantry? ? '1' : '0')
         @default_multipass      =   (phoptions.default_multipass? ? '1' : '0')
         @default_multipass_depth =  PhlatScript.conformat(phoptions.default_multipass_depth)
         @default_stepover       =   phoptions.default_stepover.to_i.to_s
         @min_z                  =   PhlatScript.conformat(phoptions.min_z)
         @max_z                  =   PhlatScript.conformat(phoptions.max_z)
      #features
         @use_vtab_speed_limit   =   (phoptions.use_vtab_speed_limit? ? '1' : '0')
         @use_exact_path         =   (phoptions.use_exact_path? ? '1' : '0')
         @always_show_safearea   =   (phoptions.always_show_safearea? ? '1' : '0')
         @use_reduced_safe_height =  (phoptions.use_reduced_safe_height? ? '1' : '0')
         @use_pocket_cw          =   (phoptions.use_pocket_cw? ? '1' : '0')
         @use_plunge_cw          =   (phoptions.use_plunge_cw? ? '1' : '0')
         @use_outfeed            =   (phoptions.use_outfeed? ? '1' : '0')
         @profile_save_material_thickness =   (phoptions.profile_save_material_thickness? ? '1' : '0')
         @use_home_height        =   (phoptions.use_home_height? ? '1' : '0')
         @default_home_height    =   PhlatScript.conformat(phoptions.default_home_height)
         @use_end_position       =   (phoptions.use_end_position? ? '1' : '0')
         @end_x                  =   PhlatScript.conformat(phoptions.end_x)   
         @end_y                  =   PhlatScript.conformat(phoptions.end_y)
         @use_fuzzy_holes        =   (phoptions.use_fuzzy_holes? ? '1' : '0')
      end
   end

   class Options
      def initialize

         @default_file_name = Default_file_name
         @default_file_ext = Default_file_ext
         @default_directory_name = Default_directory_name
         #misc
         @default_comment_remark = Default_comment_remark
         @default_gen3d = Default_gen3d
         @default_show_gplot = Default_show_gplot
         @default_tabletop = Default_tabletop
         @use_compatible_dialogs = Use_compatible_dialogs
         #tools
         @default_spindle_speed = Default_spindle_speed
         @default_feed_rate = Default_feed_rate
         @default_plunge_rate = Default_plunge_rate
         @default_safe_travel = Default_safe_travel
         @default_material_thickness = Default_material_thickness
         @default_cut_depth_factor = Default_cut_depth_factor
         @default_bit_diameter = Default_bit_diameter
         @default_tab_width = Default_tab_width
         @default_tab_depth_factor = Default_tab_depth_factor
         @default_vtabs = Default_vtabs
         @default_fold_depth_factor = Default_fold_depth_factor
         @default_pocket_depth_factor = Default_pocket_depth_factor
         @default_pocket_direction = Default_pocket_direction
         #machine
         @default_safe_origin_x = Default_safe_origin_x
         @default_safe_origin_y = Default_safe_origin_y
         @default_safe_width = Default_safe_width
         @default_safe_height = Default_safe_height
         @default_overhead_gantry = Default_overhead_gantry
         @default_multipass = Default_multipass
         @default_multipass_depth = Default_multipass_depth
         @default_stepover = Default_stepover
         @min_z = Min_z
         @max_z = Max_z
         #features
         @use_vtab_speed_limit = Use_vtab_speed_limit
         @use_exact_path = Use_exact_path
         @always_show_safearea = Always_show_safearea
         @use_reduced_safe_height = Use_reduced_safe_height
         @use_pocket_cw = Use_pocket_CW
         @use_plunge_cw = Use_plunge_CW
         @use_outfeed = Use_outfeed
         @profile_save_material_thickness = Profile_save_material_thickness
         @use_home_height = Use_Home_Height
         @default_home_height = Default_Home_Height
         @use_end_position       =  false
         @end_x                  =  0   
         @end_y                  =  0
         @use_fuzzy_holes = true

         # if MyOptions.ini exists then read it
         path = PhlatScript.toolsProfilesPath()

         filePath = File.join(path , 'MyOptions.ini')
         if File.exist?(filePath)
            ini = IniParser.new()
            sections = ini.parseFileAtPath(filePath)
            optin = sections['Options']
         #file

            @default_file_name = optin['default_file_name']            if (optin.has_key?('default_file_name'))
            @default_file_ext  = optin['default_file_ext']             if (optin.has_key?('default_file_ext'))
            @default_directory_name  = optin['default_directory_name'] if (optin.has_key?('default_directory_name'))
         #misc
            @default_comment_remark = optin['default_comment_remark']  if (optin.has_key?('default_comment_remark'))
            value = -1
            value = getvalue(optin['default_gen3d'])                if (optin.has_key?('default_gen3d'))
            @default_gen3d = value > 0 ? true :  false              if (value != -1)
            value = -1
            value = getvalue(optin['default_show_gplot'])                if (optin.has_key?('default_show_gplot'))
            @default_show_gplot = value > 0 ? true :  false              if (value != -1)
            value = -1
            value = getvalue(optin['default_tabletop'])                if (optin.has_key?('default_tabletop'))
            @default_tabletop = value > 0 ? true :  false              if (value != -1)
            value = -1
            value = getvalue(optin['use_compatible_dialogs'])                if (optin.has_key?('use_compatible_dialogs'))
            @use_compatible_dialogs = value > 0 ? true :  false              if (value != -1)

         #tools
            @default_spindle_speed = getvalue(optin['default_spindle_speed'])    if (optin.has_key?('default_spindle_speed'))
            @default_feed_rate = getvalue(optin['default_feed_rate'])            if (optin.has_key?('default_feed_rate'))
            @default_plunge_rate = getvalue(optin['default_plunge_rate'])        if (optin.has_key?('default_plunge_rate'))
            @default_safe_travel = getvalue(optin['default_safe_travel'])        if (optin.has_key?('default_safe_travel'))
            @default_material_thickness = getvalue(optin['default_material_thickness'])    if (optin.has_key?('default_material_thickness'))
            @default_cut_depth_factor = getvalue(optin['default_cut_depth_factor'])    if (optin.has_key?('default_cut_depth_factor'))
            @default_bit_diameter = getvalue(optin['default_bit_diameter'])      if (optin.has_key?('default_bit_diameter'))
            @default_tab_width = getvalue(optin['default_tab_width'])            if (optin.has_key?('default_tab_width'))
            @default_tab_depth_factor = getvalue(optin['default_tab_depth_factor'])    if (optin.has_key?('default_tab_depth_factor'))
            # Default_vtabs?
            value = -1
            value = getvalue(optin['default_vtabs'])                if (optin.has_key?('default_vtabs'))
            @default_vtabs = value > 0 ? true :  false              if (value != -1)

            @default_fold_depth_factor = getvalue(optin['default_fold_depth_factor'])     if (optin.has_key?('default_fold_depth_factor'))
            @default_pocket_depth_factor = getvalue(optin['default_pocket_depth_factor']) if (optin.has_key?('default_pocket_depth_factor'))
            # Default_pocket_direction?
            value = -1
            value = getvalue(optin['default_pocket_direction'])                if (optin.has_key?('default_pocket_direction'))
            @default_pocket_direction = value > 0 ? true :  false              if (value != -1)
         #machine
            @default_safe_origin_x = getvalue(optin['default_safe_origin_x'])    if (optin.has_key?('default_safe_origin_x'))
            @default_safe_origin_y = getvalue(optin['default_safe_origin_y'])    if (optin.has_key?('default_safe_origin_y'))
            @default_safe_width = getvalue(optin['default_safe_width'])    if (optin.has_key?('default_safe_width'))
            @default_safe_height = getvalue(optin['default_safe_height'])    if (optin.has_key?('default_safe_height'))
            # Default_overhead_gantry = false
            value = -1
            value = getvalue(optin['default_overhead_gantry'])                if (optin.has_key?('default_overhead_gantry'))
            @default_overhead_gantry = value > 0 ? true :  false              if (value != -1)

            # Default_multipass = false
            value = -1
            value = getvalue(optin['default_multipass'])                if (optin.has_key?('default_multipass'))
            @default_multipass = value > 0 ? true :  false              if (value != -1)

            @default_multipass_depth = getvalue(optin['default_multipass_depth'])    if (optin.has_key?('default_multipass_depth'))
            @default_stepover = optin['default_stepover']            if (optin.has_key?('default_stepover'))
            @min_z = getvalue(optin['min_z'])            if (optin.has_key?('min_z'))
            @max_z = getvalue(optin['max_z'])            if (optin.has_key?('max_z'))
         #features
         # Use_vtab_speed_limit = false
            value = -1
            value = getvalue(optin['use_vtab_speed_limit'])                if (optin.has_key?('use_vtab_speed_limit'))
            @use_vtab_speed_limit = value > 0 ? true :  false              if (value != -1)

         # Use_exact_path = false
            value = -1
            value = getvalue(optin['use_exact_path'])                if (optin.has_key?('use_exact_path'))
            @use_exact_path = value > 0 ? true :  false              if (value != -1)

         # Always_show_safearea = true
            value = -1
            value = getvalue(optin['always_show_safearea'])                if (optin.has_key?('always_show_safearea'))
            @always_show_safearea = value > 0 ? true :  false              if (value != -1)

         # Use_reduced_safe_height = true
            value = -1
            value = getvalue(optin['use_reduced_safe_height'])                if (optin.has_key?('use_reduced_safe_height'))
            @use_reduced_safe_height = value > 0 ? true :  false              if (value != -1)

         # Use_pocket_CW = false
            value = -1
            value = getvalue(optin['use_pocket_cw'])                if (optin.has_key?('use_pocket_cw'))
            @use_pocket_cw = value > 0 ? true :  false              if (value != -1)

         # Use_plunge_CW = false
            value = -1
            value = getvalue(optin['use_plunge_cw'])                if (optin.has_key?('use_plunge_cw'))
            @use_plunge_cw = value > 0 ? true :  false              if (value != -1)

         # Use_outfeed = false
            value = -1
            value = getvalue(optin['use_outfeed'])                if (optin.has_key?('use_outfeed'))
            @use_outfeed = value > 0 ? true :  false              if (value != -1)

         # Profile_save_material_thickness = false
            value = -1
            value = getvalue(optin['profile_save_material_thickness'])                if (optin.has_key?('profile_save_material_thickness'))
            @profile_save_material_thickness = value > 0 ? true :  false              if (value != -1)

         # Use_Home_Height = false
            value = -1
            value = getvalue(optin['use_home_height'])                if (optin.has_key?('use_home_height'))
            @use_home_height = value > 0 ? true :  false              if (value != -1)

            @default_home_height = getvalue(optin['default_home_height'])    if (optin.has_key?('default_home_height'))
         #use_end_position

            value = -1
            value = getvalue(optin['use_end_position'])                if (optin.has_key?('use_end_position'))
            @use_end_position = value > 0 ? true :  false             if (value != -1)

            @end_x            =   getvalue(optin['end_x'])    if (optin.has_key?('end_x'))   
            @end_y            =   getvalue(optin['end_y'])    if (optin.has_key?('end_y'))
         #use_fuzzy_holes
            value = -1
            value = getvalue(optin['use_fuzzy_holes'])                if (optin.has_key?('use_fuzzy_holes'))
            @use_fuzzy_holes = value > 0 ? true :  false              if (value != -1)

         end

      end #initialize

# retrieve a constant value from the str, observing units of measurement
      def getvalue(str)
         value = 0
         if str
            if str.index('.mm')
               value = str.gsub('.mm','').to_f / 25.4    # to_l does not get it right when drawing is metric
               #puts "mm to inch #{value}"
            else
               if str.index('.inch')
                  value = str.gsub('.inch','').to_f
               else
                  if str == 'true'
                     value = 1
                  else
                     if str == 'false'
                        value = 0
                     else
                        value = str.to_f
                     end
                  end
               end
            end
         end
         return value
      end


      def save
         path = PhlatScript.toolsProfilesPath()

         if not File.exist?(path)
            Dir.mkdir(path)
         end

         print "saving to path #{path}\n"

         if File.exist?(path)
            #write contents to ini file format - this will supplant current tpr format over time
            generator = IniGenerator.new()
            writeThis = OptionsWriter.new(self)
            ohash = {'Options' => writeThis.toHash}
            filePath = File.join(path, 'MyOptions.ini')
            generator.dumpHashMapToIni(ohash, filePath)
         else
            print "ERROR path does not exist #{path}"
         end
      end #save

      def default_file_name
         @default_file_name
      end
      def default_file_name=(newname)
         @default_file_name = newname
      end

      def default_file_ext
         @default_file_ext
      end
      def default_file_ext=(newext)
         @default_file_ext = newext
      end

      def default_directory_name
         @default_directory_name
      end
      def default_directory_name=(newname)
         @default_directory_name = newname
      end

      def default_comment_remark
         @default_comment_remark
      end
      def default_comment_remark=(newremark)
         @default_comment_remark = newremark
      end

      def default_gen3d?
         @default_gen3d
      end
      def default_gen3d=(newval)
         @default_gen3d = newval
      end

      def default_show_gplot?
         @default_show_gplot
      end
      def default_show_gplot=(newval)
         @default_show_gplot = newval
      end

      def default_tabletop?
         @default_tabletop
      end
      def default_tabletop=(newval)
         @default_tabletop = newval
      end

      def use_compatible_dialogs?
         @use_compatible_dialogs
      end
      def use_compatible_dialogs=(newval)
         @use_compatible_dialogs = newval
      end
#tools
      def default_spindle_speed
         @default_spindle_speed
      end
      def default_spindle_speed=(newval)
         @default_spindle_speed = newval
      end

      def default_feed_rate
         @default_feed_rate
      end
      def default_feed_rate=(newval)
         @default_feed_rate = newval
      end

      def default_plunge_rate
         @default_plunge_rate
      end
      def default_plunge_rate=(newval)
         @default_plunge_rate = newval
      end

      def default_safe_travel
         @default_safe_travel
      end
      def default_safe_travel=(newval)
         @default_safe_travel = newval
      end

      def default_material_thickness
         @default_material_thickness
      end
      def default_material_thickness=(newval)
         @default_material_thickness = newval
      end

      def default_cut_depth_factor
         @default_cut_depth_factor
      end
      def default_cut_depth_factor=(newval)
         @default_cut_depth_factor = newval
      end

      def default_bit_diameter
         @default_bit_diameter
      end
      def default_bit_diameter=(newval)
         @default_bit_diameter = newval
      end

      def default_tab_width
         @default_tab_width
      end
      def default_tab_width=(newval)
         @default_tab_width = newval
      end

      def default_tab_depth_factor
         @default_tab_depth_factor
      end
      def default_tab_depth_factor=(newval)
         @default_tab_depth_factor = newval
      end

      def default_vtabs?
         @default_vtabs
      end
      def default_vtabs=(newval)
         @default_vtabs = newval
      end

      def default_fold_depth_factor
         @default_fold_depth_factor
      end
      def default_fold_depth_factor=(newval)
         @default_fold_depth_factor = newval
      end

      def default_pocket_depth_factor
         @default_pocket_depth_factor
      end
      def default_pocket_depth_factor=(newval)
         @default_pocket_depth_factor = newval
      end

      def default_pocket_direction?
         @default_pocket_direction
      end
      def default_pocket_direction=(newval)
         @default_pocket_direction = newval
      end
#machine
      def default_safe_origin_x
         @default_safe_origin_x
      end
      def default_safe_origin_x=(newval)
         @default_safe_origin_x = newval
      end

      def default_safe_origin_y
         @default_safe_origin_y
      end
      def default_safe_origin_y=(newval)
         @default_safe_origin_y = newval
      end

      def default_safe_width
         @default_safe_width
      end
      def default_safe_width=(newval)
         @default_safe_width = newval
      end

      def default_safe_height
         @default_safe_height
      end
      def default_safe_height=(newval)
         @default_safe_height = newval
      end

      def default_overhead_gantry?
         @default_overhead_gantry
      end
      def default_overhead_gantry=(newval)
         @default_overhead_gantry = newval
      end

      def default_multipass?
         @default_multipass
      end
      def default_multipass=(newval)
         @default_multipass = newval
      end

      def default_multipass_depth
         @default_multipass_depth
      end
      def default_multipass_depth=(newval)
         @default_multipass_depth = newval
      end

      def default_stepover
         @default_stepover
      end
      def default_stepover=(newval)
         @default_stepover = newval
      end

      def min_z
         @min_z
      end
      def min_z=(newval)
         @min_z = newval
      end

      def max_z
         @max_z
      end
      def max_z=(newval)
         @max_z = newval
      end
#features
      def use_vtab_speed_limit?
         @use_vtab_speed_limit
      end
      def use_vtab_speed_limit=(newval)
         @use_vtab_speed_limit = newval
      end

      def use_exact_path?
         @use_exact_path
      end
      def use_exact_path=(newval)
         @use_exact_path = newval
      end

      def always_show_safearea?
         @always_show_safearea
      end
      def always_show_safearea=(newval)
         @always_show_safearea = newval
      end

      def use_reduced_safe_height?
         @use_reduced_safe_height
      end
      def use_reduced_safe_height=(newval)
         @use_reduced_safe_height = newval
      end

      def use_pocket_cw?
         @use_pocket_cw
      end
      def use_pocket_cw=(newval)
         @use_pocket_cw = newval
      end

      def use_plunge_cw?
         @use_plunge_cw
      end
      def use_plunge_cw=(newval)
         @use_plunge_cw = newval
      end

      def use_outfeed?
         @use_outfeed
      end
      def use_outfeed=(newval)
         @use_outfeed = newval
      end

      def profile_save_material_thickness?
         @profile_save_material_thickness
      end
      def profile_save_material_thickness=(newval)
         @profile_save_material_thickness = newval
      end

      def use_home_height?
         @use_home_height
      end
      def use_home_height=(newval)
         @use_home_height = newval
      end

      def default_home_height
         @default_home_height
      end
      def default_home_height=(newval)
         @default_home_height = newval
      end
      
      def use_end_position?
         @use_end_position
      end
      def use_end_position=(newuse)
         @use_end_position = newuse
      end
      def end_x
         @end_x
      end
      def end_y
         @end_y
      end
      def end_x=(newval)
         @end_x = newval
      end
      def end_y=(newval)
         @end_y = newval
      end
      
      def use_fuzzy_holes?
         @use_fuzzy_holes
      end
      def use_fuzzy_holes=(newval)
         @use_fuzzy_holes = newval
      end
      
   end # class Options
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   class OptionsFilesTool < PhlatTool
    def initialize(opt)   #give it the options instance
      @options = opt  # store the options instance so we can manipulate it without a global
      @tooltype=(PB_MENU_MENU)
      @tooltip="Default File Options"
      @statusText="File Options1"
      @menuItem="File Options2"
      @menuText="File Options"
    end

   def select
      model=Sketchup.active_model

      # prompts
      prompts=['Default_file_name','Default_file_ext', 'Default_directory_name']

      defaults=[
         @options.default_file_name,
         @options.default_file_ext,
         @options.default_directory_name
         ]
      # dropdown options can be added here
      #         list=["henry|bob|susan"] #should give list of existing?

      input=UI.inputbox(prompts, defaults, 'Default File Options (read the help!)')
      # input is nil if user cancelled
      if (input)
         @options.default_file_name = input[0].to_s
         @options.default_file_ext = input[1].to_s
         @options.default_directory_name = input[2].to_s

         @options.save
      end # if input
   end # def select
end # class
#========================================================
   class OptionsMiscTool < PhlatTool
      def initialize(opt)   #give it the options instance
         @options = opt  # store the options instance so we can manipulate it without a global
         @tooltype=(PB_MENU_MENU)
         @tooltip="Default Misc Options"
         @statusText="Misc Options1"
         @menuItem="Misc Options2"
         @menuText="Misc Options"
      end

      def select
         model=Sketchup.active_model

         # prompts
         prompts=['Default_comment_remark ',
            'Default_gen3d',
            'Default_show_gplot after output ',
            'Default_tabletop is Z-Zero ',
            'Use_compatible_dialogs set TRUE if you cannot see the parameters dialog' ]


         defaults=[
            @options.default_comment_remark,
            @options.default_gen3d?.inspect(),
            @options.default_show_gplot?.inspect(),
            @options.default_tabletop?.inspect(),
            @options.use_compatible_dialogs?.inspect()
            ]
         # dropdown options can be added here
         list=["",
            "true|false",
            "true|false",
            "true|false",
            "true|false"
            ]


         input=UI.inputbox(prompts, defaults, list, 'Miscallaneous Options (read the help!)')
         # input is nil if user cancelled
         if (input)
            @options.default_comment_remark  = input[0].to_s
            @options.default_gen3d           = (input[1] == 'true')
            @options.default_show_gplot      = (input[2] == 'true')
            @options.default_tabletop        = (input[3] == 'true')
            @options.use_compatible_dialogs  = (input[4] == 'true')


            @options.save
         end # if input
      end # def select
   end # class
#===============================================================================
   class OptionsToolsTool < PhlatTool
      def initialize(opt)   #give it the options instance
         @options = opt  # store the options instance so we can manipulate it without a global
         @tooltype=(PB_MENU_MENU)
         @tooltip="Default Tool Options"
         @statusText="Tool Options1"
         @menuItem="Tool Options2"
         @menuText="Tool Options"
      end

      def select
#         model=Sketchup.active_model

         # prompts

         prompts=[
            'Default_spindle_speed ',
            'Default_feed_rate ',
            'Default_plunge_rate ',
            'Default_safe_travel ',
            'Default_material_thickness ',
            'Default_cut_depth_factor ',
            'Default_bit_diameter ',
            'Default_tab_width ',
            'Default_tab_depth_factor ',
            'Default_vtabs ',
            'Default_fold_depth_factor ',
            'Default_pocket_depth_factor ',
            'Default_pocket_direction '
         ]
         defaults=[
            @options.default_spindle_speed.to_s,
            Sketchup.format_length(@options.default_feed_rate),
            Sketchup.format_length(@options.default_plunge_rate),
            Sketchup.format_length(@options.default_safe_travel),
            Sketchup.format_length(@options.default_material_thickness),
            @options.default_cut_depth_factor.to_s,
            Sketchup.format_length(@options.default_bit_diameter),
            Sketchup.format_length(@options.default_tab_width),
            @options.default_tab_depth_factor.to_s,
            @options.default_vtabs?.inspect(),
            @options.default_fold_depth_factor.to_s,
            @options.default_pocket_depth_factor.to_s,
            @options.default_pocket_direction?.inspect()
            ]
         list=[
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            'true|false',
            '',
            '',
            'true|false'
            ]


         input=UI.inputbox(prompts, defaults, list, 'Tool Options (read the help!)')
         # input is nil if user cancelled
         if (input)
            @options.default_spindle_speed      = input[0].to_i
            @options.default_feed_rate          = Sketchup.parse_length(input[1])
            @options.default_plunge_rate        = Sketchup.parse_length(input[2])
            @options.default_safe_travel        = Sketchup.parse_length(input[3])
            @options.default_material_thickness = Sketchup.parse_length(input[4])
            @options.default_cut_depth_factor   = input[5].to_f
            @options.default_bit_diameter       = Sketchup.parse_length(input[6])
            @options.default_tab_width          = Sketchup.parse_length(input[7])
            @options.default_tab_depth_factor   = input[8].to_f
            @options.default_vtabs              = (input[9] == 'true')
            @options.default_fold_depth_factor  = input[10].to_f
            @options.default_pocket_depth_factor = input[11].to_f
            @options.default_pocket_direction   = (input[12] == 'true')
            @options.save
         end # if input
      end # def select
   end # class

#===============================================================================
   class OptionsMachTool < PhlatTool
      def initialize(opt)   #give it the options instance
         @options = opt  # store the options instance so we can manipulate it without a global
         @tooltype=(PB_MENU_MENU)
         @tooltip="Default Machine Options"
         @statusText="Machine Options1"
         @menuItem="Machine Options2"
         @menuText="Machine Options"
      end

      def select
#         model=Sketchup.active_model

         # prompts

         prompts=[
            'Default_safe_origin_x ',
            'Default_safe_origin_y ',
            'Default_safe_width (X) ',
            'Default_safe_height (Y) ',
            'Default_overhead_gantry ',
            'Default_multipass ',
            'Default_multipass_depth ',
            'Default_stepover % ',
            'Min_z (- total Z travel) ',
            'Max_z (+ total Z travel) '
            ];
         defaults=[
            Sketchup.format_length(@options.default_safe_origin_x),
            Sketchup.format_length(@options.default_safe_origin_y),
            Sketchup.format_length(@options.default_safe_width),
            Sketchup.format_length(@options.default_safe_height),
            @options.default_overhead_gantry?.inspect(),
            @options.default_multipass?.inspect(),
            Sketchup.format_length(@options.default_multipass_depth),
            @options.default_stepover.to_s,
            Sketchup.format_length(@options.min_z),
            Sketchup.format_length(@options.max_z)
            ];
         list=[
            '',
            '',
            '',
            '',
            'true|false',
            'true|false',
            '',
            '',
            '',
            ''
            ];


         input=UI.inputbox(prompts, defaults, list, 'Machine Options (read the help!)')
         # input is nil if user cancelled
         if (input)
            @options.default_safe_origin_x   = Sketchup.parse_length(input[0]);
            @options.default_safe_origin_y   = Sketchup.parse_length(input[1]);
            @options.default_safe_width      = Sketchup.parse_length(input[2]);
            @options.default_safe_height     = Sketchup.parse_length(input[3]);
            @options.default_overhead_gantry = (input[4] == 'true');
            @options.default_multipass       = (input[5] == 'true');
            @options.default_multipass_depth = Sketchup.parse_length(input[6]);
            @options.default_stepover        = input[7].to_f;
            @options.min_z                   = Sketchup.parse_length(input[8]);
            @options.max_z                   = Sketchup.parse_length(input[9]);

            @options.save
         end # if input
      end # def select
   end # class
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   class OptionsFeatTool < PhlatTool
      def initialize(opt)   #give it the options instance
         @options = opt  # store the options instance so we can manipulate it without a global
         @tooltype=(PB_MENU_MENU)
         @tooltip="Default FeatOptions"
         @statusText="Feature Options1"
         @menuItem="Feature Options2"
         @menuText="Feature Options"
      end

      def select
         model=Sketchup.active_model

         # prompts
         prompts=[
            'Use_exact_path (G61) ',
            'Always_show_safearea ',
            'Use_reduced_safe_height ',
            'Use_pocket_CW ',
            'Use_plunge_CW ',
            'Use_outfeed ',
            'Use_vtab_speed_limit ',
            'Profile_save_material_thickness ',
            'Use_Home_Height ',
            'Default_Home_Height ',
            'Use_End_Position ',
            'End position X ',
            'End position Y ',
            'Use fuzzy hole stepover '
            ];
         defaults=[
            @options.use_exact_path?.inspect(),
            @options.always_show_safearea?.inspect(),
            @options.use_reduced_safe_height?.inspect(),
            @options.use_pocket_cw?.inspect(),
            @options.use_plunge_cw?.inspect(),
            @options.use_outfeed?.inspect(),
            @options.use_vtab_speed_limit?.inspect(),
            @options.profile_save_material_thickness?.inspect(),
            @options.use_home_height?.inspect(),
            Sketchup.format_length(@options.default_home_height),
            @options.use_end_position?.inspect(),
            Sketchup.format_length(@options.end_x),
            Sketchup.format_length(@options.end_y),
            @options.use_fuzzy_holes?.inspect()
            ];
         list=[
            'true|false',
            'true|false',
            'true|false',
            'true|false',
            'true|false',
            'true|false',
            'true|false',
            'true|false',
            'true|false',
            '',
            'true|false',
            '',
            '',
            'true|false'
            ];

         input=UI.inputbox(prompts, defaults, list, 'Feature Options (read the help!)')
         # input is nil if user cancelled
         if (input)
            @options.use_exact_path          = (input[0] == 'true')
            @options.always_show_safearea    = (input[1] == 'true')
            @options.use_reduced_safe_height = (input[2] == 'true')
            @options.use_pocket_cw           = (input[3] == 'true')
            @options.use_plunge_cw           = (input[4] == 'true')
            @options.use_outfeed             = (input[5] == 'true')
            @options.use_vtab_speed_limit    = (input[6] == 'true')
            @options.profile_save_material_thickness         = (input[7] == 'true')
            @options.use_home_height         = (input[8] == 'true')
            @options.default_home_height     = Sketchup.parse_length(input[9])

            @options.use_end_position        = (input[10] == 'true')
            if (@options.use_outfeed?)     # only one of them
               @options.use_end_position = false
            end
            @options.end_x                   = Sketchup.parse_length(input[11])
            @options.end_y                   = Sketchup.parse_length(input[12])

            @options.use_fuzzy_holes         = (input[13] == 'true')
            
            @options.save
         end # if input
      end # def select
   end # class



end # module PhlatScript
=begin
File
   Default_file_name = "gcode_out.cnc"
   Default_file_ext = ".cnc"
   Default_directory_name = Dir.pwd + "\\"

Tools
   Default_spindle_speed = 15000
   Default_feed_rate = 100.0.inch
   Default_plunge_rate = 100.0.inch
   Default_safe_travel = 0.125.inch
   Default_material_thickness = 0.25.inch
   Default_cut_depth_factor = 140
   Default_bit_diameter = 0.125.inch
   Default_tab_width = 0.25.inch
   Default_tab_depth_factor = 50
   Default_vtabs = false
   Default_fold_depth_factor = 50
   Default_pocket_depth_factor = 50
   Default_pocket_direction = false     X or Y zigzag

Machine
   Default_safe_origin_x = 0.0.inch
   Default_safe_origin_y = 0.0.inch
   Default_safe_width = 42.0.inch
   Default_safe_height = 22.0.inch
   Default_overhead_gantry = false
   Default_multipass = false
   Default_multipass_depth = 0.03125.inch
   Default_stepover = 70
   Min_z = -1.4
   Max_z = 1.4

Misc
   Default_comment_remark = ""
   Default_gen3d = false
   Default_show_gplot = false
   Default_tabletop = false
   Use_compatible_dialogs = false


Features

   # Set this to true if you have an older version of Mach that does not slow down
   # to the Z maximum speed during helical linear interpolation (G2/3 with Z
   # movement A.K.A vtabs on an arc). vtabs on arcs will cut at the plunge rate
   # defined in this file or overriden in the parameters dialog
   Use_vtab_speed_limit = false

   # Set this to true to use G61. This will make the machine come to a complete
   # stop when changing directions instead of rounding out square corners. When
   # set to false the default for your CNC software will be used. Without G61
   # the machine will maintain the best possible speed for the cut even if the
   # tool isn't true to the cut path. Rounded corners at low feedrates aren't
   # very noticeable but anything over 200 starts to generate large radii so
   # that the momentum of the machine can be maintained.
   Use_exact_path = false

   # Set this to true, if you want the safe area to always show, when parameters are saved.
   # Otherwise the safe area will only show, if it's size has been changed.
   Always_show_safearea = true

   # Set this to true to use 1/3 of the usual safe travel height during plunge boring moves
   # this saves time.
   Use_reduced_safe_height = true

   # Set this true to generate pocket outlines that cut in CW instead of usual CCW direction
   # Please research 'climb milling' before changing this.
   # Note this is a draw time option, if you change it here you have to redraw all pocket cuts.
   Use_pocket_CW = false

   # Set this true to generate plunge hole cuts in CW instead of usual CCW cut direction
   # Please research 'climb milling' before changing this.
   Use_plunge_CW = false

   # Outfeed: phlatprinters only!
   # Set this to true to enable outfeed.  At the end of the job it will feed the material out the front of the
   # machine instead of stopping at X0 with the material out the back.
   # It will feed to 75% of the material size as given by the safe area settings
   Use_outfeed = false

   #Set this to true to have pocket zigzags default to along Y axis, false for along X axis
   #setting can be changed on the fly with the END key
   Default_pocket_direction = true

   # Set this to TRUE to have the material thickness saved and restored in Tool Profiles
   # Profiles that do not contain a material thickness will load just fine.
   Profile_save_material_thickness = false

   # Set this true and set the height and the Z will retract to this at the end of the job
   # really only useful for overhead gantries
   Use_Home_Height = false
   Default_Home_Height = Default_safe
------------------------

------------------------



=end

