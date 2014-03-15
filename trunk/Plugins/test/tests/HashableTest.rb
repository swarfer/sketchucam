module PhlatScript

  class Hashable

    def toHash
      #function checks all instance variables set on object and converts them to a Hash.
      hash = {}
      self.instance_variables.each {|var|
        varVal = self.instance_variable_get(var)
        value = varVal.toHash() if varVal.is_a? Hashable
        value = varVal if not varVal.is_a? Hashable
        hash[var.to_s.delete("@")] = value}
      return hash
    end
  end

  class MachineSettings < Hashable

    def initialize
      @safeAreaX = 500
      @safeAreaY = 500
    end
  end

  class ToolSettings < Hashable

    def initialize
      @spindleSpeed = 8000
      @cutFactor = 1.2
      @bitDiameter = 6.35
      @tabWidth = 8
      @tabDepth = 8
      @feedRate = 300
      @plungeRate = 300
    end
  end

  class MaterialSettings < Hashable

    def initialize
      @materialThickness = 25
      @safeTravel = 30
      @useMultipass = true
      @multipassDepth = 5
      @stepover = 0.7
    end
  end

  class GeneralSettings < Hashable

    def initialize
      @gen3D = true
      @showGplot = false
      @commentText = "comment"
    end
  end

  class SettingsPrototype < Hashable

    def initialize
      @material = MaterialSettings.new()
      @machine = MachineSettings.new()
      @tool = ToolSettings.new()
      @material = MaterialSettings.new()
      @general = GeneralSettings.new()
    end
  end

  require_relative 'TestBase'
  class HashableTest < TestBase
    def run
      settings = SettingsPrototype.new()
      puts settings.toHash()
    end
  end

end