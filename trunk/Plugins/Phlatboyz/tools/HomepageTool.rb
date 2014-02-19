
require 'Phlatboyz/PhlatTool.rb'

module PhlatScript

  class HomepageTool < PhlatTool

    def initialize
      @tooltype = 3
      @tooltip = PhlatScript.getString("Go To Phlatboyz Homepage")
      @largeIcon = "images/phlatboyz_homepage_large.png"
      @smallIcon = "images/phlatboyz_homepage_small.png"
      @statusText = PhlatScript.getString("Go To Phlatboyz Homepage")
      @menuItem = PhlatScript.getString("Phlatboyz Homepage")
      @menuText = PhlatScript.getString("Homepage")
    end

    def select
      UI.openURL("http://phlatboyz.com")
    end

  end

end