@tool
class_name AssetIO extends Object

static var LOD_COUNT = 10  # The number of different LODs in your project

static var regex_mesh_match := RegEx.create_from_string("(.*)[_|\\s]lod[_|\\s]?(\\d+)")
static var regex_col_match:= RegEx.create_from_string("(.*)?[_|\\s]?(col|collision)[_|\\s](box|sphere|capsule|cylinder|concave|mesh).*")
static var blender_end_number_regex = RegEx.create_from_string("(.*)(\\.\\d+)")
static var material_regex = RegEx.create_from_string("(.*)[_ ]set[_ ]?(\\d+)$")
static var asset_data:AssetIOData = null
static var DEBUG_MODE = true #true

static var obj_to_call_on_table_update:Array

#region GLB Import	
static func glb_load(path, metadata={},no_window:bool=false):
	MAssetTable.update_last_free_mesh_id() # Important to get currect new free mesh id	
	var gltf_document = GLTFDocument.new()
	if not Engine.is_editor_hint():
		GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	var gltf_state = GLTFState.new()
	gltf_document.append_from_file(path,gltf_state)
	
	var root_name = gltf_state.get_nodes()[gltf_state.root_nodes[0]].original_name
	if "_hlod" in root_name.to_lower() or "_baker" in root_name.to_lower():
		print("processing baker import begin")		
		var original_root = gltf_document.generate_scene(gltf_state)
		var baker_node = original_root.get_child(0)					
		baker_node.owner = null
		original_root.remove_child(baker_node)
		original_root.queue_free()
		AssetIOBaker.baker_import_from_glb(path, baker_node)		
	else:
		var scene_root = gltf_document.generate_scene(gltf_state)	
		glb_load_assets(gltf_state, scene_root, path, metadata,no_window)
			
static func glb_load_assets(gltf_state, scene_root, path, metadata={},no_window:bool=false):	
	var asset_library:MAssetTable = MAssetTable.get_singleton()
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
	
	var scene = scene_root.get_children() if not scene_root is ImporterMeshInstance3D else [scene_root]
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
		#######################
		## PROCESS MESH NODE ##
		#######################
		if name_data["lod"] >=0: ## Then definitly is a mesh					
			if not node.has_meta("material_sets"):
				var mesh_item_name = name_data["name"]
				var mesh:ArrayMesh = null
				if node is ImporterMeshInstance3D:
					mesh = node.mesh.get_mesh()
				else:
					# possible stop lod
					asset_data.add_possible_stop_lod(mesh_item_name,name_data["lod"])
					continue
				if mesh==null:
					printerr(node.name," mesh is null")
					continue
				var surface_names:PackedStringArray
				for i in range(mesh.get_surface_count()):
					surface_names.push_back(mesh.surface_get_name(i))
				var material_set:= get_material_sets_from_surface_names(surface_names) # surface name also be modified
				for i in range(mesh.get_surface_count()):
					mesh.surface_set_name(i,surface_names[i])
				var mmesh:=MMesh.new()
				mmesh.create_from_mesh(mesh)
				mmesh.material_set_resize(material_set.size())
				asset_data.add_mesh_data(material_set,mmesh, mesh_item_name)
				asset_data.update_collection_mesh(mesh_item_name,name_data["lod"],mmesh)
				# if we are not on root then we add ourself as sub collection to whatever active_collection is
				if not active_collection == "__root__":
					asset_data.add_sub_collection(active_collection,mesh_item_name,node.transform)
			else:
				var mmesh = MMesh.new()
				mmesh.create_from_mesh( node.mesh.get_mesh() )
				var material_sets = node.get_meta("material_sets")				
				mmesh.material_set_resize(len(material_sets))
				for set_id in len(material_sets):
					var mesh_item_name = name_data["name"] + str("_", set_id)									
					asset_data.add_mesh_data(material_sets, mmesh, mesh_item_name)
					asset_data.update_collection_mesh(mesh_item_name,name_data.lod,mmesh)
					var collection_name = mesh_item_name if active_collection == "__root__" else active_collection
					if not active_collection == "__root__":
						asset_data.add_sub_collection(active_collection,mesh_item_name,node.transform)
					#asset_data.add_mesh_item_to_collection(collection_name, mesh_item_name, active_collection == "__root__")
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
	var saved_successful = asset_data.save_meshes() # will add mesh_item_id if is new
	if not saved_successful == OK:
		push_error("GLB import cannot import meshes: mesh could not be saved to file \n", str(asset_data.glb_path))
		return
	######################
	## Commit Mesh Item ##
	######################
	# mesh_item must be processed before collection, because collection depeneds on mesh item
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
	EditorInterface.get_resource_filesystem().scan()
	notify_asset_table_update()
	MAssetMesh.refresh_all_masset_nodes()

static func notify_asset_table_update():
	for obj in obj_to_call_on_table_update:
		if is_instance_valid(obj):
			obj.call("asset_table_update")

static func import_collection(glb_node_name:String,glb_id:int,func_depth:=0):
	if func_depth > 1000:
		printerr("It seems you have a nested collection which does not end well!")
		return
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
	var collection_id := -1
	if collection_info["state"] == AssetIOData.IMPORT_STATE.NEW:
		collection_id = asset_library.collection_create(glb_node_name)
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
	asset_library.collection_set_glb_id(collection_id,glb_id)
	asset_library.collection_set_mesh_id(collection_id,collection_info["mesh_id"])
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
				import_collection(sub_collection_name,glb_id,func_depth+1)
				sub_collection_id = asset_data.get_collection_id(sub_collection_name)
				if sub_collection_id == -1:
					printerr("Can't import")
					return
			#get sub_collection_id after import_collection for subcollection
			sub_collection_id = asset_data.get_collection_id(sub_collection_name)
			if not asset_library.has_collection(sub_collection_id):
				push_error("trying to add subcollection to collection, but sub_collection_id ", sub_collection_id, " does not exist")
			asset_library.collection_add_sub_collection(collection_id, sub_collection_id,sub_collections[sub_collection_name])

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

static func blender_end_number_remove(input:String)->String:
	var res = blender_end_number_regex.search(input)
	if not res:
		return input
	return res.strings[1]

static func get_material_sets_from_surface_names(surface_names:PackedStringArray)->Array:
	var surfaces_sets_count:PackedInt32Array
	surfaces_sets_count.resize(surface_names.size())
	surfaces_sets_count.fill(1)
	var max_set = 1
	for s in range(surface_names.size()):
		if surface_names[s].is_empty():
			surface_names[s] = "Unnamed"
		else:
			surface_names[s] = blender_end_number_remove(surface_names[s])
		var reg_res = material_regex.search(surface_names[s])
		if reg_res:
			surface_names[s] = reg_res.strings[1]
			surfaces_sets_count[s] = max(int(reg_res.strings[2]),1)
			if surfaces_sets_count[s] > max_set: max_set = surfaces_sets_count[s]
	var material_sets:=[]
	for i in range(max_set):
		var ext_name:String
		if i!=0: ext_name = "_" + str(i)
		var _mm:PackedStringArray
		for s in range(surface_names.size()):
			_mm.push_back(surface_names[s]+ext_name)
		material_sets.push_back(_mm)
	return material_sets

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

static func get_material_id(mat:Material)->int:
	if not mat: return -1
	var path = mat.resource_path
	if path.is_empty(): return -1
	var at = MAssetTable.get_singleton()
	if not at: return -1
	var materials = at.import_info["__materials"]
	for id in materials:
		if materials[id]["path"] == path:
			return id
	return -1

static func get_material(id:int)->Material:
	var at = MAssetTable.get_singleton()
	if not at: return null
	var materials = at.import_info["__materials"]
	if materials.has(id):
		var path = materials[id]["path"]
		if ResourceLoader.exists(path):
			var mat = load(path)
			if mat is Material:
				return mat
	return null

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

static func get_asset_blend_file(collection_id):
	var import_info = MAssetTable.get_singleton().import_info	
	if not import_info.has("__blend_files") or len(import_info["__blend_files"]) == 0: return null
	for glb_path in import_info.keys():
		if glb_path.begins_with("__"): continue
		for glb_node_name in import_info[glb_path]:
			if import_info[glb_path][glb_node_name].has("collection_id") and import_info[glb_path][glb_node_name]["collection_id"] == collection_id:
				for blend_file in import_info["__blend_files"]:
					if import_info["__blend_files"][blend_file] == glb_path:						
						return blend_file
				
