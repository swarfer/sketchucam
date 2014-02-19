# Airfoil_dat.rb
# A plugin to import Mark Drela's AG and ST Airfoils
# data from the airfoil coordinate files *.dat files 
#
# at 
# http://www.charlesriverrc.org/articles/drela-airfoilshop/markdrela-ag-ht-airfoils.htm 
# 
# The plugin has only been tested in Sketchup 7 on Win XP.
# 
# Use the plugin as required at your own risk.
#
# Place the file airfoil_dat.rb in the plugins folder.
#
# EJT 11 Aug 2009
# SWARFER Jul 2013 - offset from origin so shapes are easier to select and move
# $Id$
require 'sketchup.rb'

def airfoil_dat_main
  model = Sketchup.active_model
  entities = model.active_entities

  c = 1 # used to skip first line in file
  vert = []

  filename = UI.openpanel "Import Airfoil data points","d:\\myfiles\\rc\\plotfoil","*.dat"

  IO.foreach(filename){
    |x|
    if c == 1
      c = 2
    elsif
      data = x.split
      vert.push [data[0].to_f, data[1].to_f-50.mm, 0.to_f]
    end
    }

 new_line = entities.add_face vert
 
 Sketchup.send_action("viewTop:")
 Sketchup.send_action("viewZoomExtents:")
end   

if( not file_loaded?("airfoil_dat.rb") )
    add_separator_to_menu("Plugins")
    UI.menu("Plugins").add_item("Airfoil data loader") { airfoil_dat_main }
	file_loaded("airfoil_dat.rb")
end

