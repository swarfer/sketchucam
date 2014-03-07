module PhlatScript
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
      key= line[0 .. line.index('=')-1]
      value = line[line.index('=') + 1 .. line.length()-1]
      # remove " from string
      value = value.gsub '"', ''
      return key.strip, value.strip
    end

    def parseFileAtPath(filePath)
      sections = {}
      fileLines = IO.readlines(filePath)
      globals = {"values:" => {}}

      if fileLines
        sectionName = nil
        fileLines.each { |line|
          line = line.strip
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
end