@tool
class_name AssetIO extends Object

static var LOD_COUNT = 10  # The number of different LODs in your project

static var regex_mesh_match := RegEx.create_from_string("(.*)[_|\\s]lod[_|\\s]?(\\d+)")
static var regex_col_match:= RegEx.create_from_string("((.*)[_|\\s])?(col|collision)[_|\\s](box|sphere|capsule|cylinder|concave|convex).*")
static var regex_option_match:= RegEx.create_from_string("((.*)_)?(physics|meshcutoff|collisioncutoff|colcutoff)_(.*)")
static var blender_end_number_regex = RegEx.create_from_string("(.*)(\\.\\d+)")
static var asset_data:AssetIOData = null
static var DEBUG_MODE = true #true
static var EXPERIMENTAL_FEATURES_ENABLED = false

static var obj_to_call_on_table_update:Array
static var asset_placer:Control

const filter_settings_path = "res://addons/m_terrain/asset_manager/ui/current_filter_settings.res"

#region GLB Import	
static func glb_load(path, metadata={},no_window:bool=false):
	MAssetTable.update_last_free_mesh_id() # Important to get currect new free mesh id	
	var gltf_document = GLTFDocument.new()
	if not Engine.is_editor_hint():
		GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	var gltf_state = GLTFState.new()
	gltf_document.append_from_file(path,gltf_state)
	
	var root_name = gltf_state.get_nodes()[gltf_state.root_nodes[0]].original_name
	if root_name.containsn("_hlod") or root_name.containsn("_baker"):
		print("processing baker import begin")		
		var original_root = gltf_document.generate_scene(gltf_state)
		var baker_node = original_root.get_child(0)					
		baker_node.owner = null
		original_root.remove_child(baker_node)
		original_root.queue_free()
		AssetIOBaker.baker_import_from_glb(path, baker_node)		
	else:
		var scene_root = gltf_document.generate_scene(gltf_state)	
		if gltf_state.json.scenes[0].has("extras"):
			if gltf_state.json.scenes[0].extras.has("blend_file"):
				scene_root.set_meta("blend_file", gltf_state.json.scenes[0].extras.blend_file)	
			if gltf_state.json.scenes[0].extras.has("variation_groups"):
				scene_root.set_meta("variation_groups", gltf_state.json.scenes[0].extras.variation_groups)
		glb_load_assets(scene_root, path, metadata,no_window)
			
static func glb_load_assets(scene_root, path:String, metadata={},no_window:bool=false):	
	if path.ends_with("joined_mesh.glb"):
		MTool.print_edmsg("It seems that you want to import a join-mesh this way! you should import join mesh in bake inspector! if this is not a join-mesh please change the file name!")
		return
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	
	#STEP 1: Init Asset Data
	asset_data = AssetIOData.new()						
	asset_data.glb_path = path
	asset_data.meta_data = metadata	
	
	var scene: Array # children of the glb root node
	if scene_root:		
		scene = scene_root.get_children() if not scene_root is ImporterMeshInstance3D else [scene_root]		
		if scene_root.has_meta("blend_file"):
			asset_data.blend_file = scene_root.get_meta("blend_file")
		if scene_root.has_meta("variation_groups"):
			asset_data.variation_groups = scene_root.get_meta("variation_groups")
	else:
		scene = []
	#STEP 2: convert gltf scene into AssetData format	
	generate_asset_data_from_glb(scene)
	asset_data.finalize_glb_parse() ## should not go after add_glb_import_info
	#STEP 3: add data from last import for comparisons
	if asset_library.import_info.has(path):
		asset_data.add_glb_import_info(asset_library.import_info[path])
	asset_data.generate_import_tags()
	if scene_root:
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
		var option_data := node_parse_option(node)
		if option_data.size()!=0:
			var c_name:String= option_data["name"]
			if c_name.is_empty() and active_collection!="__root__": c_name = active_collection
			if c_name.is_empty():
				push_error("Option (%s , %s) has a empty name "% [option_data["option"],option_data["value"]])
				continue
			asset_data.add_option(c_name,option_data["option"],option_data["value"])
			continue
		var name_data := node_parse_name(node)
		var child_count:int = node.get_child_count()
		#######################
		## PROCESS MESH NODE ##
		#######################
		if name_data["lod"] >=0: ## Then definitly is a mesh					
			#MAKE MATERIAL SET FROM META
			if node.has_meta("material_sets"):
				var mesh: ArrayMesh = node.mesh.get_mesh()												
				var mmesh = MMesh.new()
				mmesh.create_from_mesh( mesh )
				var material_sets = node.get_meta("material_sets")				
				mmesh.material_set_resize(len(material_sets[0]))
				var mesh_item_name = name_data["name"]							
				asset_data.add_mesh_data(material_sets, mmesh, node)
				asset_data.update_collection_mesh(mesh_item_name,name_data.lod,mmesh)
				var collection_name = mesh_item_name if active_collection == "__root__" else active_collection
				if not active_collection == "__root__":					
					if active_collection != mesh_item_name:
						asset_data.add_sub_collection(active_collection,mesh_item_name,node.transform)
			#MAKE MATERIAL SET NAMING CONVENTION
			else: 
				var mesh_item_name = name_data["name"]
				var mesh:ArrayMesh = null
				if node is ImporterMeshInstance3D: mesh = node.mesh.get_mesh()
				else: continue
				if mesh==null:
					printerr(node.name," mesh is null")
					continue
				var surface_names:PackedStringArray
				for i in mesh.get_surface_count():
					surface_names.push_back(mesh.surface_get_name(i))
				var material_set:= AssetIOMaterials.get_material_sets_from_surface_names(surface_names) # surface name also be modified
				for i in mesh.get_surface_count():
					mesh.surface_set_name(i,surface_names[i])
				var mmesh:=MMesh.new()
				mmesh.create_from_mesh(mesh)
				mmesh.material_set_resize(material_set.size())
				asset_data.add_mesh_data(material_set,mmesh, node)
				asset_data.update_collection_mesh(mesh_item_name,name_data["lod"],mmesh)
				# if we are not on root then we add ourself as sub collection to whatever active_collection is
				if not active_collection == "__root__":					
					if active_collection != mesh_item_name:
						asset_data.add_sub_collection(active_collection,mesh_item_name,node.transform)				
			if child_count > 0:
				push_error(node.name + " can not have children! ignoring its children! this can be due to naming with _lod of that or it is a mesh!")									
		############################
		## PROCESS COLLISION NODE ##
		############################
		elif name_data["col"] != MAssetTable.CollisionType.UNDEF or name_data["convex"] or name_data["concave"]:
			var collection_name:String
			if name_data.name.is_empty() and active_collection!="__root__":
				collection_name = active_collection
			elif not name_data.name.is_empty():
				collection_name = name_data.name
			else:
				print("GLB name %s Found collision with empty name, this is only allowed in collections with sub_collections"%node.name)
				continue
			if name_data["col"] != MAssetTable.CollisionType.UNDEF:
				asset_data.add_collision_to_collection(collection_name,name_data["col"],node.transform)
			else:
				asset_data.add_collision_none_simple(collection_name,"convex",name_data["convex"])
				asset_data.add_collision_none_simple(collection_name,"concave",name_data["concave"])
			if child_count > 0:
				push_error(node.name + " is detected as a collission due to using _col in its name! ignoring its children!")
		#############################
		## PROCESS COLLECTION NODE ##
		#############################
		elif child_count > 0:
			if active_collection=="__root__":
				asset_data.add_master_collection(node.name,node.transform)
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
					var blend_file_dictionary = get_all_collections_blend_file_path()
					if blend_file_dictionary.has(blend_file):
						var glb_path = blend_file_dictionary[blend_file]
						subcollection_name += "::" + glb_path					
					else:
						print("error with subcollection from different blend file. Here is the list of blend files in import_info:\n", blend_file_dictionary.keys())
			asset_data.add_sub_collection(active_collection,subcollection_name,node.transform)	
		
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
	###############################
	## FIX JOINED MESH MATERIALS ##
	###############################
	if asset_data.glb_path.ends_with("joined_mesh.glb"):
		print("fixing joined mesh materials")
		for glb_material_name in asset_data.materials:
			asset_data.materials[glb_material_name] = AssetIOMaterials.find_material_by_name(glb_material_name)	
	#################
	## Save Meshes ##
	#################	
	var saved_successful = asset_data.save_meshes() # will add mesh_item_id if is new
	if not saved_successful == OK:
		push_error("GLB import cannot import meshes: mesh could not be saved to file \n", str(asset_data.glb_path))
		return
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
	asset_library.import_info[asset_data.glb_path]["__variation_groups"] = asset_data.variation_groups
	
	#check if this glb was previously removed and erase "removed tag" if reimport has collections
	if len(asset_data.collections) > 0 and asset_library.import_info.has(asset_data.glb_path) and asset_library.import_info[asset_data.glb_path].has("__removed"): 
		asset_library.import_info[asset_data.glb_path].erase("__removed")
	
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
	if glb_node_name and not asset_data.collections.has(glb_node_name) or asset_data.collections[glb_node_name]["ignore"]:
		return
	#asset_data.collections[glb_node_name]["ignore"] = true # this means this collection has been handled
	var asset_library := MAssetTable.get_singleton()
	var collection_info: Dictionary = asset_data.collections[glb_node_name]	
	if collection_info["state"] == AssetIOData.IMPORT_STATE.REMOVE:
		if collection_info["id"] == -1:
			push_error("Invalid collection to remove")
			return
		asset_library.collection_remove(collection_info["id"])
		return
	var collection_id := -1
	if collection_info["state"] == AssetIOData.IMPORT_STATE.NEW:
		collection_id = asset_library.collection_create(glb_node_name,collection_info["mesh_id"],MAssetTable.MESH,glb_id)
		asset_data.update_collection_id(glb_node_name, collection_id)
	# should also handle even if no change for adjusting collissions
	elif collection_info["id"] != -1:
		collection_id = collection_info["id"]
		if not asset_library.has_collection(collection_id):
			push_error("import collection error: trying to change existing collection, but ", collection_id, " does not exist")
		asset_library.collection_clear_sub_and_col(collection_id)
		if asset_library.collection_get_name(collection_id) != glb_node_name:
			printerr("Mismatch glb_node name in update")
		if asset_library.collection_get_item_id(collection_id) != collection_info["mesh_id"]:
			printerr("Mismatch mesh id in update")
		if asset_library.collection_get_glb_id(collection_id) != glb_id:
			printerr("Mismatch glb id in update")
	else:
		push_error("Invalid collection!!!")
		return
	if not asset_library.has_collection(collection_id):
		push_error("import collection error: ", collection_id, " does not exist")
	asset_library.collection_update_modify_time(collection_id)
	## Options
	var physics_setting_name = asset_data.get_option(glb_node_name,"physics")
	if not physics_setting_name.is_empty():
		asset_library.collection_set_physics_setting(collection_id,physics_setting_name)
	var colcutoff = asset_data.get_option(glb_node_name,"colcutoff")
	if not colcutoff.is_empty():
		asset_library.collection_set_colcutoff(collection_id,colcutoff.to_int())
	## Collissions
	for c in collection_info["collisions"]:
		asset_library.collection_add_collision(collection_id,c["type"],c["transform"],collection_info["base_transform"])
	## sub collections
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
			for sub_collection_transform in sub_collections[sub_collection_name]:
				if not asset_library.has_collection(sub_collection_id):
					push_error("trying to add subcollection to collection, but sub_collection_id ", sub_collection_id, " does not exist")
				asset_library.collection_add_sub_collection(collection_id, sub_collection_id, sub_collection_transform)									
	## ADD TAGS
	if collection_id != -1:		
		if asset_data.tags.mode == 0:
			for tag in asset_data.tags.current_tags:
				asset_library.collection_add_tag(collection_id, tag)
		else:
			for old_tag_id in asset_library.collection_get_tags(collection_id):
				if not old_tag_id in asset_data.tags.current_tags:
					asset_library.collection_remove_tag(collection_id, old_tag_id)
			for tag_id in asset_data.tags.current_tags:
				asset_library.collection_add_tag(collection_id, tag_id)
				
static func glb_show_import_window(asset_data:AssetIOData):
	var popup = Window.new()
	popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	popup.wrap_controls = true
	EditorInterface.get_editor_main_screen().add_child(popup)
	var panel = preload("res://addons/m_terrain/asset_manager/ui/import_window.tscn").instantiate()
	panel.asset_data = asset_data
	popup.add_child(panel)
	popup.popup_centered(Vector2i(800,600))	

static func node_parse_option(node:Node)->Dictionary:
	var result:Dictionary # 0 is option name and 1 is option value
	var search_result = regex_option_match.search(node.name)
	if search_result:
		result["name"] = search_result.strings[2]
		result["option"] = search_result.strings[3]
		result["value"] = search_result.strings[4]
	return result

static func node_parse_name(node:Node)->Dictionary:
	var result = {"name":"","lod":-1,"col":MAssetTable.CollisionType.UNDEF,"convex":false,"concave":false}
	var lod:int = -1	
	var search_result = regex_mesh_match.search(node.name)
	if search_result:		
		result["name"] = search_result.strings[1]
		result["lod"] = search_result.strings[2].to_int()
		return result
	search_result = regex_col_match.search(node.name)
	if search_result:			
		result["name"] = search_result.strings[2]
		match(search_result.strings[4]):
			"box": result["col"] = MAssetTable.CollisionType.BOX
			"sphere": result["col"] = MAssetTable.CollisionType.SHPERE
			"cylinder": result["col"] = MAssetTable.CollisionType.CYLINDER
			"capsule": result["col"] = MAssetTable.CollisionType.CAPSULE
			"convex":
				if node is ImporterMeshInstance3D and node.mesh.get_mesh(): result["convex"] = node.mesh.get_mesh()
				else: result["convex"] = true
			"concave":
				if node is ImporterMeshInstance3D and node.mesh.get_mesh(): result["concave"] = node.mesh.get_mesh()
				else: result["concave"] = true
	elif node is ImporterMeshInstance3D:
		result["name"] = String(node.name)
		result["lod"] = 0
	return result

static func blender_end_number_remove(input:String)->String:
	var res = blender_end_number_regex.search(input)
	if not res:
		return input
	return res.strings[1]

static func collection_parse_name(node)->String:	
	var material_suffix = ""
	#if node.has_meta("active_material_set_id"):
	#	material_suffix = str("_", node.get_meta("active_material_set_id"))
	var suffix_length = len(node.name.split("_")[-1])
	if node.name.right(suffix_length).is_valid_int():  #remove the .001 suffix
		return node.name.left(len(node.name)-suffix_length-1) + material_suffix
	return node.name + material_suffix
#endregion

static func get_glb_path_from_collection_id(collection_id)->String:
	var glb_id:int = MAssetTable.get_singleton().collection_get_glb_id(collection_id)
	var import_info:Dictionary = MAssetTable.get_singleton().import_info.duplicate()
	MAssetTable.get_singleton().clear_import_info_cache()
	for k in import_info:
		if k.begins_with("__"): continue
		if import_info[k]["__id"] == glb_id: return k
	return ""
	
static func get_blend_path_from_collection_id(collection_id)->String:
	var glb_id:int = MAssetTable.get_singleton().collection_get_glb_id(collection_id)
	return get_blend_path_from_glb_id(glb_id)

static func get_blend_path_from_glb_id(glb_id)->String:	
	var import_info:Dictionary = MAssetTable.get_singleton().import_info.duplicate()
	MAssetTable.get_singleton().clear_import_info_cache()
	for k in import_info:
		if k.begins_with("__"): continue
		if import_info[k]["__id"] == glb_id:
			if import_info[k].has("__original_blend_file"):
				return import_info[k]["__original_blend_file"]
	return ""

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
	print(result)
	return result
				
static func import_settings(path):
	var asset_library = MAssetTable.get_singleton()
	var data = JSON.parse_string( FileAccess.get_file_as_string(path))
	if not asset_library.import_info.has("__materials"):
		asset_library.import_info["__materials"] = {}
	for material in data.materials:
		asset_library.import_info["__materials"][int(material)] = data.materials[material]		
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

static func get_all_collections_blend_file_path(): # {blend_file_path: glb_path}
	var import_info = MAssetTable.get_singleton().import_info
	var result = {}
	for glb_path in import_info.keys():
		if glb_path.begins_with("__"): continue
		if "__original_blend_file" in import_info[glb_path]:
			result[ import_info[glb_path]["__original_blend_file"] ] = glb_path
	return result

static func get_asset_glb_name_from_collection_id(collection_id):
	var import_info := MAssetTable.get_singleton().import_info	
	for glb_path in import_info.keys():
		if glb_path.begins_with("__"): continue
		for glb_name in import_info[glb_path].keys():
			if glb_name.begins_with("__"): continue
			if not import_info[glb_path][glb_name].has("id"): continue
			if import_info[glb_path][glb_name].id == collection_id:
				return glb_name

static func get_collection_id_from_blend_file_and_glb_name(blend_file, glb_name):
	var import_info := MAssetTable.get_singleton().import_info	
	for glb_path in import_info.keys():
		if glb_path.begins_with("__"): continue
		if not "__original_blend_file" in import_info[glb_path]:continue
		if not import_info[glb_path]["__original_blend_file"] == blend_file: continue
		if not import_info[glb_path].has(glb_name): continue
		if not import_info[glb_path][glb_name].has("id"): continue
		return import_info[glb_path][glb_name].id


static func show_in_file_system(collection_id:int)->void:
	var type = MAssetTable.get_singleton().collection_get_type(collection_id)
	var item_id:int= MAssetTable.get_singleton().collection_get_item_id(collection_id)
	var path:String
	match type:
		MAssetTable.MESH:
			item_id = MAssetTable.mesh_item_get_first_valid_id(item_id)
			if item_id==-1:
				MTool.print_edmsg("Not valid mesh in collection "+str(collection_id))
				return
			path = MHlod.get_mesh_path(item_id)
		MAssetTable.PACKEDSCENE: path = MHlod.get_packed_scene_path(item_id)
		MAssetTable.DECAL: path = MHlod.get_decal_path(item_id)
		MAssetTable.HLOD: path = MHlod.get_hlod_path(item_id)
	EditorInterface.get_file_system_dock().navigate_to_path(path)
	
static func show_gltf(collection_id:int):
	var at:=MAssetTable.get_singleton()
	var type = at.collection_get_type(collection_id)
	if type!=MAssetTable.ItemType.MESH:
		printerr("Type MESH is not valid")
		return
	var glb_id = at.collection_get_glb_id(collection_id)
	var import_info = at.import_info
	var gpath:String
	for path:String in import_info:
		if path.begins_with("__"): continue
		if import_info[path]["__id"] == glb_id:
			gpath = path
			break
	at.clear_import_info_cache()
	if not gpath.is_empty():
		EditorInterface.get_file_system_dock().navigate_to_path(gpath)
	
static func remove_collection(collection_id:int,only_hlod=false, skip_confirmation = false)->void:
	var at:=MAssetTable.get_singleton()
	var type = at.collection_get_type(collection_id)
	var item_id:int= at.collection_get_item_id(collection_id)
	var cname = at.collection_get_name(collection_id)
	var removing_files:PackedStringArray
	match type:
		MAssetTable.MESH:
			removing_files.push_back(MHlod.get_mesh_path(item_id))
		MAssetTable.PACKEDSCENE:
			removing_files.push_back(MHlod.get_packed_scene_path(item_id))
		MAssetTable.DECAL:
			removing_files.push_back(MHlod.get_decal_path(item_id))
		MAssetTable.HLOD:
			removing_files.push_back(MHlod.get_hlod_path(item_id))
			if not only_hlod and FileAccess.file_exists(MHlod.get_hlod_path(item_id)):
				var hlod:MHlod= load(MHlod.get_hlod_path(item_id))
				removing_files.push_back(hlod.baker_path)				
 	
	if not skip_confirmation:
		var confirm_box := ConfirmationDialog.new();
		confirm_box.canceled.connect(confirm_box.queue_free)
		confirm_box.initial_position=Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
		confirm_box.dialog_text = "Removing collection \"%s\" These files will be removed:\n" % cname
		for f in removing_files:
			confirm_box.dialog_text += f +"\n"
		confirm_box.visible = true
		EditorInterface.popup_dialog( confirm_box )
		confirm_box.confirmed.connect(remove_collection_confirmed.bind(removing_files, collection_id))
	else:
		remove_collection_confirmed(removing_files, collection_id)

static func remove_collection_confirmed(removing_files, collection_id):
	var at:=MAssetTable.get_singleton()
	for f in removing_files:
		if FileAccess.file_exists(f):
			var res=load(f)
			if res:
				res.resource_path=""
				res.emit_changed()
			DirAccess.remove_absolute(f)
			var __f = FileAccess.open(f.get_basename() + ".stop",FileAccess.WRITE)
			__f.close()
		else:
			MTool.print_edmsg("file not exist to be remove: "+f)
	at.collection_remove(collection_id)
	MAssetTable.save()
	if AssetIO.asset_placer:
		AssetIO.asset_placer.regroup()
	EditorInterface.get_resource_filesystem().scan()



static func modify_in_blender(collection_id:int)->void:
	var blender_path:String= EditorInterface.get_editor_settings().get_setting("filesystem/import/blender/blender_path")
	if blender_path.is_empty():
		MTool.print_edmsg("Blender path is empty! please set blender path in editor setting")
		return
	if not FileAccess.file_exists(blender_path):
		MTool.print_edmsg("Blender path is not valid: "+blender_path)
		return
	var glb_file_path:String = AssetIO.get_glb_path_from_collection_id(collection_id)
	glb_file_path = ProjectSettings.globalize_path(glb_file_path)
	var blend_file_path:String= AssetIO.get_blend_path_from_collection_id(collection_id)
	if blend_file_path.is_empty():
		MTool.print_edmsg("blend_file_path is empty please set blend file path in import window")
		return
	var py_path:="res://addons/m_terrain/asset_manager/blender_addons/open_modify_mesh.py"
	py_path = ProjectSettings.globalize_path(py_path)
	var fpy = FileAccess.open(py_path,FileAccess.READ)
	var py_script = fpy.get_as_text()
	fpy.close()
	## replace
	var obj_name = MAssetTable.get_singleton().collection_get_name(collection_id)
	py_script = py_script.replace("__OBJ_NAME__",obj_name)
	py_script = py_script.replace("_GLB_FILE_PATH",glb_file_path)
	py_script = py_script.replace("_BLEND_FILE_PATH",blend_file_path)
	var tmp_path = "res://addons/m_terrain/tmp/pytmp.py"
	if FileAccess.file_exists(tmp_path):DirAccess.remove_absolute(tmp_path) # good idea to clear to make sure eveyrthing go well
	if not DirAccess.dir_exists_absolute(tmp_path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(tmp_path.get_base_dir())
	var tmpf = FileAccess.open(tmp_path,FileAccess.WRITE)
	if not tmpf:
		MTool.print_edmsg("Can not create tmp file for blender python script")
		return
	tmpf.store_string(py_script)
	tmpf.close()
	## RUN
	tmp_path = ProjectSettings.globalize_path(tmp_path)
	var args:PackedStringArray = ["--python",tmp_path]
	OS.create_process(blender_path,args)
	
static func show_tag(collection_id:int)->void:
	AssetIO.asset_placer.open_settings_window("tag", [collection_id])
	
static func open_packed_scene(collection_id:int)->void:
	var item_id = MAssetTable.get_singleton().collection_get_item_id(collection_id)
	var spath = MHlod.get_packed_scene_path(item_id)
	if FileAccess.file_exists(spath):
		EditorInterface.call_deferred("open_scene_from_path",spath)
	else:
		MTool.print_edmsg("Path not exist: "+spath)


static func validate_collections_and_remove_broken():
	var at = MAssetTable.get_singleton()	
	var collections_to_remove = []
	var processed_item_ids = []
	for collection_id in at.collections_get_by_type(MAssetTable.ItemType.HLOD):
		var id = at.collection_get_item_id(collection_id)
		processed_item_ids.push_back(id)
		if not FileAccess.file_exists( MHlod.get_hlod_path(id) ) or id in processed_item_ids:			
			collections_to_remove.push_back(collection_id)			
	for collection_id in at.collections_get_by_type(MAssetTable.ItemType.PACKEDSCENE):
		var id = at.collection_get_item_id(collection_id)
		if not FileAccess.file_exists( MHlod.get_packed_scene_path(id) ):
			collections_to_remove.push_back(collection_id)
	for collection_id in at.collections_get_by_type(MAssetTable.ItemType.DECAL):
		var id = at.collection_get_item_id(collection_id)
		if not FileAccess.file_exists( MHlod.get_decal_path(id) ):
			collections_to_remove.push_back(collection_id)
	for collection_id in at.collections_get_by_type(MAssetTable.ItemType.MESH):
		var id = at.collection_get_item_id(collection_id)
		if not FileAccess.file_exists( MHlod.get_mesh_path(id) ):
			collections_to_remove.push_back(collection_id)	
	for collection_id in collections_to_remove:
		at.collection_remove(collection_id)
	MAssetTable.save()
	if AssetIO.asset_placer:
		AssetIO.asset_placer.regroup()
	EditorInterface.get_resource_filesystem().scan()
		
static func create_packed_scene():
	var asset_library = MAssetTable.get_singleton()
	var id = MAssetTable.get_last_free_packed_scene_id()	
	var node := MHlodNode3D.new()		
	node.name = "MHlodNode3D_" + str(id)
	var collection_id = asset_library.collection_create(node.name, id, MAssetTable.PACKEDSCENE, -1)
	asset_library.save()
	node.set_meta("collection_id", collection_id)	
	var packed = PackedScene.new()
	packed.pack(node)
	var path = MHlod.get_packed_scene_path(id)
	ResourceSaver.save(packed, path)			
	
	EditorInterface.open_scene_from_path(path)					
	
static func create_decal():
	var asset_library = MAssetTable.get_singleton()
	var id = MAssetTable.get_last_free_decal_id()		
	var decal := MDecal.new()
	decal.resource_name = "New Decal"
	var path = MHlod.get_decal_path(id)		
	#if FileAccess.file_exists(path):	
	ResourceSaver.save(decal, path)	
	decal.take_over_path(path)	
	var collection_id = asset_library.collection_create(decal.resource_name, id, MAssetTable.DECAL, -1)
	asset_library.save()	
	var node := MDecalInstance.new()	
	node.decal = decal
	ResourceSaver.save(decal, path)				
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root==null:
		return
	scene_root.add_child(node)
	node.name = "New Decal"
	node.owner = scene_root
	node.set_meta("collection_id", collection_id)		
	return decal	
