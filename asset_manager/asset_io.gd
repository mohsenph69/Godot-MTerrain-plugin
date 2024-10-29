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

enum IMPORT_STATE {
	NONE, NEW, CHANGE, REMOVE, 
}

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
static func glb_load(path, metadata={}):
	# metadata {
	#	glb_type: Asset / Scene / HLod?
	#	join_mesh_baker_scene_path: path.tscn
	# }
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	var gltf_document = GLTFDocument.new()
	if not Engine.is_editor_hint():
		GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	var gltf_state = GLTFState.new()
	gltf_document.append_from_file(path,gltf_state)

	#STEP 1: convert gltf file into nodes
	var scene = gltf_document.generate_scene(gltf_state).get_children()
	#STEP 2: flatten nodes into a dictionary
	var preview_dictionary = generate_preview_dictionary(scene, path)		
	#STEP 3: compare to previous import, and mark up changes					
	var import_dictionary = convert_import_dictionary_to_preview_dictionary(path, metadata)			
	compare_preview_dictionary_to_import_dictionary(preview_dictionary, import_dictionary)	
	#STEP 4: diplay import window and allow user to change import settings			
	glb_show_import_window(path, preview_dictionary, metadata)
	#STEP 5: commit changes to asset table and update import dictionary - called by import window
	#glb_import_commit_changes(preview_dictionary, path)

#Parse GLB file and prepare a preview of changes to asset library
static func generate_preview_dictionary(scene:Array, glb_path):
	#preview_dictionary = {
	#	single_item_collection_name: {
	#		meshes: Array[Mesh or null]		
	#	}
	#	collection_name: {
	#		collections: Array[sub_collection_name]
	#		collection_transforms: Array[sub_collection Transform3D]
	#	}
	#}
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	var preview_dictionary = {}
	for node: Node3D in scene:
		add_node_to_preview_dictionary(preview_dictionary, node, glb_path, true)						
	for node_name in preview_dictionary.keys():
		if "meshes" in preview_dictionary[node_name]:
			preview_dictionary[node_name].meshes = process_mesh_array(preview_dictionary[node_name].meshes)		
	return preview_dictionary

#Recursive function that flattens the collections heirarchy, returns node name (for adding as subcollection)
static func add_node_to_preview_dictionary(preview_dictionary:Dictionary, node, glb_path, is_root=false)->String:
	var name_data = mesh_node_parse_name(node.name)	
	var node_name
	if "_hlod" in node.name:
		node_name = add_hlod_to_preview_dictionary(preview_dictionary, node, glb_path)		
	elif "collision" in node.name:		
		node_name = add_collision_node_to_preview_dictionary(preview_dictionary, node)
	#If node should be converted to become part of a mesh_item:
	elif node is ImporterMeshInstance3D or node is MeshInstance3D or (name_data.name != "" and name_data.name in preview_dictionary.keys()):		
		node_name = add_mesh_node_to_preview_dictionary(preview_dictionary, node, name_data)
	elif node is Light3D:		
		node_name = add_light_node_to_preview_dictionary(preview_dictionary, node)		
	else: #If node is an empty that contains subcollections:
		node_name = add_collection_node_to_preview_dictionary(preview_dictionary, node, glb_path)
	if is_root:
		preview_dictionary[node_name]["is_root"] = true	
	return node_name
		
static func add_collection_node_to_preview_dictionary(preview_dictionary, node, glb_path):
	if node.get_child_count() > 0: # this is defining a new collection
		var glb_node_name = node.name 
		preview_dictionary[glb_node_name] = {"collections":[], "collection_transforms":[]}
		for child in node.get_children():
			var sub_collection_name = add_node_to_preview_dictionary(preview_dictionary, child, glb_path)
			if preview_dictionary[sub_collection_name].has("meshes"):
				preview_dictionary[sub_collection_name]["tag_as_hidden"] = true
			if sub_collection_name == null or sub_collection_name in preview_dictionary[glb_node_name].collections:
				continue
			#elif "collision" in sub_collection_name or "light" in sub_collection_name:
			#	continue # temporary... until this is implemented correctly
			else:
				preview_dictionary[glb_node_name].collections.push_back(sub_collection_name)
				preview_dictionary[glb_node_name].collection_transforms.push_back(child.transform)			
		return glb_node_name
	else: #This is a reference to an existing collection, replace.				
		if node.has_meta("blend_file"): 
			var blend_file_name = node.get_meta("blend_file")
			if blend_file_name in MAssetTable.get_singleton().import_info.keys():
				preview_dictionary[node.name] = {"replace_with_collection": node.name, "blend_file": blend_file_name}
			else:
				#TO DO: try to import this blend file first?
				push_error("cannot add node to preview dictionary because it references a collection from a blend file that has not been imported yet: ", blend_file_name)
		else: #this node is referencing a collection from it's own file.
			preview_dictionary[node.name] = {"replace_with_collection": node.name}
			return node.name

static func add_collision_node_to_preview_dictionary(preview_dictionary,node)->String:		
	var name = node.get_parent().name + "_collisions"
	if not preview_dictionary.has(name) or not preview_dictionary[name].has("collisions"):
		preview_dictionary[name] = {"collisions": []}
	if "collision_box" in node.name:					
		preview_dictionary[name]["collisions"].push_back({"type": "box", "position":node.position, "rotation": node.rotation, "size": abs(node.scale)})
	elif "collision_sphere" in node.name:
		preview_dictionary[name]["collisions"].push_back({"type": "sphere", "position":node.position, "rotation": node.rotation, "radius": abs(node.scale.x)})
	elif "collision_capsule" in node.name:
		preview_dictionary[name]["collisions"].push_back({"type": "capsule", "position":node.position, "rotation": node.rotation, "radius": abs(node.scale.x), "height": abs(node.scale.y)})
	elif "collision_cylinder" in node.name:
		preview_dictionary[name]["collisions"].push_back({"type": "cylinder", "position":node.position, "rotation": node.rotation, "radius": abs(node.scale.x), "height": abs(node.scale.y)})
	elif "collision_convex" in node.name:
		if node is ImporterMeshInstance3D or node is MeshInstance3D:							
			var mesh:ArrayMesh = node.mesh if node is MeshInstance3D else node.mesh.get_mesh()				
			preview_dictionary[name]["collisions"].push_back({"type": "convex", "position":node.position, "rotation": node.rotation, "points": mesh.surface_get_arrays(0)[0]})				
		else:
			push_error("cannot add convex collision node to preview dictionary because it doesn't have a mesh")
	else:
		pass #generate collision from mesh?						
	return name
	
static func add_mesh_node_to_preview_dictionary(preview_dictionary, node, name_data)->String:
	if not name_data.name in preview_dictionary:
			preview_dictionary[name_data.name] = {"meshes":[]}
	var mesh = ArrayMesh.new()		
	if node is ImporterMeshInstance3D: mesh = node.mesh.get_mesh() 
	if node is MeshInstance3D: mesh = node.mesh
	mesh.resource_name = node.name if name_data.lod != -1 else node.name + "_lod_0"				
	preview_dictionary[name_data.name].meshes.push_back(mesh)				
	if node.get_child_count() > 0:
		push_error("glb import error: while building preview dictionary, ", node.name, " was processed as a mesh/lod node, but also has child nodes")
	return name_data.name

static func add_light_node_to_preview_dictionary(preview_dictionary, node):
	var light_name = node.name
	preview_dictionary[light_name] = {"color": node.light_color, "energy":node.light_energy}
	var light_type = DirectionalLight3D
	if node is OmniLight3D:
		light_type = OmniLight3D			
		preview_dictionary[light_name]["range"] = node.omni_range
		preview_dictionary[light_name]["attenuation"] = node.omni_attenuation
	var a:SpotLight3D		
	if node is SpotLight3D:
		light_type = SpotLight3D		
		preview_dictionary[light_name]["range"] = node.spot_range
		preview_dictionary[light_name]["attenuation"] = node.spot_attenuation
		preview_dictionary[light_name]["angle"] = node.spot_angle
	preview_dictionary[light_name]["light_type"] = light_type
	return light_name
	
static func add_hlod_to_preview_dictionary(preview_dictionary, node:Node3D, glb_path):
	if node.get_child_count() == 0:		
		preview_dictionary[node.name] = {"replace_with_hlod": node.name}
		return node.name		
	else:
		preview_dictionary[node.name] = {"hlod": generate_preview_dictionary(node.get_children(), glb_path)}		
		return node.name
	
static func process_mesh_array(original_mesh_array:Array):
	#eg. mesh_lod_1, mesh_lod3 =>mesh_lod_null,mesh_lod_1, mesh_lod1, mesh_lod3,mesh_lod3,mesh_lod3
	var mesh_array = []		
	for mesh in original_mesh_array:
		var name_data = mesh_node_parse_name(mesh.resource_name)
		while len(mesh_array) < name_data.lod:
			if len(mesh_array) == 0:
				var blank_mesh = ArrayMesh.new()
				blank_mesh.resource_name = name_data.name + "_lod_0" 
				mesh_array.push_back(blank_mesh)
			else:
				mesh_array.push_back(mesh_array[-1])
		mesh_array.push_back(mesh)	
	var last_mesh = mesh_array[-1]
	#while mesh_array.size() < LOD_COUNT:
	#	mesh_array.push_back(mesh_array[-1])
	for i in len(mesh_array):
		var mesh_id = MAssetTable.get_singleton().mesh_get_id(mesh_array[i])
		if mesh_id != -1:
			mesh_array[i] = mesh_id			
	return mesh_array

static func compare_preview_dictionary_to_import_dictionary(preview_dictionary:Dictionary, import_dictionary):	
	#######################################################
	# STEP 1: ADD IMPORT DICTIONARY TO PREVIEW DICTIONARY #
	#######################################################
	var asset_library = MAssetTable.get_singleton()	
	for glb_node_name in preview_dictionary.keys():	
		var preview_node = preview_dictionary[glb_node_name]		
		if import_dictionary.has(glb_node_name):
			var original_node = import_dictionary[glb_node_name]			
			var original_keys = original_node.keys()
			var preview_keys = preview_node.keys()
			for key in original_keys:				
				if original_node[key] is Dictionary:
					preview_node["original_" + key] = original_node[key].duplicate(true)
				else:
					preview_node["original_" + key] = original_node[key]					
			for key in preview_keys:
				if not key in original_keys:					
					preview_node["original_" + key] = null		
			preview_node["collection_id"] = original_node.collection_id																														
		else:			
			for key in preview_node.keys():				
				preview_node["original_" + key] = null																	
			preview_node["collection_id"] = -1 #this is new collection
	for glb_node_name in import_dictionary.keys():		
		if not preview_dictionary.has(glb_node_name):
			preview_dictionary[glb_node_name] = { "remove_collection": true }
			for key in import_dictionary[glb_node_name].keys():				
				if key == "collection_id":
					preview_dictionary[glb_node_name]["collection_id"] = import_dictionary[glb_node_name].collection_id				
				else:
					if import_dictionary[glb_node_name][key] is Dictionary:
						preview_dictionary[glb_node_name]["original_" + key] = import_dictionary[glb_node_name][key].duplicate(true)
					else:
						preview_dictionary[glb_node_name]["original_" + key] = import_dictionary[glb_node_name][key]									
	
	###########################
	# STEP 2: ADD IMPORT TAGS #
	###########################
	for glb_node_name in preview_dictionary.keys():					
		var preview_node = preview_dictionary[glb_node_name]			
		preview_node["import_state"] = {"state":IMPORT_STATE.NONE}
		if preview_node.has("meshes"):
			#Set import state based on mesh array comparison
			preview_node.import_state = compare_mesh_arrays(preview_node.original_meshes, preview_node.meshes)						
		if preview_node.has("collections"):
			if preview_node.original_collections == null:
				preview_node.import_state.state = IMPORT_STATE.NEW
			else:
				preview_node.import_state = compare_subcollections(glb_node_name, preview_dictionary)						
		if preview_node.has("collisions"):
			if preview_node.original_collisions == null:
				preview_node.import_state.state = IMPORT_STATE.NEW
			else:
				preview_node.import_state = compare_collisions(glb_node_name, preview_dictionary)									
		if preview_node.has("light_type"):
			if preview_node.original_light_type == null:
				preview_node.import_state.state = IMPORT_STATE.NEW
			else:
				preview_node.import_state = compare_lights(preview_node)										
		if preview_node.has("hlod"):
			if preview_node.original_hlod == null:
				preview_node.import_state.state = IMPORT_STATE.NEW
			else:
				preview_node.import_state = compare_hlod(preview_node)
		if preview_node.has("remove_collection"):
			preview_node.import_state.state = IMPORT_STATE.REMOVE
			preview_node.erase("remove_collection")			
		preview_dictionary[glb_node_name].import_state["ignore"] = false
	
static func compare_mesh_arrays(original, new)->Dictionary:
	var result := {}
	var mesh_states = []
	if original == null or len(original) == 0:
		result["state"] = IMPORT_STATE.NEW
		result["mesh_state"] = new.map(func(a):return IMPORT_STATE.NEW)
		return result
	elif new == null or len(new) == 0:
		result["state"] = IMPORT_STATE.REMOVE
		result["mesh_state"] = original.map(func(a):return IMPORT_STATE.REMOVE)
		return result
		
	if len(original) > len(new):
		while len(new) != len(original):
			new.push_back(null)
	else:
		while len(original) != len(new):
			original.push_back(null)			
	mesh_states.resize(len(new))
	var is_same := true
	for i in len(original):
		if typeof(original[i]) != typeof(new[i]) or original[i] != new[i]:
			is_same = false
			if new[i] == null:
				mesh_states[i] = IMPORT_STATE.REMOVE
			elif original[i] == null:
				mesh_states[i] = IMPORT_STATE.NEW
			else:
				mesh_states[i] = IMPORT_STATE.CHANGE
		else:
			mesh_states[i] = IMPORT_STATE.NONE
	if is_same:
		result["state"] = IMPORT_STATE.NONE	
	else:
		result["state"] = IMPORT_STATE.CHANGE
		
	result["mesh_states"] = mesh_states
	return result
		
static func compare_subcollections(node_name, preview_dictionary):
	var result = {"state": IMPORT_STATE.NONE, "collection_states":{}}
	if not preview_dictionary[node_name].has("collections"):
		push_error("trying to compare subcollections of node that has no subcollections")
		return
	for sub_node_name in preview_dictionary[node_name].collections:						
		if sub_node_name in preview_dictionary[node_name].original_collections:		
			result.collection_states[sub_node_name] = IMPORT_STATE.NONE
		else:
			result.collection_states[sub_node_name] = IMPORT_STATE.NEW
			result.state = IMPORT_STATE.CHANGE
	for sub_node_name in preview_dictionary[node_name].original_collections:		
		if not sub_node_name in preview_dictionary[node_name].collections:
			result.collection_states[sub_node_name] = IMPORT_STATE.REMOVE					
			result.state = IMPORT_STATE.CHANGE	
	return result

static func compare_collisions(glb_node_name, preview_dictionary):
	var result = {"state": IMPORT_STATE.NONE, "collision_states": []}
	var node = preview_dictionary[glb_node_name]
	result.collision_states.resize(len(node.collisions))
	for i in len(node.collisions):
		result.collision_states[i] = IMPORT_STATE.NONE
		for key in node.collisions[i].keys():			
			if node.collisions[i][key] != node.original_collisions[i][key]:
				result.collision_states[i] = IMPORT_STATE.CHANGE
				result.state = IMPORT_STATE.CHANGE
				break
		
static func compare_lights(preview_node):
	var result = {"state": IMPORT_STATE.NONE}	
	var keys_to_check = ["light_type", "energy", "color", "range", "attenuation", "angle"]
	for key in keys_to_check:
		if not preview_node.has(key): continue
		if preview_node[key] != preview_node["original_" + key]:
			result.state = IMPORT_STATE.CHANGE
			return result
	return result

static func compare_hlod(preview_node):	
	pass
	
static func convert_import_dictionary_to_preview_dictionary(glb_path, metadata):
	var asset_library = MAssetTable.get_singleton()
	var result = {}
	if not asset_library.import_info.has(glb_path):
		print("import dictionary: empty")
		return {}			
	for glb_node_name in asset_library.import_info[glb_path].keys():		
		if glb_node_name == "metadata": 
			continue
		var collection_id = asset_library.import_info[glb_path][glb_node_name]				
		result[glb_node_name] = convert_collection_to_preview_dictionary_format(collection_id, glb_path)
	
	if asset_library.import_info[glb_path].has(metadata):
		for key in asset_library.import_info[glb_path].metadata:
			if not metadata.has_key():		
				metadata[key] = asset_library.import_info[glb_path].metadata[key]
	return result
	
static func convert_collection_to_preview_dictionary_format(collection_id, glb_path=null):			
	var asset_library = MAssetTable.get_singleton()
	var result := {"collection_id": collection_id}
	var mesh_items = asset_library.collection_get_mesh_items_info(collection_id)
	var sub_collections = asset_library.collection_get_sub_collections(collection_id)
	var sub_collection_transforms = asset_library.collection_get_sub_collections_transforms(collection_id)					
	if len(mesh_items) != 0:
		result["meshes"] = mesh_items[0].mesh 	
	if sub_collections:
		result["collections"] = []
		result["collection_transforms"] = []
	for i in len(sub_collections):					
		var sub_collection_id = sub_collections[i]
		var sub_collection_name = null		
		if glb_path != null:
			sub_collection_name = asset_library.import_info[glb_path].find_key(sub_collection_id)			
		else:
			for glb_path_key in asset_library.import_info.keys():
				sub_collection_name = asset_library.import_info[glb_path_key].find_key(sub_collection_id)
				if sub_collection_name != null: 
					break									
		if sub_collection_name and sub_collection_name != "":
			result["collections"].push_back(sub_collection_name)			
			result["collection_transforms"].push_back(sub_collection_transforms[i])
	return result

static func glb_import_commit_changes(preview_dictionary:Dictionary, glb_path, metadata):	
	var asset_library = MAssetTable.get_singleton()	
	if not glb_path in asset_library.import_info.keys():
		asset_library.import_info[glb_path] = {}		
	
	var glb_node_names = preview_dictionary.keys()
	glb_node_names.reverse()		
	
	for glb_node_name in glb_node_names:				
		var node_info = preview_dictionary[glb_node_name]				
		if node_info.import_state.ignore:
			continue
		if node_info.import_state.state == IMPORT_STATE.NEW:
			node_info.collection_id = import_new_collection(node_info, glb_node_name, preview_dictionary)			
		elif node_info.import_state.state == IMPORT_STATE.CHANGE:
			import_change_collection(node_info, preview_dictionary)
		elif node_info.import_state.state == IMPORT_STATE.REMOVE:
			import_remove_collection(node_info)			
		else:
			print("no changes for ", glb_node_name)		
	
	########################
	# UPDATING IMPORT INFO #
	########################
	var result = {}
	for glb_node_name in glb_node_names:
		var node_info = preview_dictionary[glb_node_name]		
		if node_info.import_state.state == IMPORT_STATE.REMOVE:
			continue		
		if node_info.collection_id in [-1, null]: #ERROR 
			push_warning("import warning: ", glb_node_name, " has collection id -1 after import")
			continue
		result[glb_node_name] = node_info.collection_id
	result["metadata"] = metadata
	asset_library.import_info[glb_path] = result	
	asset_library.save()
	asset_library.finish_import.emit(glb_path)
	
static func import_new_collection(node_info, glb_node_name, preview_dictionary):
	var asset_library = MAssetTable.get_singleton()		
	print("adding new: ", glb_node_name)			
	if node_info.has("meshes"):
		var mesh_array := []
		for mesh in node_info.meshes:					
			var mesh_id = save_mesh_to_file(mesh)
			mesh_array.push_back(mesh_id)
		var mesh_item_id = asset_library.mesh_item_add(mesh_array, mesh_array.map(func(a):return -1))
		var collection_id = asset_library.collection_create(glb_node_name)		
		asset_library.collection_add_item(collection_id, MAssetTable.MESH, mesh_item_id,Transform3D())
		asset_library.collection_add_tag(collection_id, 0)
		if node_info.has("tag_as_hidden"):
			asset_library.collection_add_tag(collection_id, 1)
		return collection_id
	elif node_info.has("collections"):
		var collection_id = asset_library.collection_create(glb_node_name)					
		for i in len(node_info.collections):
			var sub_node_name = node_info.collections[i]
			var subcollection_id = preview_dictionary[sub_node_name].collection_id						
			var subcollection_transform = node_info.collection_transforms[i]
			if subcollection_id is int and subcollection_id != -1 and subcollection_transform is Transform3D:
				asset_library.collection_add_sub_collection(collection_id, subcollection_id, subcollection_transform)
			
		return collection_id
		
static func import_change_collection(node_info, preview_dictionary):
	var asset_library = MAssetTable.get_singleton()		
	if node_info.has("meshes"):
		var mesh_states = node_info.import_state.mesh_states
		var mesh_array := []													
		for i in len(mesh_states):
			if mesh_states[i] == IMPORT_STATE.NONE:
				mesh_array.push_back(node_info.original_meshes[i])																
			elif mesh_states[i] == IMPORT_STATE.NEW:
				var mesh_id = save_mesh_to_file(node_info.meshes[i])
				mesh_array.push_back(mesh_id)
				print("changing: adding new mesh to mesh_item",)
			elif mesh_states[i] == IMPORT_STATE.CHANGE:
				#delete old mesh
				pass
				#save new mesh
				var mesh_id = save_mesh_to_file(node_info.meshes[i])
				mesh_array.push_back(mesh_id)						
				print("changing: changing mesh for mesh_item")
			elif mesh_states[i] == IMPORT_STATE.REMOVE:
				#delete old mesh
				pass
				mesh_array.push_back(-1)												
				print("changing: removing mesh for mesh_item")
		var collection_id = node_info.collection_id
		var mesh_id = asset_library.collection_get_mesh_items_ids(collection_id)[0]
		asset_library.mesh_item_update(mesh_id, mesh_array, mesh_array.map(func(a):return-1))
		if node_info.has("tag_as_hidden"):			
			asset_library.collection_add_tag(collection_id, 1)
	elif node_info.has("collections"):						
		for i in len(node_info.collections):
			var sub_node_name = node_info.collections[i]
			if node_info.import_state.collection_states[sub_node_name] == IMPORT_STATE.NEW:							
				var sub_collection_id = preview_dictionary[sub_node_name].collection_id				
				if sub_collection_id in [null, -1]:
					push_warning("can't add subcollection ", sub_node_name )
					continue
				asset_library.collection_add_sub_collection(node_info.collection_id, sub_collection_id, node_info.collection_transforms[i])
			elif node_info.import_state.collection_states[sub_node_name] == IMPORT_STATE.REMOVE:							
				var sub_collection_id = preview_dictionary[sub_node_name].collection_id				
				asset_library.collection_remove_sub_collection(node_info.collection_id, sub_collection_id)							
		
static func import_remove_collection(node_info):
	print("removing collection ")
	var asset_library := MAssetTable.get_singleton()		
	var collection_id = node_info.collection_id
	if node_info.has("meshes"):
		var mesh_id = asset_library.collection_get_mesh_items_ids(collection_id)[0]
		asset_library.mesh_item_remove(mesh_id)	
	asset_library.collection_remove(collection_id)
	
static func save_mesh_to_file(mesh):
	if mesh == null:
		return -1
	if mesh is int:
		return mesh
	if not mesh is Mesh:
		push_error("trying to save mesh to file but it is not type mesh or int")
		return -1
	var asset_library = MAssetTable.get_singleton()
	var mesh_id = asset_library.mesh_get_id(mesh)
	if mesh_id == -1:
		#Save mesh
		var path = asset_library.mesh_get_path(mesh)
		ResourceSaver.save(mesh, path)
		mesh_id = asset_library.mesh_get_id(mesh)
		if mesh_id == -1:
			push_error("asset library cannot save mesh")			
			return -1
	return mesh_id
	
static func collection_parse_name(name:String):
	if name.right(3).is_valid_int():  #remove the .001 suffix
		return name.left(len(name)-4)
	return name

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

static func glb_show_import_window(glb_path, preview_dictionary, metadata):
	var popup = Window.new()
	popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	popup.wrap_controls = true
	EditorInterface.get_editor_main_screen().add_child(popup)
	var panel = preload("res://addons/m_terrain/asset_manager/ui/import_window.tscn").instantiate()
	panel.glb_path = glb_path	
	panel.preview_dictionary = preview_dictionary		
	panel.metadata = metadata
	popup.add_child(panel)
	popup.popup_centered(Vector2i(800,600))	

static func convert_node_to_hlod_baker(object):
	var asset_library = MAssetTable.get_singleton()
	object.set_script(preload("res://addons/m_terrain/asset_manager/hlod_baker.gd"))
	var mesh_children = []
	for child in object.get_children():
		child.owner = object
		if child is ImporterMeshInstance3D:
			mesh_children.push_back(child)
		else:
			#Check if collection exists
			var collection_name = child.name.left(len(child.name) - len(child.name.split("_")[-1])-1)
			var collection_id = asset_library.collection_get_id( collection_name.to_lower())
			if collection_id != -1:
				object.remove_child(child)
				var node = collection_instantiate(collection_id)
				object.add_child(node)
				node.transform = child.transform
				node.owner = object
				node.set_meta("collection_id", collection_id)
				node.name = child.name
				child.queue_free()
			elif "_hlod" in child.name:
				var node = MHlodScene.new()
				#node.hlod = load()
				child.add_sibling(node)
				child.get_parent().remove_child(child)
				node.name = child.name
				node.owner = object
				child.queue_free()
	var data = mesh_item_import_from_nodes(mesh_children)
	var nodes_to_delete = []
	for child in mesh_children:
		child.owner = null
		nodes_to_delete.push_back(child)
	for i in data.ids.size():
		var single_item_collections = asset_library.tag_get_collections_in_collections( asset_library.mesh_item_find_collections(data.ids[i]) ,0)
		if len(single_item_collections) == 1:
			var node = collection_instantiate(single_item_collections[0])
			object.add_child(node)
			object.move_child(node, data.sibling_ids[i])
			node.owner = object

	var packed_scene:PackedScene = PackedScene.new()
	packed_scene.pack(object)
	ResourceSaver.save(packed_scene, "res://addons/m_terrain/asset_manager/example_asset_library/hlods/" + object.name + ".tscn")
	for node:Node in nodes_to_delete:
		node.queue_free()

static func mesh_item_import_from_nodes(nodes, ignore_transform = true):
	var asset_library := MAssetTable.get_singleton()
	var mesh_item_ids = []
	var mesh_item_transforms = []
	var sibling_ids = []

	var mesh_items = {}
	for child:Node in nodes:
		var name_data = mesh_node_parse_name(child.name)
		if not name_data.name in mesh_items.keys():
			mesh_items[name_data.name] = []
		mesh_items[name_data.name].push_back(child)

	for item_name in mesh_items.keys():
		sibling_ids.push_back(mesh_items[item_name][0].get_index())
		var mesh_item_array = []
		var meshes = []
		for node in mesh_items[item_name]:
			var name_data = mesh_node_parse_name(node.name)
			#Save Meshes
			var mesh:Mesh
			if node is MeshInstance3D:
				mesh = node.mesh
			elif node is ImporterMeshInstance3D:
				mesh = node.mesh.get_mesh()
			else:
				mesh = null
			if mesh:
				var mesh_save_path = asset_library.mesh_get_path(mesh)
				if FileAccess.file_exists(mesh_save_path):
					mesh.take_over_path(mesh_save_path)
				else:
					ResourceSaver.save(mesh, mesh_save_path)

			while len(mesh_item_array) < name_data.lod:
				if len(mesh_item_array) == 0:
					mesh_item_array.push_back(0)
					#material_ids.push_back(-1)
				else:
					mesh_item_array.push_back(mesh_item_array.back())
					#material_ids.push_back(material_ids.back())
			mesh_item_array.push_back(asset_library.mesh_get_id(mesh))
			meshes.push_back(mesh)

		#Fill empty lod with last mesh
		var last_mesh = mesh_item_array[-1]
		while mesh_item_array.size() < LOD_COUNT:
			mesh_item_array.push_back(mesh_item_array[-1])

		#Add Mesh Item
		var material_ids = mesh_item_array.map(func(a): return -1)
		var mesh_item_id = asset_library.mesh_item_find_by_info( mesh_item_array, material_ids)
		if mesh_item_id == -1:
			mesh_item_id = asset_library.mesh_item_add( mesh_item_array, material_ids)
		else:
			asset_library.mesh_item_update(mesh_item_id, mesh_item_array, material_ids)
		mesh_item_ids.push_back(mesh_item_id)
		mesh_item_transforms.push_back(mesh_items[item_name][0].transform)
	#Create single item collections
	var collection_ids = []
	for i in mesh_item_ids.size():
		var name = mesh_items.keys()[i] + "_mesh" if not mesh_items.keys()[i].ends_with("_mesh") else mesh_items.keys()[i]
		var collection_id = asset_library.collection_get_id(name)
		if collection_id == -1:
			collection_id = asset_library.collection_create(name)
		else:
			for mesh_id in asset_library.collection_get_mesh_items_ids(collection_id):
				asset_library.mesh_item_remove(mesh_id)
			asset_library.collection_remove_all_items(collection_id)
			asset_library.collection_remove_all_sub_collection(collection_id)
		if not collection_id in asset_library.tag_get_collections(0):
			asset_library.collection_add_tag(collection_id,0)
		collection_ids.push_back(collection_id)
		var transform = Transform3D() if ignore_transform else mesh_item_transforms[i]
		asset_library.collection_add_item(collection_id, MAssetTable.MESH, mesh_item_ids[i], transform)

	return {"ids":mesh_item_ids, "collection_ids": collection_ids , "transforms": mesh_item_transforms, "sibling_ids": sibling_ids}
#endregion
#region Mesh Item
static func mesh_item_get_mesh_resources(mesh_id): #return meshes[.res]
	var asset_library = MAssetTable.get_singleton() #load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))
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

static func mesh_item_save_from_resources(mesh_item_id, meshes, material_ids)->int:
	var asset_library = MAssetTable.get_singleton()
	var mesh_item_array = []	
	for mesh:Mesh in meshes:
		var mesh_save_path = asset_library.mesh_get_path(mesh)
		if FileAccess.file_exists(mesh_save_path):
			mesh.take_over_path(mesh_save_path)
		else:
			ResourceSaver.save(mesh, mesh_save_path)
		mesh_item_array.push_back(asset_library.mesh_get_id(mesh))

	if asset_library.has_mesh_item(mesh_item_id):
		asset_library.mesh_item_update(mesh_item_id, mesh_item_array, material_ids )
	else:
		mesh_item_id = asset_library.mesh_item_add(mesh_item_array, material_ids )
	return mesh_item_id

static func mesh_node_parse_name(name:String):
	var result = {"name": "", "lod": -1}
	if "_lod" in name:
		result.name = name.get_slice("_lod", 0).to_lower() + "_mesh"
		result.lod = name.get_slice("_lod", 1)
		if result.lod.begins_with("_"):
			result.lod = result.lod.trim_prefix("_")
		if "_" in result.lod:
			result.lod = result.lod.get_slice("_", 0)
		result.lod = int(result.lod)
	return result

#endregion
#region Collection
static func convert_node_to_preview_dictionary(root_node):
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	#preview_dictionary = {
	#	single_item_collection_name: {
	#		meshes: Array[Mesh or null]		
	#	}
	#	collection_name: {
	#		collections: Array[sub_collection_name]
	#		collection_transforms: Array[sub_collection Transform3D]
	#	}
	#}
	var result = { "collection_id": root_node.get_meta("collection_id") }
	if root_node is MAssetMesh:				
		result["meshes"] = root_node.meshes.meshes	
	else:
		result["collections"] = []
		result["collection_transforms"] = []
		var overrides = root_node.get_meta("overrides") if root_node.has_meta("overrides") else {}						
		#for child in root_node.get_children():
			#if child.has_meta("mesh_id"):
				#var mesh_id = child.get_meta("mesh_id")
				#asset_library.collection_add_item(collection_id, MAssetTable.MESH, mesh_id, child.transform)
			#elif child is CollisionShape3D:
				#pass
			#elif child.has_meta("collection_id"):
				#var sub_collection_id = child.get_meta("collection_id")
				#asset_library.collection_add_sub_collection(collection_id, sub_collection_id, child.transform)
		#return collection_id

static func collection_save_from_nodes(root_node) -> int: #returns collection_id
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	if root_node is MAssetMesh:
		var material_overrides = root_node.get_meta("material_overrides") if root_node.has_meta("material_overrides") else []
		var mesh_id = root_node.get_meta("mesh_id") if root_node.has_meta("mesh_id") else -1
		mesh_id = mesh_item_save_from_resources(mesh_id, root_node.meshes.meshes, material_overrides)
		root_node.set_meta("mesh_id", mesh_id)
		root_node.notify_property_list_changed()
		return root_node.get_meta("collection_id")
	else:
		var overrides = root_node.get_meta("overrides") if root_node.has_meta("overrides") else {}
		var collection_id = root_node.get_meta("collection_id")
		if collection_id == -1:	return collection_id
		asset_library.collection_remove_all_items(collection_id)
		asset_library.collection_remove_all_sub_collection(collection_id)
		for child in root_node.get_children():
			if child.has_meta("mesh_id"):
				var mesh_id = child.get_meta("mesh_id")
				asset_library.collection_add_item(collection_id, MAssetTable.MESH, mesh_id, child.transform)
			elif child is CollisionShape3D:
				pass
			elif child.has_meta("collection_id"):
				var sub_collection_id = child.get_meta("collection_id")
				asset_library.collection_add_sub_collection(collection_id, sub_collection_id, child.transform)
		return collection_id

static func reload_collection(node:Node3D, collection_id):
	var asset_library:MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))
	if not collection_id in asset_library.collection_get_list(): return
	var overrides = node.get_meta("overrides") if node.has_meta("overrides") else {}
	var parent = node.get_parent()
	var overrides_for_this_node = {}
	if is_instance_valid(parent) and parent.has_meta("overrides"):
		var parents_overrides = parent.get_meta("overrides")
		if node.name in parents_overrides:
			overrides_for_this_node = parents_overrides[node.name]
	var new_root = collection_instantiate(collection_id, overrides_for_this_node)
	new_root.transform = node.transform
	for node_name in overrides:
		if new_root.has_node(node_name):
			new_root.get_node(node_name).transform = overrides[node_name].transform
		else:
			print(new_root.name, " is trying to override ", node_name, " but node does not exist " )
	if is_instance_valid(new_root):
		var old_meta = {}
		for meta in node.get_meta_list():
			old_meta[meta] = node.get_meta(meta)
		node.add_sibling(new_root)		
		new_root.name = node.name.trim_suffix("*")
		new_root.owner = node.owner
		EditorInterface.get_selection().add_node.call_deferred(new_root)

		node.queue_free()
		for meta in old_meta:
			new_root.set_meta(meta, old_meta[meta])
	else:
		new_root = null
		print("NULL ROOT")
	return new_root

static func collection_instantiate(collection_id, overrides = {})->Node3D:
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	if not asset_library.has_collection(collection_id):		
		return null	
	if collection_id in asset_library.tag_get_collections(0):		
		var node = MAssetMesh.new()
		var mesh_id = asset_library.collection_get_mesh_items_ids(collection_id)[0]
		node.set_meta("mesh_id", mesh_id)
		node.set_meta("collection_id", collection_id)
		node.meshes = MMeshLod.new()
		node.meshes.meshes = mesh_item_get_mesh_resources(mesh_id)
		node.name = asset_library.collection_get_name(collection_id)
		if "transform" in overrides:
			node.transform = overrides.transform
		else:
			node.transform = asset_library.collection_get_mesh_items_info(collection_id)[0].transform
		return node
	else:
		var node = Node3D.new()
		node.name = asset_library.collection_get_name(collection_id)
		node.set_meta("collection_id", collection_id)
		if "transform" in overrides:
			node.transform = overrides.transform
		var item_ids = asset_library.collection_get_mesh_items_ids(collection_id)
		var items_info = asset_library.collection_get_mesh_items_info(collection_id)
		for i in item_ids.size():
			var mesh_item = MAssetMesh.new()
			var mesh_id = item_ids[i]
			mesh_item.set_meta("mesh_id", mesh_id)
			var single_item_collection_ids = asset_library.tag_get_collections_in_collections(asset_library.mesh_item_find_collections(mesh_id), 0)
			if len(single_item_collection_ids) == 0: 
				push_error("single item collection doesn't exist! mesh_id: ", mesh_id)
			mesh_item.set_meta("collection_id", single_item_collection_ids[0])
			var mesh_item_name = asset_library.collection_get_name(single_item_collection_ids[0])
			mesh_item.meshes = MMeshLod.new()
			mesh_item.meshes.meshes = mesh_item_get_mesh_resources(mesh_id)
			mesh_item.transform = items_info[i].transform
			node.add_child(mesh_item)
			mesh_item.name = mesh_item_name

		var sub_collections = asset_library.collection_get_sub_collections(collection_id)
		var sub_collections_transforms = asset_library.collection_get_sub_collections_transforms(collection_id)
		for i in sub_collections.size():
			var sub_collection = collection_instantiate(sub_collections[i])			
			node.add_child(sub_collection)
			sub_collection.transform = sub_collections_transforms[i]		
		return node

static func edit_collection(object, toggle_on):
	for child in object.get_children():
		if toggle_on:
			child.owner = EditorInterface.get_edited_scene_root()
			object.notify_property_list_changed()
		else:
			child.owner = null
			object.notify_property_list_changed()
	var n = Node.new()
	object.add_child(n)
	n.queue_free()

static func collections_load_recursive(root:Node)->Node:
	if root.has_meta("collection_id"):
		var new_root = reload_collection(root, root.get_meta("collection_id"))
		return new_root if is_instance_valid(new_root) else null
	else:
		for child in root.get_children():
			if child.has_meta("collection_id"):
				reload_collection(child, child.get_meta("collection_id"))
		return root

#endregion
