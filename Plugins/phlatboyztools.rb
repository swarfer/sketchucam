#-----------------------------------------------------------------------------
# Name        :   PhlatBoyzTools
# Description :   A set of tools for marking up Phlatland Sketchup drawings and generating Phlatprinter g-code.
# Menu Item   :   
# Context Menu:   
# Usage       :   install in plugins folder
# Date        :   Aug 2013
# Type        :   
# Version     :   SketchUcam 1.1 
#-----------------------------------------------------------------------------

require('sketchup.rb')

class PhlatScriptExtention < SketchupExtension 
  def initialize
    super 'Phlatboyz Tools', 'Phlatboyz/Phlatscript.rb' 
    self.description = 'A set of tools for marking up Phlatland Sketchup drawings and generating Phlatprinter g-code.' 
    self.version = '1.1a' 
    self.creator = 'Phlatboyz' 
    self.copyright = 'Aug2013, Phlatboyz' 
  end

  def load
    require 'Phlatboyz/Phlatscript.rb'
    PhlatScript.load
  end 

end
$PhlatScriptExtension = PhlatScriptExtention.new
Sketchup.register_extension($PhlatScriptExtension, true)
