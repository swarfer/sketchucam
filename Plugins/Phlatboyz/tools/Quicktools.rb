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

class FourthAxisTool < PhlatTool

      def initialize
         toolname = 'Fourth Axis Tool'
         @tooltype=(PB_MENU_QTOOL)
         @tooltip="Fourth Axis Settings"
         @statusText= "Select 4th Axis options"
         @menuItem="Fourth Axis"
         @menuText="Fourth Axis"
         @largeIcon = "images/rotate_large.png"
         @smallIcon = "images/rotate_small.png"
         @cmmd = nil
      end
      
      def statusText
         return @statusText
      end
       
      def cmmd=(val)
         @cmmd =  val
      end
      
      def select
         # prompts
         prompts=['Use A axis ',
            'A axis position ',
            'Use B axis ',
            'B axis position ',
            'Use C axis ',
            'C axis position '            ]

         defaults=[
            $phoptions.useA?.inspect(),
            $phoptions.posA.to_s,
            $phoptions.useB?.inspect(),
            $phoptions.posB.to_s,
            $phoptions.useC?.inspect(),
            $phoptions.posC.to_s
            ]
         # dropdown options can be added here
         list=[            
            "true|false",
            "",
            "true|false",
            "",
            "true|false",
            ""
            ]

         input=UI.inputbox(prompts, defaults, list, 'Rotation options')
         # input is nil if user cancelled
         if (input)
            $phoptions.useA                    = (input[0] == 'true')
            $phoptions.posA                    = input[1].to_f
            $phoptions.useB                    = (input[2] == 'true')
            $phoptions.posB                    = input[3].to_f
            $phoptions.useC                    = (input[4] == 'true')
            $phoptions.posC                    = input[5].to_f
            
            #puts "useA #{$phoptions.useA?.to_s}"
            #puts "posA #{$phoptions.posA.to_s}"
            #puts "useB #{$phoptions.useB?.to_s}"
            #puts "posB #{$phoptions.posB.to_s}"
         end # if input      end #select
      end
   end # class
   
   
end # module