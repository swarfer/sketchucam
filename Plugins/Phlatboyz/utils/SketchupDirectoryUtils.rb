module PhlatScript
# Class contains methods for dealing with sketchup directories.
# Class implements platform specific methods for accessing directories

   # return true if running on Mac platform
   def PhlatScript.isMac?
      if (RUBY_PLATFORM =~ /mswin|mingw/)
         return false
      else
         return true
      end 
   end

   # this method returns a path for storing profiles.
   # path depends on the system, macosx is recognized by RUBY_PLATFORM.
   def PhlatScript.toolsProfilesPath
      if PhlatScript.isMac?
         #MAC
         # Sketchup.find_support_file returns directory in:
         # ~/Library/Application Support/Sketchup X/SketchUp/
         # we will store profiles in Profiles subdirectory
         path = File.join(Sketchup.find_support_file("Plugins"),"Phlatboyz", "Profiles")
      else
         # Windows - support files are read only in win7, so use appdata
         path = ENV['APPDATA'] + "\\Sketchup"
      end
      return path
   end

end