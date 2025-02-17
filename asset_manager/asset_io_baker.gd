@tool
class_name AssetIOBaker extends Object

# SCENARIOS:
# - import hlod scene with joined mesh
# - re-import hlod scene with joined mesh
# - save joined meseh to .res from baker scene

static func get_glb_path_by_baker_path(baker_path:String, sub_baker_name: String = "")->String:
	if baker_path.is_empty(): return ""
	var baker_name = baker_path.get_file().get_basename()
	if sub_baker_name.is_empty():
		return baker_path.get_base_dir().path_join(baker_name+"_joined_mesh.glb")		
	else:				
		return baker_path.get_base_dir().path_join(baker_name+ "__" + sub_baker_name + "_joined_mesh.glb")				
	

static func rebake_hlod(hlod:MHlod):
	var baker: HLod_Baker= load(hlod.baker_path).instantiate()
	baker.is_tmp_bake = true
	EditorInterface.get_base_control().add_child(baker)
	baker.bake_to_hlod_resource()

static func baker_export_to_glb(baker_node:HLod_Baker):
	var path = baker_node.scene_file_path.get_base_dir().path_join(baker_node.name + ".glb")		
	var gltf_document= GLTFDocument.new()
	var gltf_save_state = GLTFState.new()		
	#TO DO : add joined mesh meshes to root node
	var joined_mesh_node	
	if MAssetTable.mesh_join_get_stop_lod(baker_node.joined_mesh_id) == -1:
		joined_mesh_node = explode_join_mesh_nodes(baker_node)
		baker_node.add_child(joined_mesh_node)
	if not baker_node.has_meta("baker_path"):
		baker_node.set_meta("baker_path", baker_node.scene_file_path)
	if not baker_node.has_meta("joined_mesh_id"):
		baker_node.set_meta("joined_mesh_id", baker_node.joined_mesh_id)
	gltf_document.append_from_scene(baker_node, gltf_save_state)		
	gltf_document.write_to_filesystem(gltf_save_state, path)
	if joined_mesh_node:
		joined_mesh_node.queue_free()
	EditorInterface.get_resource_filesystem().scan()

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
		if baker_node.joined_mesh_id == -1:
			baker_node.set_join_mesh_id(MAssetTable.get_last_free_mesh_join_id())
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
	if FileAccess.file_exists(baker_path):
		packed_scene.take_over_path(baker_path)							
		ResourceSaver.save(packed_scene, baker_path)	
		if baker_path in EditorInterface.get_open_scenes():
			EditorInterface.reload_scene_from_path(baker_path)
	else:
		ResourceSaver.save(packed_scene, baker_path)	
	baker_node.queue_free()
			
static func save_joined_mesh(joined_mesh_id:int, joined_meshes:Array, joined_mesh_lods:Array):
	## clear
	for l in range(0,MAssetTable.mesh_item_get_max_lod()):
		var mesh_path = MHlod.get_mesh_root_dir().path_join(str(joined_mesh_id - l, ".res"))
		var stop_path = mesh_path.get_basename() + ".stop"
		if FileAccess.file_exists(mesh_path):
			DirAccess.remove_absolute(mesh_path)
		if FileAccess.file_exists(stop_path):
			DirAccess.remove_absolute(stop_path)
	
	## saving
	for i in len(joined_meshes):
		var mesh_path = MHlod.get_mesh_root_dir().path_join(str(joined_mesh_id - joined_mesh_lods[i], ".res"))
		if FileAccess.file_exists(mesh_path):
			joined_meshes[i].take_over_path(mesh_path)
		ResourceSaver.save(joined_meshes[i], mesh_path)
	EditorInterface.get_resource_filesystem().scan()

static func explode_join_mesh_nodes(baker_node):
	var joined_mesh_node = Node3D.new()	
	baker_node.add_child(joined_mesh_node)
	joined_mesh_node.owner = baker_node		
	joined_mesh_node.name = baker_node.name + "_joined_mesh"
	var meshes = MAssetTable.mesh_join_meshes_no_replace(baker_node.joined_mesh_id)		
	var lods = MAssetTable.mesh_join_ids_no_replace(baker_node.joined_mesh_id)
	for i in len(meshes):
		if meshes[i] == null: continue
		var mmesh:MMesh = meshes[i]
		var lod = lods[i] - baker_node.joined_mesh_id
		var mesh_node = MeshInstance3D.new()
		mesh_node.mesh = mmesh.get_mesh()
		for s in mesh_node.mesh.get_surface_count():
			var surf_mat:Material = mesh_node.mesh.surface_get_material(s)
			var mname = AssetIOMaterials.get_material_name(surf_mat)
			if mname.is_empty(): mname="None"
			var dummy_material:=StandardMaterial3D.new()
			dummy_material.resource_name = mname
			dummy_material.albedo_color = Color(randf_range(0.2,1.0),randf_range(0.2,1.0),randf_range(0.2,1.0),1)
			mesh_node.mesh.surface_set_material(s,dummy_material)
		joined_mesh_node.add_child(mesh_node)		
		mesh_node.owner = baker_node
		mesh_node.name = baker_node.name + "_joined_mesh_lod_" + str(abs(lod))			
	return joined_mesh_node
	
static func export_join_mesh_only(baker_node:Node3D):	 	
	if not MAssetTable.mesh_join_is_valid(baker_node.joined_mesh_id):
		MTool.print_edmsg("There is no join mesh for this! first create a join mesh!")
		return
	var joined_mesh_node = explode_join_mesh_nodes(baker_node)
	var m:ArrayMesh = joined_mesh_node.get_children()[0].mesh
	var gltf_document= GLTFDocument.new()
	var gltf_save_state = GLTFState.new()					
	var path
	if baker_node.owner and baker_node.owner.scene_file_path: # sub-baker
		path = get_glb_path_by_baker_path(owner.scene_file_path, baker_node.name)
	else: # root baker
	 	path = get_glb_path_by_baker_path(baker_node.scene_file_path)
	gltf_document.append_from_scene(joined_mesh_node, gltf_save_state)		
	gltf_document.write_to_filesystem(gltf_save_state, path)
	if joined_mesh_node:
		joined_mesh_node.queue_free()
	EditorInterface.get_resource_filesystem().scan()

static func import_join_mesh_only(baker_node:Node3D):
	var gltf_document= GLTFDocument.new()
	var gltf_state = GLTFState.new()
	gltf_document.image_format = "None"
	var path = get_glb_path_by_baker_path(baker_node.scene_file_path)
	if not FileAccess.file_exists(path):
		MTool.print_edmsg("There is no gltf for join mesh, to export your gltf file click on save button in inspector after creating join mesh!")
	gltf_document.append_from_file(path, gltf_state)		
	var scene = gltf_document.generate_scene(gltf_state)				
	var joined_mesh_nodes = scene.find_children("*_joined_mesh*")
	var mesh_arr:Array
	var lod_arr:Array
	for joined_mesh_node in joined_mesh_nodes:
		if not joined_mesh_node is ImporterMeshInstance3D: continue
		var name_data = AssetIO.node_parse_name(joined_mesh_node)		
		if name_data.lod != -1:
			var smesh:ArrayMesh= joined_mesh_node.mesh.get_mesh()
			for s in range(smesh.get_surface_count()):
				var sname:String = smesh.surface_get_name(s)				
				sname = AssetIO.blender_end_number_remove(sname)
				if sname == "None": continue
				var sid = sname.to_int()
				var mat = AssetIOMaterials.get_material_by_name(sname)
				if mat:
					smesh.surface_set_material(s,mat)
				else:
					MTool.print_edmsg("Can not find material with name: "+sname)
			var mmesh = MMesh.new()
			mmesh.create_from_mesh(smesh)
			mesh_arr.push_back(mmesh)
			lod_arr.push_back(name_data.lod)	
	save_joined_mesh(baker_node.joined_mesh_id, mesh_arr, lod_arr)
	MAssetMeshUpdater.refresh_all_masset_updater()
	EditorInterface.get_resource_filesystem().scan()

static func import_join_mesh_auto(path, joined_mesh_nodes, joined_mesh_id):		
	return
	for joined_mesh_node in joined_mesh_nodes:
		var name_data = AssetIO.node_parse_name(joined_mesh_node)		
		if name_data.lod != -1:			
			if joined_mesh_node is ImporterMeshInstance3D:
				var smesh = joined_mesh_node.mesh.get_mesh()
				for s in range(smesh.get_surface_count()):
					var sname:String = smesh.surface_get_name(s)
					sname = AssetIO.blender_end_number_remove(sname)
					var sid = sname.to_int()
					var mat = AssetIOMaterials.get_material(sid)
					if mat:
						smesh.surface_set_material(s,mat)
				var mmesh = MMesh.new()
				mmesh.create_from_mesh(smesh)
				save_joined_mesh(joined_mesh_id, [mmesh], [name_data.lod])
	MAssetMeshUpdater.refresh_all_masset_updater()
	EditorInterface.get_resource_filesystem().scan()
