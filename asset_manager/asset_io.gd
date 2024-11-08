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
			node.queue_free()
			var path = baker_path.get_basename() + "_joined_mesh.glb"			
			glb_export(parent_node, path)			
			parent_node.queue_free()
			glb_load(path, {}, true)					
			if not path in asset_library.import_info:
				print("no joined mesh path in import info", path)
				continue
			if not name_data.name in asset_library.import_info[path]:
				print("no node name in import info", name_data.name)				
				continue			
			scene.joined_mesh_collection_id = asset_library.import_info[path][name_data.name].id
			asset_library.collection_add_tag(scene.joined_mesh_collection_id, 0)						
		if not node.has_meta("blend_file"):			
			continue
		if not asset_library.import_info["__blend_files"].has(node.get_meta("blend_file")):			
			continue
		var glb_path = asset_library.import_info["__blend_files"][node.get_meta("blend_file")]			
		var node_name := collection_parse_name(node.name)
		if not asset_library.import_info[glb_path].has(node_name):			
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
	scene.update_joined_mesh_limits()
	packed_scene.pack(scene)
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
	asset_data.finalize_glb_parse()
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
		var name_data := node_parse_name(node)		
		var child_count:int = node.get_child_count()
		if name_data["lod"] >=0: ## Then defently is a mesh			
			asset_data.add_mesh_item(name_data["name"],name_data["lod"],node)
			if active_collection == "__root__":
				asset_data.add_mesh_to_collection(name_data["name"],name_data["name"],true)
			else:
				asset_data.add_mesh_to_collection(active_collection,name_data["name"],false)
			if child_count > 0:
				push_error(node.name + " can not have children! ignoring its children! this can be due to naming with _lod of that or it is a mesh!")
		elif name_data["col"] != null:
			var collection_name = name_data.name if active_collection=="__root__" else active_collection
			if node is ImporterMeshInstance3D:
				asset_data.add_collision_to_collection(collection_name, name_data["col"], node.transform, node.mesh.get_mesh())
			else:
				print(collection_name, " is collision imported from ", node.get_parent().name)
				asset_data.add_collision_to_collection(collection_name, name_data["col"], node.transform)				
			if child_count > 0:
				push_error(node.name + " is detected as a collission due to using _col in its name! ignoring its children!")
		elif child_count > 0:
			if active_collection=="__root__":
				generate_asset_data_from_glb(node.get_children(),node.name)
				if node.has_meta("tags"):										
					if asset_data.collections.has(node.name):
						asset_data.collections[node.name].tags = node.get_meta("tags")
			else:
				push_error(node.name," is two deep level which is not allowed")
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

static func glb_import_commit_changes():
	var asset_library = MAssetTable.get_singleton()
	######################
	## Commit Mesh Item ##
	######################
	# mesh_item must be processed before collection, because collection depeneds on mesh item
	var mesh_names = asset_data.mesh_items.keys()
	for mesh_name in mesh_names:
		var mesh_info = asset_data.mesh_items[mesh_name]
		if mesh_info["ignore"] or mesh_info["state"] == AssetIOData.IMPORT_STATE.NO_CHANGE:
			continue
		### Handling Remove First
		if mesh_info["state"] == AssetIOData.IMPORT_STATE.REMOVE:
			asset_library.mesh_item_remove(mesh_info["id"])
			continue
		### Other State
		asset_data.save_unsaved_meshes(mesh_name) ## now all mesh are saved with and integer ID
		var meshes = fill_mesh_lod_gaps(mesh_info["meshes"])
		
		var materials:PackedInt32Array
		## for now later we change
		materials.resize(meshes.size())
		materials.fill(-1)
		if mesh_info["state"] == AssetIOData.IMPORT_STATE.NEW:			
			var mid = asset_library.mesh_item_add(meshes,materials)
			asset_data.update_mesh_items_id(mesh_name,mid)			
		elif mesh_info["state"] == AssetIOData.IMPORT_STATE.CHANGE:
			if mesh_info["id"] == -1:
				push_error("something bad happened mesh id should not be -1")
				continue
			asset_library.mesh_item_update(mesh_info["id"],meshes,materials)
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
	MAssetTable.save()
	
static func fill_mesh_lod_gaps(mesh_array):
	var result = mesh_array.duplicate()
	var last_mesh = null
	for i in len(mesh_array):		
		if mesh_array[i] == -1 and last_mesh != null:
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
		
static func mesh_item_update_from_collection_dictionary(collection):
	var asset_library := MAssetTable.get_singleton()			
	if "original_meshes" in collection.keys():		
		for mesh in collection.original_meshes:
			if not mesh in collection.meshes:
				#first check if anyone else is still using this mesh:
				#if len(asset_library.mesh_get_mesh_items(collection.original_meshes[i])) == 1:				
					print("erased mesh resource ", asset_library.mesh_get_path(mesh))
					DirAccess.remove_absolute(asset_library.mesh_get_path(mesh))						
		
	var mesh_item_array = []
	for i in len(collection.meshes):				
		if collection.meshes[i].get_surface_count() == 0: 
			mesh_item_array.push_back(-1)
			continue
		var new_id = asset_library.mesh_get_id(collection.meshes[i])
		print("processing mesh id:", new_id)
		if new_id == -1:			
			var mesh_save_path = asset_library.mesh_get_path(collection.meshes[i])
			print("saving mesh to ", mesh_save_path)
			if FileAccess.file_exists(mesh_save_path):
				collection.meshes[i].take_over_path(mesh_save_path)				
			else:
				ResourceSaver.save(collection.meshes[i], mesh_save_path)		
		mesh_item_array.push_back(new_id)
	#Add Mesh Item
	var material_ids = mesh_item_array.map(func(a): return -1)				
	print("adding mesh item with meshes: ", mesh_item_array)
	asset_library.mesh_item_update(collection.mesh_item_id, mesh_item_array, material_ids)							

static func glb_show_import_window(asset_data:AssetIOData):
	var popup = Window.new()
	popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	popup.wrap_controls = true
	EditorInterface.get_editor_main_screen().add_child(popup)
	var panel = preload("res://addons/m_terrain/asset_manager/ui/import_window.tscn").instantiate()
	panel.asset_data = asset_data
	popup.add_child(panel)
	popup.popup_centered(Vector2i(800,600))	
#endregion
#region Mesh Item
static func mesh_item_get_mesh_resources(mesh_id): #return meshes[.res]
	var asset_library = MAssetTable.get_singleton()
	if asset_library.has_mesh_item(mesh_id):
		var meshes = []
		var data = asset_library.mesh_item_get_info(mesh_id)
		for mesh_resource_id in data.mesh:
			var path = MHlod.get_mesh_path(mesh_resource_id)
			if FileAccess.file_exists(path):
				meshes.push_back(load(path))
			else:
				meshes.push_back(null)
		return meshes

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
