extends SceneTree

func _init():
	var args = OS.get_cmdline_args()	
	var separator_index = args.find("--args")
	if separator_index != -1:
		args = args.slice(separator_index + 1)	
	
	var func_name = args[0]	
	var scene_path = args[1]
	call(func_name, scene_path)
	quit()

func tscn_to_json(scene_path):	
	# Load the PackedScene
	var packed_scene := load(scene_path) as PackedScene	
	
	if not packed_scene:
		print("Failed to load scene: ", scene_path)
		quit()
		return
			
	var state := packed_scene.get_state()
	var nodes = {}
	for node_id in state.get_node_count():
		var name = str(state.get_node_name(node_id))
		nodes[name] = {}
		for prop_id in state.get_node_property_count(node_id):
			var prop = state.get_node_property_name(node_id, prop_id)
			if prop == "transform":
				nodes[name]["transform"] = state.get_node_property_value(node_id, prop_id)
			if prop == "_collection_identifier":
				nodes[name]["glb_id"] = state.get_node_property_value(node_id, prop_id)[0]
				nodes[name]["glb_name"] = state.get_node_property_value(node_id, prop_id)[0]
				nodes[name]["type"] = state.get_node_type(node_id)
	# Output the list
	print(nodes)


# Recursive function to gather node names
func get_node_names(node, names):
	names.append(node.name)
	for child in node.get_children():
		get_node_names(child, names)
