require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/utils/SketchupDirectoryUtils.rb'

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
          #create file
          filePath = File.join(path, profilename + '.tpr')
          outf=File.new(filePath,"w")
          #write contents
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
        else
          print "ERROR path does not exist #{path}"
        end # path exists so we saved it
      end # if input
    end # def select
  end # class

  class ProfilesTool < PhlatTool
    def getDropDownList
      list=[""]
      path = SketchupDirectoryUtils.toolsProfilesPath()
      if not File.exist?(path)
        Dir.mkdir(path)
      end
      if File.exist?(path)
        #print "path exists\n"
        Dir.foreach( path ) {| filename |
          #puts "got #{filename}"
          if filename.index('.rb') or filename.index('.tpr')
            filename=filename.gsub(/\.rb|\.tpr/,"")
            if list[0] == ""
              list=[filename]
            else
              list[0]= list[0] + "|#{filename}"
            end
          end
        }
        #            puts list
      end
      return list
    end
  end
  
  class ProfilesLoadTool < ProfilesTool
    def initialize
      @tooltype=(PB_MENU_MENU)
      @tooltip="Load tool profile"
      @statusText="Load Tool Profile"
      @menuItem="LoadProfile"
      @menuText="Load Profile"
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

      input=UI.inputbox(prompts, defaults, list, 'Load Profile')
      # input is nil if user cancelled
      if (input)
        fileNameToOpen = input[0] + ".tpr"  # select tpr before rb
        filePath = File.join(path , fileNameToOpen)
        if not File.exist?(filePath)
          fileNameToOpen = input[0] + ".rb"
          filePath= File.join(path , fileNameToOpen)
        end

        # load and interpret the file, creating variables

        inf = IO.readlines(filePath)
        if inf
          inf.each { |line|
            #                  puts line
            bits = line.split('=')
            #puts "bits[1] #{bits[1]}"

            if bits[1].index('.mm')
              value = bits[1].gsub('.mm','').to_f / 25.4    # to_l does not get it right when drawing is metric
              #puts "mm to inch #{value}"
            else
              if bits[1].index('.inch')
                value = bits[1].gsub('.inch','').to_f
              else
                value = bits[1].to_f
              end
            end

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
              puts "Unknown variable in load"
            end
          }
          PhlatScript.commentText = "Loaded profile #{input[0]}"
          puts "Loaded profile '#{input[0]}'"
        else
          puts "ERROR reading file for load"
        end
        
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
        toget=input[0] + ".rb"     # delete rb before tpr
        pth = File.join(path,toget)
        if not File.exist?(pth)
          toget=input[0] + ".tpr"
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
