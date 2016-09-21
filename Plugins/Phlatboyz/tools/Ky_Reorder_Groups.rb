=begin
Copyright(C) 2010, kyyu
All Rights Reserved
Permission to use, copy, modify, and distribute this software for any purpose
and without fee is hereby granted, provided this notice appears in any copies.
THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

Name:                   Reorder Groups
Version:                1.1
SU Version:     7.0
Date:                   06-12-2010

Description:    Phlatscript plugin generates gcode for cnc.  If you want to manually choose a particular cut order,
                then you must group your parts in that order.  This plugin allows you to easily reorder the groups.

Usage:          Plugin is activated from the Plugin menu, in [kyyu] submenu.  Just hover over the part to auto select the group.
                Push either 1)"Control" key or 2) mouse left click, to do the regroup.  It happens instantly.
                You will notice the group deselects, until you move the cursor.  Then on to the next group.
                Just continue on in the order you want the parts cut.

History:
   1.0 (02-02-2010)  -  first version
   1.1 (06-12-2010)  -  added "mouse left click" option, modified for [kyyu] submenu
   1.1.1 (08-20-2013)   -  swarfer integrates this into the Phlatscript toolset
   $Id$
=end

require 'sketchup.rb'
require 'Phlatboyz/PhlatCut.rb'

module PhlatScript
   class Ky_Reorder_Groups < PhlatTool

       def initialize
         super()
         @tooltype = 3
         @tooltip = PhlatScript.getString("ReOrder Groups")
         @largeIcon = "images/reorder_large.png"
         @smallIcon = "images/reorder_small.png"
         @statusText = "kyyu Reorder Groups"
         @menuText = PhlatScript.getString("ReOrder Groups")
         @statusMsg = "Kyyu Group ReOrder - click groups in the order you want them cut"
       end

      def activate
         @entities = []
         @group_already = 0
         Sketchup::set_status_text(@statusMsg, SB_PROMPT)
      end

      def statusText
         return @statusMsg
      end

    # on MouseMove perform selection
      def onMouseMove(flags, x, y, view)
         ph = view.pick_helper
         found = ph.do_pick(x,y)
         picked = ph.best_picked

         if (picked != nil)
            # do not add edges/faces to selection
             if (!picked.kind_of? Sketchup::Edge and !picked.kind_of? Sketchup::Face and @group_already != 1)
               Sketchup.active_model.selection.add(picked) if (picked != @entities)
               @entities = picked
               @group_already = 1
             end
               if (@entities != picked)
                  Sketchup.active_model.selection.clear
                  @group_already = 0
               end
         else
            Sketchup.active_model.selection.clear
            @entities = nil
	    @group_already = 0
         end
      end

          # process mouse
      def onLButtonDown(flags, x, y, view)
	 model = Sketchup.active_model
	 sel = model.selection
	 if (sel[0] != nil)
	    sel[0].explode
	    Sketchup.undo
	 end
      end

         # process keyboard
      def onKeyDown(key, repeat, flags, view)
         model = Sketchup.active_model
         sel = model.selection
         case key
            when VK_CONTROL
               if (sel[0] != nil)
                  sel[0].explode
                  Sketchup.undo
               end
         end
      end

   end          # end class ku_Reorder_Groups
end # module
#----------------------------------------------------------------------------
# add menu items

#if( not file_loaded?('ky_Reorder_Groups.rb') )
#       if $kyyu_submenu == 1
#               $kyyu_PlugName.add_item('Reorder Groups') { Sketchup.active_model.select_tool Kyyu_Reorder_Groups.new }
#       else
#               $kyyu_PlugName=UI.menu('Plugins').add_submenu('[kyyu]')
#               $kyyu_PlugName.add_item('Reorder Groups') { Sketchup.active_model.select_tool Kyyu_Reorder_Groups.new }
#               $kyyu_submenu = 1
#       end
#end


#file_loaded "ky_Reorder_Groups.rb"
