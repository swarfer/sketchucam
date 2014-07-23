#module to allow user to change deault options without needing to edit any file.
# this will read Constants.rb and use those values to populate the options class
# then, if MyOptions.ini exists it will read that and override the settings in the options class
# everywhere that the old Default globals are used must be changed to use the options class values
# $Id$

require 'PhlatBoyz/Constants.rb'
#if  __FILE__ does not contain 'myconstants' then try to load it
res = __FILE__
res = res.scan(/myconstant/i)
if  (res.empty? )
  myc = Sketchup.find_support_file( 'Plugins' ) + '/Phlatboyz/MyConstants.rb'
  if File.exist?(myc)
    res = load(myc)
  end
end

require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/utils/SketchupDirectoryUtils.rb'
require('Phlatboyz/utils/IniParser.rb')


module PhlatScript

   class Options < Hashable
      def initialize
         @default_file_name = Default_file_name
         @default_file_ext = Default_file_ext
         @default_directory_name = Default_directory_name
         
         # if MyConstats.ini exists then read it
      end #initialize
      
      def save
         path = PhlatScript.toolsProfilesPath()

         if not File.exist?(path)
            Dir.mkdir(path)
         end

         print "saving to path #{path}\n"

         if File.exist?(path)
            #write contents to ini file format - this will supplant current tpr format over time
            generator = IniGenerator.new()
            
            ohash = {'Options' => self.toHash}
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
      
   end # class Options
   
   class OptionsFilesTool < PhlatTool
    def initialize(opt)   #give it the options instance
      @options = opt
      @tooltype=(PB_MENU_MENU)
      @tooltip="Default File Options"
      @statusText="File Options1"
      @menuItem="File Options2"
      @menuText="File Options3"
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

      input=UI.inputbox(prompts, defaults, 'Default File Options')
      # input is nil if user cancelled
      if (input)
         @options.default_file_name = input[0].to_s
         @options.default_file_ext = input[1].to_s
         @options.default_directory_name = input[2].to_s

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
   # Set this to true if you have problems with the parameter dialog being blank or crashing SU
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
   Default_Home_Height = Default_safe_travel

=end
