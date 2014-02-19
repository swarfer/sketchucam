
require 'sketchup.rb'
require 'Phlatboyz/Phlatscript.rb'


class GPlot

  def initialize
    @exe = Sketchup.find_support_file("GPlot.exe", "/Plugins")
    if (!@exe)
      UI.messagebox('Could not locate GPlot.exe in Sketchup Plugins folder.')
    end
  end

  def plot
    filename = PhlatScript.cncFileDir  + PhlatScript.cncFileName
    if (filename) && (File.exist?(filename)) then
      Thread.new{system(@exe, filename)}
    else
      UI.messagebox("Could not locate a gcode file to plot. Try using the generate gcode button.")
    end
  end

end

#-----------------------------------------------------------------------------
if( not file_loaded?("GPlot.rb") )
    UI.menu("Plugins").add_item("Plot GCode") { GPlot.new.plot }
end
#-----------------------------------------------------------------------------
file_loaded("GPlot.rb")

