require 'sketchup.rb'
require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/utils/SketchupDirectoryUtils.rb'
# $Id: HelpTool.rb 57 2014-07-27 16:18:12Z swarfer@gmail.com $
module PhlatScript

   class RampTabTool < PhlatTool

      def initialize
         super()
         @tooltype=(PB_MENU_MENU)
         @tooltip="Set Ramp VTabs"
         @statusText="Set Ramp VTabs"
         @menuText="Set Ramp VTabs"
      end

# calculate the correct tab width, and recalculate the depth, such that the rampangle is obeyed for V tabs
#  tab has to be wider and higher in order to get the correct desired height
#  higher by tan(a) * ()bit/2)
#  wider by 1 bit diam
      def select

# T the tab width to get rampangle V tabs
# a = rampangle in radians
# th = (100-td/100)    real tab height percent
# O = MT * (100-td/100)
# A = O / tan(a)
# T = A * 2 + bitdiam

# height offset o =  tan(a) * bit/2
# new tab depth = 100 - (((th * mt) + o) / mt * 100)
# new tab width = T + bitdiam
        msg = ''
         a = PhlatScript.torad(PhlatScript.rampangle.to_f)
        msg += "a in radians #{a}\n"
         th = (100-PhlatScript.tabDepth.to_f) / 100  # tab thickness percent
        msg += "th = #{th}\n"
         o = PhlatScript.materialThickness.to_f * th  # physical tab thickness
        msg += "phys tab o = #{o.to_mm}\n"
         aa = o / Math::tan(a)
        msg += "aa = #{aa.to_mm}\n"
         t = aa * 2 + PhlatScript.bitDiameter
        msg += "t = #{t.to_mm}\n"
         ho = Math::tan(a) * (PhlatScript.bitDiameter/2)
        msg += "height adjust ho = #{ho.to_mm}\n"
         newdepth = 100 - ((o + ho) / PhlatScript.materialThickness * 100)
         newwidth = t 
        msg += "new depth = #{newdepth}\nnewwidth=#{newwidth.to_mm}"
         PhlatScript.tabDepth = newdepth.round
         PhlatScript.tabWidth = newwidth
#         UI.messagebox(msg,MB_MULTILINE)
      end #select
   end # class

end
