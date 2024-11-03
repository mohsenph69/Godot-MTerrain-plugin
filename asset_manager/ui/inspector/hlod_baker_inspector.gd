@tool
extends VBoxContainer

var object

func _ready():
	if not is_instance_valid(object) or not object.has_method("bake_to_hlod_resource"): return	
	check_if_can_join_meshes(object)
	%BakePath.text = object.bake_path
	%BakePath.text_changed.connect(	func(text): 
		object.bake_path = text
		%Bake.disabled = not text.ends_with(".res")
	)
	%select_bake_path.pressed.connect(func():
		var popup := FileDialog.new()
		popup.access = FileDialog.ACCESS_RESOURCES
		popup.add_filter("*.res")
		popup.file_mode =FileDialog.FILE_MODE_SAVE_FILE
		popup.file_selected.connect(func(path):
			%BakePath.text = path
			object.bake_path = path
		)
		add_child(popup)	
		popup.popup_centered(Vector2i(300,500))		
	)	
	%Bake.pressed.connect(object.bake_to_hlod_resource)		
		
	%JoinLod.value = object.join_at_lod
	%JoinLod.max_value = AssetIO.LOD_COUNT-1
	%JoinLod.value_changed.connect(func(value): 
		object.join_at_lod = value				
		object.update_joined_mesh_limits()
		check_if_can_join_meshes(object)
	)	
	%Join.pressed.connect(func():					
		var root_node = Node3D.new()
		root_node.name = "root_node"
		var mesh_instance = MeshInstance3D.new()
		root_node.add_child(mesh_instance)		
		
		mesh_instance.name = object.name.to_lower() + "_joined_mesh_lod_" + str(object.join_at_lod)
		mesh_instance.mesh = object.make_joined_mesh()						
		mesh_instance.mesh.resource_name = mesh_instance.name								
		var glb_path = object.scene_file_path.get_basename() + "_joined_mesh.glb"
		AssetIO.glb_export(root_node, glb_path)
	
		var import_info = MAssetTable.get_singleton().import_info		
		if not import_info.has(glb_path):
			import_info[glb_path] = {"__metadata":{}}		
		if not import_info[glb_path].has("__metadata"):
			import_info[glb_path]["__metadata"] = {}		
		if not import_info[glb_path]["__metadata"].has("baker_path"):
			import_info[glb_path]["__metadata"]["baker_path"] = object.scene_file_path		
		var glb_collection_name = AssetIO.node_parse_name( mesh_instance ).name
		
		if not MAssetTable.get_singleton().finish_import.is_connected(finish_import.bind(glb_collection_name)):
			MAssetTable.get_singleton().finish_import.connect(finish_import.bind(glb_collection_name))
		
		AssetIO.glb_load(glb_path, import_info[glb_path]["__metadata"], true)		
				
	)
func finish_import(glb_path, glb_collection_name=""):
	if not "joined_mesh" in glb_collection_name:
		return
	#CHECK IF IS JOINED MESH		
	var asset_library = MAssetTable.get_singleton()
	var import_info = asset_library.import_info		
	var collection_id = -1
	if import_info[glb_path].has( glb_collection_name ):
		collection_id = import_info[glb_path][glb_collection_name]["id"]				
		asset_library.collection_add_tag(collection_id, 0)
		var node
		if object.has_node( glb_collection_name ):
			node = object.get_node(glb_collection_name)
			var original_node = AssetIO.collection_instantiate(collection_id)			
			original_node.get_child(0).reparent( node )
			original_node.queue_free()			
		else:
			node = AssetIO.collection_instantiate(collection_id)
			object.add_child(node)		
			node.owner = object	
			node.name = glb_collection_name
		object.joined_mesh_node = node	
		
	MAssetTable.get_singleton().finish_import.disconnect(finish_import)
	
	
func check_if_can_join_meshes(object):
	if object.join_at_lod == -1:
		%Join.disabled = true
		%join_hint.text = "please set join at lod"
		return
	if object.scene_file_path == "":
		%Join.disabled = true
		%join_hint.text = "please save baker scene before making joined mesh"
		return
	if len(object.meshes_to_join.filter(func(a): return is_instance_valid(a))) == 0:
		%Join.disabled = true
		%join_hint.text = "please add some meshes to \"meshes to join\" "
		return
	%Join.disabled = false
		
	
