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
static func glb_load(path):
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	var gltf_document = GLTFDocument.new()
	if not Engine.is_editor_hint():
		GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	var gltf_state = GLTFState.new()
	gltf_document.append_from_file(path,gltf_state)

	#STEP 1: convert gltf file into nodes
	var scene = gltf_document.generate_scene(gltf_state).get_children()
	#STEP 2: flatten nodes into a dictionary
	var preview_dictionary = glb_generate_preview_dictionary(scene, path)
	#STEP 3: compare to previous import, and mark up changes
	#print("===before===\n", preview_dictionary)
	compare_preview_dictionary_to_import_dictionary(path, preview_dictionary)
	#print("===after===\n", preview_dictionary)		
	#STEP 4: diplay import window and allow user to change import settings			
	glb_show_import_window(path, preview_dictionary)
	#STEP 5: commit changes to asset table and update import dictionary - called by import window
	#glb_import_commit_changes(preview_dictionary, path)

#Parse GLB file and prepare a preview of changes to asset library
static func glb_generate_preview_dictionary(scene:Array, glb_path):
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
		glb_import_add_node_to_preview_dictionary(preview_dictionary, node)
	for glb_node_name in preview_dictionary.keys():
		if "meshes" in preview_dictionary[glb_node_name]:
			preview_dictionary[glb_node_name].meshes = process_mesh_array(preview_dictionary[glb_node_name].meshes)
	return preview_dictionary

#Recursive function that flattens the collections heirarchy
static func glb_import_add_node_to_preview_dictionary(preview_dictionary:Dictionary, node):
	var name_data = mesh_node_parse_name(node.name)	
	#If node should be converted to become part of a mesh_item:
	if node is ImporterMeshInstance3D or (name_data.name != "" and name_data.name in preview_dictionary.keys()):		
		if not name_data.name in preview_dictionary:
			preview_dictionary[name_data.name] = {"meshes":[]}
		var mesh = node.mesh.get_mesh() if node is ImporterMeshInstance3D else ArrayMesh.new()		
		mesh.resource_name = node.name if name_data.lod != -1 else node.name + "_lod_0"				
		preview_dictionary[name_data.name].meshes.push_back(mesh)		
		
		if node.get_child_count() > 0:
			push_error("glb import error: while building preview dictionary, ", node.name, " was processed as a mesh/lod node, but also has child nodes")
		return name_data.name
	elif "collision" in node.name:
		pass
	#If node is an empty that contains subcollections:
	else:
		if not node.get_child_count() > 0: return null
		var glb_node_name = node.name #collection_parse_name(node.name)
		preview_dictionary[glb_node_name] = {"collections":[], "collection_transforms":[]}
		for child in node.get_children():
			var sub_collection_name = glb_import_add_node_to_preview_dictionary(preview_dictionary, child)
			if sub_collection_name and not sub_collection_name in preview_dictionary[glb_node_name].collections:
				preview_dictionary[glb_node_name].collections.push_back(sub_collection_name)
				preview_dictionary[glb_node_name].collection_transforms.push_back(child.transform)			
		return glb_node_name

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

static func compare_preview_dictionary_to_import_dictionary(glb_path, preview_dictionary:Dictionary):	
	#here we should add collection id or -1 to each collection
	var asset_library = MAssetTable.get_singleton()
	var import_dictionary = convert_import_dictionary_to_preview_dictionary(glb_path)			
	for glb_node_name in preview_dictionary.keys():
		if glb_node_name in import_dictionary.keys():			
			preview_dictionary[glb_node_name]["collection_id"] = import_dictionary[glb_node_name]				
			var preview_has_meshes = "meshes" in preview_dictionary[glb_node_name].keys()
			var original_has_meshes = "meshes" in import_dictionary[glb_node_name].keys()
			if preview_has_meshes and original_has_meshes:
				preview_dictionary[glb_node_name]["original_meshes"] = import_dictionary[glb_node_name].meshes
			elif preview_has_meshes:
				preview_dictionary[glb_node_name]["original_meshes"] = null
			elif original_has_meshes:
				preview_dictionary[glb_node_name]["original_meshes"] = import_dictionary[glb_node_name].meshes
				preview_dictionary[glb_node_name]["meshes"] = null
			else:
				var preview_has_collections = "collections" in preview_dictionary[glb_node_name].keys()
				var original_has_collections = "collections" in import_dictionary[glb_node_name].keys()
				if preview_has_collections and original_has_collections:
					preview_dictionary[glb_node_name]["original_collections"] = import_dictionary[glb_node_name].collections
					preview_dictionary[glb_node_name]["original_collection_transforms"] = import_dictionary[glb_node_name].collection_transforms
				elif preview_has_collections:
					preview_dictionary[glb_node_name]["original_collections"] = null
					preview_dictionary[glb_node_name]["original_collection_transforms"] = null
				elif original_has_collections:
					preview_dictionary[glb_node_name]["collections"] = null
					preview_dictionary[glb_node_name]["collection_transforms"] = null
					preview_dictionary[glb_node_name]["original_collections"] = import_dictionary[glb_node_name].collections
					preview_dictionary[glb_node_name]["original_collection_transforms"] = import_dictionary[glb_node_name].collection_transforms												
		else:		
			
			preview_dictionary[glb_node_name]["collection_id"] = -1 #this is new collection
			if "meshes" in preview_dictionary[glb_node_name].keys():
				preview_dictionary[glb_node_name]["original_meshes"] = []
			if "collections" in preview_dictionary[glb_node_name].keys():
				preview_dictionary[glb_node_name]["original_collections"] = []
				preview_dictionary[glb_node_name]["original_collection_transforms"] = []
	
	for glb_node_name in import_dictionary.keys():
		if not glb_node_name in preview_dictionary.keys():
			preview_dictionary[glb_node_name] = import_dictionary[glb_node_name].duplicate(true)
			preview_dictionary[glb_node_name]["remove_collection"] = true #to remove collection!		
	
	#########################
	#STEP 2: ADD IMPORT TAGS#
	#########################
	for glb_node_name in preview_dictionary.keys():
		if "meshes" in preview_dictionary[glb_node_name]:
			#Set import state based on mesh array compare
			preview_dictionary[glb_node_name].import_state = compare_mesh_arrays(preview_dictionary[glb_node_name].original_meshes, preview_dictionary[glb_node_name].meshes)						
		#elif "collections" in preview_dictionary[glb_node_name]:
			#preview_dictionary.import_state = {}
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
		
static func convert_import_dictionary_to_preview_dictionary(glb_path):
	var asset_library = MAssetTable.get_singleton()
	var result = {}
	if not glb_path in asset_library.import_info.keys():
		print("import dictionary: empty")
		return {}			
	for glb_node_name in asset_library.import_info[glb_path].keys():		
		var collection_id = asset_library.import_info[glb_path][glb_node_name]		
		print(collection_id)
		var mesh_items = asset_library.collection_get_mesh_items_info(collection_id)
		var sub_collections = asset_library.collection_get_sub_collections(collection_id)
		result[glb_node_name] = {
			"collection_id" = collection_id			
		}		
		
		if mesh_items:
			result[glb_node_name]["meshes"] = []
		for mesh_item in mesh_items:
			for mesh_id in mesh_item.mesh:				
				var mesh = load(MHlod.get_mesh_path(mesh_id)) if mesh_id != -1 else ArrayMesh.new()
				result[glb_node_name]["meshes"].push_back(mesh)			
			#TODO: Materials
		if sub_collections:
			result[glb_node_name]["collections"] = []
		for sub_collection_id in sub_collections:			
			var sub_collection_name = asset_library.import_info[glb_path].find_key(sub_collection_id)
			if sub_collection_name and sub_collection_name != "":
				result[glb_node_name]["collections"].push_back(sub_collection_name)	
	return result

static func glb_import_commit_changes(preview_dictionary:Dictionary, glb_path):
	var asset_library = MAssetTable.get_singleton()	
	if not glb_path in asset_library.import_info.keys():
		asset_library.import_info[glb_path] = {}		
	
	var glb_node_names = preview_dictionary.keys()
	glb_node_names.reverse()		
	
	print("======starting commit changes to asset table=======\n",preview_dictionary)
	for glb_node_name in glb_node_names:		
		var node_info = preview_dictionary[glb_node_name]		
		if node_info.import_state.ignore:
			continue
		if node_info.import_state.state == IMPORT_STATE.NEW:
			node_info.collection_id = import_new_collection(node_info, glb_node_name)
		elif node_info.import_state.state == IMPORT_STATE.CHANGE:
			import_change_collection(node_info)
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
		result[glb_node_name] = node_info.collection_id
	asset_library.import_info[glb_path] = result
	asset_library.save()
static func import_new_collection(node_info, glb_node_name):
	var asset_library = MAssetTable.get_singleton()		
	print("adding new: ", glb_node_name)			
	if "meshes" in node_info:
		var mesh_array := []
		for mesh in node_info.meshes:					
			var mesh_id = save_mesh_to_file(mesh)
			mesh_array.push_back(mesh_id)
		var mesh_item_id = asset_library.mesh_item_add(mesh_array, mesh_array.map(func(a):return -1))
		var collection_id = asset_library.collection_create(glb_node_name)		
		asset_library.collection_add_item(collection_id, MAssetTable.MESH, mesh_item_id,Transform3D())
		asset_library.collection_add_tag(collection_id, 0)
		return collection_id
		
static func import_change_collection(node_info):
	var asset_library = MAssetTable.get_singleton()		
	if "meshes" in node_info:
		var mesh_states = node_info.import_state.mesh_state
		var mesh_array := []													
		for i in len(mesh_states):
			if mesh_states == IMPORT_STATE.NONE:
				mesh_array.push_back(node_info.original_meshes[i])																
			elif mesh_states == IMPORT_STATE.NEW:
				var mesh_id = save_mesh_to_file(node_info.meshes[i])
				mesh_array.push_back(mesh_id)
				print("changing: adding new mesh to mesh_item",)
			elif mesh_states == IMPORT_STATE.CHANGE:
				#delete old mesh
				pass
				#save new mesh
				var mesh_id = save_mesh_to_file(node_info.meshes[i])
				mesh_array.push_back(mesh_id)						
				print("changing: changing mesh for mesh_item")
			elif mesh_states == IMPORT_STATE.REMOVE:
				#delete old mesh
				pass
				mesh_array.push_back(-1)												
				print("changing: removing mesh for mesh_item")
		var collection_id = node_info.collection_id
		var mesh_id = asset_library.collection_get_mesh_items_ids(collection_id)[0]
		asset_library.mesh_item_update(mesh_id, mesh_array, mesh_array.map(func(a):return-1))

static func import_remove_collection(node_info):
	print("removing collection ")
	var asset_library = MAssetTable.get_singleton()		
	var collection_id = node_info.collection_id
	var mesh_id = asset_library.collection_get_mesh_items_ids(collection_id)[0]
	asset_library.mesh_item_remove(mesh_id)	
		
		#if preview_dictionary[glb_node_name].state in preview_dictionary[glb_node_name].keys():						
			#var collection_id = glb_import_collection(glb_node_name, preview_dictionary)						
			#if collection_id == -1:
				#asset_library.import_info[glb_path].erase(glb_node_name)
			#else:
				#asset_library.import_info[glb_path][glb_node_name] = collection_id
		

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
	
static func glb_import_collection(glb_node_name, preview_dictionary:Dictionary)->int: #returns collection_id	
	var asset_library = MAssetTable.get_singleton()	
	var collection = preview_dictionary[glb_node_name]
	print(collection)
	if "remove_collection" in collection.keys():
		#if single item collection, remove mesh item also
		if "meshes" in collection.keys():
			for mesh_item_id in asset_library.collection_get_mesh_items_ids(collection.collection_id):
				asset_library.mesh_item_remove(mesh_item_id)
		asset_library.collection_remove(collection.collection_id)
		return -1
	elif collection.collection_id == -1:		
		collection.collection_id = asset_library.collection_create(glb_node_name)
		print("created new collection: ", collection.collection_id, " ", glb_node_name)
		if "meshes" in collection.keys():
			collection["mesh_item_id"] = -1
	else:				
		collection["mesh_item_id"] = asset_library.collection_get_mesh_items_ids(collection.collection_id)[0] if "original_meshes" in collection.keys() else -1
		if collection.collections != collection.original_collections: 
			asset_library.collection_remove_all_sub_collection(collection.collection_id)		
		print("cleared existing collection: ", collection.collection_id, " ", glb_node_name)
		
	if "meshes" in collection.keys():		
		asset_library.collection_add_tag(collection.collection_id, 0)			 
		if collection.mesh_item_id == -1:
			var null_array = []
			null_array.resize(LOD_COUNT)
			null_array.fill(-1)
			collection.mesh_item_id = asset_library.mesh_item_add(null_array,null_array)
			asset_library.collection_add_item(collection.collection_id, MAssetTable.MESH, collection.mesh_item_id, Transform3D())	
		print("creating mesh item ", collection.mesh_item_id )
		mesh_item_update_from_collection_dictionary(collection)
	else:
		asset_library.collection_remove_tag(collection.collection_id, 0)
		if "collections" in collection.keys() and collection.collections != collection.original_collections:		
			for i in len(collection.collections):
				var sub_collection_id = preview_dictionary[collection.collections[i]].collection_id
				if sub_collection_id != -1:
					asset_library.collection_add_sub_collection(collection.collection_id, sub_collection_id, collection.collection_transforms[i])
					print("adding subcollection ", sub_collection_id, " to collection ", collection.collection_id)
	return collection.collection_id
	
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

static func glb_show_import_window(glb_path, preview_dictionary):
	var popup = Window.new()
	popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	popup.wrap_controls = true
	EditorInterface.get_editor_main_screen().add_child(popup)
	var panel = preload("res://addons/m_terrain/asset_manager/ui/import_window.tscn").instantiate()
	panel.glb_path = glb_path
	panel.preview_dictionary = preview_dictionary		
	popup.add_child(panel)
	popup.popup_centered(Vector2i(600,480))	

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
	var asset_library = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))
	var mesh_item_array = []
	var mesh_hash_index_array = []

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
static func collection_save_from_nodes(root_node) -> int: #returns collection_id
	var asset_library:MAssetTable = MAssetTable.get_singleton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))
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
		#node.replace_by(new_root)
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
		print("collection doesn't exist")
		#TODO: CHECK IF THERE"S A GLB THAT NEEDS TO BE LOADED
		return null
	var node
	if collection_id in asset_library.tag_get_collections(0):
		print("instantiating single item collection ", asset_library.collection_get_name(collection_id))
		node = MAssetMesh.new()
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
		node = Node3D.new()
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
			if len(single_item_collection_ids) == 0: push_error("single item collection doesn't exist! mesh_id: ", mesh_id)
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
			#var sub_collection = Node3D.new()
			#sub_collection.set_meta("collection_id", id)
			node.add_child(sub_collection)
			sub_collection.transform = sub_collections_transforms[i]
		#for hlod in asset_library.collection_get_sub_hlods(collection_id):
			#var hlod_baker_scene = load().instantiate()
			#add_child(hlod_baker_scene)
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
