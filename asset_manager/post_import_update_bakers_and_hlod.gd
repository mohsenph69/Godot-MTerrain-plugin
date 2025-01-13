extends Object
	
static func get_baker_scene_list(root = MAssetTable.get_editor_baker_scenes_dir()):
	var result = []
	for dir in DirAccess.get_directories_at(root):		
		var current_dir = root.path_join(dir)
		result.append_array( DirAccess.get_files_at( current_dir ))
		result.append_array(get_baker_scene_list(current_dir))
	return result
		
static func is_collection_in_baker(baker_path, collection_id):
	var baker:PackedScene = load(baker_path)
	var state: SceneState = baker.get_state()
	for node_id in state.get_node_count():
		for prop_id in state.get_node_property_count(node_id):
			if state.get_node_property_name(node_id, prop_id) == "collection_id":
				if state.get_node_property_value(node_id, prop_id) == collection_id:
					return true
					
static func update_bakers(collection_ids := []):
	for path in get_baker_scene_list():
		for collection_id in collection_ids:
			if is_collection_in_baker(path, collection_id):
				pass # rebake
