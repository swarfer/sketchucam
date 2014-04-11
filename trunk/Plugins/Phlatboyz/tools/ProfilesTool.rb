require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/utils/SketchupDirectoryUtils.rb'

require('Phlatboyz/utils/IniParser.rb')

# $Id$
module PhlatScript
  def PhlatScript.conformat(inp)
    #replace mm with .mm
    if PhlatScript.isMetric
      out= inp.to_mm.to_s + '.mm'
    else
      #replace trailing " with .inch
      out=inp.to_inch.to_s + '.inch'
    end
    out=out.gsub("~ ",'')
    return out
  end #
  
  class Hashable  # grabbed from hashabletest.rb

    def toHash
      #function checks all instance variables set on object and converts them to a Hash.
      hash = {}
      self.instance_variables.each {|var|
        varVal = self.instance_variable_get(var)
        value = varVal.toHash() if varVal.is_a? Hashable
        value = varVal if not varVal.is_a? Hashable
        hash[var.to_s.delete("@")] = value
        }
      return hash
    end
  end
#-----------------------------------------------------------------------------  

  # create one and save it and the settings will be current
class ProfileSettings < Hashable

   def initialize
      # put all the things we want to save here
      @prof_spindlespeed = PhlatScript.spindleSpeed.to_i.to_s
      @prof_feedrate    = PhlatScript.conformat(PhlatScript.feedRate)
      @prof_plungerate  = PhlatScript.conformat(PhlatScript.plungeRate) 
      @prof_savematthick = (Profile_save_material_thickness ? '1' : '0')
      @prof_matthick    = PhlatScript.conformat(PhlatScript.materialThickness)
      @prof_cutfactor   = PhlatScript.cutFactor.to_s 
      @prof_bitdiameter = PhlatScript.conformat(PhlatScript.bitDiameter)
      @prof_tabwidth    = PhlatScript.conformat(PhlatScript.tabWidth) 
      @prof_tabdepth    = PhlatScript.tabDepth.to_i.to_s
      @prof_safetravel  = PhlatScript.conformat(PhlatScript.safeTravel) 

      @prof_usemultipass = (PhlatScript.useMultipass? ? '1' : '0') 
      @prof_multipassdepth = PhlatScript.conformat(PhlatScript.multipassDepth)
      @prof_gen3d       = (PhlatScript.gen3D ? '1' : '0')
      @prof_stepover    = PhlatScript.stepover.to_i.to_s  
   end
end
#-----------------------------------------------------------------------------  

  class ProfilesSaveTool < PhlatTool
    def initialize
      @tooltype=(PB_MENU_MENU)
      @tooltip="Save tool profile"
      @statusText="Save Tool Profile"
      @menuItem="SaveProfile"
      @menuText="Save profile"
    end

    def select
      model=Sketchup.active_model

      # prompts
      prompts=['Name']
      defaults=['default']
      # dropdown options can be added here
      #         list=["henry|bob|susan"] #should give list of existing?

      input=UI.inputbox(prompts, defaults, 'Save Tool Profile')
      # input is nil if user cancelled
      if (input)
        profilename=input[0].to_s.gsub(/ /,'')

        path = SketchupDirectoryUtils.toolsProfilesPath()

        if not File.exist?(path)
          Dir.mkdir(path)
        end

        print "saving to #{profilename} in path #{path}\n"

        if File.exist?(path)
          #write contents to ini file format - this will supplant current tpr format over time
          generator = IniGenerator.new()
          prof = ProfileSettings.new()
          ohash = {'profile',prof.toHash}
          filePath = File.join(path, profilename + '.tpi')
          generator.dumpHashMapToIni(ohash, filePath)
          
=begin          
          #create file
          filePath = File.join(path, profilename + '.tpr')
          outf=File.new(filePath,"w")

          #outf.print "module PhlatScript\n";
          outf.print "prof_spindlespeed=" + PhlatScript.spindleSpeed.to_i.to_s  + "\n"
          outf.print "prof_feedrate="     + PhlatScript.conformat(PhlatScript.feedRate)  + "\n"
          outf.print "prof_plungerate="   + PhlatScript.conformat(PhlatScript.plungeRate)  + "\n"
          if (Profile_save_material_thickness)
            outf.print "prof_matthick="   + PhlatScript.conformat(PhlatScript.materialThickness)  + "\n"
          end
          outf.print "prof_cutfactor="    + PhlatScript.cutFactor.to_s   + "\n"
          outf.print "prof_bitdiameter="  + PhlatScript.conformat(PhlatScript.bitDiameter)   + "\n"
          outf.print "prof_tabwidth="     + PhlatScript.conformat(PhlatScript.tabWidth)   + "\n"
          outf.print "prof_tabdepth="     + PhlatScript.tabDepth.to_i.to_s   + "\n"
          outf.print "prof_safetravel="   + PhlatScript.conformat(PhlatScript.safeTravel)   + "\n"

          outf.print "prof_usemultipass=" + (PhlatScript.useMultipass? ? '1' : '0')   + "\n"
          outf.print "prof_multipassdepth=" + PhlatScript.conformat(PhlatScript.multipassDepth)   + "\n"
          outf.print "prof_gen3d="        + (PhlatScript.gen3D ? '1' : '0')   + "\n"
          outf.print "prof_stepover="     + PhlatScript.stepover.to_i.to_s   + "\n"
          #outf.print "end\n";
          #close file
          outf.close
=end          
        else
          print "ERROR path does not exist #{path}"
        end # path exists so we saved it
      end # if input
    end # def select
  end # class
#-----------------------------------------------------------------------------  

class ProfilesTool < PhlatTool
   def getDropDownList
      list=[""]
      path = SketchupDirectoryUtils.toolsProfilesPath()
      if not File.exist?(path)
        Dir.mkdir(path)
      end
      if File.exist?(path)
         items = []  # stick names into array to we can .uniq it as we might have repeats with different extentions
         #print "path exists\n"
         Dir.foreach( path ) {| filename |
            #puts "got #{filename}"
            if filename.index(/\.tpi|\.rb|\.tpr/)
              filename=filename.gsub(/\.rb|\.tpr|\.tpi/,"")
              items.push(filename)
            end
         }
         items = items.uniq
         items.each {|item|   #make a string
            if list[0] == ''
               list[0] = item
            else
               list[0]= list[0] + "|#{item}"
            end
            }
#        puts list
      end
      return list
   end
 end
#--------------------------------------------------------------------------------  
class ProfilesLoadTool < ProfilesTool
    def initialize
      @tooltype=(PB_MENU_MENU)
      @tooltip="Load tool profile"
      @statusText="Load Tool Profile"
      @menuItem="LoadProfile"
      @menuText="Load Profile"
    end
    
      # retrieve a constant value from the str, observing units of measurement
   def getvalue(str)
      value = 0
      if str
         if str.index('.mm')
            value = str.gsub('.mm','').to_f / 25.4    # to_l does not get it right when drawing is metric
         #puts "mm to inch #{value}"
         else
            if str.index('.inch')
               value = str.gsub('.inch','').to_f
            else
               value = str.to_f
            end
         end
      end
      return value
   end

   def select
      model=Sketchup.active_model

      # prompts
      prompts=["Select Profile"]

      defaults=['default']
=begin
      defaults=[PhlatScript.spindleSpeed.to_s,
      Sketchup.format_length(PhlatScript.feedRate),
      Sketchup.format_length(PhlatScript.plungeRate),
      Sketchup.format_length(PhlatScript.materialThickness),
      PhlatScript.cutFactor.to_s,
      Sketchup.format_length(PhlatScript.bitDiameter),
      Sketchup.format_length(PhlatScript.tabWidth),
      PhlatScript.tabDepth.to_s,
      Sketchup.format_length(PhlatScript.safeTravel),
      Sketchup.format_length(PhlatScript.safeWidth),
      Sketchup.format_length(PhlatScript.safeHeight),
      PhlatScript.useOverheadGantry?.inspect()]

      if PhlatScript.multipassEnabled?
         defaults.push(PhlatScript.useMultipass?.inspect())
         defaults.push(Sketchup.format_length(PhlatScript.multipassDepth))
      end
      defaults.push(PhlatScript.gen3D.inspect())
      defaults.push(PhlatScript.stepover)
      defaults.push(PhlatScript.showGplot?.inspect())
      defaults.push(encoded_comment_text)
=end
      # dropdown options can be added here
      list = getDropDownList()
      if list[0] == ""
         UI.messagebox('No profiles found. You have to save a profile before you can load one')
         return
      end
      path = SketchupDirectoryUtils.toolsProfilesPath()
      input=UI.inputbox(prompts, defaults, list, 'Load Profile')
      # input is nil if user cancelled
      if (input)
         fileNameToOpen = input[0] + ".ini"  # select ini before tpr and rb
         filePath = File.join(path , fileNameToOpen)
         if not File.exist?(filePath)
            fileNameToOpen = input[0] + ".tpr"
            filePath= File.join(path , fileNameToOpen)
         end
         if not File.exist?(filePath)
            fileNameToOpen = input[0] + ".rb"
            filePath= File.join(path , fileNameToOpen)
         end
         if not File.exist?(filePath)
            die "error finding file"
         end           
         # load and interpret the file, updating variables
         if filePath.index('.ini')
         puts 'using ini file'
            ini = IniParser.new()
            sections = ini.parseFileAtPath(filePath)
#            puts(sections)
            profile = sections['profile'] # get the profile hash
            puts 'keys'
            puts profile.keys
            PhlatScript.spindleSpeed = getvalue(profile['prof_spindlespeed']) if (profile.has_key?('prof_spindlespeed'))
            PhlatScript.feedRate    = getvalue(profile['prof_feedrate']) if (profile.has_key?('prof_feedrate'))
            PhlatScript.plungeRate  = getvalue(profile['prof_plungerate']) if (profile.has_key?('prof_plungerate'))
            PhlatScript.cutFactor   = getvalue(profile['prof_cutfactor']) if (profile.has_key?('prof_cutfactor'))
            useit = 0
            useit = getvalue(profile['prof_savematthick']) if (profile.has_key?('prof_savematthick'))
            if useit == 1
               PhlatScript.materialThickness = getvalue(profile['prof_matthick']) if (profile.has_key?('prof_matthick'))
            end
            PhlatScript.bitDiameter = getvalue(profile['prof_bitdiameter']) if (profile.has_key?('prof_bitdiameter'))
            PhlatScript.tabWidth = getvalue(profile['prof_tabwidth']) if (profile.has_key?('prof_tabwidth'))
            PhlatScript.tabDepth = getvalue(profile['prof_tabdepth']) if (profile.has_key?('prof_tabdepth'))
            PhlatScript.safeTravel = getvalue(profile['prof_safetravel']) if (profile.has_key?('prof_safetravel'))

            value = 0      
            value = getvalue(profile['prof_usemultipass']) if (profile.has_key?('prof_usemultipass'))      
            PhlatScript.useMultipass = value > 0 ? true :  false
            PhlatScript.multipassDepth = getvalue(profile['prof_multipassdepth']) if (profile.has_key?('prof_multipassdepth'))

            value = 0
            value = getvalue(profile['prof_gen3d']) if (profile.has_key?('prof_gen3d'))
            PhlatScript.gen3D = value > 0 ? true : false

            PhlatScript.stepover = getvalue(profile['prof_stepover']) if (profile.has_key?('prof_stepover'))

         else  # read old format
            inf = IO.readlines(filePath)
            if inf
               inf.each { |line|
                  bits = line.split('=')
                  value = getvalue(bits[1])

                  #puts "final value string " + value.to_s
                  case bits[0]
                     when 'prof_spindlespeed'
                        PhlatScript.spindleSpeed = value
                     when 'prof_feedrate'
                        PhlatScript.feedRate = value.to_f
                     when 'prof_plungerate'
                        PhlatScript.plungeRate = value.to_f
                     when 'prof_cutfactor'
                        PhlatScript.cutFactor = value
                     when 'prof_matthick'
                        PhlatScript.materialThickness = value
                     when 'prof_bitdiameter'
                        PhlatScript.bitDiameter = value
                     when 'prof_tabwidth'
                        PhlatScript.tabWidth = value
                     when 'prof_tabdepth'
                        PhlatScript.tabDepth = value
                     when 'prof_safetravel'
                        PhlatScript.safeTravel = value
                     when 'prof_usemultipass'
                        PhlatScript.useMultipass = value > 0 ? true :  false
                     when 'prof_multipassdepth'
                        PhlatScript.multipassDepth = value
                     when 'prof_gen3d'
                        PhlatScript.gen3D = value > 0 ? true : false
                     when 'prof_stepover'
                        PhlatScript.stepover = value
                  else
                     puts "Unknown variable in load '#{bits[0]}'"
                  end #case
                  }
               PhlatScript.commentText = "Loaded profile #{input[0]}"
               puts "Loaded profile '#{input[0]}'"
            else
               puts "ERROR reading file for load"
            end # if inf
         end # if ini format
      end # if input
   end # def select
end # class

 class ProfilesDeleteTool < ProfilesTool
   def initialize
      @tooltype=(PB_MENU_MENU)
      @tooltip="Delete tool profile"
      @statusText="Delete Tool Profile"
      @menuItem="DelProfile"
      @menuText="Delete Profile"
   end

   def select
      model=Sketchup.active_model
      # prompts
      prompts=["Select Profile to Delete"]

      defaults=['select one']
      # dropdown options can be added here
      list = getDropDownList()
      if list[0] == ""
         UI.messagebox('No profiles found. You have to save a profile before you can delete one')
         return
      end

      input=UI.inputbox(prompts, defaults, list, 'Delete Profile')
      # input is nil if user cancelled
      if (input)
         path = SketchupDirectoryUtils.toolsProfilesPath()        
         toget=input[0] + ".rb"     # delete rb before tpr
         pth = File.join(path,toget)
         if not File.exist?(pth)
            toget=input[0] + ".tpr"
            pth = File.join(path,toget)
         end
         if not File.exist?(pth)
            toget=input[0] + ".tpi"
            pth = File.join(path,toget)
         end
         
        # delete the file
        if File.exist?(pth)
          if File.delete(pth)
            UI.messagebox("Deleted the profile #{input[0]}")
          else
            UI.messagebox("FAILED to delete the profile #{input[0]}")
          end
        else
          UI.messagebox('Profile does not exist for delete')
          puts "delete: not found #{pth}"
        end

      end # if input
    end # def select
  end # class

end #module
