module PhlatScript
  # utility classes for ini file handling
  # IniParser will read ini file and convert it to HashMap
  # IniGenerator will generate ini file from HashMap
  # Make sure that Hash has a proper structure fe:
  #		{"SECTION_NAME" => {"ATTR_NAME"=>"ATTR_VALUE"}}
  # $Id$

  class IniParser

    def isSectionLine(line)
      return false if line[0] == ";"
      return (line.index('[') == 0 and line.index(']') == (line.length-1))
    end

    def sectionName(line)
      #remove first and last char
      if line
        return line[1..line.length()-2]
      end
      return false
    end

    def validateLine(line)
      raise ArgumentError, 'Incorrect file structure at: ' + line  if (not isPropertyLine(line)) && (not isSectionLine(line)) && (line) && (line!= "") && (line[0] != ";")
    end

    def isPropertyLine(line)
      return false  if line[0] == ";"
      if line
        return (line.index('=') != nil)
      end
      return false
    end

    #return key/value tuple for line
    def keyAndValueForLine(line)
      key = line[0 .. line.index('=') - 1]
      value = line[line.index('=') + 1 .. line.length()-1]
      # remove " from string
      value = value.gsub '"', ''
      return key.strip, value.strip
    end

    def removeCommentFromLine(line)
      if line.index(';')
        return line[0 .. line.index(';') - 1]
      end
      return line
    end

    def parseFileAtPath(filePath)
      sections = {}
      fileLines = IO.readlines(filePath)

      if fileLines
        sectionName = nil
        fileLines.each { |line|
          line = line.strip
          line = removeCommentFromLine(line)

          validateLine(line)
          if line[0] !=';'
            if isSectionLine(line)
              sectionName = self.sectionName(line)
              sections[sectionName] = {}
            end
            if self.isPropertyLine(line)
              if sectionName
                key, value = self.keyAndValueForLine(line)
                sections[sectionName][key] = value
              end
            end
          end
        }
      end
      return sections
    end
  end

  class IniGenerator

    def isSimpleType(var)
      return (var.is_a? Fixnum or var.is_a? String or var.is_a? Float or var.is_a? TrueClass or var.is_a? FalseClass)
    end

    def validateMap(map)
      #input map format validation.
      #map needs two levels, one level for sections
      #second level for settings
      raise ArgumentError, "incorrect map\n" if not map
      raise ArgumentError, "incorrect map not a hash\n" + map.to_s if not map.is_a? Hash
      map.each do |key, value|
        raise ArgumentError, "incorrect map not a subHash #{value}\n" + map.to_s if not value.is_a? Hash
        value.each do |deepKey, deepValue|
          raise ArgumentError, "incorrect map not simple\n" + map.to_s if not isSimpleType(deepValue)
        end
      end
    end

    def hashMapToIni(map)
      validateMap(map);
      iniString = ""
      # generate ini, iterate hash map,
      # use templates to generate strings
      map.each do |key, value|
        iniString << "[#{key}]\n"
        value.each do |deepKey, deepValue|
          iniString <<  "#{deepKey}=#{deepValue}\n"
        end
      end
      return iniString
    end

    def dumpHashMapToIni(map, filePath)
      #generate ini string
      iniString = hashMapToIni(map)
      #ensure path exists, force if needed
      dirPath = File.dirname(filePath)
      if not File.exist? dirPath
        Dir.mkdir(dirPath)
      end
      #write to file safely
      iniFile = File.new(filePath,"w")
      begin
        iniFile << iniString
        iniFile.close  # if we don't close it here we will never see the content until after Sketchup closes
      rescue
        iniFile.close unless iniFile.nil?
      end
    end
    
  end
end