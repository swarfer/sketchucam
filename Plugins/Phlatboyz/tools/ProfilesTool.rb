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
    out=out.gsub(/~ /,'')
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
      @prof_savematthick = ($phoptions.profile_save_material_thickness? ? '1' : '0') # we save this and only set mattthick if this is 1 when we read
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
      @prof_mustramp    = (PhlatScript.mustramp?  ? '1' : '0')
      @prof_rampangle   = PhlatScript.rampangle.to_f.to_s
      
      @prof_toolnum = $phoptions.toolnum.to_i.to_s
      @prof_useg43  = $phoptions.useg43? ?  '1' : '0'
      @prof_useH    = $phoptions.useH?   ? '1' : '0'
      @prof_toolh   = $phoptions.toolh.to_i.to_s
      @prof_toolfile = $phoptions.toolfile
      @prof_tooloffset = PhlatScript.conformat($phoptions.tooloffset)
   end
end
#-----------------------------------------------------------------------------

  class ProfilesSaveTool < PhlatTool
    def initialize
      super()
      @tooltype=(PB_MENU_MENU)
      @tooltip="Save tool profile"
      @statusText="Save Tool Profile"
      @menuText="Save profile"
    end

    def select
      model=Sketchup.active_model
      
      tct = ToolChangeTool.new
      tct.select
      
#use savepanel
      path = PhlatScript.toolsProfilesPath()
      if not File.exist?(path)
         Dir.mkdir(path)
      end      
      trying = true
      #deal with the pre 2014 dialog bug
      @vv = Sketchup.version.split(".")[0].to_i  #primary version number      
      if (@vv >= 14)
         wildcard = '.tpi Files|*.tpi|All tool files|*.t*||'
      else
         wildcard = "default.tpi"
      end
      
      while trying do
         result = UI.savepanel(PhlatScript.getString("Save Tool Profile"), path, wildcard)
         if (result != nil)
            result = File.basename(result)  # remove path because we force it later
            result += '.tpi' if (File.extname(result).empty?)
            if !result.match(/\.tpi/)
               UI.messagebox('Please select a *.tpi file or omit the extension')
            else
               trying = false
            end
         else
            trying = false
         end
      end # while
      
      if (result != nil)   
         profilename = result.gsub(/ /,'') # never allow spaces in names
=begin
      # prompts
      prompts=['Name']
      defaults=['default']
      # dropdown options can be added here
      #         list=["henry|bob|susan"] #should give list of existing?

      input=UI.inputbox(prompts, defaults, 'Save Tool Profile')
      # input is nil if user cancelled
      if (input)
         profilename=input[0].to_s.gsub(/ /,'')
=end      
         print "saving to #{profilename} in path #{path}\n"

         if File.exist?(path)
            #write contents to ini file format - this will supplant current tpr format over time
            generator = IniGenerator.new()
            prof = ProfileSettings.new()
            ohash = {'profile' => prof.toHash}
            filePath = File.join(path, profilename)
            generator.dumpHashMapToIni(ohash, filePath)
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
      path = PhlatScript.toolsProfilesPath()
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
      super()
      @tooltype=(PB_MENU_MENU)
      @tooltip="Load tool profile"
      @statusText="Load Tool Profile"
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
               if str == 'true'
                  value = 1
               else
                  if str == 'false'
                     value = 0
                  else
                     value = str.to_f
                  end
               end
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

#      if PhlatScript.multipassEnabled?
         defaults.push(PhlatScript.useMultipass?.inspect())
         defaults.push(Sketchup.format_length(PhlatScript.multipassDepth))
#      end
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
      path = PhlatScript.toolsProfilesPath()
      input=UI.inputbox(prompts, defaults, list, 'Load Profile')
      # input is nil if user cancelled
      if (input)
         fileNameToOpen = input[0] + ".tpi"  # select ini before tpr and rb
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
            die "error finding file #{filePath}"
         end
         # load and interpret the file, updating variables
         if filePath.index('.tpi')
            puts 'using ini file'
            ini = IniParser.new()
            sections = ini.parseFileAtPath(filePath)
#            puts(sections)
            profile = sections['profile'] # get the profile hash
#            puts 'keys'
#            puts profile.keys
            PhlatScript.spindleSpeed = getvalue(profile['prof_spindlespeed'])    if (profile.has_key?('prof_spindlespeed'))
            PhlatScript.feedRate    = getvalue(profile['prof_feedrate'])         if (profile.has_key?('prof_feedrate'))
            PhlatScript.plungeRate  = getvalue(profile['prof_plungerate'])       if (profile.has_key?('prof_plungerate'))
            PhlatScript.cutFactor   = getvalue(profile['prof_cutfactor'])        if (profile.has_key?('prof_cutfactor'))
            useit = 0
            useit = getvalue(profile['prof_savematthick'])                       if (profile.has_key?('prof_savematthick'))
            if useit == 1
               PhlatScript.materialThickness = getvalue(profile['prof_matthick']) if (profile.has_key?('prof_matthick'))
            end
            PhlatScript.bitDiameter = getvalue(profile['prof_bitdiameter'])      if (profile.has_key?('prof_bitdiameter'))
            PhlatScript.tabWidth = getvalue(profile['prof_tabwidth'])            if (profile.has_key?('prof_tabwidth'))
            PhlatScript.tabDepth = getvalue(profile['prof_tabdepth'])            if (profile.has_key?('prof_tabdepth'))
            PhlatScript.safeTravel = getvalue(profile['prof_safetravel'])        if (profile.has_key?('prof_safetravel'))

            value = -1
            value = getvalue(profile['prof_usemultipass'])                       if (profile.has_key?('prof_usemultipass'))
            PhlatScript.useMultipass = value > 0 ? true :  false                 if (value != -1)
            PhlatScript.multipassDepth = getvalue(profile['prof_multipassdepth']) if (profile.has_key?('prof_multipassdepth'))

            value = -1
            value = getvalue(profile['prof_gen3d'])                              if (profile.has_key?('prof_gen3d'))
            PhlatScript.gen3D = value > 0 ? true : false                         if (value != -1)

            PhlatScript.stepover = getvalue(profile['prof_stepover'])            if (profile.has_key?('prof_stepover'))
            
            @prof_mustramp    = (PhlatScript.mustramp?  ? '1' : '0')
            @prof_rampangle   = PhlatScript.rampangle.to_f.to_s

            value = -1
            value = getvalue(profile['prof_mustramp'])                           if (profile.has_key?('prof_mustramp'))
            PhlatScript.mustramp = value > 0 ? true : false                         if (value != -1)
            PhlatScript.rampangle = getvalue(profile['prof_rampangle'])          if (profile.has_key?('prof_rampangle'))
#stuff for tool change        
            $phoptions.toolnum = -1.to_i
            $phoptions.toolnum   =  getvalue(profile['prof_toolnum']).to_i       if (profile.has_key?('prof_toolnum'))
         #puts "$phoptions.toolnum #{$phoptions.toolnum}"
            value = -1
            value = getvalue(profile['prof_useg43'])                             if (profile.has_key?('prof_useg43'))
            $phoptions.useg43 = false
            $phoptions.useg43 = value > 0 ? true : false                        if (value != -1)
         #puts "$phoptions.useg43 #{$phoptions.useg43?}"
           
            value = -1
            value = getvalue(profile['prof_useH'])                             if (profile.has_key?('prof_useH'))
            $phoptions.useH = false
            $phoptions.useH = value > 0 ? true : false                        if (value != -1)
         #puts "$phoptions.useH #{$phoptions.useH?}"
            
            $phoptions.toolh = -1.to_i
            $phoptions.toolh = getvalue(profile['prof_toolh']).to_i            if (profile.has_key?('prof_toolh'))
         #puts "$phoptions.toolh #{$phoptions.toolh}"   
         
            $phoptions.toolfile = 'no'
            $phoptions.toolfile = profile['prof_toolfile']                     if (profile.has_key?('prof_toolfile'))
         #puts "$phoptions.toolfile #{$phoptions.toolfile}"
         
            $phoptions.tooloffset = 0.to_l
            $phoptions.tooloffset = getvalue(profile['prof_tooloffset'])       if (profile.has_key?('prof_tooloffset'))
         #puts "$phoptions.tooloffset #{$phoptions.tooloffset} #{$phoptions.tooloffset.class}"

            PhlatScript.commentText = "Loaded profile #{input[0]}"
            puts "Loaded profile '#{input[0]}' from ini"

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
      super()
      @tooltype=(PB_MENU_MENU)
      @tooltip="Delete tool profile"
      @statusText="Delete Tool Profile"
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
         path = PhlatScript.toolsProfilesPath()
=begin
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
=end
         exts = [".rb",".tpr",".tpi"]  #need to delete all the possible extensions
         count=0
         exts.each {|ext|
            toget=input[0] + ext
            pth = File.join(path,toget)
            if File.exist?(pth)
               if File.delete(pth)
                  count += 1
               end
            end
            }
         if count > 0
            UI.messagebox("Deleted the profile #{input[0]}")
         else
            UI.messagebox('Profile does not exist for delete')
            puts "delete: not found #{pth}"
         end
         # delete the file
=begin
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
=end
      end # if input
    end # def select
  end # class

end #module
