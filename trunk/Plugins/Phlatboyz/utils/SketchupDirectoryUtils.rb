# Class contains methods for dealing with sketchup directories.
# Class implements platform specific methods for accessing directories

class SketchupDirectoryUtils
  
  def self.toolsProfilesPath
    # this method returns a path for storing profiles.
    # path depends on the system, macosx is recognized by RUBY_PLATFORM.
    if RUBY_PLATFORM =~ /(darwin)/
      # Sketchup.find_support_file returns directory in:
      # ~/Library/Application Support/Sketchup X/SketchUp/
      # we will store profiles in Profiles subdirectory
      path = File.join(Sketchup.find_support_file("Plugins"),"Phlatboyz", "Profiles")
    else # Windows
      path = ENV['APPDATA'] + "\\Sketchup"
    end
    return path
  end
end
