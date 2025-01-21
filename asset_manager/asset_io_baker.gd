@tool
class_name AssetIOBaker extends Object

# SCENARIOS:
# - import hlod scene with joined mesh
# - re-import hlod scene with joined mesh
# - save joined meseh to .res from baker scene
	
static func baker_export_to_glb(baker_node:HLod_Baker, path:= ""):
	if path == "":
		push_error("Trying to export glb to empty path")
		return	
	var gltf_document= GLTFDocument.new()
	var gltf_save_state = GLTFState.new()		
	#TO DO : add joined mesh meshes to root node
	var joined_mesh_node
	if MAssetTable.mesh_join_get_stop_lod(baker_node.joined_mesh_id) > 0:
		joined_mesh_node = Node3D.new()
		baker_node.add_child(joined_mesh_node)
		joined_mesh_node.owner = baker_node		
		var meshes = MAssetTable.mesh_join_meshes_no_replace(baker_node.joined_mesh_id)
		var lods = MAssetTable.mesh_join_ids_no_replace(baker_node.joined_mesh_id)
		for i in len(meshes):
			var mmesh:MMesh = meshes[i]
			var lod = lods[i]
			var mesh_node = MeshInstance3D.new()
			mesh_node.mesh = mmesh.get_mesh()
			joined_mesh_node.add_child(mesh_node)		
			mesh_node.owner = baker_node
			mesh_node.name = baker_node.name + "_joined_mesh_lod" + str(lod)			
	if not baker_node.has_meta("baker_path"):
		baker_node.set_meta("baker_path", baker_node.scene_file_path)
	if not baker_node.has_meta("joined_mesh_id"):
		baker_node.set_meta("joined_mesh_id", baker_node.joined_mesh_id)
	gltf_document.append_from_scene(baker_node, gltf_save_state)		
	gltf_document.write_to_filesystem(gltf_save_state, path)
	if joined_mesh_node:
		joined_mesh_node.queue_free()

static func baker_import_from_glb(glb_path, baker_node: Node3D):		
	baker_parse_glb(baker_node)
	baker_show_import_window(baker_node) # this window will call baker_import_commit_changes
	
static func baker_parse_glb(baker_node:Node3D):
	var asset_library:MAssetTable = MAssetTable.get_singleton()	
	baker_node.set_script(preload("res://addons/m_terrain/asset_manager/hlod_baker.gd"))	
	if not baker_node.has_meta("baker_path"):			
		baker_node.set_meta("baker_path", str(MAssetTable.get_editor_baker_scenes_dir().path_join(baker_node.name + ".tscn" )))		
	if not baker_node.has_meta("joined_mesh_id"):
		baker_node.set_meta("joined_mesh_id", MAssetTable.get_last_free_mesh_join_id())
		
	var joined_mesh_node = Node3D.new()
	joined_mesh_node.name = baker_node.name + "_joined_mesh"	 
	baker_node.add_child(joined_mesh_node)
	
	var nodes = baker_node.find_children("*", "Node3D", true, false)		
	nodes.reverse()	
	EditorInterface.get_edited_scene_root().add_child(baker_node)
	for node in nodes:		
		if node.name == baker_node.name + "_joined_mesh": continue
		if node is ImporterMeshInstance3D:									
			node.reparent(joined_mesh_node)																	
			var mesh_node = MeshInstance3D.new()
			joined_mesh_node.add_child(mesh_node)									
			mesh_node.owner = baker_node
			mesh_node.name = node.name
			mesh_node.transform = node.transform
			mesh_node.mesh = node.mesh.get_mesh()
			node.get_parent().remove_child(node)
			node.queue_free()						
			continue					
		if not node.has_meta("blend_file"):			
			node.set_meta("import_error", "has no blend file metadata")			
			continue
		if not asset_library.import_info["__blend_files"].has(node.get_meta("blend_file")):			
			node.set_meta("import_error", "has no blend file metadata")			
			continue
		var glb_path = asset_library.import_info["__blend_files"][node.get_meta("blend_file")]			
		var node_name := AssetIO.collection_parse_name(node)
		if not asset_library.import_info[glb_path].has(node_name):			
			node.set_meta("import_error", str("import info does not have this node name for this glb: ", node_name, " <- ", glb_path))
			continue
		var new_node = MAssetMesh.new()	
		new_node.collection_id = asset_library.import_info[glb_path][node_name].id
		var parent = node.get_parent()
		parent.add_child(new_node)
		new_node.transform = node.transform
		parent.remove_child(node)	
		new_node.name = node.name			
		if baker_node.is_ancestor_of(new_node):			
			new_node.owner = baker_node
		else:						
			new_node.queue_free()
		node.queue_free()
	EditorInterface.get_edited_scene_root().remove_child(baker_node)	
	
static func baker_show_import_window(baker_node):
	var popup = Window.new()
	popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	popup.wrap_controls = true
	EditorInterface.get_editor_main_screen().add_child(popup)
	var panel = preload("res://addons/m_terrain/asset_manager/ui/import_window_hlod_scene.tscn").instantiate()
	panel.baker_node = baker_node
	popup.add_child(panel)
	popup.popup_centered(Vector2i(800,600))	

static func baker_import_commit_changes(baker_node:Node3D):		
	var asset_library:MAssetTable = MAssetTable.get_singleton()	
		
	if baker_node.has_node(baker_node.name + "_joined_mesh"):
		var node = baker_node.get_node(baker_node.name + "_joined_mesh")
	
		var meshes =[]
		var lods = []				
		for mesh_node:MeshInstance3D in node.get_children():
			var mmesh: MMesh = MMesh.new()
			mmesh.create_from_mesh(mesh_node.mesh)
			meshes.push_back(mmesh)
			var name_data = AssetIO.node_parse_name(mesh_node)
			lods.push_back(name_data.lod)
		save_joined_mesh(baker_node.joined_mesh_id, meshes,lods)	
	for node in baker_node.find_children("*"):
		if node.has_meta("ignore") and node.get_meta("ignore") == true: 
			node.get_parent().remove_child(node)
			node.queue_free()
	
	var packed_scene = PackedScene.new()	
	packed_scene.pack(baker_node)	
	var baker_path = baker_node.get_meta("baker_path")
	print("baker path: ", baker_path)
	if FileAccess.file_exists(baker_path):
		packed_scene.take_over_path(baker_path)							
		ResourceSaver.save(packed_scene, baker_path)	
		if baker_path in EditorInterface.get_open_scenes():
			EditorInterface.reload_scene_from_path(baker_path)
	else:
		ResourceSaver.save(packed_scene, baker_path)	
	baker_node.queue_free()
			
static func save_joined_mesh(joined_mesh_id:int, joined_meshes:Array, joined_mesh_lods:Array):	
	print("saving_joined_meshes: ", joined_mesh_id )
	for i in len(joined_meshes):
		var mesh_path = MHlod.get_mesh_root_dir().path_join(str(joined_mesh_id - joined_mesh_lods[i], ".res"))
		if FileAccess.file_exists(mesh_path):
			joined_meshes[i].take_over_path(mesh_path)
		ResourceSaver.save(joined_meshes[i], mesh_path)
