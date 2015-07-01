
require 'sketchup.rb'
require 'Phlatboyz/Phlatscript.rb'
# $Id$

class GPlot

  def initialize
      if ($phoptions.gplotter == 'default') 
         @exe = Sketchup.find_support_file("GPlot.exe", "/Plugins")
      else
         @exe = $phoptions.gplotter
      end
      if (!@exe) || (!File.exist?(@exe))
         UI.messagebox('Could not locate GPlotter.  Check Tools|Phlatboyz|Options|File Options|Gplotter')
         @exe = Sketchup.find_support_file("GPlot.exe", "/Plugins")
      end
  end

  def plot(filename=nil)   #swarfer: allow overriding filename
    if (filename == nil)
       filename = PhlatScript.cncFileDir  + PhlatScript.cncFileName
    end
    if (filename) && (File.exist?(filename)) then
       #puts "#{@exe} #{filename}"
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

