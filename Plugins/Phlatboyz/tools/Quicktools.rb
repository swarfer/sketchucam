#some tools to allow quick changing of some options, only on quick toolbar

require 'Phlatboyz/PhlatTool.rb'
# $Id$
module PhlatScript
   class UseCommentsTool < PhlatTool

      def initialize
         toolname = 'Use Comments?'
         @tooltype=(PB_MENU_QTOOL)
         @tooltip="Toggle Use Comments"
         @statusText= ($phoptions.usecomments?) ? "UseComments is ON" : "UseComments is OFF"
         @menuItem="Comments on/off"
         @menuText="Comments on/off"
         @largeIcon = "images/comment_large.png"
         @smallIcon = "images/comment_small.png"
         @cmmd = nil
      end
      
      def statusText
         return @statusText
      end
       
      def cmmd=(val)
         @cmmd =  val
      end
      
      def select
         $phoptions.usecomments = !$phoptions.usecomments?
         if (@cmmd != nil)
            @cmmd.status_bar_text = ($phoptions.usecomments?) ? "UseComments is ON" : "UseComments is OFF" 
         end
      end #select
   end # class

class UseBracketsTool < PhlatTool

      def initialize
         toolname = 'Comment Style'
         @tooltype=(PB_MENU_QTOOL)
         @tooltip="Toggle Comment style"
         @statusText= ($phoptions.bracket?) ? "Comment style is ()" : "Comment style is ;" 
         @menuItem="Toggle Comment Style"
         @menuText="Toggle Comment Style"
         @largeIcon = "images/bracket_large.png"
         @smallIcon = "images/bracket_small.png"
         @cmmd = nil
      end
      
      def statusText
         return @statusText
      end
       
      def cmmd=(val)
         @cmmd =  val
      end
      
      def select
         $phoptions.bracket = !$phoptions.bracket?
         if (@cmmd != nil)
            @cmmd.status_bar_text = ($phoptions.bracket?) ? "Comment style is ()" : "Comment style is ;" 
         end
      end #select
   end # class

end # module