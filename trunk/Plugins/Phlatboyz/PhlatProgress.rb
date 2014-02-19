# $Id$
#need some sort of progress bar, cannot find the dll so just do text in the statusbar
require ('Phlatboyz/Phlatscript.rb')
#require 'Win32API'

module PhlatScript

#  class ProgressDialog

#    def initialize(caption, steps)
#      #Win32API.new( dllname, procname, importArray, export )
#      @dlg = Win32API.new("C:/Program Files/Google/Google SketchUp 8/plugins/Phlatboyz/PhlatDLL.dll","ProgressDlg",['P', 'L'],"V")
#      @step = Win32API.new("C:/Program Files/Google/Google SketchUp 8/plugins/Phlatboyz/PhlatDLL.dll","ProgressStep",['L'],"V")
#      @close = Win32API.new("C:/Program Files/Google/Google SketchUp 8/plugins/Phlatboyz/PhlatDLL.dll","ProgressClose",[],"V")
#      @dlg.call(caption, steps)
#    end
# 
#    def step
#      @step.call(0)
#    end#

#    def position=(position)
#      @step.call(position)
#    end#
#
#    def close
#      @close.call
#    end
#
#  end
#

#  pb = PhProgressBar.new(items_to_process) 
#  To update the status bar: 
#  pb.update(item number)  

   class PhProgressBar 

      @@background = "-" * 50    
      @@foreground = "*" * 50

      def initialize(total)  
         if (!total.integer? or total < 0)
            total = 100
         end 
         @total = total.to_i
         self.update(1)
      end
      
      def symbols(back,fore)
        @@background = back * 50
        @@foreground = fore * 50
      end

      def update(progress) 
         if !progress.integer? 
            progress = progress.to_i  
            return
         end  
         now = progress.abs
         if now > @total
            now = @total
         end
         pct = (now*100)/@total
         pct = 2 if (pct < 2) 
         pct_p = pct / 2 
         block = @@foreground[0,pct_p-1] + @@background[0,50-pct_p]
         Sketchup.set_status_text(block)
      end
   end  



end