@tool
class_name AssetIO extends Object

############################################
# AssetIO contains:
# - static functions for importing/exporting glb files
# - static functions for instantiating collections
# - static functions for updating MAssetTable from nodes

# AssetTable Import Info is structured as follows: {
#	gbl_path.glb: {
#		object_name: collection_id
#	}

# QUESTION: If I have a fence with 100 fence posts, is it better to have 1 mesh with 8000 verticies or 100 instances of a single mesh with 80vertices?

const LOD_COUNT = 8  # The number of different LODs in your project

static var regex_mesh_match := RegEx.create_from_string("(.*)[_|\\s]lod[_|\\s]?(\\d+)")
static var regex_col_match:= RegEx.create_from_string("(.*)?[_|\\s]?(col|collision)[_|\\s](box|sphere|capsule|cylinder|concave|mesh).*")
static var asset_data:AssetIOData = null

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

	var node = root_node.duplicate(0)
	node.transform = Transform3D()
	node.name = node.name.split("*")[0]
	for child in node.get_children():
		child.owner = node
		if child.has_meta("collection_id"):
			if not child.get_meta("collection_id") in asset_library.tag_get_collections(0):
				for grandchild in child.get_children():
					child.remove_child(grandchild)
					grandchild.queue_free()

	EditorInterface.get_edited_scene_root().add_child(node)

	gltf_document.append_from_scene(node, gltf_save_state)
	print("exporting to ", path)
	var error = gltf_document.write_to_filesystem(gltf_save_state, path)
	node.queue_free()	
#endregion

#region GLB Import	
static func load_glb_as_hlod(original_scene,root_name):		
	var asset_library:MAssetTable = MAssetTable.get_singleton()	
	var scene = original_scene.get_child(0)			
	scene.set_script(preload("res://addons/m_terrain/asset_manager/hlod_baker.gd"))
	var nodes = scene.find_children("*", "Node3D", true, false)	
	var baker_path := str("res://addons/m_terrain/asset_manager/reference/" + root_name + "_baker.tscn" )
	nodes.reverse()	
	for node in nodes:		
		if node is ImporterMeshInstance3D:						
			var parent_node = Node3D.new()
			var mesh_node = MeshInstance3D.new()
			parent_node.add_child(mesh_node)
			var name_data = node_parse_name(node)			
			scene.join_at_lod = name_data.lod
			parent_node.name = name_data.name + "_joined_mesh" if not "_joined_mesh" in name_data.name else name_data.name
			mesh_node.owner = parent_node
			mesh_node.name = node.name
			mesh_node.transform = node.transform
			mesh_node.mesh = node.mesh.get_mesh()
			node.get_parent().remove_child(node)
			node.queue_free()
			var path = baker_path.get_basename() + "_joined_mesh.glb"			
			glb_export(parent_node, path)			
			parent_node.queue_free()			
			glb_load(path, {}, true)					
			if not path in asset_library.import_info:
				print("joined mesh reimport: no joined mesh path in import info", path)
				continue
			if not name_data.name in asset_library.import_info[path]:
				print("joined mesh reimport: no node name in import info", name_data.name)				
				continue			
			scene.joined_mesh_collection_id = asset_library.import_info[path][name_data.name].id
			asset_library.collection_add_tag(scene.joined_mesh_collection_id, 0)						
			continue					
		if not node.has_meta("blend_file"):			
			print("NO BLend file in node")
			continue
		if not asset_library.import_info["__blend_files"].has(node.get_meta("blend_file")):			
			print("NO BLend file in import info")
			continue
		var glb_path = asset_library.import_info["__blend_files"][node.get_meta("blend_file")]			
		var node_name := collection_parse_name(node.name)
		if not asset_library.import_info[glb_path].has(node_name):			
			print("import info does not have this node name for this glb")
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
	var packed_scene = PackedScene.new()	
	packed_scene.pack(scene)
	original_scene.queue_free()		
	if FileAccess.file_exists(baker_path):
		packed_scene.take_over_path(baker_path)
		ResourceSaver.save(packed_scene, baker_path)			
	else:
		ResourceSaver.save(packed_scene, baker_path)
	original_scene.queue_free()	

static func glb_load(path, metadata={},no_window:bool=false):
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	var gltf_document = GLTFDocument.new()
	if not Engine.is_editor_hint():
		GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	var gltf_state = GLTFState.new()
	gltf_document.append_from_file(path,gltf_state)
	
	var root_name = gltf_state.get_nodes()[gltf_state.root_nodes[0]].original_name
	if "_hlod" in root_name and not "_joined_mesh" in root_name:
		load_glb_as_hlod(gltf_document.generate_scene(gltf_state), root_name)
		return		
	
	#STEP 0: Init Asset Data
	asset_data = AssetIOData.new()	
	if gltf_state.json.scenes[0].has("extras") and gltf_state.json.scenes[0].extras.has("blend_file"):
		asset_data.blend_file = gltf_state.json.scenes[0].extras.blend_file	
	asset_data.glb_path = path
	asset_data.meta_data = metadata		
	#STEP 1: convert gltf file into nodes
	var scene_root = gltf_document.generate_scene(gltf_state)
	var scene = scene_root.get_children()
	#STEP 2: convert gltf scene into AssetData format	
	generate_asset_data_from_glb(scene)	
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
				var mesh :Mesh= node.mesh.get_mesh()
				asset_data.add_mesh_data([[mesh.surface_get_material(0).resource_name]],mesh , mesh_item_name)						
				asset_data.add_mesh_item(mesh_item_name,name_data["lod"],node, 0)			
				var collection_name = name_data["name"] + "_0" if active_collection == "__root__" else active_collection				
				asset_data.add_mesh_to_collection(collection_name, mesh_item_name, active_collection == "__root__")				
			else:
				for set_id in len(node.get_meta("material_sets")):
					var mesh_item_name = name_data["name"] + str("_", set_id)								
					asset_data.add_mesh_data(node.get_meta("material_sets"), node.mesh.get_mesh(), mesh_item_name)						
					asset_data.add_mesh_item(mesh_item_name,name_data["lod"],node, set_id)			
					var collection_name = name_data["name"] + str("_", set_id) if active_collection == "__root__" else active_collection				
					asset_data.add_mesh_to_collection(collection_name, mesh_item_name, active_collection == "__root__")				
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
			var subcollection_name = collection_parse_name(node.name)						
			if node.has_meta("blend_file"):				
				var blend_file = node.get_meta("blend_file").trim_prefix("//")				
				if asset_data.blend_file != blend_file:
					if blend_file in asset_library.import_info["__blend_files"]:
						var glb_path = asset_library.import_info["__blend_files"][blend_file]
						subcollection_name += "::" + glb_path					
					else:
						print("error with subcollection from different blend file. Here is the list of blend files in import_info:\n", asset_library.import_info["__blend_files"].keys())
			asset_data.add_sub_collection(active_collection,subcollection_name,node.transform)	
	if active_collection == "__root__":
		asset_data.finalize_glb_parse()
		
static func glb_import_commit_changes():
	var asset_library = MAssetTable.get_singleton()
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
	# mesh_item must be processed before collection, because collection depeneds on mesh item
	for mesh_item_name in asset_data.mesh_items.keys(): #mesh_names:
		var mesh_item_info = asset_data.mesh_items[mesh_item_name]
		if mesh_item_info["ignore"] or mesh_item_info["state"] == AssetIOData.IMPORT_STATE.NO_CHANGE:
			continue
		### Handling Remove First
		if mesh_item_info["state"] == AssetIOData.IMPORT_STATE.REMOVE:			
			for mesh_id in asset_library.mesh_item_get_info(mesh_item_info["id"]).mesh:
				if len(asset_library.mesh_get_mesh_items_users(mesh_id)) > 1:
					continue
				var path = MHlod.get_mesh_path(mesh_id)
				asset_library.erase_mesh_hash(load(path))
				if FileAccess.file_exists(path):
					DirAccess.remove_absolute(path)				
			asset_library.mesh_item_remove(mesh_item_info["id"])
			continue
		### Other State	
		var mesh_id_array = fill_mesh_lod_gaps(mesh_item_info["meshes"])						
		var material_set_id_array:PackedInt32Array
		material_set_id_array.resize(mesh_id_array.size())
		var material_set_id = int(mesh_item_name.split("_")[-1])
		material_set_id_array.fill(material_set_id) ## TODO - replace with code that gets the right material
		if mesh_item_info["state"] == AssetIOData.IMPORT_STATE.NEW:			
			var mid = asset_library.mesh_item_add(mesh_id_array,material_set_id_array)
			asset_data.update_mesh_items_id(mesh_item_name,mid)			
		elif mesh_item_info["state"] == AssetIOData.IMPORT_STATE.CHANGE:
			if mesh_item_info["id"] == -1:
				push_error("something bad happened mesh id should not be -1")
				continue
			asset_library.mesh_item_update(mesh_item_info["id"],mesh_id_array,material_set_id_array)
		
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
		import_collection(collection_name)
	########################
	## Adding Import Info ##
	########################
	asset_library.import_info[asset_data.glb_path] = asset_data.get_glb_import_info()	
	if not "__blend_files" in asset_library.import_info:
		asset_library.import_info["__blend_files"] = {}
	asset_library.import_info["__blend_files"][asset_data.blend_file] = asset_data.glb_path
	asset_library.finish_import.emit(asset_data.glb_path)
	asset_library.save()	
	
static func fill_mesh_lod_gaps(mesh_array):		
	var result = mesh_array.duplicate()
	var last_mesh = null
	for i in len(mesh_array):						
		if mesh_array[i] == -1 and last_mesh != null and i != len(mesh_array)-1:						
			result[i] = last_mesh
		else:			
			last_mesh = mesh_array[i]	
	return result		

static func import_collection(glb_node_name:String):		
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
				import_collection(sub_collection_name)			
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

static func collection_parse_name(name:String)->String:
	if name.right(3).is_valid_int():  #remove the .001 suffix
		return name.left(len(name)-4)
	return name
#endregion

#region THUMBNAILS
static func generate_material_thumbnails(material_ids):	
	for id in material_ids:
		generate_material_thumbnail(id)

static func generate_material_thumbnail(material_id):			
	if not AssetIO.get_material_table().has(material_id):
		push_error("trying to generate thumbnail for material id that does not exist:", material_id)
		return null
	var path = get_material_table()[material_id]
	var thumbnail_path = get_thumbnail_path(material_id, false)	
	if FileAccess.file_exists(thumbnail_path) and FileAccess.file_exists(path) and FileAccess.get_modified_time(path) < FileAccess.get_modified_time( thumbnail_path ):							
		return		
	var material = load(path)
	EditorInterface.get_resource_previewer().queue_edited_resource_preview(material, AssetIO, "material_thumbnail_generated", material_id)						

static func generate_collection_thumbnails(collection_ids):	
	for id in collection_ids:
		generate_collection_thumbnail(id)	

static func generate_collection_thumbnail(collection_id):	
	if not MAssetTable.get_singleton().has_collection(collection_id):
		push_error("trying to generate thumbnail for collection that does not exist:", collection_id)
		return
	#Check if glb has changed since last thumbnail generation					
	var glb_path = get_glb_path_from_collection_id(collection_id)	
	var thumbnail_path = get_thumbnail_path(collection_id)	
	if thumbnail_path and glb_path and FileAccess.file_exists(thumbnail_path) and FileAccess.file_exists(glb_path) and FileAccess.get_modified_time(glb_path) < FileAccess.get_modified_time( thumbnail_path):				
		return
	var data = {"meshes":[], "transforms":[]}
	combine_collection_meshes_and_transforms_recursive(collection_id, data, Transform3D.IDENTITY)													
	var mesh_joiner := MMeshJoiner.new()					
	mesh_joiner.insert_mesh_data(data.meshes, data.transforms, data.transforms.map(func(a):return -1))
	var mesh = mesh_joiner.join_meshes()			
	EditorInterface.get_resource_previewer().queue_edited_resource_preview(mesh, AssetIO, "collection_thumbnail_generated", collection_id)							
	
static func get_glb_path_from_collection_id(collection_id):
	var import_info = MAssetTable.get_singleton().import_info
	for glb_path in import_info.keys():
		if glb_path.begins_with("__"): continue
		for node_name in import_info[glb_path].keys():
			if node_name.begins_with("__"): continue
			if import_info[glb_path][node_name].has("id") and import_info[glb_path][node_name].id == collection_id:
				return glb_path
				
static func combine_collection_meshes_and_transforms_recursive(collection_id, data, combined_transform):
	var asset_library = MAssetTable.get_singleton()
	var subcollection_ids = asset_library.collection_get_sub_collections(collection_id)
	var subcollection_transforms = asset_library.collection_get_sub_collections_transforms(collection_id)
	if len(subcollection_ids) > 0:
		for i in len(subcollection_ids):
			combine_collection_meshes_and_transforms_recursive(subcollection_ids[i], data, combined_transform * subcollection_transforms[i])
	var mesh_items = asset_library.collection_get_mesh_items_info(collection_id)	
	for item in mesh_items:
		var i = 0
		while i < len(item.mesh):			
			if item.mesh[i] == -1: 
				i += 1
				continue
			var mesh_path = MHlod.get_mesh_path(item.mesh[i])													
			var mmesh:MMesh = load(mesh_path)						
			if mmesh.get_surface_count() > 0:		
				data.meshes.push_back(mmesh.get_mesh())
				data.transforms.push_back(combined_transform * item.transform)
				break	
			i+= 1

static func material_thumbnail_generated(path, preview, thumbnail_preview, material_id):	
	var thumbnail_path = AssetIO.get_thumbnail_path(material_id, false)
	save_thumbnail(preview, thumbnail_path)						
			
static func collection_thumbnail_generated(path, preview, thumbnail_preview, collection_id):	
	var thumbnail_path = AssetIO.get_thumbnail_path(collection_id)
	save_thumbnail(preview, thumbnail_path)						

static func get_thumbnail_path(id: int, is_collection:bool=true):
	if is_collection:
		return "res://massets/thumbnails/" + str(id) + ".dat"
	else:
		return "res://massets/thumbnails/material_" + str(id) + ".dat"

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
	print(mesh_item_ids)
	for mesh_item_id in mesh_item_ids:
		if not asset_library.has_mesh_item(mesh_item_id):
			push_error("trying to remove a mesh item that doesn't exist: ", mesh_item_id)
			continue
		var mesh_array = asset_library.mesh_item_get_info(mesh_item_id).mesh
		asset_library.mesh_item_remove(mesh_item_id)
		
		for mesh_id in mesh_array:
			if len(asset_library.mesh_get_mesh_items_users(mesh_id)) == 0:				
				if FileAccess.file_exists(MHlod.get_mesh_path(mesh_id)):					
					var path = MHlod.get_mesh_path(mesh_id)
					asset_library.erase_mesh_hash(load(path))
					DirAccess.remove_absolute(path)	
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
	var materials = get_material_table()
	if id == -1:
		id = 0		
		while materials.has(id):
			id += 1
	materials[id] = path
	asset_library.import_info["__materials"] = materials
	
static func remove_material(id):
	var asset_library := MAssetTable.get_singleton()	
	var materials = get_material_table()
	if materials.has(id):	
		materials.erase(id)
	asset_library.import_info["__materials"] = materials
	
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
	#
	
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
