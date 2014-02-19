#-----------------------------------------------------------------------------
# Name        :   PhlatBoyzTools
# Description :   A set of tools for marking up Phlatland Sketchup drawings and generating Phlatprinter g-code.
# Menu Item   :   
# Context Menu:   
# Usage       :   install in plugins folder
# Date        :   Feb 2014
# Type        :   
# Version     :   SketchUcam 1.1 
#-----------------------------------------------------------------------------

require('sketchup.rb')
require('extensions.rb')

class PhlatScriptExtention < SketchupExtension 
  def initialize
    super 'Phlatboyz Tools', 'Phlatboyz/Phlatscript.rb' 
    self.description = 'A set of tools for marking up Phlatland Sketchup drawings and generating Phlatprinter g-code.' 
    self.version = '1.1d-beta' 
    self.creator = 'Phlatboyz' 
    self.copyright = '2014, Phlatboyz' 
  end

  def load
    require 'Phlatboyz/Phlatscript.rb'
    PhlatScript.load
  end 

end
$PhlatScriptExtension = PhlatScriptExtention.new
Sketchup.register_extension($PhlatScriptExtension, true)
