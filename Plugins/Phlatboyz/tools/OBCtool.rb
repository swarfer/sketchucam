require 'sketchup.rb'
# David the Swarfer, 2019
require 'Phlatboyz/PhlatboyzMethods.rb'
require 'Phlatboyz/PhlatTool.rb'
require 'net/http'  #only from Sketchup Make 2014 upwards

module PhlatScript

   # A tool for sending Gcode to the OpenbuildsCONTROL interface
   class OBCsquirt < PhlatTool

      def initialize
         super()
         toolname = 'Send to OpenBuildsCONTROL'
         @tooltype=(PB_MENU_TOOLBAR)
         @tooltip="Send Gcode"
         @statusText= "Send latest file to OpenbuildsCONTROL"
         @largeIcon = "images/OBicon_large.png"
         @smallIcon = "images/OBicon_small.png"
         @cmmd = nil
      end

      def statusText
         return @statusText
      end

      def cmmd=(val)
         @cmmd =  val
      end
      # Send the latest file to OBCONTROL
      def select
         if haveOBC?
            puts "haveobc"
            if sendToOBC
               puts "sent"
            end
         else
            UI.messagebox("OpenBuildsCONTROL is not active")
         end
      end #select
      
      # detect an instance of OBCONTROL
      def haveOBC?
         server = 'mymachine.openbuilds.com'
         url = URI("http://#{server}:3000/api/version")
         #check if the driver is loaded
         begin
            res = Net::HTTP.get_response(url)
         rescue Errno::ECONNREFUSED, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
                Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
            return false
            #puts "rescued - OB server not found at #{server}"
            #exit
         end    
         if res.code == '200'
            ver = Net::HTTP.get(url)
            puts ver
            return true
         else
            return false
            #puts 'Driver not found with code #{res.code}'
            #exit
         end
      end

      # sned the most recently saved gcode file to the OBC instance
      # only call this if OBC actually exists
      def sendToOBC
         puts "sendToOBC"
         server = 'mymachine.openbuilds.com'
         url = URI("http://#{server}:3000/upload")
         
         filename = PhlatScript.cncFileDir + PhlatScript.cncFileName
         puts "   #{filename}"
         data = File.read(filename)
         
         request = Net::HTTP::Post.new(url)
         #request["User-Agent"] = 'PostmanRuntime/7.13.0'
         #request["Accept"] = '*/*'
         request["Cache-Control"] = 'no-cache'
         #request["Postman-Token"] = '9cd91cbf-4d85-4e0f-ad35-6cef45453e71,1c053219-f3ad-4d43-9f3f-46c22253f5bc'
         request["Host"] = 'mymachine.openbuilds.com:3001'
         request["accept-encoding"] = 'gzip, deflate'
         request["content-type"] = 'multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW'
         request["Connection"] = 'keep-alive'
         request["cache-control"] = 'no-cache'
         # important to add the actual file data to the body!
         request.body = "------WebKitFormBoundary7MA4YWxkTrZu0gW\r\nContent-Disposition: form-data; name=\"file\"; filename=\"edited-gcode.gcode\"\r\nContent-Type: false\r\n\r\n#{data}\r\n\r\n------WebKitFormBoundary7MA4YWxkTrZu0gW--"
         #now update the body length
         request["content-length"] = request.body.length
         
         #by doing it this way I can set use_ssl to true, otherwise we must use http not https
         # I do get ssl cert errors when sending to a remote machine
         response = Net::HTTP.start(url.hostname, url.port, use_ssl: false) do |http|
            res = http.request(request)
            case res
               when Net::HTTPSuccess then
                  puts '   success'
               else
                  puts '   failed'
            end
         end
      end
      
   end # class
end # module