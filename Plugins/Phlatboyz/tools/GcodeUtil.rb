require 'sketchup.rb'
#require 'Phlatboyz/Constants.rb'

require 'Phlatboyz/PhlatboyzMethods.rb'
require 'Phlatboyz/PhlatOffset.rb'

require 'Phlatboyz/PhlatMill.rb'
require 'Phlatboyz/PhlatTool.rb'
require 'Phlatboyz/PhlatCut.rb'
require 'Phlatboyz/PSUpgrade.rb'
require 'Phlatboyz/Phlat3D.rb'
require 'Phlatboyz/PhlatProgress.rb'

module PhlatScript

  class GroupList < PhlatTool
    # this tool gets the list of groups containing phlatcuts and displays them in the cut order
    # it displays 2 levels deep in the case of a group of groups
    def initialize
       @tooltype=(PB_MENU_MENU)
       @tooltip="Group Listing in cut order"
       @statusText="Groups Summary display"
       @menuItem="Groups Summary"
       @menuText="Groups Summary"
    end

    # recursive method to add all group names to msg
    def listgroups(msg, ent, ii, depth)
      ent.each { |bit|
         if (bit.kind_of?(Sketchup::Group))
            bname = (bit.name.empty?) ? 'no name' : bit.name
            spacer = "   " * depth
            msg += spacer + ii.to_s + " - " + bname + "\n"
            msg = listgroups(msg,bit.entities,ii,depth+1)
         end
         }
      return msg
    end

    def select
      groups = GroupList.listgroups()
      msg = "Summary of groups in CUT ORDER\n"
      if (groups.length > 0)
         i = 1
         groups.each { |e|
            ename = (e.name.empty?) ? 'no name' : e.name
            if (!ename.include?("safearea") )
               msg += i.to_s + " - " + ename + "\n"
               msg = listgroups(msg,e.entities,i,1)       # list all the groups that are members of this group
               i += 1
            end
            } #groups.each
      else
         msg += "No groups found to cut\n"
      end
      UI.messagebox(msg,MB_MULTILINE)
    end #select

    # copied from loopnodefromentities so if that changes maybe this should too
    def GroupList.listgroups
      #copied from "loopnodefromentities" and trimmed to just return the list of groups
      model = Sketchup.active_model
      entities = model.active_entities
      safe_area_points = P.get_safe_area_point3d_array()
      # find all outside loops
      loops = []
      groups = []
      phlatcuts = []
      dele_edges = [] # store edges that are part of loops to remove from phlatcuts
      entities.each { |e|
        if e.kind_of?(Sketchup::Face)
          has_edges = false
          # only keep loops that contain phlatcuts
          e.outer_loop.edges.each { |edge|
            pc = PhlatCut.from_edge(edge)
            has_edges = ((!pc.nil?) && (pc.in_polygon?(safe_area_points)))
            dele_edges.push(edge)
          }
          loops.push(e.outer_loop) if has_edges
        elsif e.kind_of?(Sketchup::Edge)
            # make sure that all edges are marked as not processed
            pc = PhlatCut.from_edge(e)
            if (pc)
              pc.processed = (false)
              phlatcuts.push(pc) if ((pc.in_polygon?(safe_area_points)) && ((pc.kind_of? PhlatScript::PlungeCut) || (pc.kind_of? PhlatScript::CenterLineCut)))
            end
        elsif e.kind_of?(Sketchup::Group)
          groups.push(e)
        end
        } # entities.each

      # make sure any edges part of a curve or loop aren't in the free standing phlatcuts array
      phlatcuts.collect! { |pc| dele_edges.include?(pc.edge) ? nil : pc }
      phlatcuts.compact!
      puts("Located #{groups.length.to_s} GROUPS containing PhlatCuts")   if (groups.length > 0)
      groups.each { |e|
        group_name = e.name
        puts "(Group: #{group_name})" if !group_name.empty?
        } #groups.each
      loops.flatten!
      loops.uniq!
      puts("Located #{loops.length.to_s} loops containing PhlatCuts") if (loops.length > 0)
      return groups
    end #listgroups

  end
#-%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  class GcodeUtil < PhlatTool

      @@x_save = nil
      @@y_save = nil
      @@cut_depth_save = nil
      @g_save_point = Geom::Point3d.new(0, 0, 0) #swarfer: after a millEdges call, this will have the last point cut

      #experimental - turn off for distribution
      @fakeorigin = false
      @optimize = true
      
      @current_bit_diameter = 0
      @tabletop = false
      @must_ramp = false    # make this an option!
      @limitangle = 0      # if > 0 will limit to this ramp angle
      @debug = false
      @level = 0
    def initialize
      @tooltype = 3
      @tooltip = PhlatScript.getString("Phlatboyz GCode")
      @largeIcon = "images/gcode_large.png"
      @smallIcon = "images/gcode_small.png"
      @statusText = PhlatScript.getString("Phlatboyz GCode")
      @menuItem = PhlatScript.getString("GCode")
      @menuText = PhlatScript.getString("GCode")

   end

   def select
      if PhlatScript.gen3D
         result = UI.messagebox 'Generate 3D GCode?', MB_OKCANCEL
         if result == 1  # OK
            GCodeGen3D.new.generate
            if PhlatScript.showGplot?
               GPlot.new.plot
               Sketchup.active_model.select_tool(nil)  #auto select the select tool to force program show
            end
         else
            return
         end
      else
         GcodeUtil.generate_gcode
         if PhlatScript.showGplot?
            GPlot.new.plot
            Sketchup.active_model.select_tool(nil)  #auto select the select tool to force program show
         end
      end
   end

    def statusText
      return "Generate Gcode output"
    end

    def GcodeUtil.generate_gcode
#      if PSUpgrader.upgrade
#        UI.messagebox("GCode generation has been aborted due to the upgrade")
#        return
#      end

            #swarfer: need these so that all aMill calls are given the right numbers, aMill should be unaware of defaults
      # by doing this we can have Z0 on the table surface, or at top of material
      @tabletop = PhlatScript.tabletop?

      if (@tabletop)
         @safeHeight =  PhlatScript.materialThickness + PhlatScript.safeTravel.to_f
         @materialTop = PhlatScript.materialThickness
         #ZL = material thickness(MT)
         #               cut = ZL - (cutfactor * MT)
         #               safe = ZL+SH  {- safe height is safe margin above material
         @zL = PhlatScript.materialThickness
      else
         @safeHeight = PhlatScript.safeTravel.to_f
         @materialTop = 0
         @zL = 0
         #Mat Zero : ZL = 0
         #              cut = ZL - (cf * MT)
         #              safe = ZL + SH   {- safeheight is mt + some safety margin
      end
      @rampangle = PhlatScript.rampangle.to_f
      @must_ramp = PhlatScript.mustramp?

puts(" safeheight '#{@safeHeight.to_mm}'\n")
puts(" materialTop '#{@materialTop.to_mm}'\n")
puts(" ZL '#{@zL.to_mm}'\n")
puts(" tabletop '#{@tabletop}'\n")
puts(" rampangle '#{@rampangle}'\n") if (@must_ramp)

      @g_save_point = Geom::Point3d.new(0, 0, 0)
      model = Sketchup.active_model
      if(enter_file_dialog(model))
        # first get the material thickness from the model dictionary
        material_thickness = PhlatScript.materialThickness
        if(material_thickness)

          begin
            output_directory_name = model.get_attribute Dict_name, Dict_output_directory_name, $phoptions.default_directory_name
            output_file_name = model.get_attribute Dict_name, Dict_output_file_name, $phoptions.default_file_name
#            @current_bit_diameter = model.get_attribute Dict_name, Dict_bit_diameter, Default_bit_diameter
            @current_bit_diameter = PhlatScript.bitDiameter

            # TODO check for existing / on the end of output_directory_name
            absolute_File_name = output_directory_name + output_file_name

            safe_array = P.get_safe_array()
            min_x = 0.0
            min_y = 0.0
            max_x = safe_array[2]
            max_y = safe_array[3]
            safe_area_points = P.get_safe_area_point3d_array()
            
            if ((PhlatScript.zerooffsetx > 0) || (PhlatScript.zerooffsety > 0))
               @fakeorigin = true
               puts " fakeorigin true"
               # offset the safe area
               min_x -= PhlatScript.zerooffsetx
               min_y -= PhlatScript.zerooffsety
               max_x -= PhlatScript.zerooffsetx
               max_y -= PhlatScript.zerooffsety
            else
               @fakeorigin = false
            end

            min_max_array = [min_x, max_x, min_y, max_y, $phoptions.min_z, $phoptions.max_z]
            #aMill = CNCMill.new(nil, nil, absolute_File_name, min_max_array)
            aMill = PhlatMill.new(absolute_File_name, min_max_array)

            aMill.set_bit_diam(@current_bit_diameter)
            aMill.set_retract_depth(@safeHeight,@tabletop) #tell amill the retract height, for table zero ops

#   puts("starting aMill absolute_File_name="+absolute_File_name)
            if @tabletop
               ext = "Z ZERO IS TABLETOP"
            else
               ext = "-"
            end
            if (@fakeorigin)
               x =  Sketchup.format_length(PhlatScript.zerooffsetx)
               y =  Sketchup.format_length(PhlatScript.zerooffsety)
               fo = "Origin offset #{x}, #{y}"
               if (ext == '-')
                  ext = fo
               else
                  ext += "\n" + fo
               end
            end
            aMill.job_start(@optimize,ext)
            
#   puts "amill jobstart done"
            if (Sketchup.active_model.selection.length > 0)
               loop_root = LoopNodeFromEntities(Sketchup.active_model.selection, aMill, material_thickness)
            else
               loop_root = LoopNodeFromEntities(Sketchup.active_model.active_entities, aMill, material_thickness)
            end
            loop_root.sort
            millLoopNode(aMill, loop_root, material_thickness)

            #puts("done milling")
            if PhlatScript.UseOutfeed?
               aMill.retract(@safeHeight)
               aMill.cncPrintC("Outfeed")
               aMill.move(PhlatScript.safeWidth * 0.75,0)
            else
               if PhlatScript.UseEndPosition?
                  if ($phoptions.use_home_height?)
                     height = $phoptions.default_home_height
                  else
                     height = @safeHeight
                  end
                  aMill.retract(@safeHeight) #forces cmd_rapid
                  aMill.cncPrintC("EndPosition")
                  #puts PhlatScript.end_x
                  #puts PhlatScript.end_y
                  #puts height
                  #puts PhlatScript.feedRate
                  aMill.move(PhlatScript.end_x,PhlatScript.end_y, height, PhlatScript.feedRate, 'G0')
               else
                  # retracts the milling head and and then moves it home.
                  # This prevents accidental milling
                  # through your work piece when moving home.
                  aMill.home()
               end
            end
               if (PhlatScript.useOverheadGantry?)
#              if ($phoptions.use_home_height? != nil)
                if ($phoptions.use_home_height?)
                  aMill.retract($phoptions.default_home_height)
                end
#              end
            end

            #puts("finishing up")
            aMill.job_finish() # output housekeeping code
          rescue
            puts $!
            UI.messagebox "GcodeUtil.generate_gcode failed; Error:"+$!.to_s
          end
        else
          UI.messagebox(PhlatScript.getString("You must define the material thickness."))
        end
      end
    end

##PLASMAPLASMAPLASMAPLASMAPLASMAPLASMAPLASMAPLASMAPLASMAPLASMAPLASMAPLASMAPLASMAPLASMAPLASMAPLASMAPLASMA    
## generate gcode for a plasma cutter
## no Z movement
## allow for user specified codes prior to G0 and G1 moves, whenever it changes from G0 to G1 and back
   def GcodeUtil.generate_gcode_plasma
#      if PSUpgrader.upgrade
#        UI.messagebox("GCode generation has been aborted due to the upgrade")
#        return
#      end

      #swarfer: need these so that all aMill calls are given the right numbers, aMill should be unaware of defaults
      # by doing this we can have Z0 on the table surface, or at top of material
      @tabletop = PhlatScript.tabletop?

      if (@tabletop)
         @safeHeight =  PhlatScript.materialThickness + PhlatScript.safeTravel.to_f
         @materialTop = PhlatScript.materialThickness
         #ZL = material thickness(MT)
         #               cut = ZL - (cutfactor * MT)
         #               safe = ZL+SH  {- safe height is safe margin above material
         @zL = PhlatScript.materialThickness
      else
         @safeHeight = PhlatScript.safeTravel.to_f
         @materialTop = 0
         @zL = 0
         #Mat Zero : ZL = 0
         #              cut = ZL - (cf * MT)
         #              safe = ZL + SH   {- safeheight is mt + some safety margin
      end
      @rampangle = PhlatScript.rampangle.to_f
      @must_ramp = PhlatScript.mustramp?

puts(" safeheight '#{@safeHeight.to_mm}'\n")
puts(" materialTop '#{@materialTop.to_mm}'\n")
puts(" ZL '#{@zL.to_mm}'\n")
puts(" tabletop '#{@tabletop}'\n")
puts(" rampangle '#{@rampangle}'\n") if (@must_ramp)

      @g_save_point = Geom::Point3d.new(0, 0, 0)
      model = Sketchup.active_model
      if(enter_file_dialog(model))
        # first get the material thickness from the model dictionary
        material_thickness = PhlatScript.materialThickness
        if(material_thickness)

          begin
            output_directory_name = model.get_attribute Dict_name, Dict_output_directory_name, $phoptions.default_directory_name
            output_file_name = model.get_attribute Dict_name, Dict_output_file_name, $phoptions.default_file_name
#            @current_bit_diameter = model.get_attribute Dict_name, Dict_bit_diameter, Default_bit_diameter
            @current_bit_diameter = PhlatScript.bitDiameter

            # TODO check for existing / on the end of output_directory_name
            absolute_File_name = output_directory_name + output_file_name

            safe_array = P.get_safe_array()
            min_x = 0.0
            min_y = 0.0
            max_x = safe_array[2]
            max_y = safe_array[3]
            safe_area_points = P.get_safe_area_point3d_array()

            min_max_array = [min_x, max_x, min_y, max_y, $phoptions.min_z, $phoptions.max_z]
            #aMill = CNCMill.new(nil, nil, absolute_File_name, min_max_array)
            aMill = PhlatMill.new(absolute_File_name, min_max_array)

            aMill.set_bit_diam(@current_bit_diameter)
            aMill.set_retract_depth(@safeHeight,@tabletop) #tell amill the retract height, for table zero ops

#   puts("starting aMill absolute_File_name="+absolute_File_name)
            if @tabletop
               ext = "Z ZERO IS TABLETOP"
            else
               ext = "-"
            end
            aMill.job_start(@optimize,ext)
#   puts "amill jobstart done"
            loop_root = LoopNodeFromEntities(Sketchup.active_model.active_entities, aMill, material_thickness)
            loop_root.sort
            millLoopNode(aMill, loop_root, material_thickness)

            #puts("done milling")
            if PhlatScript.UseOutfeed?
               aMill.retract(@safeHeight)
               aMill.cncPrintC("Outfeed")
               aMill.move(PhlatScript.safeWidth * 0.75,0)
            else
               if PhlatScript.UseEndPosition?
                  if ($phoptions.use_home_height?)
                     height = $phoptions.default_home_height
                  else
                     height = @safeHeight
                  end
                  aMill.retract(@safeHeight) #forces cmd_rapid
                  aMill.cncPrintC("EndPosition")
                  aMill.move(PhlatScript.end_x,PhlatScript.end_y, height, 100, 'G0')
               else
                  # retracts the milling head and and then moves it home.
                  # This prevents accidental milling
                  # through your work piece when moving home.
                  aMill.home()
               end
            end
               if (PhlatScript.useOverheadGantry?)
#              if ($phoptions.use_home_height? != nil)
                if ($phoptions.use_home_height?)
                  aMill.retract($phoptions.default_home_height)
                end
#              end
            end

            #puts("finishing up")
            aMill.job_finish() # output housekeeping code
          rescue
            UI.messagebox "GcodeUtil.generate_gcode failed; Error:"+$!
          end
        else
          UI.messagebox(PhlatScript.getString("You must define the material thickness."))
        end
      end
   end
    
    
    private

    def GcodeUtil.LoopNodeFromEntities(entities, aMill, material_thickness)
#      puts"loopnodefromentities #{entities.length}"
      model = Sketchup.active_model
      safe_area_points = P.get_safe_area_point3d_array()
      # find all outside loops
      loops = []
      groups = []
      phlatcuts = []
      dele_edges = [] # store edges that are part of loops to remove from phlatcuts
      entities.each { |e|
        if e.kind_of?(Sketchup::Face)
          has_edges = false
          # only keep loops that contain phlatcuts
          e.outer_loop.edges.each { |edge|
            pc = PhlatCut.from_edge(edge)
            has_edges = ((!pc.nil?) && (pc.in_polygon?(safe_area_points)))
            dele_edges.push(edge)
          }
          loops.push(e.outer_loop) if has_edges
        elsif e.kind_of?(Sketchup::Edge)
            # make sure that all edges are marked as not processed
            pc = PhlatCut.from_edge(e)
            if (pc)
              pc.processed = (false)
              phlatcuts.push(pc) if ((pc.in_polygon?(safe_area_points)) && ((pc.kind_of? PhlatScript::PlungeCut) || (pc.kind_of? PhlatScript::CenterLineCut)))
            end
        elsif e.kind_of?(Sketchup::Group)
          groups.push(e) # should only do this if it is inside safearea
        end
      }

      # make sure any edges part of a curve or loop aren't in the free standing phlatcuts array
      phlatcuts.collect! { |pc| dele_edges.include?(pc.edge) ? nil : pc }
      phlatcuts.compact!
      puts("Located #{groups.length.to_s} GROUPS containing PhlatCuts")   if (groups.length > 0)
      groups.each { |e|
         # this is a bit hacky and we should try to use a transformation based on
         # the group.local_bounds.corner(0) in the future
         group_name = e.name
         if (!group_name.empty?) # the safe area labels are groups with names containing 'safearea', dont print them
            aMill.cncPrintC("Group: #{group_name}")    if !group_name.include?("safearea")
            puts PhlatScript.gcomment("Group: #{group_name}")                 if !group_name.include?("safearea")
         end
         model.start_operation "Exploding Group", true
         es = e.explode
         gnode = LoopNodeFromEntities(es, aMill, material_thickness)
         gnode.sort
         #		  puts "GNODE #{gnode}"
         millLoopNode(aMill, gnode, material_thickness)
         # abort the group explode
         model.abort_operation
         if (!group_name.empty?)
            aMill.cncPrintC("Group complete: #{group_name}")          if !group_name.include?("safearea")
            puts PhlatScript.gcomment("Group end: #{group_name}")                      if !group_name.include?("safearea")
         end
      }
      loops.flatten!
      loops.uniq!
      puts("Located #{loops.length.to_s} loops containing PhlatCuts")   if (loops.length > 0)

      loop_root = LoopNode.new(nil)
      loops.each { |loop|
         loop_root.find_container(loop)
      }

      # push all the plunge, centerline and fold cuts into the proper loop node
      phlatcuts.each { |pc|
         loop_root.find_container(pc)
         pc.processed = true
      }
      return loop_root
    end

   #take array of loop node sorted cuts and return true if they are all the same type of cut         
   def GcodeUtil.sameType(edges)
      first = true
      same = false
      atype = ""
      edges.each { |sc|  # find out if all same type of cuts
#		   puts "sc #{sc}"
         if (first)
            atype = sc.class.to_s
#            puts "atype=#{atype}"
            first = false
            same = true
         else
            if (atype != sc.class.to_s)
               same = false
               break
            end
         end
         }
      if (same   )
         return atype
      else
         return nil
      end
   end
   
   # compare two cuts and return true if they share a vertex
   def GcodeUtil.shareaVertex(v1,v2)
      c1 = ((v1.edge.start.position.x - v2.edge.start.position.x).abs < 0.001) && 
           ((v1.edge.start.position.y - v2.edge.start.position.y).abs < 0.001) 
                  
      c2 = ((v1.edge.start.position.x - v2.edge.end.position.x).abs < 0.001) &&
           ((v1.edge.start.position.y - v2.edge.end.position.y).abs < 0.001) 
      
      c3 = ((v1.edge.end.position.x - v2.edge.start.position.x).abs < 0.001) &&
           ((v1.edge.end.position.y - v2.edge.start.position.y).abs < 0.001)
      
      c4 = ((v1.edge.end.position.x - v2.edge.end.position.x).abs < 0.001) &&
           ((v1.edge.end.position.y - v2.edge.end.position.y).abs < 0.001) 
      return c1 || c2 || c3 || c4            
   end

#take the array of edges of *same* type and cut the connected ones together    
#probably only useful for centerline and fold cuts
   def GcodeUtil.cutConnected(aMill, sortedcuts, material_thickness)
      #create an array of all connected cuts and cut them, until no more cuts found
      debugcutc = false
      centers = []
      cnt = 1
      prev = nil
      prrev = rev = false
      puts "cutc: cutting #{sortedcuts.size} edges" if (debugcutc)
      sortedcuts.each { |pk|
#               puts "looking at #{pk} #{cnt}"
         if (cnt == 1)
            prev = pk
            #puts "pushing first #{pk} #{prev} #{cnt}"
            centers.push(pk)
#            puts "#{cnt} #{pk.edge.start.position} #{pk.edge.end.position}"
         else
            #if prev is connected to pk then add pk to array
#            puts "#{cnt} #{pk.edge.start.position} #{pk.edge.end.position}"
            #puts "cnt #{cnt} #{pk}"
            if (prev == nil) 
               puts "cutc: prev is nil"
            end
            if (pk == nil)
               puts "cutc: pk is nil"
            end
            if ( shareaVertex(prev,pk) )
               #puts "pushing #{pk}  #{cnt}"
               centers.push(pk)
               #TODO if rev changes after 2nd push, cut what you got and start again?
               prrev = rev
               #try to figure cut direction
               rev = (((pk.edge.end.position.x - prev.edge.start.position.x).abs < 0.001) && ((pk.edge.end.position.y - prev.edge.start.position.y).abs < 0.001 ) )
               if (prrev != rev)
                  puts "cutc: rev changed to #{rev} at #{cnt} #{centers.size}"  if (debugcutc)
               end
            else
               if !centers.empty?
                  puts "cutc: CUTTING connected centers #{rev} #{centers.size}"  if (debugcutc)
#                        centers.reverse! if rev
                  if (rev)
                     centers.reverse!
                     rev = false
                  end
                  millEdges(aMill, centers, material_thickness, rev) 
                  prrev = rev = false
               end
               centers = []
               centers.push(pk)
            end
            prev = pk
         end
         cnt += 1 
         }   
      if !centers.empty?
         puts "cutc: remaining Centerlines  rev(#{rev})  centers.size(#{centers.size})" if (debugcutc)
#               centers.reverse! if rev
                  if (rev)
#                     puts " cutting remaining centers with rev TRUE"
#                     c = 1
#                     centers.each { |ed|
#                        puts " #{c} #{ed.edge.start.position} #{ed.edge.end.position}"
#                        }
                  centers.reverse!
                  rev = false      
                  end
         millEdges(aMill, centers, material_thickness, rev) 
      end
   end   

   def GcodeUtil.millLoopNode(aMill, loopNode, material_thickness)
      debugmln = false
      @level += 1
      puts "millLoopNode #{@level}" if (debugmln)
      # always mill the child loops first
      loopNode.children.each{ |childloop|
         puts "mln: mill child loop" if (debugmln)
         millLoopNode(aMill, childloop, material_thickness)
      }
#      if (PhlatScript.useMultipass?) and (Use_old_multipass == false)
#        loopNode.sorted_cuts.each { |sc| millEdges(aMill, [sc], material_thickness) }
#      else
#       millEdges(aMill, [sc], material_thickness)
#      end

   if (PhlatScript.useMultipass?) #and (Use_old_multipass == false)
      #are all the cuts the same type?
      same = sameType(loopNode.sorted_cuts) # return type name if same, else nil
      if (same)  # all same type, if they are connected, cut together, else seperately
         atype = same
			#puts "SAME #{atype}"

         if (atype == "PhlatScript::CenterLineCut") || (atype == "PhlatScript::FoldCut")
#            puts " same separates?"
#new way
            cutConnected(aMill,loopNode.sorted_cuts, material_thickness)

=begin
            cnt = 1
            fend = Geom::Point3d.new
            sstart = Geom::Point3d.new(1,1,1)
            # loop through the nodes and check if the end point of the first edge is the start point of the 2nd edge
            # if they are then cut together, else cut separately
            loopNode.sorted_cuts.each { |pk|
               pk.cut_points(false) {    |cp, cut_factor|
                  if (cnt == 2)
                     fend = cp
                  end
                  if (cnt == 3)
                     sstart = cp
                  end
                  cnt = cnt + 1
                  }
               }
=end               
=begin
            if (fend.x == sstart.x	) && (fend.y == sstart.y)
               puts "mln: same Together #{atype}" if (debugmln)
  				   millEdges(aMill, loopNode.sorted_cuts, material_thickness)
            else  
               puts "mln: same separate" if (debugmln)
               loopNode.sorted_cuts.each { |sc| millEdges(aMill, [sc], material_thickness) }
            end
=end            
         else
            puts "  same together #{atype}" if (debugmln)
            millEdges(aMill, loopNode.sorted_cuts, material_thickness)
         end
      else
#   create arrays of same types, and cut them together
         folds = []
         centers = []
         others = []       #mostly plunge cuts
         loopNode.sorted_cuts.each { |sc|
            cls = sc.class
            case cls.to_s
               when "PhlatScript::FoldCut"
                  folds.push(sc)
               when "PhlatScript::CenterLineCut"
                  centers.push(sc)
               else
##					  puts "   You gave me #{cls}."
                 others.push(sc)
            end
            }
         if !folds.empty?
#				puts "   all folds #{folds.length}"
            cutConnected(aMill,folds, material_thickness)
            #folds.each { |sc| millEdges(aMill, [sc], material_thickness) }
         end
         if !centers.empty?
  			   puts "mln: all CenterLines #{centers.length}" if (debugmln)
            cutConnected(aMill,centers, material_thickness)
#  			   cc = 0;
#            centers.each { |sc| 
#               puts "   mln: mill centerlines #{cc}" if (debugmln)
#               millEdges(aMill, [sc], material_thickness) 
#               cc += 1
#               }
         end
         if !others.empty?
#				puts "   all others #{others.length}"
            millEdges(aMill, others, material_thickness)
         end
      end
   else  ## if not multipass, just cut em
      puts "mln: JUST CUT EM, NOTMULTI" if (debugmln)
      millEdges(aMill, loopNode.sorted_cuts, material_thickness)
   end
 

#      end

      # finally we can walk the loop and make it's cuts
      puts "mln: finally walk edges" if (debugmln)
      edges = []
      reverse = false
      pe = nil
      if !loopNode.loop.nil?
        loopNode.loop.edgeuses.each{ |eu|
          pe = PhlatCut.from_edge(eu.edge)
          if (pe) && (!pe.processed)
#           if (!Sketchup.active_model.get_attribute(Dict_name, Dict_overhead_gantry, $phoptions.default_overhead_gantry?))
            if (! PhlatScript.useOverheadGantry?)
                reverse = reverse || (pe.kind_of?(PhlatScript::InsideCut)) || eu.reversed?
            else
                reverse = reverse || (pe.kind_of?(PhlatScript::OutsideCut)) || eu.reversed?
            end
            edges.push(pe)
            pe.processed = true
          end
          }
        loopNode.loop_start.downto(0) { |x|
           edges.push(edges.shift) if x > 0
           }
        edges.reverse! if reverse
      end
      edges.compact!
      if (edges.size)
         puts "mln:  finally milledges #{edges.size} reverse #{reverse}" if (debugmln)
         millEdges(aMill, edges, material_thickness, reverse)
      end
      
      puts "   millLoopNode exit #{@level}" if (debugmln)
      @level -= 1
    end

   def GcodeUtil.optimize(edges,reverse,trans,aMill)
      if (@g_save_point != nil)
         #puts "optimize: last point  #{@g_save_point}"
         #swarfer: find closest point that is not a tabcut and re-order edges to start there
         cnt = edges.size;
         idx = 0
         mindist = 100000
         idxsave = -1
         
         if (edges[0].kind_of? PhlatScript::CenterLineCut)
            return edges
         end
=begin       attempts at optmizing centerlines....     
	 puts "before"
         if ((cnt > 1) && (edges[0].kind_of? PhlatScript::CenterLineCut)) 
            if (reverse)
               puts "reverse true in centerline optimize"
            else
               puts "cnt #{cnt}"
               edges.each { | phlatcut |
                  a = phlatcut.edge.start.position
                  b = phlatcut.edge.end.position          
                  puts "a #{a}   b #{b}  #{reverse} "
                  
                  point = (trans ? (a.transform(trans)) : a)
                  adist = point.distance(@g_save_point)
                  point = (trans ? (b.transform(trans)) : b)
                  bdist = point.distance(@g_save_point)
                  
                  puts "   #{adist}   #{bdist}"    
                  }  
              # a = edges[0].edge.start.position
              # b = edges[cnt-1].edge.end.position          
              # puts "a #{a}   b #{b}  #{reverse}"
               
              # point = (trans ? (a.transform(trans)) : a)
              # adist = point.distance(@g_save_point)
              # point = (trans ? (b.transform(trans)) : b)
              # bdist = point.distance(@g_save_point)
               
              # puts "#{adist}   #{bdist}"
            end
            if (cnt == 1)
               a = edges[0].edge.start.position
               b = edges[0].edge.end.position          
               puts "a #{a}   b #{b}  #{reverse}"
               
               point = (trans ? (a.transform(trans)) : a)
               adist = point.distance(@g_save_point)
               point = (trans ? (b.transform(trans)) : b)
               bdist = point.distance(@g_save_point)
               
               puts "#{adist}   #{bdist}"
               puts "edge #{edges[0]}"
               if (reverse)   # then b is start point
                  if (bdist > adist)   # then we need to reverse this edge so it starts at b
#                     c = edges[0].edge.start
#                     edges[0].edge.start = edges[0].edge.end
#                     edges[0].edge.end = c
                  end
               else   #a is start point
                  if (adist > bdist)   # then we need to reverse this edge so it starts at b
#                     c = edges[0].edge.start
#                     edges[0].edge.start = edges[0].edge.end
#                     edges[0].edge.end = c
                  end
               end

            end
         
         
         
            return edges   
#               if (phlatcut.kind_of? PhlatScript::CenterLineCut)
#                  #only look at first and last point
#                  if idx == 0
#		     puts "optimize centerline first point"
#                     point = (trans ? (cp.transform(trans)) : cp)
#                     dist = point.distance(@g_save_point)
#                  end
#                  if idx == (edges.size-1)
#		     puts "last point"
#                  end
         end         
	 puts "after"
=end	 
         edges.each { | phlatcut |
#            if phlatcut.kind_of?( PhlatScript::CenterLineCut)
               #find which end is closest
               #puts "centerline #{phlatcut}"
#            end
            #               puts "edge #{phlatcut}"
            phlatcut.cut_points(reverse) {    |cp, cut_factor|
	            if (!phlatcut.kind_of? PhlatScript::TabCut) && (!phlatcut.kind_of? PhlatScript::PocketCut)
               #                     puts "   cutpoint #{cp} #{cut_factor}"
                  #if ramping then ignore segments that are too short
                  if @must_ramp
                     if (phlatcut.edge.length < aMill.tooshorttoramp)
                        puts "#{phlatcut.edge.length.to_mm} < #{aMill.tooshorttoramp.to_mm}" if (@debug)
                        break
                     end
                  end
                  
                  
                  # transform the point if a transformation is provided
                  point = (trans ? (cp.transform(trans)) : cp)
                  dist = point.distance(@g_save_point)
                  if dist < mindist
                     @whichend = idxsave == idx
                     mindist = dist
                     idxsave = idx
                     #                    puts "  saved #{idx} at #{dist} distance #{point} #{@whichend}"
                  end
                  break  #only look at the first cut point
               else
                  break
               end #if not tabcut
            } #cut_points
            idx += 1
         } # edges.each
         
         if (idxsave == -1) #this means that no optimized edge was found, often happens with inside cuts on circles with ramping on, the segments are too short
            return edges
         end
         
         #puts "reStart from #{idxsave} of #{cnt} mindist #{mindist}"
         #puts "reverse #{reverse}"
         prev = (idxsave - 1 + cnt) % cnt
         nxt = (idxsave + 1 + cnt) % cnt
         #puts edges[prev] , edges[idxsave] , edges[nxt]

         if (edges[idxsave].kind_of? PhlatScript::PlungeCut)
            idxsave = 0  # ignore plunge cuts
            changed = true
         else
            changed = false
            if (edges[idxsave].kind_of? PhlatScript::CenterLineCut)
               #puts "ignoring centerlinecut"
               changed = true
               idxsave = 0
            end
            #              puts "ignoring tab cuts for the moment, just use the nearest point"

            #              if (edges[idxsave].kind_of? PhlatScript::InsideCut)
            #                if (!@whichend )
            #                  idxsave = (idxsave - 1 + cnt) % cnt
            #                  puts "   idxsave moved -1 to #{idxsave} whichend false"
            #                  changed = true
            #                end
            #              end

            if (edges[idxsave].kind_of? PhlatScript::OutsideCut) && (reverse) && (@whichend)
               idxsave = (idxsave + 1 + cnt) % cnt
               #                  puts "   idxsave moved +1 to #{idxsave} whichend true reverse=true"
               changed = true
            end

            #idxsave 2 reverse=false whichend=true kind_of=Insidecut   +1
            if (edges[idxsave].kind_of? PhlatScript::InsideCut) && (!reverse) && (@whichend)
               idxsave = (idxsave + 1 + cnt) % cnt
               #                  puts "   idxsave moved +1 to #{idxsave} whichend true reverse=false"
               changed = true
            end


            #              if (edges[prev].kind_of? PhlatScript::TabCut) &&
            #                 (edges[idxsave].kind_of? PhlatScript::OutsideCut) &&
            #                 (edges[nxt].kind_of? PhlatScript::OutsideCut)
            #                idxsave = (idxsave + 1 + cnt) % cnt
            #                puts "   idxsave moved +1 to #{idxsave} away from outside tab TOO"
            #                changed = true
            #              end

            #             if (edges[prev].kind_of? PhlatScript::TabCut) &&
            #                (edges[idxsave].kind_of? PhlatScript::InsideCut) &&
            #                (edges[nxt].kind_of? PhlatScript::InsideCut)
            #               idxsave = (idxsave + 1 + cnt) % cnt
            #               #puts "   idxsave moved to #{idxsave} away from inside tab"
            #               changed = true
            #             end

            #              if (edges[prev].kind_of? PhlatScript::InsideCut) &&
            #                 (edges[idxsave].kind_of? PhlatScript::InsideCut) &&
            #                 (edges[nxt].kind_of? PhlatScript::TabCut)
            #                idxsave = (idxsave - 1 + cnt) % cnt
            #                #puts "   idxsave moved to #{idxsave} away from inside tab"
            #                changed = true
            #              end

            #             if (edges[prev].kind_of? PhlatScript::OutsideCut) &&
            #                (edges[idxsave].kind_of? PhlatScript::OutsideCut) &&
            #                (edges[nxt].kind_of? PhlatScript::TabCut)
            #               idxsave = (idxsave - 1 + cnt) % cnt
            #               puts "   idxsave moved -1 to #{idxsave} away from outside tab OOT"
            #               changed = true
            #             end

            #              if (edges[prev].kind_of? PhlatScript::OutsideCut) &&
            #                 (edges[idxsave].kind_of? PhlatScript::OutsideCut) &&
            #                 (edges[nxt].kind_of? PhlatScript::OutsideCut)
            #                idxsave = (idxsave + 1 + cnt) % cnt
            #                puts "   idxsave moved +1 #{idxsave} OOO"
            #                changed = true
            #              end

            #              if (edges[prev].kind_of? PhlatScript::InsideCut) &&
            #                 (edges[idxsave].kind_of? PhlatScript::InsideCut) &&
            #                 (edges[nxt].kind_of? PhlatScript::InsideCut)
            #                idxsave = (idxsave - 1 + cnt) % cnt
            #                puts "   idxsave moved -1 #{idxsave} III"
            #                changed = true
            #              end

            #              if !changed
            #                 if reverse
            #                   idxsave = (idxsave + 1 + cnt) % cnt
            #                   puts "   idxsave moved to #{idxsave} reverse=true"
            #                 else
            #                   idxsave = (idxsave + 1 + cnt) % cnt
            #                   puts "   idxsave moved to #{idxsave} reverse=false"
            #                 end
            #              end
         end # else is not plungecut

         ctype = "other"
         if (edges[idxsave].kind_of? PhlatScript::InsideCut)
            ctype = "Insidecut"
         end
         if (edges[idxsave].kind_of? PhlatScript::OutsideCut)
            ctype = "Outsidecut"
         end

         #puts "  idxsave #{idxsave} reverse=#{reverse} whichend=#{@whichend} kind_of=#{ctype}"
         #idxsave = 0
         if (idxsave > 0)
            newedges = []
            done = false
            idx = idxsave # start here
            puts "moving #{ctype} to idxsave #{idxsave} #{ctype}"
            while (!done)
               newedges.push(edges[idx])
               #               puts "   pushed #{idx} #{edges[idx]}"
               idx += 1
               if idx == cnt
                  idx = 0
               end
               if idx == idxsave
                  done = true
               end
            end #while
            edges = newedges
         end

      end # if g_save_point
   return edges
   end

# lengthen the edge by 'short'
   def GcodeUtil.lengthen(ledge,short)
      pts = []
      cf = 0
      puts "#{ledge.edge.start.position}\n"
      puts "#{ledge.edge.end.position}\n"
      s = ledge.edge.start.position
      e = ledge.edge.end.position
      if s.x == e.x
         puts "adding to x\n"
         ledge.edge.end.position.x += short
      elsif s.y == e.y
         puts "adding to Y\n"
         ledge.edge.end.position.y += short
      else
         theta = Math.asin( (e.y-s.y) / (e.x-s.x) )
puts "theta #{theta}\n"
         ax = Math.cos(theta) * short
puts "  ax #{ax.to_mm}\n"
         ay = Math.sin(theta) * short
puts "  ay #{ay.to_mm}\n"
         ledge.edge.end.position.x = ledge.edge.end.position.x + ax
         ledge.edge.end.position.y += ay
      end


      puts "  #{ledge.edge.end.position}\n"


      return ledge
   end

# modify the list of edges to make the dragknife turn corners properly
   def GcodeUtil.dragknife(edges,reverse,trans)
      anglelimit = 20   # ignore less than this
      drag = 2.mm       # distance from axle to knife tip
      newedges = edges
      pts = Array.new()
      edges.each { | phlatcut |
puts "#{phlatcut}\n";
         phlatcut.cut_points(reverse) { |cp, cut_factor|
#puts "   #{cp}\n";
#         point = (trans ? (cp.transform(trans)) : cp)
         point = cp
         pts.push(point)
         break  # only first points
         }
      }
      i = pts.length-1
      while i > 0   #skip first point, go backwards through edges
         prev = pts[i-1]
         if i == (pts.length-1)
            nex = pts[0]
         else
            nex = pts[i+1]
         end
         #find angle between them http://stackoverflow.com/questions/21686913/collapse-consecutive-same-elements-in-array/21693144#21693144
         p0p1 = (pts[i].x-prev.x)**2 + (pts[i].y-prev.y)**2
         p2p1 = (pts[i].x-nex.x)**2 + (pts[i].y-nex.y)**2
         p0p2 = (nex.x-prev.x)**2 + (nex.y-prev.y)**2
         angle = Math.acos( (p2p1+p0p1-p0p2) / Math.sqrt(4*p2p1*p0p1) )*180/Math::PI
puts "#{i}   angle #{angle}\n"
         if angle > anglelimit  # then need to insert corner
            #lengthen prev-i by drag
            newedges[i-1] = lengthen(newedges[i-1],drag)
puts " new #{newedges[i-1]}\n"
            #shorten i-nex by drag
            #insert arc centered on i, begin end prev-i, end begin nex
         end
         i -= 1
      end

      return edges
   end

   def GcodeUtil.millEdges(aMill, edges, material_thickness, reverse=false)
      if @must_ramp
         millEdgesRamp(aMill, edges, material_thickness, reverse)
      else
         millEdgesPlain(aMill, edges, material_thickness, reverse)
      end
   end #millEdges
   
#//////////////////   
   def GcodeUtil.millEdgesRamp(aMill, edges, material_thickness, reverse=false)
      if (edges) && (!edges.empty?)
      begin
      mirror = P.get_safe_reflection_translation()
      trans = P.get_safe_origin_translation()
      trans = trans * mirror if Reflection_output
      # virtual o,o point      
      if (@fakeorigin)
         x = PhlatScript.zerooffsetx
         y = PhlatScript.zerooffsety
         vc = Geom::Transformation.translation(Geom::Vector3d.new(-x, -y, 0))
         vc = vc * mirror if Reflection_output
         trans = trans * vc  # apply both translations
      end
      aMill.retract(@safeHeight)

      save_point = nil
      cut_depth = 0
      max_depth = 0
      pass = 0
      pass_depth = 0
      if @optimize &&  (@g_save_point != nil)
         edges = optimize(edges,reverse,trans,aMill)
      end # optimize

      points = edges.size  # number of edges in this cut
      pass_depth = @tabletop ? material_thickness : 0
      max_depth = @zL
      prog = PhProgressBar.new(edges.length)
      prog.symbols("e","E")
      printPass = true
      
#      if edges[0].kind_of?(CenterLineCut) && (edges.length > 1)
#         edges.reverse!
#      end
      @tab_top  = 100
      begin # multipass
         pass += 1
         aMill.cncPrintC("Pass: #{pass.to_s}") if (PhlatScript.useMultipass? && printPass)
         ecnt = 0
         edges.each { | phlatcut |

            ecnt = ecnt + 1
            prog.update(ecnt)
            cut_started = false
            point = nil
            cut_depth = @zL   #not always 0
            #              puts "cut_depth #{cut_depth}\n"
            
            phlatcut.cut_points(reverse) { |cp, cut_factor|
               prev_pass_depth = pass_depth
               #cut = ZL - (cutfactor * MT)
               #safe = ZL+SH  {- safe height is safe margin above material

               #                  cut_depth = -1.0 * material_thickness * (cut_factor.to_f/100).to_f
               prev_cut_depth = cut_depth
               real_cut_depth = cut_depth = @zL - (material_thickness * (cut_factor.to_f/100).to_f)
               # store the max depth encountered to determine if another pass is needed
               max_depth = [max_depth, cut_depth].min
               #puts "max_depth #{max_depth.to_mm}"   if (pass == 1)

               if PhlatScript.useMultipass?
                  #                     cut_depth = [cut_depth, (-1.0 * PhlatScript.multipassDepth * pass)].max
                  prev_pass_depth = @zL - (PhlatScript.multipassDepth * (pass-1))
                  cut_depth = [cut_depth, @zL - (PhlatScript.multipassDepth * pass)].max
                  #puts " cut_depth #{cut_depth.to_mm}  #{pass}\n"   if (pass >= 14)
                  pass_depth = cut_depth
                  #                     puts " pass_depth #{pass_depth.to_mm}\n"
               end

               # transform the point if a transformation is provided
               point = (trans ? (cp.transform(trans)) : cp)

# for ramping we need to know the point at the other end of the current edge
               rev = reverse
               if (phlatcut.kind_of? CenterLineCut)  # uses internal cut_reversed so we must too
                  rev = phlatcut.cut_reversed?
               end
               if (rev) 
                  otherpoint = phlatcut.edge.start.position
               else
                  otherpoint = phlatcut.edge.end.position
               end
               otherpoint = (trans ? (otherpoint.transform(trans)) : otherpoint)
               
               if (phlatcut.kind_of? CenterLineCut)
                  puts "#{phlatcut} start#{point} end#{otherpoint} x#{point.x.to_mm} y#{point.y.to_mm} rv#{reverse}" if (@debug)
               end

               # retract if this cut does not start where the last one ended
               if ((save_point.nil?) || (save_point.x != point.x) || (save_point.y != point.y) || (save_point.z != cut_depth))
                  if (!cut_started)
                     if PhlatScript.useMultipass?  # multipass retract avoid by Yoram and swarfer
                        # If it's peck drilling we want it to retract after each plunge to clear the tool
                        if (phlatcut.kind_of? PlungeCut)
                           if pass == 1
                              #puts "plunge multi #{phlatcut}"
                              aMill.retract(@safeHeight)
                              aMill.move(point.x, point.y)
                              #aMill.plung(cut_depth)
                              diam = (phlatcut.diameter > 0) ? phlatcut.diameter : @current_bit_diameter
                              #c_depth = -1.0 * material_thickness * (cut_factor.to_f/100).to_f
                              c_depth = @zL - (material_thickness * (cut_factor.to_f/100).to_f)
                              #puts "plunge  material_thickness #{material_thickness.to_mm} cutfactor #{cut_factor} c_depth #{c_depth.to_mm} diam #{diam.to_mm}"
                              aMill.plungebore(point.x, point.y, @zL,c_depth, diam)
                              printPass = false  # prevent print pass comments because holes are self contained and empty passes freak users out
                           end
                        else
                           if  ((phlatcut.kind_of? CenterLineCut) || (phlatcut.kind_of? PocketCut))
                              # for these cuts we must retract else we get collisions with existing material
                              # this results from commenting the code in lines 203-205 to stop using 'oldmethod'
                              # for pockets.
=begin                              
                              if (points > 1) #if cutting more than 1 edge at a time, must retract
                                 aMill.retract(@safeHeight)
                              else
                                 #            if multipass and 1 edge and not finished , then partly retract
                                 #                                    puts "#{PhlatScript.useMultipass?} #{points==1} #{pass>1} #{(pass_depth-max_depth).abs >= 0} #{phlatcut.kind_of?(CenterLineCut)}"
                                 if PhlatScript.useMultipass? && (points == 1) &&
                                    (pass > 1) && ((pass_depth-max_depth).abs >= 0.0) && (phlatcut.kind_of?(CenterLineCut) )
                                    puts "   part retract p_pass_depth #{prev_pass_depth.to_mm} #{cut_depth.to_mm}" if (@debug)
                                    #                                       aMill.cncPrint("(PARTIAL RETRACT)\n")
                                    if (PhlatScript.multipassDepth <= 0.5.mm)
                                       cloffset = PhlatScript.multipassDepth / 2
                                    else
                                       cloffset = 0.5.mm
                                    end
                                    aMill.retract(prev_pass_depth+ cloffset )
                                    ccmd = "G00" #must be 00 to prevent aMill.move overriding the cmd because zo is not safe height
                                 end
                              end
                              if ccmd
                                 #                                    aMill.cncPrint("(RAPID #{ccmd})\n")
                                 aMill.move(point.x, point.y, prev_pass_depth + cloffset , PhlatScript.feedRate, 'G0')
                                 ccmd = nil
                              else
                                 aMill.move(point.x, point.y)
                                 if ((prev_pass_depth < @zL) && (cut_depth < prev_pass_depth))
                                    aMill.cncPrintC("plunging to previous pass")    if (@debug)
                                    aMill.plung(prev_pass_depth,1,'G0')
                                 end
                              end
                              aMill.ramp(@rampangle,otherpoint, cut_depth, PhlatScript.plungeRate)
=end

                              if (points > 1) #if cutting more than 1 edge at a time, must retract
                                 aMill.cncPrintC("points > 1")       if @debug
                                 aMill.retract(@safeHeight)
                                 aMill.move(point.x, point.y)
                                 if ((prev_pass_depth < @zL) && (cut_depth < prev_pass_depth))
                                    aMill.cncPrintC("plunging to previous pass")    if (@debug)
                                    aMill.plung(prev_pass_depth,1,'G0')
                                 end
                                 aMill.ramp(@rampangle,otherpoint, cut_depth, PhlatScript.plungeRate)
                              else
                                 aMill.cncPrintC("points = 1")          if @debug
                                 if PhlatScript.useMultipass? && (phlatcut.kind_of?(CenterLineCut) )
                                    aMill.move(point.x, point.y)        if (pass == 1)
                                    aMill.cncPrintC("RAMP")             if @debug
                                    aMill.ramp(@rampangle,otherpoint, cut_depth, PhlatScript.plungeRate)
                                 else
                                    aMill.cncPrintC(" normal move and ramp to cut_depth")    if @debug
                                    aMill.move(point.x, point.y)
                                    if ((prev_pass_depth < @zL) && (cut_depth < prev_pass_depth))
                                       aMill.cncPrintC("plunging to previous pass")    if (@debug)
                                       aMill.plung(prev_pass_depth,1,'G0')
                                    end
                                    aMill.ramp(@rampangle,otherpoint, cut_depth, PhlatScript.plungeRate)
                                 end
                              end
                           else
                              # If it's not a peck drilling we don't need retract
                              aMill.move(point.x, point.y)
                              if ((phlatcut.kind_of? PhlatArc) && (phlatcut.is_arc?) )
                                 center = phlatcut.center
                                 tcenter = (trans ? (center.transform(trans)) : center) #transform if needed
                                 puts "arc ramping in tcenter #{tcenter}"           if (@debug)
                                 g3 = reverse ? !phlatcut.g3? : phlatcut.g3?
                                 puts "ramping multi g3=#{g3}"                      if (@debug)
                                 if (g3)
                                    cmnd = 'G03'
                                 else
                                    cmnd = 'G02'
                                 end   
                                 aMill.ramplimitArc(@rampangle, otherpoint, phlatcut.radius, tcenter, cut_depth, PhlatScript.plungeRate, cmnd)
                              else
                                 aMill.ramp(@rampangle,otherpoint, cut_depth, PhlatScript.plungeRate)
                              end
                           end
                        end # if else plungcut
                     else #NOT multipass
                        aMill.retract(@safeHeight)
                        aMill.move(point.x, point.y)
                        if (phlatcut.kind_of? PlungeCut)
                           #puts "plunge #{phlatcut}"
                           #puts "   plunge dia #{phlatcut.diameter}"
                           if phlatcut.diameter > 0
                              diam = phlatcut.diameter
                           else
                              diam = @current_bit_diameter
                           end
                           aMill.plungebore(point.x, point.y, @zL,cut_depth, diam)
#                           else
#                              aMill.plung(cut_depth, PhlatScript.plungeRate)
#                           end
                        else
                           
                           if ((phlatcut.kind_of? PhlatArc) && (phlatcut.is_arc?) )
                              center = phlatcut.center
                              tcenter = (trans ? (center.transform(trans)) : center) #transform if needed
                              puts "arc ramping in tcenter #{tcenter}" if (@debug)
                              g3 = reverse ? !phlatcut.g3? : phlatcut.g3?
                              if (g3)
                                 cmnd = 'G03'
                              else
                                 cmnd = 'G02'
                              end   
                              aMill.ramplimitArc(@rampangle, otherpoint, phlatcut.radius, tcenter, cut_depth, PhlatScript.plungeRate, cmnd)
                           else
                              puts "straight ramp to #{cut_depth}"            if (@debug)
                              aMill.ramp(@rampangle,otherpoint, cut_depth, PhlatScript.plungeRate)
                           end
                        end # if plungecut
                     end # if else multipass
                  else #cut in progress
                     if ((phlatcut.kind_of? PhlatArc) && (phlatcut.is_arc?) && ((save_point.nil?) || (save_point.x != point.x) || (save_point.y != point.y)))
                        if (phlatcut.kind_of?(PhlatScript::TabCut)) 
                           puts "ARC tabcut with ramp "                                 if (@debug)
                           puts "VTAB"                                if (phlatcut.vtab? && @debug)
                           puts " p cut_depth #{prev_cut_depth.to_mm}"                  if (@debug)
                           puts "   cut_depth #{cut_depth.to_mm}"                       if (@debug)
                           puts "        point #{point.x}  #{point.y} #{point.z}"       if (@debug)
                           puts "  other point #{otherpoint.x}  #{otherpoint.y} #{otherpoint.z}"    if (@debug)
                        end
                        
                        g3 = reverse ? !phlatcut.g3? : phlatcut.g3?
                        if (@ramp_next)
                           puts "RAMP_NEXT true for arc, ramping then arcing" if (@debug)
                           center = phlatcut.center
                           tcenter = (trans ? (center.transform(trans)) : center) #transform if needed
                           puts "arc ramping in tcenter #{tcenter}" if (@debug)
                           if (g3)
                              cmnd = 'G03'
                           else
                              cmnd = 'G02'
                           end   
                           aMill.ramplimitArc(@rampangle, otherpoint, phlatcut.radius, tcenter, cut_depth, PhlatScript.plungeRate, cmnd)
                           @ramp_next = false
                        end

                        # if speed limit is enabled for arc vtabs set the feed rate to the plunge rate here
                        center = phlatcut.center
                        tcenter = (trans ? (center.transform(trans)) : center) #transform if needed
                        puts "tcenter #{tcenter}" if (@debug)

                        if (phlatcut.kind_of? PhlatScript::TabCut) && (phlatcut.vtab?) && ($phoptions.use_vtab_speed_limit?)
                           aMill.arcmove(point.x, point.y, phlatcut.radius, g3, cut_depth, PhlatScript.plungeRate)
                        else 
                           puts "ARC to #{point.x}  #{point.y} #{cut_depth.to_mm}" if (@debug)
                           aMill.arcmove(point.x, point.y, phlatcut.radius, g3, cut_depth)
                        end
                     else  # not arc
                        if (@must_ramp)
#                           aMill.ramp(otherpoint, cut_depth, PhlatScript.plungeRate)
                        # need to detect the plunge end of a tab, save the height, and flag it for 'ramp next time'
                        # do not ramp for vtabs, they are their own ramp!
                           if ((phlatcut.kind_of? PhlatScript::TabCut) && (!phlatcut.vtab?))
                              puts "Must ramp and tab pass=#{pass}"                        if (@debug)
                              puts "VTAB"                               if (phlatcut.vtab? &&  @debug)
                              puts " p pass depth #{prev_pass_depth.to_mm}"                if (@debug)
                              puts " p cut_depth #{prev_cut_depth.to_mm}"                  if (@debug)
                              puts "   cut_depth #{cut_depth.to_mm}"                       if (@debug)
                              puts "        point #{point.x}  #{point.y} #{point.z}"       if (@debug)
                              puts "  other point #{otherpoint.x}  #{otherpoint.y} #{otherpoint.z}"    if (@debug)
#must ramp and tab
# p cut_depth -10.5
#   cut_depth -5.0
#        point 61.5mm  31.5mm 0.0mm
#  other point 61.5mm  38.5mm 0.0mm
# must do this move
                             if  ( ((point.x != otherpoint.x) || (point.y != otherpoint.y)) && (prev_cut_depth < cut_depth))
                                puts " RAMP moving up onto tab #{point.x.to_mm} #{point.y.to_mm} #{cut_depth.to_mm}"  if (@debug)
                                @tab_top = cut_depth
                                aMill.move(point.x, point.y, cut_depth)
                             end
#must ramp and tab
# p cut_depth -5.0
#   cut_depth -5.0
#        point 61.5mm  38.5mm 0.0mm
#  other point 61.5mm  38.5mm 0.0mm
#do this move
                              if (  ((point.x == otherpoint.x) && (point.y == otherpoint.y)) && (prev_cut_depth == cut_depth) )
                                puts "  RAMP moving tab #{point.x.to_mm} #{point.y.to_mm} #{cut_depth.to_mm}"  if (@debug)
                                aMill.move(point.x, point.y, cut_depth)
                              end
#must ramp and tab
# p cut_depth -5.0
#   cut_depth -10.5
#        point 61.5mm  38.5mm 0.0mm
#  other point 61.5mm  38.5mm 0.0mm                     
#set ramp next move
                              if ( (point.x == otherpoint.x) && (point.y == otherpoint.y) && (prev_cut_depth > cut_depth) )
                                 puts "   setting ramp_next true"  if (@debug)
                                 @ramp_next = true  && !phlatcut.vtab?
                                 #if coming down on the trailing edge of a tab, and ramping, then
                                 #we can rapid down to NEAR the previous pass level and ramp from there
                                 if (PhlatScript.useMultipass?)
                                    if ( (prev_pass_depth < prev_cut_depth) && (prev_cut_depth == @tab_top) )
                                       if (PhlatScript.multipassDepth <= 0.25.mm)
                                          cloffset = PhlatScript.multipassDepth / 2
                                       else
                                          cloffset = 0.25.mm
                                       end
                                       aMill.cncPrintC( "PLUNGE to previous pass depth #{prev_pass_depth.to_mm}") if (@debug)
                                       aMill.plung(prev_pass_depth + cloffset,PhlatScript.feedRate, 'G0' )
                                    end
                                 end   
#                                 @ramp_depth = cut_depth  # where it starts
                              end
                           else  # not a tab cut
                              if (@ramp_next)
                                 puts "ramping ramp_next true #{point.x.to_mm} #{point.y.to_mm} #{cut_depth.to_mm}  tab_top #{@tab_top.to_mm} "  if (@debug)
                                 aMill.ramp(@rampangle,otherpoint, cut_depth, PhlatScript.plungeRate)
                                 aMill.move(point.x, point.y, cut_depth)
                                 @ramp_next = false
                              else
                                 if (points == 1) && PhlatScript.useMultipass? && (phlatcut.kind_of?(CenterLineCut) )
                                    aMill.cncPrintC("if last pass, do move")        if @debug
                                    if ((real_cut_depth - cut_depth).abs < 0.0001)
                                       aMill.cncPrintC("doing move")                if @debug
                                       aMill.move(point.x, point.y, cut_depth)
                                    end
                                    #aMill.ramp(@rampangle,otherpoint, cut_depth, PhlatScript.plungeRate)
                                 else
                                 #puts "plain move, not tab, not ramp_next #{point.x.to_mm} #{point.y.to_mm} #{cut_depth.to_mm}" if (@debug)
                                    aMill.cncPrintC("plain move")  if (phlatcut.kind_of?(CenterLineCut) && @debug)
                                    aMill.move(point.x, point.y, cut_depth)
                                 end
                              end
                           end
                        else  # just move
                           puts "just move" if (@debug)
                           aMill.cncPrintC("just move in ramp") if @debug
                           aMill.move(point.x, point.y, cut_depth)
                        end # if must_ramp
                     end
                  end # if !cutstarted
               end # if point != savepoint
               cut_started = true 
               save_point = (point.nil?) ? nil : Geom::Point3d.new(point.x, point.y, cut_depth)
             
            } # phlatcut.cut_points.each
         } # edges.each
         if pass > ((material_thickness / PhlatScript.multipassDepth) + 2) # just in case it runs away, mainly debugging
            rem =  (pass_depth-max_depth).abs
            puts "breaking at #{rem} remaining"
            aMill.cncPrintC("BREAK pass #{pass}") 
            puts "BREAK large pass #{pass}  too many passes for mat thickness\n"  
            break
         end
         # new condition, detect 'close enough' to max_depth instead of equality,
         # for some multipass settings this would result in an extra pass with the same depth
#         rem =  (pass_depth-max_depth).abs
#         puts "remaining #{rem}"
      end until ((!PhlatScript.useMultipass?) || ( (pass_depth-max_depth).abs < 0.0001) )
      @g_save_point = save_point if (save_point != nil)   # for optimizer
      rescue Exception => e
         UI.messagebox "Exception in millEdges "+$! + e.backtrace.to_s
      end
   else   
      puts "no edges in milledgesramp" if (@debug)
      end # if edges
   end  # millEdgesRamp
 #---------------------------------------------------------------------------------------------  
 
   ## the original milledges, no ramp handling
   def GcodeUtil.millEdgesPlain(aMill, edges, material_thickness, reverse=false)
      if (edges) && (!edges.empty?)
      begin
      
      #puts "millEdgesPlain reverse=#{reverse}"
      
      mirror = P.get_safe_reflection_translation()
      trans = P.get_safe_origin_translation()
      trans = trans * mirror if Reflection_output
      # virtual o,o point      
      if (@fakeorigin)
         x = PhlatScript.zerooffsetx
         y = PhlatScript.zerooffsety
         vc = Geom::Transformation.translation(Geom::Vector3d.new(-x, -y, 0))
         vc = vc * mirror if Reflection_output
         trans = trans * vc  # apply both translations
      end
      #use vc as an additional transform

      aMill.retract(@safeHeight)

      save_point = nil
      cut_depth = 0
      max_depth = 0
      pass = 0
      pass_depth = 0
      if @optimize &&  (@g_save_point != nil)
         edges = optimize(edges,reverse,trans,aMill)
      end # optimize

#      edges = dragknife(edges,reverse,trans)

      points = edges.size
      if @tabletop
         pass_depth = material_thickness
      else
         pass_depth = 0
      end
      max_depth = @zL
      prog = PhProgressBar.new(edges.length)
      prog.symbols("e","E")
      printPass = true

      begin # multipass
         pass += 1
         aMill.cncPrintC("Pass: #{pass.to_s}") if (PhlatScript.useMultipass? && printPass)
         ecnt = 0
         edges.each { | phlatcut |

            ecnt = ecnt + 1
            prog.update(ecnt)
            cut_started = false
            point = nil
            cut_depth = @zL   #not always 0
            #              puts "cut_depth #{cut_depth}\n"
            
            phlatcut.cut_points(reverse) { |cp, cut_factor|
               prev_pass_depth = pass_depth
               #cut = ZL - (cutfactor * MT)
               #safe = ZL+SH  {- safe height is safe margin above material

               #                  cut_depth = -1.0 * material_thickness * (cut_factor.to_f/100).to_f
               prev_cut_depth = cut_depth
               cut_depth = @zL - (material_thickness * (cut_factor.to_f/100).to_f)
               # store the max depth encountered to determine if another pass is needed
               max_depth = [max_depth, cut_depth].min

               if PhlatScript.useMultipass?
                  #                     cut_depth = [cut_depth, (-1.0 * PhlatScript.multipassDepth * pass)].max
                  cut_depth = [cut_depth, @zL - (PhlatScript.multipassDepth * pass)].max
                  #                     puts " cut_depth #{cut_depth.to_mm}\n"
                  pass_depth = cut_depth
                  #                     puts " pass_depth #{pass_depth.to_mm}\n"
               end

               # transform the point if a transformation is provided
               point = (trans ? (cp.transform(trans)) : cp)
               
#               puts "#{phlatcut.edge.end}\n"

               # retract if this cut does not start where the last one ended
               if ((save_point.nil?) || (save_point.x != point.x) || (save_point.y != point.y) || (save_point.z != cut_depth))
                  if (!cut_started)
                     if PhlatScript.useMultipass?  # multipass retract avoid by Yoram and swarfer
                        # If it's peck drilling we want it to retract after each plunge to clear the tool
                        if (phlatcut.kind_of? PlungeCut)
                           if pass == 1
                              #puts "plunge multi #{phlatcut}"
                              aMill.retract(@safeHeight)
                              aMill.move(point.x, point.y)
                              #aMill.plung(cut_depth)
                              
                              
                              if (phlatcut.angle > 0)
                                 ang = phlatcut.angle
                                 diam = phlatcut.diameter
                                 aMill.plungebore(point.x, point.y, @zL,cut_depth, diam, ang)
                              else
                                 diam = (phlatcut.diameter > 0) ? phlatcut.diameter : @current_bit_diameter
                                 c_depth = @zL - (material_thickness * (cut_factor.to_f/100).to_f)
                                 aMill.plungebore(point.x, point.y, @zL,c_depth, diam)
                              end
                              #puts "plunge  material_thickness #{material_thickness.to_mm} cutfactor #{cut_factor} c_depth #{c_depth.to_mm} diam #{diam.to_mm}"
                              printPass = false  # prevent print pass comments because holes are self contained and empty passes freak users out
                           end
                        else
                           if  ((phlatcut.kind_of? CenterLineCut) || (phlatcut.kind_of? PocketCut))
                              # for these cuts we must retract else we get collisions with existing material
                              # this results from commenting the code in lines 203-205 to stop using 'oldmethod'
                              # for pockets.
                              if (points > 1) #if cutting more than 1 edge at a time, must retract
                                 aMill.retract(@safeHeight)
                              else
                                 #            if multipass and 1 edge and not finished , then partly retract
                                 #                                    puts "#{PhlatScript.useMultipass?} #{points==1} #{pass>1} #{(pass_depth-max_depth).abs >= 0} #{phlatcut.kind_of?(CenterLineCut)}"
                                 if PhlatScript.useMultipass? && (points == 1) && 
                                    (pass > 1) && ((pass_depth-max_depth).abs >= 0.0) && (phlatcut.kind_of?(CenterLineCut) )
                                    #                                       puts "   part retract"
                                    #aMill.cncPrint("(PARTIAL RETRACT)\n")
                                    aMill.retract(prev_pass_depth+ 0.5.mm )
                                    ccmd = "G00" #must be 00 to prevent aMill.move overriding the cmd because zo is not safe height
                                 end
                              end
                              if ccmd
                                 #aMill.cncPrint("(RAPID #{ccmd})\n")
                                 aMill.move(point.x, point.y, prev_pass_depth + 0.5.mm , PhlatScript.feedRate, "G0")
                                 ccmd = nil
                              else
                                 aMill.move(point.x, point.y)
                              end
                              aMill.plung(cut_depth, PhlatScript.plungeRate)
                           else
                              # If it's not a peck drilling we don't need retract
                              aMill.move(point.x, point.y)
                              aMill.plung(cut_depth, PhlatScript.plungeRate)
                           end
                        end # if else plungcut
                     else #NOT multipass
                        aMill.retract(@safeHeight)
                        aMill.move(point.x, point.y)
                        if (phlatcut.kind_of? PlungeCut)
                           #puts "plunge #{phlatcut}"
                           #puts "   plunge dia #{phlatcut.diameter}"
                           if (phlatcut.angle > 0)
                              ang = phlatcut.angle
                              diam = phlatcut.diameter
                              aMill.plungebore(point.x, point.y, @zL,cut_depth, diam, ang)
                           else
                              if (phlatcut.diameter > 0)
                                 diam = phlatcut.diameter
                              else
                                 diam = @current_bit_diameter
                              end
                              aMill.plungebore(point.x, point.y, @zL,cut_depth, diam)
                           end
                        else
                           aMill.plung(cut_depth, PhlatScript.plungeRate)
                        end # if plungecut
                     end # if else multipass
                  else #cut in progress
                     if ((phlatcut.kind_of? PhlatArc) && (phlatcut.is_arc?) && ((save_point.nil?) || (save_point.x != point.x) || (save_point.y != point.y)))
#something odd with this reverse thing, for some arcs it gets the wrong direction, outputting G3 for clockwise cuts instead of G2
                        g3 = reverse ? !phlatcut.g3? : phlatcut.g3?
                        puts "reverse #{reverse} .g3 #{phlatcut.g3?} cutkind=#{cutkind}  ===  g3=#{g3}" if (@debug)

                        # if speed limit is enabled for arc vtabs set the feed rate to the plunge rate here
#                        center = phlatcut.center
#                        tcenter = (trans ? (center.transform(trans)) : center) #transform if needed
                        if (phlatcut.kind_of? PhlatScript::TabCut) && (phlatcut.vtab?) && ($phoptions.use_vtab_speed_limit?)
                           aMill.arcmove(point.x, point.y, phlatcut.radius, g3, cut_depth, PhlatScript.plungeRate)
                        else 
                           aMill.arcmove(point.x, point.y, phlatcut.radius, g3, cut_depth)
                        end
                     else
                        aMill.move(point.x, point.y, cut_depth)
                     end
                  end # if !cutstarted
               end # if point != savepoint
               cut_started = true 
               save_point = (point.nil?) ? nil : Geom::Point3d.new(point.x, point.y, cut_depth)
            }
         } # edges.each
         if pass > ((material_thickness / PhlatScript.multipassDepth) + 2) # just in case it runs away, mainly debugging
            aMill.cncPrintC("BREAK pass #{pass}")
            puts "BREAK large pass #{pass}\n"  
            break
         end
         # new condition, detect 'close enough' to max_depth instead of equality,
         # for some multipass settings this would result in an extra pass with the same depth
      end until ((!PhlatScript.useMultipass?) || ( (pass_depth-max_depth).abs < 0.0001) )

      @g_save_point = save_point if (save_point != nil)   # for optimizer

      rescue Exception => e
         UI.messagebox "Exception in millEdges "+$! + e.backtrace.to_s
      end
      end # if edges
   end  # milledges without ramp

   def GcodeUtil.enter_file_dialog(model=Sketchup.active_model)
      output_directory_name = PhlatScript.cncFileDir
      output_filename = PhlatScript.cncFileName
      status = false
      result = UI.savepanel(PhlatScript.getString("Save CNC File"), output_directory_name, output_filename)
      if(result != nil)
         # if there isn't a file extension set it to the default
         result += $phoptions.default_file_ext if (File.extname(result).empty?)
         PhlatScript.cncFile = result
         PhlatScript.checkParens(result, "Output File")
         status = true
      end
      status
   end

   def GcodeUtil.points_in_points(test_pts, bounding_pts)
      fits = true
      test_pts.each { |pt|
         next if !fits
         fits = Geom.point_in_polygon_2D(pt, bounding_pts, false)
         }
      return fits
   end

  end

end
# $Id$

      #return true if the 2 edges given share an end point
=begin   
   def GcodeUtil.sharepoint(fe,se)
      fes = fe.start.position
      fee = fe.end.position
      ses = se.start.position
      see = se.end.position
      if ( ((fes.x - ses.x).abs < 0.0001) && ((fes.y - ses.y).abs < 0.0001) ) ||
         ( ((fes.x - see.x).abs < 0.0001) && ((fes.y - see.y).abs < 0.0001) ) ||
         ( ((fee.x - ses.x).abs < 0.0001) && ((fee.y - ses.y).abs < 0.0001) ) ||
         ( ((fee.x - see.x).abs < 0.0001) && ((fee.y - see.y).abs < 0.0001) )  
         return true
      else
         return false
      end
   end
=end   
