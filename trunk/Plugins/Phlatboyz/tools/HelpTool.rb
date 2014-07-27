require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/utils/SketchupDirectoryUtils.rb'
# $Id$
module PhlatScript

  class HelpTool < PhlatTool
    def select
      help_file = Sketchup.find_support_file "help.html", "Plugins/Phlatboyz/html"
      if (help_file)
        # Open the help_file in a web browser
        UI.openURL "file://" + help_file
      else
        UI.messagebox "Failed to open help file"
      end
    end
  end

   class SummaryTool < PhlatTool

      def initialize
         @tooltype=(PB_MENU_MENU)
         @tooltip="Options Summary"
         @statusText="Options Summary display"
         @menuItem="Options Summary"
         @menuText="Options Summary"
      end

      def select
         msg = "Summary of your settings from (My)Constants.rb\n" +
            "  Default_show_gplot = #{$phoptions.default_show_gplot?}\n" +
            "  Default_pocket_direction = #{$phoptions.default_pocket_direction?}\n" +
            "  Min_z = #{$phoptions.min_z}\n" +
            "  Max_z = #{$phoptions.max_z}\n" +
            "  Use_compatible_dialogs = #{$phoptions.use_compatible_dialogs?}\n" +
            "  Use_vtab_speed_limit = #{$phoptions.use_vtab_speed_limit?}\n" +
            "  Use_exact_path = #{$phoptions.use_exact_path?}\n" +
            "  Always_show_safearea = #{$phoptions.always_show_safearea?}\n" +
            "  Use_reduced_safe_height = #{$phoptions.use_reduced_safe_height?}\n" +
            "  Use_pocket_CW = #{$phoptions.use_pocket_cw?}\n" +
            "  Use_plunge_CW = #{$phoptions.use_plunge_cw?}\n" +
            "  Use_outfeed = #{$phoptions.use_outfeed?}\n" +
            "  Use_Home_Height = #{$phoptions.use_home_height?}\n"
            if $phoptions.use_home_height?
               msg += "  Default_Home_Height = #{$phoptions.default_home_height}\n"
            end
            msg += "  Profile_save_material_thickness = #{$phoptions.profile_save_material_thickness?}\n"
         UI.messagebox(msg,MB_MULTILINE)
      end #select
   end # class

# open a file browser with the APPDATA/Sketchup folder current, probably only work on Windows
   class DisplayProfileFolderTool < PhlatTool

      def initialize
         @tooltype=(PB_MENU_MENU)
         @tooltip="Display Profiles folder"
         @statusText="Display profile folder"
         @menuItem="Profiles_Folder"
         @menuText="Display Profiles Folder"
      end

      def select
#         path = ENV['APPDATA'] + "\\Sketchup"
         path = PhlatScript.toolsProfilesPath()
         if File.exist?(path)
            UI.openURL(path)
         else
            UI.messagebox('First you need to save a profile before you can display the folder that contains it')
         end

      end #select
   end # class

end
