#POST IMPORT EXTRAS
@tool
extends EditorScenePostImport

const KEYS_TO_IGNORE  = ['conform_object', "bc", "ant_landscape", "rigify_owner_rig", "scatter5" ]

func _post_import(scene: Node) -> Object:				
	for child in scene.get_children():
		recursive_check(child)
	if scene.get_child_count()!=1:
		return scene
	
	var new_root = scene.get_child(0) 
	update_children_recursive(new_root, new_root)	
	
	return new_root

func update_children_recursive(new_owner, current_node):
	for child in current_node.get_children():
		child.owner = new_owner
		update_children_recursive(new_owner, child)
	
func recursive_check(node:Node):
	#var node = node.name	
	if node is MeshInstance3D:		
		for i in node.mesh.get_surface_count():								
			var name = node.mesh.surface_get_material(i).resource_name
			if FileAccess.file_exists( str( "res://3D/Materials/Polygon/Polygon_", name,  ".tres")):
				node.mesh.surface_set_material(i, load( str( "res://3D/Materials/Polygon/Polygon_", name,  ".tres")))				
			elif FileAccess.file_exists( str( "res://3D/Materials/Stylized/", name,  ".tres")):
				node.mesh.surface_set_material(i, load( str( "res://3D/Materials/Stylized/", name,  ".tres") ))
			elif FileAccess.file_exists( str( "res://3D/Materials/", name, ".material")):
				node.mesh.surface_set_material(i, load( str( "res://3D/Materials/",name, ".material")))
			elif FileAccess.file_exists( str( "res://3D/Materials/", name, ".tres")):
				node.mesh.surface_set_material(i, load( str( "res://3D/Materials/",name, ".tres")))
			else:
				print( "Material ", name, " doesn't exist in Polygon or Stylized folders" )			
	
	if node.has_meta("extras"):			
		if node.name.ends_with("_meta"):			
			var real_node = node.get_parent().get_child(node.get_index()+1)
			for meta in node.get_meta_list():				
				real_node.set_meta(meta, node.get_meta(meta))
			node.free()		
			return				
		#var extras:Dictionary = node.get_meta("extras")								
		#for key in KEYS_TO_IGNORE:
		#	if key in extras.keys():
		#		extras.erase(key)
		#if extras.keys().size() ==0:		
		node.remove_meta("extras")			
		#else:
		#	node.set_meta("extras", extras)							
			#if extras.has("mesh_rename"):		
			#	node.name = extras.mesh_rename
		if node.has_meta("subscene"):				
			var path = node.get_meta("subscene")
			if FileAccess.file_exists(path):						
				if path.find(".tscn") != -1 or path.to_lower().find(".glb") != -1:
					node.scene_file_path = path
					for child in node.get_children():				
						if not child.has_meta("extras") or not child.get_meta("extras").has("subsubscene"):						
							child.free()
			else:
				print("path doesn't exists: ", path)								
					#if path.find("YurtBuilder.tscn")!=-1:						
						#node.make_random(node.get_index(false))			
		if node.has_meta("script"):
			var path = node.get_meta("script")
			if path.find(".gd") > 0 and FileAccess.file_exists(path):
				node.set_script( load(path) )	
		if node.has_meta("replace_root"):				
			#node.owner.replace_by(node)
			node.owner.name+="1"						
		#if node.has_meta("static_body"):
			#node = replace_node_with_static_body(node)
		#if node.has_meta("rigid_body"):
			#node = replace_node_with_rigid_body(node)
		if node.has_meta("collision_box"):			
			var collision_box = node.get_meta("collision_box")
			node = replace_node_with_collision_box(node, collision_box[0],collision_box[2],collision_box[1])			
		if node.has_meta("collision_capsule"):			
			var collision_capsule = node.get_meta("collision_capsule")		
			node = replace_node_with_collision_capsule(node, collision_capsule[0],collision_capsule[1])			
		if node.has_meta("collision_sphere"):			
			var collision_sphere = node.get_meta("collision_sphere")			
			node = replace_node_with_collision_sphere(node, collision_sphere)			
		if node.has_meta("stair_count"):			
			var stair_count = node.get_meta("stair_count")					
			var stair_width = node.get_meta("stair_width")					
			var stair_height = node.get_meta("stair_height")					
			var stair_depth = node.get_meta("stair_depth")					
			var ramp = build_stairs_with_ramp(node, stair_count, stair_width,stair_height,stair_depth)			
			#build_stairs_with_boxes(node, extras.stair_count, extras.stair_width,extras.stair_height,extras.stair_depth)			
			node = replace_node_with_static_body(node)			
		if node.has_meta("collision_cylinder_walls"):			
			var collision_cylinder_walls = node.get_meta("collision_cylinder_walls")					
			var side_count = collision_cylinder_walls[3]
			var r = collision_cylinder_walls[0] - collision_cylinder_walls[2]/2
			var angle = PI*2 / side_count
			var vertices = []
			var box_shape = BoxShape3D.new()
			var box_width = 2*collision_cylinder_walls[0] * sin(PI/side_count)
			box_shape.size = Vector3(box_width,collision_cylinder_walls[1],collision_cylinder_walls[2])				
			for i in side_count:				
				var x = (r* cos(2*i*PI / side_count + angle/2) + r*cos(2*(i+1) * PI / side_count + angle/2))/2
				var y = (r* sin(2*i*PI / side_count + angle/2 ) + r*sin(2*(i+1) * PI / side_count + angle/2))/2
				vertices.push_back(Vector2(x,y) )
			var sides_to_ignore = node.get_meta("sides_to_ignore") if node.has_meta("sides_to_ignore") else null
			for i in side_count:						
				if int(sides_to_ignore) & (1<<int(i)): continue								
				var box = CollisionShape3D.new()				
				box.shape = box_shape
				node.add_child(box)				
				box.position = Vector3(vertices[i].x,0, vertices[i].y)
				box.rotation.y = PI/2 + i * -angle - angle
				box.owner = node.owner
				box.name = str("CollisionShape", i)				
			replace_node_with_static_body(node)
		if node.has_meta("area3d"):				
			node = replace_node_with_area3d(node)											
		if node.has_meta("mesh_resource"):			
			node = replace_node_with_mesh(node, node.get_meta("mesh_resource"))					
	if not is_instance_valid(node):return
	for child in node.get_children():	
		recursive_check(child)	

func replace_node_with_collision_box(node, x,y,z):
	var box = CollisionShape3D.new()
	var node_name = node.name
	var node_transform = node.transform
	node.replace_by(box)
	node.free()
	node = box
	node.name = node_name
	node.transform = node_transform
	node.scale = Vector3.ONE
	node.shape = BoxShape3D.new()
	node.shape.size = Vector3(abs(x*2),abs(y*2),abs(z*2))	
	return node

func replace_node_with_collision_capsule(node, radius,height):
	var capsule = CollisionShape3D.new()
	var node_name = node.name
	var node_transform = node.transform
	node.replace_by(capsule)
	node.free()
	node = capsule
	node.name = node_name
	node.shape = CapsuleShape3D.new()
	node.shape.radius = radius
	node.shape.height = height
	node.transform = node_transform
	node.scale = Vector3.ONE
	return node

func replace_node_with_collision_sphere(node, radius):
	var box = CollisionShape3D.new()
	var node_name = node.name
	var node_transform = node.transform
	node.replace_by(box)
	node.free()
	node = box
	node.name = node_name
	node.shape = SphereShape3D.new()
	node.shape.radius = radius
	node.transform = node_transform
	return node


func replace_node_with_area3d(node):
	var area3d = Area3D.new()
	var node_transform: Transform3D = node.transform						
	var node_name = node.name										
	node.replace_by(area3d)				
	node.free()
	node = area3d
	node.name = node_name
	node.transform = node_transform
	return node
	
func replace_node_with_mesh(node, path):
	var mesh = MeshInstance3D.new()
	mesh.name = node.name
	mesh.mesh = load(path)	
	node.replace_by(mesh)		
	node.free()
	node = mesh
	return node
	
func replace_node_with_rigid_body(node):
	var rigid_body = RigidBody3D.new()
	rigid_body.freeze = true
	#rigid_body.physics_material_override = preload("res://3D/Tools/standard_object.phymat")
	var node_name = node.name			
	var node_transform = node.transform
	node.replace_by(rigid_body)
	node.free()
	node = rigid_body
	node.name = node_name	
	node.transform = node_transform
	return node
	
func replace_node_with_static_body(node):
	var static_body = StaticBody3D.new()
	var node_name = node.name			
	var node_transform = node.transform
	node.replace_by(static_body)
	node.free()
	node = static_body
	node.name = node_name	
	node.transform = node_transform
	return node

func build_stairs_with_ramp(node, count, width,height,depth):
	var ramp_shape: ConvexPolygonShape3D =ConvexPolygonShape3D.new()
	var points:PackedVector3Array = []
	points.push_back(Vector3(width*-0.5,0,0))
	points.push_back(Vector3(width*0.5,0,0))
	points.push_back(Vector3(width*-0.5,0,-depth/2))
	points.push_back(Vector3(width*0.5,0,-depth/2))
	points.push_back(Vector3(width*-0.5,-height*(count+1),0))
	points.push_back(Vector3(width*0.5,-height*(count+1),0))
	points.push_back(Vector3(width*-0.5,-height*(count+1), -(count+1)*depth-depth/2))
	points.push_back(Vector3(width*0.5,-height*(count+1),-(count+1)*depth-depth/2))
	ramp_shape.points = points
	var ramp = CollisionShape3D.new()
	ramp.shape = ramp_shape
	node.add_child( ramp )
	#ramp.position.y -= height/2
	#ramp.position.z -= depth/2 
	#ramp.position.y -= 0
	#ramp.position.z -= 0		
	ramp.owner = node.owner
	ramp.name = "Ramp"
	
func build_stairs_with_boxes(node, count, width,height,depth):
	var box_shape = BoxShape3D.new()				
	box_shape.size = Vector3(width, height, depth)				
	for i in count + 1:				
		var box = CollisionShape3D.new()				
		box.shape = box_shape
		node.add_child(box)				
		box.position.y -= height/2
		box.position.z -= depth/2 
		box.position.y -= height * i
		box.position.z -= depth * i		
		box.owner = node.owner
		box.name = str("Step", i)
