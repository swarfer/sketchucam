require 'sketchup.rb'

# Name Begins With Variable Scope
# $  A global variable
# @  An instance variable
# [a-z] or _  A local variable
# [A-Z]  A constant
# @@ A class variable

module PhlatScript

# - - - - - - - - - - - - - - - - -
#           Default Values
# - - - - - - - - - - - - - - - - -
Default_file_name = "gcode_out.nc"
Default_file_ext = ".nc"
Default_directory_name = Dir.pwd + "/"

Default_spindle_speed = 15000
Default_feed_rate = 2000.0.mm
Default_plunge_rate = 1500.mm
Default_safe_travel = 3.mm
Default_material_thickness = 4.mm
Default_cut_depth_factor = 110
Default_bit_diameter = 3.2.mm
Default_tab_width = 8.mm
Default_tab_depth_factor = 50
Default_vtabs = false
Default_fold_depth_factor = 50

Default_safe_origin_x = 0.0.inch
Default_safe_origin_y = 0.0.inch
Default_safe_width = 1300.mm
Default_safe_height = 2500.mm
Default_comment_remark = "Davids defaults"

Default_overhead_gantry = true
Default_multipass = false
Default_multipass_depth = 2.mm
Default_gen3d = false
Default_stepover = 30

# -------------------------
# PhlatScript Features - things you can set here and not in the parameters dialog
# -------------------------

#set these values to reflect how far your Z axis can travel, Z axis motion will be limited to this length
#Min_z = -1.4.inch
#Max_z = 1.4.inch

# Set this to true if you have problems with the parameter dialog being blank or crashing SU
# on Mac, you will probably need this true
# UPDATE Mar 2014 - this shoudl not be needed on MAC anymore, we think we fixed it!
# on Linux, you might need this, if you do, you can fix Wine by searching the web for the howto on fixing Sketchup WebDialogs
Use_compatible_dialogs = false

# Set this to true to enable multipass fields in the parameters dialog. When it is false
# you will not be prompted to use multipass. When true you will be able to turn it off and
# on in the parameters dialog
Use_multipass = true

# Set this to true if you have an older version of Mach that does not slow down
# to the Z maximum speed during helical linear interpolation (G2/3 with Z
# movement A.K.A vtabs on an arc). vtabs on arcs will cut at the plunge rate
# defined in this file or overriden in the parameters dialog
Use_vtab_speed_limit = false

# Set this to true to use G61. This will make the machine come to a complete
# stop when changing directions instead of rounding out square corners. When
# set to false the default for your CNC software will be used. Without G61
# the machine might be in G64 mode, this will maintain the best possible speed 
# for the cut even if the tool isn't true to the cut path. 
# Rounded corners at low feedrates aren't very noticeable but anything over 
# 200"/min starts to generate large radii so that the momentum of the machine can be maintained.
Use_exact_path = true

# Set this to true, if you want the safe area to always show, when parameters are saved.
# Otherwise the safe area will only show, if it's size has been changed.
Always_show_safearea = true

# Set this to true to use 1/3 of the usual safe travel height during plunge boring moves
# this saves a lot of air cutting time
Use_reduced_safe_height = true

# Set this true and set the height and the Z will retract to this at the end of the job
# really only useful for overhead gantries - check your max_z setting too
Use_Home_Height = false
Default_Home_Height = 30.mm

# Set this true to generate pocket outlines that cut in CW instead of usual CCW direction
# Please research 'climb milling' before changing this.
# Note this is a draw time option, if you change it in the Gcode you have to redraw all pocket cuts.
Use_pocket_CW = false

# Set this true to generate plunge cuts in CW instead of usual CCW cut direction
# Please research 'climb milling' before changing this.
Use_plunge_CW = false

# Outfeed: phlatprinters only!
# Set this to true to enable outfeed.  At the end of the job it will feed the material out the front of the
# machine instead of stopping at X0 with the material out the back.
# It will feed to 75% of the material size as given by the safe area settings
Use_outfeed = false

#Set this to true to have pocket zigzags default to along Y axis, false for along X axis
#setting can be changed on the fly with the END key
Default_pocket_direction = false

# Set this to TRUE to have the material thickness saved and restored in Tool Profiles
# Profiles that do not contain a material thickness will load just fine.
Profile_save_material_thickness = false

#set this to true to default table top to Z0 instead of material top
Default_tabletop = false


end # module PhlatScript
