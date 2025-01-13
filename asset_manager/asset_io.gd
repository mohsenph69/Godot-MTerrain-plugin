@tool
class_name AssetIO extends Object

const LOD_COUNT = 8  # The number of different LODs in your project

static var regex_mesh_match := RegEx.create_from_string("(.*)[_|\\s]lod[_|\\s]?(\\d+)")
static var regex_col_match:= RegEx.create_from_string("(.*)?[_|\\s]?(col|collision)[_|\\s](box|sphere|capsule|cylinder|concave|mesh).*")
static var asset_data:AssetIOData = null
static var DEBUG_MODE = false #true
#region GLB	Export
static func glb_get_root_node_name(path):
	var gltf_document = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	gltf_document.append_from_file(path,gltf_state)
	return gltf_state.get_nodes()[gltf_state.root_nodes[0]].original_name

static func glb_export(root_node:Node3D, path = str("res://addons/m_terrain/asset_manager/example_asset_library/export/", root_node.name.to_lower(), ".glb") ):
	var asset_library:MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))
	var gltf_document= GLTFDocument.new()
	var gltf_save_state = GLTFState.new()	
	#if root_node is MeshInstance3D:
		#print(root_node)
		#for surface_id in root_node.mesh.get_surface_count():
			#print(root_node.mesh.surface_get_material(surface_id).resource_name) #resource_path.get_file().get_slice(".", 0))
		
	gltf_document.append_from_scene(root_node, gltf_save_state)
	print("exporting to ", path)
	var error = gltf_document.write_to_filesystem(gltf_save_state, path)	
#endregion

#region GLB Import	
static func glb_load_hlod_commit_changes(scene, baker_path):		
	var asset_library:MAssetTable = MAssetTable.get_singleton()		
	
	for node in scene.get_children():		
		if node.has_meta("export_path"):			
			var path = node.get_meta("export_path")		
			glb_export(node, path)	
			node.queue_free()			
			glb_load(path, {}, true)
			node.name = node.name + "_0"														
			scene.joined_mesh_collection_id = asset_library.import_info[path][node.name].id
			asset_library.collection_add_tag(scene.joined_mesh_collection_id, 0)						
	
	for node in scene.find_children("*"):
		if node.has_meta("ignore") and node.get_meta("ignore") == true: 
			node.get_parent().remove_child(node)
			node.queue_free()
	
	var packed_scene = PackedScene.new()	
	packed_scene.pack(scene)	
	print("baker path: ", baker_path)
	if FileAccess.file_exists(baker_path):
		packed_scene.take_over_path(baker_path)							
		ResourceSaver.save(packed_scene, baker_path)	
		if baker_path in EditorInterface.get_open_scenes():
			EditorInterface.reload_scene_from_path(baker_path)
	else:
		ResourceSaver.save(packed_scene, baker_path)	

static func glb_parse_hlod_scene(original_scene:Node, root_name):
	var asset_library:MAssetTable = MAssetTable.get_singleton()	
	var scene = original_scene.get_child(0)			
	original_scene.remove_child(scene)
	original_scene.queue_free()
	scene.set_script(preload("res://addons/m_terrain/asset_manager/hlod_baker.gd"))
	scene.name = root_name
	var nodes = scene.find_children("*", "Node3D", true, false)	
	var joined_mesh_node = null	
	var baker_path := str(MAssetTable.get_editor_baker_scenes_dir().path_join(root_name + "_baker.tscn" ))
	scene.set_meta("baker_path", baker_path)
	nodes.reverse()	
	for node in nodes:		
		if node is ImporterMeshInstance3D:						
			if joined_mesh_node == null:
				joined_mesh_node = Node3D.new()
				scene.add_child(joined_mesh_node)
				var path = baker_path.get_basename() + "_joined_mesh.glb"			
				joined_mesh_node.set_meta("export_path", path)
				var name_data = node_parse_name(node)			
				joined_mesh_node.name = name_data.name + "_joined_mesh" if not "_joined_mesh" in name_data.name else name_data.name
			node.reparent(joined_mesh_node)																	
			var mesh_node = MeshInstance3D.new()
			joined_mesh_node.add_child(mesh_node)									
			mesh_node.owner = joined_mesh_node
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
		var node_name := collection_parse_name(node)
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
		if scene.is_ancestor_of(new_node):			
			new_node.owner = scene
		else:						
			new_node.queue_free()
		node.queue_free()	
	return scene
	
static func glb_show_import_scene_window(scene):
	var popup = Window.new()
	popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	popup.wrap_controls = true
	EditorInterface.get_editor_main_screen().add_child(popup)
	var panel = preload("res://addons/m_terrain/asset_manager/ui/import_window_hlod_scene.tscn").instantiate()
	panel.scene = scene	
	popup.add_child(panel)
	popup.popup_centered(Vector2i(800,600))	
	
static func glb_load(path, metadata={},no_window:bool=false):
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	var gltf_document = GLTFDocument.new()
	if not Engine.is_editor_hint():
		GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	var gltf_state = GLTFState.new()
	gltf_document.append_from_file(path,gltf_state)
	
	var root_name = gltf_state.get_nodes()[gltf_state.root_nodes[0]].original_name
	if "_hlod" in root_name and not "_joined_mesh" in root_name:
		var scene = glb_parse_hlod_scene(gltf_document.generate_scene(gltf_state), root_name)
		glb_show_import_scene_window(scene)
		return		
	
	#STEP 0: Init Asset Data
	asset_data = AssetIOData.new()	
	if gltf_state.json.scenes[0].has("extras"):
		if gltf_state.json.scenes[0].extras.has("blend_file"):
			asset_data.blend_file = gltf_state.json.scenes[0].extras.blend_file	
		if gltf_state.json.scenes[0].extras.has("variation_groups"):
			asset_data.variation_groups = gltf_state.json.scenes[0].extras.variation_groups			
	asset_data.glb_path = path
	asset_data.meta_data = metadata		
	#STEP 1: convert gltf file into nodes
	var scene_root = gltf_document.generate_scene(gltf_state)	
	var scene = scene_root.get_children() if not scene_root is ImporterMeshInstance3D else [scene_root]
	#STEP 2: convert gltf scene into AssetData format	
	generate_asset_data_from_glb(scene)
	asset_data.finalize_glb_parse()
	asset_data.fill_mesh_lod_gaps()
	#STEP 3: add data from last import for comparisons
	if asset_library.import_info.has(path):
		asset_data.add_glb_import_info(asset_library.import_info[path])
	asset_data.generate_import_tags()
	scene_root.queue_free() ## Really important otherwise memory leaks
	#STEP 4: Allow user to change import settings
	if not no_window:
		glb_show_import_window(asset_data)
	#STEP 5: Commit changes - import window will call this step when user clicks "import"
	else:		
		glb_import_commit_changes()			
		
#Parse GLB file and prepare a preview of changes to asset library
static func generate_asset_data_from_glb(scene:Array,active_collection="__root__"):
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	for node in scene:
		if not node:
			print(node, " is not a node")
		var name_data := node_parse_name(node)		
		var child_count:int = node.get_child_count()
		#######################
		## PROCESS MESH NODE ##
		#######################
		if name_data["lod"] >=0: ## Then definitly is a mesh					
			if not node.has_meta("material_sets"):
				var mesh_item_name = name_data["name"] + "_0"
				var mesh:Mesh = null
				if node is ImporterMeshInstance3D:
					mesh = node.mesh.get_mesh()
				var material_set := []
				if mesh!=null:
					for i in mesh.get_surface_count():
						material_set.push_back(mesh.surface_get_material(i).resource_name)
				asset_data.add_mesh_data([material_set],mesh, mesh_item_name)						
				asset_data.add_mesh_item(mesh_item_name,name_data["lod"],node, 0)			
				var collection_name = mesh_item_name if active_collection == "__root__" else active_collection				
				asset_data.add_mesh_item_to_collection(collection_name, mesh_item_name, active_collection == "__root__")				
			else:
				for set_id in len(node.get_meta("material_sets")):
					var mesh_item_name = name_data["name"] + str("_", set_id)								
					asset_data.add_mesh_data(node.get_meta("material_sets"), node.mesh.get_mesh(), mesh_item_name)						
					asset_data.add_mesh_item(mesh_item_name,name_data["lod"],node, set_id)			
					var collection_name = mesh_item_name if active_collection == "__root__" else active_collection				
					asset_data.add_mesh_item_to_collection(collection_name, mesh_item_name, active_collection == "__root__")				
					#for group in asset_data.variation_groups:
						#if name_data["name"] in group:
							
			if child_count > 0:
				push_error(node.name + " can not have children! ignoring its children! this can be due to naming with _lod of that or it is a mesh!")									
		############################
		## PROCESS COLLISION NODE ##
		############################
		elif name_data["col"] != null:
			var collection_name = name_data.name if active_collection=="__root__" else active_collection
			if node is ImporterMeshInstance3D:
				asset_data.add_collision_to_collection(collection_name, name_data["col"], node.transform, node.mesh.get_mesh())
			else:				
				asset_data.add_collision_to_collection(collection_name, name_data["col"], node.transform)				
			if child_count > 0:
				push_error(node.name + " is detected as a collission due to using _col in its name! ignoring its children!")
		#############################
		## PROCESS COLLECTION NODE ##
		#############################
		elif child_count > 0:
			if active_collection=="__root__":
				generate_asset_data_from_glb(node.get_children(),node.name)
				if node.has_meta("tags"):										
					if asset_data.collections.has(node.name):
						asset_data.collections[node.name].tags = node.get_meta("tags")
			else:
				push_error(active_collection, " has sub_collection with children: ", node.name)
		#################################
		## PROCESS SUB_COLLECTION NODE ##	
		#################################
		elif active_collection != "__root__": # can be sub collection			
			var subcollection_name = collection_parse_name(node)						
			if node.has_meta("blend_file"):				
				var blend_file = node.get_meta("blend_file").trim_prefix("//")				
				if asset_data.blend_file != blend_file:
					if blend_file in asset_library.import_info["__blend_files"]:
						var glb_path = asset_library.import_info["__blend_files"][blend_file]
						subcollection_name += "::" + glb_path					
					else:
						print("error with subcollection from different blend file. Here is the list of blend files in import_info:\n", asset_library.import_info["__blend_files"].keys())
			asset_data.add_sub_collection(active_collection,subcollection_name,node.transform)	
	#if active_collection == "__root__":
		#asset_data.finalize_glb_parse()
		
static func glb_import_commit_changes():
	var asset_library = MAssetTable.get_singleton()
	###########################################
	## glb_id unique ID assigned to each glb ##
	###########################################
	var glb_id:int;
	if asset_library.import_info.has(asset_data.glb_path) and asset_library.import_info[asset_data.glb_path].has("__id"):
		glb_id = asset_library.import_info[asset_data.glb_path]["__id"]
	else: ## assign new glb id
		var used_ids:PackedInt32Array
		for k in asset_library.import_info:
			if k.begins_with("__"): continue
			if asset_library.import_info[k].has("__id"): used_ids.push_back(asset_library.import_info[k]["__id"])
		for i in range(1000_000_000):
			if used_ids.find(i) == -1:
				glb_id = i 
				break
	#################
	## Save Meshes ##
	#################
	var saved_successful = asset_data.save_unsaved_meshes()
	if not saved_successful == OK:
		push_error("GLB import cannot import meshes: mesh could not be saved to file \n", str(asset_data.glb_path))
		return					
	######################
	## Commit Mesh Item ##
	######################
	var meshes_to_remove := {}
	# mesh_item must be processed before collection, because collection depeneds on mesh item
	for mesh_item_name in asset_data.mesh_items.keys(): 
		var mesh_item_info = asset_data.mesh_items[mesh_item_name]
		if mesh_item_info["ignore"] or mesh_item_info["state"] == AssetIOData.IMPORT_STATE.NO_CHANGE:
			continue
		### Handling Remove First
		if mesh_item_info["state"] == AssetIOData.IMPORT_STATE.REMOVE:			
			for mesh_id in asset_library.mesh_item_get_info(mesh_item_info["id"]).mesh:
				meshes_to_remove[mesh_id] = true				
			asset_library.mesh_item_remove(mesh_item_info["id"])
			continue
		### Other State	
		var mesh_id_array = mesh_item_info["meshes"]
		#var material_set_id = int(mesh_item_name.split("_")[-1])			
		if mesh_item_info["state"] == AssetIOData.IMPORT_STATE.NEW:			
			var mid = asset_library.mesh_item_add(mesh_id_array, mesh_item_info.material_set_id)
			asset_data.update_mesh_items_id(mesh_item_name,mid)			
		elif mesh_item_info["state"] == AssetIOData.IMPORT_STATE.CHANGE:
			if mesh_item_info["id"] == -1:
				push_error("something bad happened mesh id should not be -1")
				continue
			for i in len(mesh_item_info.mesh_state):
				if mesh_item_info.mesh_state[i] in [AssetIOData.IMPORT_STATE.CHANGE, AssetIOData.IMPORT_STATE.REMOVE]:
					meshes_to_remove[ mesh_item_info.original_meshes[i] ] = true
			asset_library.mesh_item_update(mesh_item_info.id, mesh_id_array, mesh_item_info.material_set_id)
	
	
	for mesh_id in meshes_to_remove:
		remove_mesh(mesh_id)
	#######################
	## Commit collisions ##
	#######################
	#for collision_item_name in asset_data.collision_items:
		#var collision_item_id = asset_library.collision_item_add(collision_item.type, collision_item.transform, collision_item.data)
		#asset_data.collision_items[collision_item_name].id = collision_item_id
	
	########################
	## Commit Collections ##
	########################
	var collection_names = asset_data.collections.keys()
	for collection_name in collection_names:
		import_collection(collection_name,glb_id)
	########################
	## Adding Import Info ##
	########################
			
	asset_library.import_info[asset_data.glb_path] = asset_data.get_glb_import_info()	
	asset_library.import_info[asset_data.glb_path]["__id"] = glb_id
	if not "__blend_files" in asset_library.import_info:
		asset_library.import_info["__blend_files"] = {}
	asset_library.import_info["__blend_files"][asset_data.blend_file] = asset_data.glb_path	
	
	asset_library.import_info[asset_data.glb_path]["__variation_groups"] = asset_data.variation_groups
	
	asset_library.finish_import.emit(asset_data.glb_path)
	asset_library.save()

static func import_collection(glb_node_name:String,glb_id:int):		
	if glb_node_name and not asset_data.collections.has(glb_node_name) or asset_data.collections[glb_node_name]["ignore"] or asset_data.collections[glb_node_name]["state"] == AssetIOData.IMPORT_STATE.NO_CHANGE:
		return
	asset_data.collections[glb_node_name]["ignore"] = true # this means this collection has been handled
	var asset_library := MAssetTable.get_singleton()
	var collection_info: Dictionary = asset_data.collections[glb_node_name]	
	if collection_info["state"] == AssetIOData.IMPORT_STATE.REMOVE:
		if collection_info["id"] == -1:
			push_error("Invalid collection to remove")
			return
		asset_library.remove_collection(collection_info["id"])
		return
	var mesh_items = collection_info["mesh_items"]
	var collection_id := -1
	if collection_info["state"] == AssetIOData.IMPORT_STATE.NEW:
		collection_id = asset_library.collection_create(glb_node_name)
		asset_library.collection_update_name(collection_id, glb_node_name)
		asset_data.update_collection_id(glb_node_name, collection_id)
	elif collection_info["id"] != -1 and collection_info["state"] == AssetIOData.IMPORT_STATE.CHANGE:
		collection_id = collection_info["id"]
		if not asset_library.has_collection(collection_id):
			push_error("import collection error: trying to change existing collection, but ", collection_id, " does not exist")
		asset_library.collection_clear(collection_id)
	else:
		push_error("Invalid collection!!!")
		return
	asset_library.collection_set_glb_id(collection_id,glb_id)
	if not asset_library.has_collection(collection_id):
		push_error("import collection error: ", collection_id, " does not exist")
					
	#Add Mesh Items to Collection
	for mesh_item_name in mesh_items:
		var mesh_item_id = asset_data.get_mesh_items_id(mesh_item_name)
		if mesh_item_id == -1:
			push_error("invalid mesh item to insert in collection ",glb_node_name)
			return
		asset_library.collection_add_item(collection_id,MAssetTable.MESH,mesh_item_id,mesh_items[mesh_item_name])
	
	#Add Collision Items to Collection
	#var collision_items = collection_info["collision_items"] #this is Array of {type, transform, }
	#for collision_item_name in collision_items:
		#var collision_item_id = asset_data.get_collision_item_id(collision_item_name)		
		#asset_library.collection_add_item(collection_id,MAssetTable.COLLISION,collision_item_id, )
	
	#Adding Sub Collection to Collection
	var sub_collections:Dictionary = collection_info["sub_collections"]
	for sub_collection_name in sub_collections:
		#If sub_collection in different glb...				
		if "::" in sub_collection_name:			
			var glb_path = sub_collection_name.get_slice("::", 1)	
			var node_name = sub_collection_name.get_slice("::", 0)			
			if node_name in asset_library.import_info[glb_path]:
				var sub_collection_id = asset_library.import_info[glb_path][node_name].id							
				for sub_collection_transform in sub_collections[sub_collection_name]:
					if not asset_library.has_collection(sub_collection_id):
						push_error("trying to add subcollection to collection, but sub_collection_id ", sub_collection_id, " does not exist")
					asset_library.collection_add_sub_collection(collection_id, sub_collection_id, sub_collection_transform)				
		#If sub_collection is from THIS glb
		else: 			
			var sub_collection_id = asset_data.get_collection_id(sub_collection_name)			
			if sub_collection_id == -1:
				import_collection(sub_collection_name,glb_id)			
			#get sub_collection_id after import_collection for subcollection
			sub_collection_id = asset_data.get_collection_id(sub_collection_name)
			if not asset_library.has_collection(sub_collection_id):
				push_error("trying to add subcollection to collection, but sub_collection_id ", sub_collection_id, " does not exist")
			for sub_collection_transform in sub_collections[sub_collection_name]:
				asset_library.collection_add_sub_collection(collection_id, sub_collection_id, sub_collection_transform)	
	
static func glb_show_import_window(asset_data:AssetIOData):
	var popup = Window.new()
	popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	popup.wrap_controls = true
	EditorInterface.get_editor_main_screen().add_child(popup)
	var panel = preload("res://addons/m_terrain/asset_manager/ui/import_window.tscn").instantiate()
	panel.asset_data = asset_data
	popup.add_child(panel)
	popup.popup_centered(Vector2i(800,600))	
	
static func node_parse_name(node:Node)->Dictionary:
	var result = {"name":"","lod":-1,"col":null}
	var lod:int = -1	
	var search_result = regex_mesh_match.search(node.name)
	if search_result:		
		result["name"] = search_result.strings[1]
		result["lod"] = search_result.strings[2].to_int()
	elif node is ImporterMeshInstance3D:
		result["name"] = String(node.name)
		result["lod"] = 0
	else:
		search_result = regex_col_match.search(node.name)		
		if search_result:			
			result["name"] = search_result.strings[1]
			match(search_result.strings[-1]):
				"box": result["col"] = AssetIOData.COLLISION_TYPE.BOX
				"sphere": result["col"] = AssetIOData.COLLISION_TYPE.SPHERE
				"cylinder": result["col"] = AssetIOData.COLLISION_TYPE.CYLINDER
				"capsule": result["col"] = AssetIOData.COLLISION_TYPE.CAPSULE
				"convex": result["col"] = AssetIOData.COLLISION_TYPE.CONVEX
				"mesh": result["col"] = AssetIOData.COLLISION_TYPE.MESH							
	return result

static func collection_parse_name(node)->String:	
	var material_suffix = ""
	if node.has_meta("active_material_set_id"):
		material_suffix = str("_", node.get_meta("active_material_set_id"))
	var suffix_length = len(node.name.split("_")[-1])
	if node.name.right(suffix_length).is_valid_int():  #remove the .001 suffix
		return node.name.left(len(node.name)-suffix_length-1) + material_suffix
	return node.name + material_suffix
#endregion

#region THUMBNAILS
static func generate_material_thumbnails(material_ids):	
	for id in material_ids:
		generate_material_thumbnail(id)

static func generate_material_thumbnail(material_id):			
	if not AssetIO.get_material_table().has(material_id):
		push_error("trying to generate thumbnail for material id that does not exist:", material_id)
		return null
	var path = get_material_table()[material_id].path
	var thumbnail_path = get_thumbnail_path(material_id, false)	
	if FileAccess.file_exists(thumbnail_path) and FileAccess.file_exists(path) and FileAccess.get_modified_time(path) < FileAccess.get_modified_time( thumbnail_path ):							
		return		
	var material = load(path)
	EditorInterface.get_resource_previewer().queue_edited_resource_preview(material, AssetIO, "material_thumbnail_generated", material_id)						
	
	
static func get_glb_path_from_collection_id(collection_id)->String:
	var glb_id:int = MAssetTable.get_singleton().collection_get_glb_id(collection_id)
	var import_info:Dictionary = MAssetTable.get_singleton().import_info
	for k in import_info:
		if k.begins_with("__"): continue
		if import_info[k]["__id"] == glb_id: return k
	return ""

static func get_collection_import_time(collection_id:int)->float:
	var glb_id:int = MAssetTable.get_singleton().collection_get_glb_id(collection_id)
	var import_info:Dictionary = MAssetTable.get_singleton().import_info
	for k in import_info:
		if k.begins_with("__"): continue
		if import_info[k]["__id"] == glb_id: return import_info[k]["__import_time"]
	return -1

static func material_thumbnail_generated(path, preview, thumbnail_preview, material_id):	
	var thumbnail_path = AssetIO.get_thumbnail_path(material_id, false)
	save_thumbnail(preview, thumbnail_path)						

static func get_thumbnail_path(id: int, is_collection:bool=true):
	if is_collection:
		return MAssetTable.get_asset_thumbnails_dir() + str(id) + ".dat"
	else:
		return MAssetTable.get_asset_thumbnails_dir() + "material_" + str(id) + ".dat"

static func save_thumbnail(preview:ImageTexture, thumbnail_path:String):			
	var data = preview.get_image().save_png_to_buffer() if preview else Image.create_empty(64,64,false, Image.FORMAT_R8).save_png_to_buffer()
	var file = FileAccess.open(thumbnail_path, FileAccess.WRITE)
	if not DirAccess.dir_exists_absolute( thumbnail_path.get_base_dir() ):
		DirAccess.make_dir_recursive_absolute( thumbnail_path.get_base_dir() )
	file.store_var(data)
	file.close()
	
static func get_thumbnail(path):	
	if not FileAccess.file_exists(path):
		return null	
	var file = FileAccess.open(path, FileAccess.READ)		
	var image:= Image.new()
	image.load_png_from_buffer(file.get_var())
	file.close()		
	return ImageTexture.create_from_image(image)		
#endregion

static func remove_collection(collection_id):
	var asset_library = MAssetTable.get_singleton()
	if not asset_library.has_collection(collection_id):
		push_error("trying to remove collection that doesn't exist: ", collection_id)
	var mesh_item_ids = asset_library.collection_get_mesh_items_ids(collection_id)	
	for mesh_item_id in mesh_item_ids:
		if not asset_library.has_mesh_item(mesh_item_id):
			push_error("trying to remove a mesh item that doesn't exist: ", mesh_item_id)
			continue
		var mesh_array = asset_library.mesh_item_get_info(mesh_item_id).mesh		
		for mesh_id in mesh_array:
			remove_mesh(mesh_id)
		asset_library.mesh_item_remove(mesh_item_id)		
	asset_library.collection_remove(collection_id)				
	var thumbnail_path = get_thumbnail_path(collection_id)
	if FileAccess.file_exists(thumbnail_path):		
		DirAccess.remove_absolute(thumbnail_path)		
	for glb_path in asset_library.import_info.keys():
		if glb_path.begins_with("__"): continue
		for node_name in asset_library.import_info[glb_path].keys():
			if node_name.begins_with("__"): continue
			if asset_library.import_info[glb_path][node_name].has("id"):
				if asset_library.import_info[glb_path][node_name].id == collection_id:
					asset_library.import_info[glb_path].erase(node_name)
					return

static func get_orphaned_collections():
	var asset_library := MAssetTable.get_singleton()
	var ids = asset_library.collection_get_list()			
	var result = Array(ids)
	for glb in asset_library.import_info.keys():
		if glb.begins_with("__"): continue
		for node_name in asset_library.import_info[glb]:
			if node_name.begins_with("__"): continue
			if asset_library.import_info[glb][node_name].has("id"):						
				if asset_library.import_info[glb][node_name].id in result:
					result.erase(asset_library.import_info[glb][node_name].id)
	return result

static func get_material_table():
	var asset_library := MAssetTable.get_singleton()	
	if not asset_library.import_info.has("__materials"):
		asset_library.import_info["__materials"] = {}
	return asset_library.import_info["__materials"]

static func update_material(id, path):
	var asset_library := MAssetTable.get_singleton()	
	var material_table = get_material_table()
	var material = load(path)
	if not material is Material:
		push_error("failed adding material to material table: resource is not material")
		return
	if material.resource_name == "": 
		material.resource_name = path.get_file().get_slice(".",0)
		ResourceSaver.save(material)
	##################
	## New Material ##
	##################		
	if id == -1:
		id = 0		
		while material_table.has(id):
			id += 1
		asset_library.import_info["__materials"][id] = {"path": path, "meshes": []}		 
		
		return		
	#######################
	## Existing Material ##
	#######################
	## 1. Update material table in import info	
	asset_library.import_info["__materials"][id] = {"path": path, "meshes":material_table[id].meshes}
			
	## 2. Update all mmesh resources that use this material
	for mesh_id in material_table[id].keys():
		var mesh_path = MHlod.get_mesh_path(mesh_id)
		if not FileAccess.file_exists(mesh_path): continue
		var mmesh:MMesh = load(path)
		for set_id in mmesh.material_set_get_count():
			var material_names = mmesh.material_set_get(set_id)
			for i in len(material_names):
				if material_names[i] == path:
					mmesh.surface_set_material(set_id, i, path)
		ResourceSaver.save(mmesh)
	
			
static func remove_material(id):
	var asset_library := MAssetTable.get_singleton()	
	var materials = get_material_table()
	if materials.has(id):	
		if len(materials[id].meshes) > 0:
			push_error("cannot remove material from table: still in use by ", len(materials[id].meshes) , " meshes")
			return
		materials.erase(id)
		var thumbnail_path = get_thumbnail_path(id, false)
		if FileAccess.file_exists(thumbnail_path):
			DirAccess.remove_absolute( thumbnail_path )
	asset_library.import_info["__materials"] = materials

static func remove_ununused_meshes():
	var root = MHlod.get_mesh_root_dir()
	for path in DirAccess.get_files_at( root ):
		var mesh_id = int(path)
		if len(MAssetTable.get_singleton().mesh_get_mesh_items_users(mesh_id)) == 0:
			DirAccess.remove_absolute(root.path_join(path))

static func remove_mesh(mesh_id):	
	return
	var asset_library =MAssetTable.get_singleton()	
	if len(asset_library.mesh_get_mesh_items_users(mesh_id)) > 1:
		return
	asset_library.mesh_remove(mesh_id)	
	var material_table = get_material_table()
	for material_id in material_table:
		if mesh_id in material_table[material_id].meshes:
			material_table[material_id].meshes.erase(mesh_id)			
				
static func import_settings(path):
	var asset_library = MAssetTable.get_singleton()
	var data = JSON.parse_string( FileAccess.get_file_as_string(path))
	if not asset_library.import_info.has("__materials"):
		asset_library.import_info["__materials"] = {}
	for material in data.materials:
		asset_library.import_info["__materials"][int(material)] = data.materials[material]	
	if not asset_library.import_info.has("__blend_files"):
		asset_library.import_info["__blend_files"] = {}
	for blend_file in data.blend_files:
		asset_library.import_info["__blend_files"][blend_file] = data.blend_files[blend_file]
	for tag in data.tags.keys():
		asset_library.tag_set_name(int(data.tags[tag]), tag)		
	for group in data.groups:
		#if asset_library.group_exist(group):
			#print(group, " exists: ", asset_library.group_get_tags(group))
			#asset_library.group_remove(group)	
		asset_library.group_create(group)
		for tag in data.groups[group]:
			asset_library.group_add_tag(group, tag)
	for glb_path in data.collections.keys():
		for node_name in data.collections[glb_path].keys():
			var id = data.collections[glb_path][node_name].id
			if not asset_library.has_collection(id): continue
			for tag in data.collections[glb_path][node_name].tags:
				asset_library.collection_add_tag(id, tag)

static func export_settings(path):
	var asset_library = MAssetTable.get_singleton()	
	var result = {}
	result["tags"] = asset_library.tag_get_names()
	result["groups"] = {}
	for group in asset_library.group_get_list():
		result["groups"][group] = asset_library.group_get_tags(group)
	result["materials"] = asset_library.import_info["__materials"] if asset_library.import_info.has("__materials") else {}
	result["blend_files"] = asset_library.import_info["__blend_files"] if asset_library.import_info.has("__blend_files") else {}
	result["collections"] = {}	
	#COLLECTIONS
	for glb_path in asset_library.import_info.keys():
		if glb_path.begins_with("__"): continue #not a glb!
		if not glb_path in result["blend_files"].values(): continue # not from a blend file
		var key = result["blend_files"].find_key(glb_path) #  return the blend file that made this glb		
		result.collections[key] = {}
		for node_name in asset_library.import_info[glb_path]:
			if node_name.begins_with("__"): continue #not a node!			
			result.collections[key][node_name] = {"id": asset_library.import_info[glb_path][node_name].id} #store the glb node names that came from that blend file
			result.collections[key][node_name]["tags"] = asset_library.collection_get_tags(result.collections[key][node_name].id)
			
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
