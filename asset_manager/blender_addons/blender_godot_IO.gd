@tool
extends Node

const tmp_file_path = "res://addons/m_terrain/tmp/tscn_as_json.json"
var server:TCPServer
var client:StreamPeerTCP
func _ready():
	server = TCPServer.new()
	server.listen(9999)	
	
func _process(delta):	
	if server and not client:
		if server.is_connection_available():	
			client = server.take_connection()
			if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
				client.put_string("AAAA")
	#if client.poll()
		
#func _init():
	#var args = OS.get_cmdline_args()	
	#var separator_index = args.find("--args")
	#if separator_index != -1:
		#args = args.slice(separator_index + 1)	
	#
	#var func_name = args[0]	
	#var scene_path = args[1]
	#call(func_name, scene_path)


func json_to_tscn(scene_path:String):	
	var data: Dictionary = JSON.parse_string( FileAccess.get_file_as_string(tmp_file_path)	)
	var packed_scene := PackedScene.new()	
	var root_node
	var nodes = {}
	var node_paths = data.keys()
	#node_paths.sort()
	for node_path in node_paths:
		var node:Node3D = ClassDB.instantiate(data[node_path].node_type)							
		var node_path_split = node_path.split("/")				
		node.name = node_path_split[-1]				
		nodes[node_path] = node
		var parent_node_path
		if len(node_path_split) == 1:
			root_node = node
			add_child(root_node)
		else:	
			parent_node_path = node_path.trim_suffix( "/" + node_path.split("/")[-1] ) 							
			root_node.add_child(node)
		print(node.name, ": inside tree?--------------", node.is_inside_tree())
		for prop in data[node_path].keys():			
			if prop == "node_path": continue
			if prop == "node_type": continue
			if prop == "position": node.position = str_to_var( data[node_path][prop])
			elif prop == "basis_x": node.transform.basis.x = str_to_var( data[node_path][prop] )
			elif prop == "basis_y": node.transform.basis.y = str_to_var( data[node_path][prop] )
			elif prop == "basis_z": node.transform.basis.z = str_to_var( data[node_path][prop] )				
			elif prop == "object_name":	pass					
			elif prop == "blend_file": pass
			elif prop == "script": pass
			elif prop == "shape": pass
			else:
				var value = data[node_path][prop]			
				if value is String:
					value = str_to_var(value)
				node.set(prop, value)
		if parent_node_path:
			node.reparent(nodes[parent_node_path])
			node.owner = root_node			
	packed_scene.pack(root_node)	
	if FileAccess.file_exists(scene_path):
		packed_scene.take_over_path(scene_path)
	elif not DirAccess.dir_exists_absolute(scene_path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(scene_path.get_base_dir())
	ResourceSaver.save(packed_scene, scene_path)
	root_node.queue_free()	
	
func tscn_to_json(scene_path):		
	var packed_scene := load(scene_path) as PackedScene			
	var state := packed_scene.get_state()	
	var nodes = {}
	var root_node_name
	for node_id in state.get_node_count():
		var node_path:String = state.get_node_path(node_id) as String 
		if node_path == ".":			
			root_node_name = str(state.get_node_name(node_id))
			node_path = root_node_name
		else:			
			node_path = node_path.replace(".", root_node_name)
		nodes[node_path] = {}
		nodes[node_path]["node_type"] = state.get_node_type(node_id)							
		nodes[node_path]["global_transform"] = Transform3D()
		for prop_id in state.get_node_property_count(node_id):
			var prop = state.get_node_property_name(node_id, prop_id)						
			if prop == "transform" and node_path != ".":				
				var local_transform = state.get_node_property_value(node_id, prop_id)												
				var parent_path = node_path.trim_suffix( "/" + node_path.split("/")[-1] ) 				
				parent_path.replace(".", root_node_name)								
				if nodes[parent_path].has("global_transform"):
					nodes[node_path]["global_transform"] = nodes[parent_path]["global_transform"] * local_transform
				nodes[node_path]["position"] = var_to_str( nodes[node_path]["global_transform"].origin )
				nodes[node_path]["basis_x"] = var_to_str( nodes[node_path]["global_transform"].basis.x )
				nodes[node_path]["basis_y"] = var_to_str( nodes[node_path]["global_transform"].basis.y )
				nodes[node_path]["basis_z"] = var_to_str( nodes[node_path]["global_transform"].basis.z )							
			elif prop == "_collection_identifier":
				nodes[node_path]["blend_file"] = get_blend_path_from_glb_id( state.get_node_property_value(node_id, prop_id)[0] )				
				nodes[node_path]["object_name"] = state.get_node_property_value(node_id, prop_id)[0]
			elif prop == "script":				
				nodes[node_path]["script"] = state.get_node_property_value(node_id, prop_id).get_path()
			elif prop == "shape":			
				var shape = state.get_node_property_value(node_id, prop_id)
				if shape is BoxShape3D:	
					nodes[node_path]["collision_box"] = shape.size
				if shape is SphereShape3D:	
					nodes[node_path]["collision_sphere"] = shape.radius
				if shape is CylinderShape3D:	
					nodes[node_path]["collision_cylinder"] = Vector2(shape.radius, shape.height)
				if shape is CapsuleShape3D:	
					nodes[node_path]["collision_capsule"] = Vector2(shape.radius, shape.height)
			else:
				nodes[node_path][prop] = var_to_str(state.get_node_property_value(node_id, prop_id)	)
	for node_path in nodes.keys():
		if nodes[node_path].has("global_transform"):
			nodes[node_path].erase("global_transform")
	var json = JSON.stringify(nodes, "", false)
	var file = FileAccess.open(tmp_file_path, FileAccess.WRITE)
	file.resize(0)
	file.store_string(json)
	print("SUCCESS")

func get_blend_path_from_glb_id(glb_id):
	var import_info_path = "res://massets_editor/import_info.json"
	var import_info = JSON.parse_string( FileAccess.get_file_as_string(import_info_path) )
	for k in import_info:
		if k.begins_with("__"): continue
		if import_info[k]["__id"] == glb_id:
			if import_info[k].has("__original_blend_file"):
				return import_info[k]["__original_blend_file"]

# Recursive function to gather node names
func get_node_names(node, names):
	names.append(node.name)
	for child in node.get_children():
		get_node_names(child, names)
