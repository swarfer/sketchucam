require 'sketchup.rb'
# General method library
module PhlatScript

# Commented out all methods that are no longer used.

=begin
def get_and_verify_directory(input_dir=nil)
	model = Sketchup.active_model
	if input_dir != nil
		dir_name = input_dir
	else
		dir_name = model.get_attribute Dict_name, Dict_output_directory_name, Default_directory_name
	end
	if not File.directory?(dir_name)
		dir_name = Default_directory_name
	end
	output_directory_name = ""
	arr = dir_name.split(/\//)
	arr.each {|element| output_directory_name << element << "/"}

	model.set_attribute Dict_name, Dict_output_directory_name, output_directory_name
	#UI.messagebox(output_directory_name)
	return output_directory_name
end

def validate_output_file(output_file)
	result_array = nil
	begin
		file_basename = nil
		file_dirname = nil
		status = (output_file != nil)
		if(status)
			file_basename = File.basename(output_file)
			status = Sketchup.is_valid_filename?(file_basename)
			if(status)
				file_dirname = File.dirname(output_file)
				status = File.directory?(file_dirname)
			end
		end
		if(status)
			result_array = Array.new
			result_array[0] = file_dirname + File::SEPARATOR
			result_array[1] = file_basename
		else
			UI.messagebox($phlatboyzStrings.GetString("Filename Error") + ": " + ((output_file == nil) ? "nil" : output_file))
		end
	rescue
		UI.messagebox "Exception in validate_output_file "+$!
		nil
	end
	result_array
end

def get_model_filename_or_default(model=Sketchup.active_model)
	begin
		path = model.path
		if path && path.length > 0
			path.match(/([a-zA-Z0-9\s]*)\.skp$/)
			default_filename = $1+".cnc"
		else
			#output_filename = model.get_attribute Dict_name, Dict_output_file_name, Default_file_name
			default_filename = Default_file_name
		end
	rescue
		UI.messagebox "Exception in PhlatboyzMethods.get_model_filename_or_default() "+$!
	end
	filename = model.get_attribute(Dict_name, Dict_output_file_name, default_filename)
	#UI.messagebox("default_filename="+default_filename+" filename="+filename)
	return filename
end

def selected_edges(model=Sketchup.active_model)
	# Get selections from the active model
	# Get an Array of all of the selected Edges
	return model.selection.find_all { |e| e.kind_of?(Sketchup::Edge) }
end

def get_selected_edges(model=Sketchup.active_model)
	edges = selected_edges()
	# We need at least 1 Edge
	if( edges.length < 1 )
		UI.messagebox($phlatboyzStrings.GetString("You must select at least one Edge"))
		return nil
	else
		return edges
	end
end

def selected_faces(model=Sketchup.active_model)
	# Get selections from the active model
	# Get an Array of all of the selected Faces
	return model.selection.find_all { |e| e.kind_of?(Sketchup::Face) }
end


def get_selected_faces(model=Sketchup.active_model)
	faces = selected_faces
	# We need at least 1 Face
	if( faces.length < 1 )
		UI.messagebox($phlatboyzStrings.GetString("You must select at least one Face"))
		return nil
	else
		return faces
	end
end

def active_edges
	# Get all active edges
	entities = Sketchup.active_model.active_entities
  arr = []
  entities.each { |entity| arr << entity if entity.kind_of?(Sketchup::Edge) }
	return arr
end

def set_z_zero_selected_edges(model=Sketchup.active_model)
	#model = Sketchup.active_model
	model.start_operation $phlatboyzStrings.GetString("operation_set_zequalzero_selected_edges")
	edges = get_selected_edges
	edges.each do | edge |
		_set_z_zero_edge(edge)
	end
	model.commit_operation
	Sketchup.active_model.selection.remove edges
end

def set_z_zero_selected_faces_and_edges(model=Sketchup.active_model)
	model.start_operation $phlatboyzStrings.GetString("operation_set_zequalzero_selected_edges_and_faces")

	faces = selected_faces()
	faces.each do | face |
		_set_z_zero_face(face)
	end

	edges = selected_edges()
	edges.each do | edge |
		_set_z_zero_edge(edge)
	end
	Sketchup.active_model.selection.remove edges
	model.commit_operation
end

def _set_z_zero_edge(in_edge, model=Sketchup.active_model)
	in_pt_start = in_edge.start.position
	in_pt_end = in_edge.end.position
	pt_start = Geom::Point3d.new(in_pt_start.x, in_pt_start.y, 0)
	pt_end = Geom::Point3d.new(in_pt_end.x, in_pt_end.y, 0)

	new_edges = model.entities.add_edges(pt_start, pt_end)
	new_edge = new_edges[0]

	model.entities.erase_entities in_edge
end

def set_z_zero_selected_faces(model=Sketchup.active_model)
	model.start_operation $phlatboyzStrings.GetString("operation_set_zequalzero_selected_faces")
	faces = get_selected_faces(model)
	faces.each do | face |
		_set_z_zero_face(face)
	end
	model.commit_operation
	Sketchup.active_model.selection.remove faces
end

def _set_z_zero_face(in_face, model=Sketchup.active_model)
	loop = in_face.outer_loop
	vertices = loop.vertices

	points = Array.new
	vertices.each do | vertex |
		points << Geom::Point3d.new(vertex.position.x, vertex.position.y, 0.0)
	end

	edges = loop.edges
	edges_to_remove = Array.new
	edges.each do | edge |
		edges_to_remove << edge if (edge.faces.length == 1)
	end
	model.entities.erase_entities edges_to_remove
	model.entities.add_face points
end
=end
# ------------------------------------------------------------------------------------------------------------------------

def PhlatScript.set_safe_array(x, y, w, h, model=Sketchup.active_model)
	model.set_attribute(Dict_name, Dict_safe_origin_x, x)
	model.set_attribute(Dict_name, Dict_safe_origin_y, y)
	model.set_attribute(Dict_name, Dict_safe_width, w)
	model.set_attribute(Dict_name, Dict_safe_height, h)
  draw_safe_area(model)
end

#format a string with Gcode comments, either '(comment)' or '; comment'
def PhlatScript.gcomment(comment)
   if PhlatScript.usecommentbracket?
      return "(" + comment + ")"
   else
      return "; " + comment
   end
end

#split a string into 'short enough' comments if it is too long for GRBL/UGS
#returns an array of strings ready to output, used by phjoiner
def PhlatScript.gcomments(comment)
   output = Array.new
      string = comment.gsub(/\n/,"")
      string = string.gsub(/\(|\)/,"")  # remove existing brackets
      if (string.length > 70)
         chunks = string.scan(/.{1,68}/)
         chunks.each { |bit|
            bb = PhlatScript.gcomment(bit)
            output += [bb]
            }
      else
         string = PhlatScript.gcomment(string)
         output += [string]
      end
   return output
end



#SWARFER : need this is many places, so centralize the resource.
def PhlatScript.isMetric()
  case Sketchup.active_model.options['UnitsOptions']['LengthUnit']
    when 0,1 then
      is_metric = false
    when 2..4 then
      is_metric = true
    else
      is_metric = false
    end
  return is_metric
end

def PhlatScript.get_safe_array(model=Sketchup.active_model)
	x = model.get_attribute(Dict_name, Dict_safe_origin_x, $phoptions.default_safe_origin_x)
	y = model.get_attribute(Dict_name, Dict_safe_origin_y, $phoptions.default_safe_origin_y)
	w = model.get_attribute(Dict_name, Dict_safe_width, $phoptions.default_safe_width)
	h = model.get_attribute(Dict_name, Dict_safe_height, $phoptions.default_safe_height)
	return [x,y,w,h]
end

def PhlatScript._get_area_point3d_array(x, y, w, h)
	p0 = Geom::Point3d.new(x, y, 0)
	p1 = p0.transform Geom::Transformation.translation(Geom::Vector3d.new( w, 0, 0))
	p2 = p1.transform Geom::Transformation.translation(Geom::Vector3d.new( 0, h, 0))
	p3 = p2.transform Geom::Transformation.translation(Geom::Vector3d.new(-w, 0, 0))
	return [p0,p1,p2,p3]
end

def PhlatScript.get_safe_origin_translation(model=Sketchup.active_model)
	x = model.get_attribute(Dict_name, Dict_safe_origin_x, $phoptions.default_safe_origin_x)
	y = model.get_attribute(Dict_name, Dict_safe_origin_y, $phoptions.default_safe_origin_y)
	return Geom::Transformation.translation(Geom::Vector3d.new(-x, -y, 0))
end

def PhlatScript.get_safe_reflection_translation_old(model=Sketchup.active_model)
	y = model.get_attribute(Dict_name, Dict_safe_origin_y, $phoptions.default_safe_origin_y)
	h = model.get_attribute(Dict_name, Dict_safe_height, $phoptions.default_safe_height)
	origin = Geom::Point3d.new(0, (2*y + h), 0)
	xp = Geom::Vector3d.new(1, 0, 0)
	yp = Geom::Vector3d.new(0,-1, 0)
	zp = Geom::Vector3d.new(0, 0,-1)
	return Geom::Transformation.axes(origin, xp, yp, zp)
end

def PhlatScript.get_safe_reflection_translation(model=Sketchup.active_model)
	x = model.get_attribute(Dict_name, Dict_safe_origin_x, $phoptions.default_safe_origin_x)
	w = model.get_attribute(Dict_name, Dict_safe_width, $phoptions.default_safe_width)
	origin = Geom::Point3d.new((2*x + w), 0, 0)
	xp = Geom::Vector3d.new(-1, 0, 0)
	yp = Geom::Vector3d.new( 0, 1, 0)
	zp = Geom::Vector3d.new( 0, 0,-1)
	return Geom::Transformation.axes(origin, xp, yp, zp)
end

def PhlatScript.get_safe_area_point3d_array(model=Sketchup.active_model)
	safe_array = get_safe_array(model)
	x = safe_array[0]
	y = safe_array[1]
	w = safe_array[2]
	h = safe_array[3]
	return _get_area_point3d_array(x, y, w, h)
end

def PhlatScript.mark_construction_object(in_object)
	in_object.set_attribute(Dict_name, Dict_construction_mark, true)
end

def PhlatScript.erase_construction_objects(model=Sketchup.active_model)
	entities = model.active_entities
	entities_to_erase = Array.new
	entities.each do | entity |
		if(entity.get_attribute(Dict_name, Dict_construction_mark))
			entities_to_erase << entity
		end
	end
	entities_to_erase.each { |entity| entities.erase_entities(entity)}
end

def PhlatScript.add_point_label(in_entities, in_point, in_height, in_align)
	# align:0 - bottom, left
	# align:1 - top, right
	label = in_point.x.to_s+", "+in_point.y.to_s

	g = in_entities.add_group()
   g.name = "safearea#{in_align}"  # needs a name to be exluded from group summary list
	g_entities = g.entities
	construction_point = g_entities.add_3d_text(label, TextAlignLeft, "Times", false, false, in_height, 0.1.inch, 0, true, 0)
	bbox = g.bounds

	v1 = (in_align == 0) ? Geom::Vector3d.new(-bbox.width/2, -1.5*bbox.height, 0) : Geom::Vector3d.new(-bbox.width/2, 0.5*bbox.height, 0)
	t = Geom::Transformation.new(in_point.offset(v1))

	g.move!(t)
	#g.explode()
	return g
end

def PhlatScript.test_safe_area(safe_point3d_array, model=Sketchup.active_model)
	safe_area = (safe_point3d_array[0].distance safe_point3d_array[1]) > 0.5.inch
	safe_area &= (safe_point3d_array[1].distance safe_point3d_array[2]) > 0.5.inch
	return safe_area
end

def PhlatScript.draw_safe_area(model=Sketchup.active_model)
	safe_point3d_array = get_safe_area_point3d_array(model)
	erase_construction_objects(model)

	if(test_safe_area(safe_point3d_array, model))
		begin
			entities = model.active_entities

			mark_construction_object(entities.add_cline(safe_point3d_array[0], safe_point3d_array[1],'-'))
			mark_construction_object(entities.add_cline(safe_point3d_array[1], safe_point3d_array[2],'-'))
			mark_construction_object(entities.add_cline(safe_point3d_array[2], safe_point3d_array[3],'-'))
			mark_construction_object(entities.add_cline(safe_point3d_array[3], safe_point3d_array[0],'-'))

			mark_construction_object(entities.add_cpoint(safe_point3d_array[0]))
			mark_construction_object(entities.add_cpoint(safe_point3d_array[1]))
			mark_construction_object(entities.add_cpoint(safe_point3d_array[2]))
			mark_construction_object(entities.add_cpoint(safe_point3d_array[3]))
         if ((PhlatScript.zerooffsetx > 0) || (PhlatScript.zerooffsety > 0))
            pts = Array.new
            x = PhlatScript.zerooffsetx + safe_point3d_array[0].x
            y = PhlatScript.zerooffsety + safe_point3d_array[0].y
            pts << Geom::Point3d.new(x + 0.1 , y + 0.1, 0)
            pts << Geom::Point3d.new(x - 0.1 , y + 0.1, 0)
            pts << Geom::Point3d.new(x + 0.1 , y - 0.1, 0)
            pts << Geom::Point3d.new(x - 0.1 , y - 0.1, 0)
            pts << Geom::Point3d.new(x + 0.1 , y + 0.1, 0)
            mark_construction_object(entities.add_cline(pts[0], pts[1],'-'))
            mark_construction_object(entities.add_cline(pts[1], pts[2],'-'))
            mark_construction_object(entities.add_cline(pts[2], pts[3],'-'))
            mark_construction_object(entities.add_cline(pts[3], pts[4],'-'))
         end 
         
         mark_construction_object(add_point_label(entities, safe_point3d_array[0], Construction_font_height, 0))
			mark_construction_object(add_point_label(entities, safe_point3d_array[2], Construction_font_height, 1))
		rescue
			UI.messagebox "Exception in draw_safe_area "+$!
			nil
		end
	end
end

# convert degrees to radians   (SK8 needs this, V2014 on has it in the math lib)
   def PhlatScript.torad(deg)
       deg * Math::PI / 180
   end     
#convert radians to degrees
   def PhlatScript.todeg(rad)
      rad * 180 / Math::PI 
   end


=begin
def order_selected_edges
	model = Sketchup.active_model
	edges = selected_edges(model)
	if( edges.length < 2 )  # We need at least 2 edges
		UI.messagebox($phlatboyzStrings.GetString("You must select at least two Edges"))
	else
		begin
#			start_verticies = edges.collect{|edge| edge.start}
#			end_verticies = edges.collect{|edge| edge.end}
#			all_verticies = start_verticies + end_verticies

			all_verticies = []
			edges.each{ |edge| all_verticies << edge.vertices }
			all_verticies.flatten!
			uniq_verticies = all_verticies.uniq

			non_dup_verts = uniq_verticies.reject {|v| ((i = all_verticies.index(v)) > -1) && ((j = all_verticies.rindex(v)) > -1) && (i != j)}
			# non_dup_verts will have two items when the curve is not closed, start vertex & end vertex; and it will be empty when the curve is closed

			closed = (non_dup_verts.length == 0)
			start_vert = closed ? uniq_verticies.first : non_dup_verts.first
			start_edge = (start_vert.edges & edges).first

			# find connected edges
			# sort vertices
			sorted_verts = [start_vert]
			n = 0
			failed = false
			while(sorted_verts.length < uniq_verticies.length && !failed)
				edges.each do |edge|
					if(sorted_verts.last == edge.start)
						sorted_verts << edge.end
					elsif(sorted_verts.last == edge.end)
						sorted_verts << edge.start
					end
				end
				failed = (++n > uniq_verticies.length)
			end

			if(!failed)
				model.start_operation $phlatboyzStrings.GetString("operation_ordering_selected_edges")

				sorted_verts << sorted_verts[0] if closed
				sorted_points = sorted_verts.collect{|x| x.position}

				# Remove the selected edges if they are being replaced
				edges_to_erase = edges.uniq
				edges_to_erase.reject!{|edge| !(sorted_points.include?(edge.start.position) && sorted_points.include?(edge.end.position))}
				model.entities.erase_entities edges_to_erase

				curve = model.entities.add_curve(sorted_points)
				model.entities.add_face(curve) if closed

				model.commit_operation
			else
				UI.messagebox("failed")
			end

			model.selection.clear()
		rescue
			UI.messagebox "Exception in _test_order_edges "+$!
			nil
		end
	end
end
=end

end # module PhlatScript
