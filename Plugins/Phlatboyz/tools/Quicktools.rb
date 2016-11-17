# QuickTools - some tools to allow quick changing of some options, only on quick toolbar.

require 'Phlatboyz/PhlatTool.rb'

module PhlatScript
   # Turn comments on or off
   class UseCommentsTool < PhlatTool

      def initialize
         super()
         toolname = 'Use Comments?'
         @tooltype=(PB_MENU_QTOOL)
         #@tooltip="Toggle Use Comments"
         @statusText= ($phoptions.usecomments?) ? "UseComments is ON" : "UseComments is OFF"
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
      # Turn comments on or off
      def select
         $phoptions.usecomments = !$phoptions.usecomments?
         if (@cmmd != nil)
            @cmmd.status_bar_text = ($phoptions.usecomments?) ? "UseComments is ON" : "UseComments is OFF" 
         end
      end #select
   end # class

# Change bracket mode
class UseBracketsTool < PhlatTool

      def initialize
         super()
         toolname = 'Comment Style'
         @tooltype=(PB_MENU_QTOOL)
         @tooltip="Toggle Comment style"
         @statusText= ($phoptions.bracket?) ? "Comment style is ()" : "Comment style is ;" 
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

# Set fourth axis options   
class FourthAxisTool < PhlatTool

      def initialize
         super()
         toolname = 'Fourth Axis Tool'
         @tooltype=(PB_MENU_QTOOL)
         @tooltip="Fourth Axis Settings"
         @statusText= "Select 4th Axis options"
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
            $phoptions.posA.to_f,
            $phoptions.useB?.inspect(),
            $phoptions.posB.to_f,
            $phoptions.useC?.inspect(),
            $phoptions.posC.to_f
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
         begin
            input=UI.inputbox(prompts, defaults, list, 'Rotation options')
         rescue ArgumentError => error
            UI.messagebox(error.message)
            retry
         end
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

# Set tool change options   
class ToolChangeTool < PhlatTool

      def initialize
         super()
         toolname = 'Tool Change Tool'
         @tooltype=(PB_MENU_QTOOL)
         @tooltip="Tool Change Settings"
         @statusText= "Select Tool Change options"
         @menuText="Tool Change"
         @largeIcon = "images/toolchange_large.png"
         @smallIcon = "images/toolchange_small.png"
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
         prompts=['Tool Number (-1 for none)',
            'Use G43',
            'Use H',
            'H Number',
            'OR: Use Tool File (ignores above)',
            'AND Tool Offset'            ]

         defaults=[
            $phoptions.toolnum.to_i,
            $phoptions.useg43?.inspect(),
            $phoptions.useH?.inspect(),
            $phoptions.toolh.to_i,
            $phoptions.toolfile,
            $phoptions.tooloffset   #must be a length
            ]
         # dropdown options can be added here
         tf = $phoptions.toolfile == 'no' ? "no|yes - prompt after Ok" : "no|#{$phoptions.toolfile}|yes"
         list=[            
            "",
            "true|false",
            "true|false",
            "",
            tf,
            ""
            ]
         begin
            input=UI.inputbox(prompts, defaults, list, 'Tool Change options')
         rescue ArgumentError => error
            UI.messagebox(error.message)
            retry
         end
         # input is nil if user cancelled
         if (input)
         
            if input[4] == 'no'
            #puts "use normal tool change"
               $phoptions.toolnum                 = input[0] < 0 ? -1 : input[0]
               $phoptions.useg43                  = (input[1] == 'true')
               $phoptions.useH                    = (input[2] == 'true')
            #puts "$phoptions.useH #{$phoptions.useH?}"
               if ($phoptions.useH?)
                  if input[3] > -1
                     $phoptions.toolh                   = input[3]
                     #puts "toolh #{$phoptions.toolh}"
                  else
                     $phoptions.useH = false
                     #puts "forced useh false"
                  end
               end
               $phoptions.toolfile = 'no'
               $phoptions.tooloffset = 0.to_l
            else
               if input[4].match(/yes/)
                  #puts "# get filename from user"
                  file_ext = $phoptions.default_file_ext	# Local variable so we can format it
                  file_ext = file_ext.upcase				# Convert string to upper case
                  if (file_ext[0].chr == ".")				# First char is a dot
                     file_ext.slice!(0)					# Remove the dot
                  end
                  @vv = Sketchup.version.split(".")[0].to_i  #primary version number
                  path = PhlatScript.toolsProfilesPath()
                  if (@vv >= 14)
                     #for >= 2014
                     wildcard = ".#{file_ext} Files|\*.#{file_ext}|All Files|\*.\*||"
                     result = UI.openpanel("Select toolchange G-code file.", path, wildcard)
                  else
                     #for < 2014 dialog is broken so work around it
                     wildcard = "toolchange.#{file_ext}"
                     result = UI.openpanel("Select Toolchange G-code file.", path, wildcard)
                  end
                  if (result && File.exists?(result))
                     $phoptions.toolnum = -2
                     $phoptions.toolfile = result
                     $phoptions.tooloffset = input[5]
                  else
                     UI.messagebox('File not found, ignoring')
                  end
               else  #it is a filename
                  $phoptions.toolnum = -2
                  #puts "# do not change existing toolfile"
                  $phoptions.tooloffset = input[5]
               end
            end
            #puts "toolnum #{$phoptions.toolnum}"
            #puts "useG43  #{$phoptions.useg43?.inspect()}"
            #puts "useH    #{$phoptions.useH?.inspect()}"
            #puts "toolh   #{$phoptions.toolh}"
         end # if input      end #select
      end
   end # class
   
   
end # module