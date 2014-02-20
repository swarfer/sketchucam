require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/utils/SketchupDirectoryUtils.rb'

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
            "  Default_show_gplot = #{Default_show_gplot}\n" +
            "  Default_pocket_direction = #{Default_pocket_direction}\n" +
            "  Min_z = #{Min_z}\n" +
            "  Max_z = #{Max_z}\n" +
            "  Use_compatible_dialogs = #{Use_compatible_dialogs}\n" +
            "  Use_vtab_speed_limit = #{Use_vtab_speed_limit}\n" +
            "  Use_exact_path = #{Use_exact_path}\n" +
            "  Always_show_safearea = #{Always_show_safearea}\n" +
            "  Use_reduced_safe_height = #{Use_reduced_safe_height}\n" +
            "  Use_pocket_CW = #{Use_pocket_CW}\n" +
            "  Use_plunge_CW = #{Use_plunge_CW}\n" +
            "  Use_outfeed = #{Use_outfeed}\n" +
            "  Use_Home_Height = #{Use_Home_Height}\n"
            if Use_Home_Height
               msg += "  Default_Home_Height = #{Default_Home_Height}\n"
            end
            msg += "  Profile_save_material_thickness = #{Profile_save_material_thickness}\n"
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
         path = SketchupDirectoryUtils.toolsProfilesPath()
         if File.exist?(path)
            UI.openURL(path)
         else
            UI.messagebox('First you need to save a profile before you can display the folder that contains it')
         end
         
      end #select
   end # class

end