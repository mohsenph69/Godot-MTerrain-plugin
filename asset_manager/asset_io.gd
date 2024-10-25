@tool
class_name AssetIO extends Object

############################################
# AssetIO contains:
# - static functions for importing/exporting glb files
# - static functions for instantiating collections
# - static functions for updating MAssetTable from nodes

const LOD_COUNT = 8  # The number of different LODs in your project

#region GLB	
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
	
static func glb_load(path):
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	var gltf_document = GLTFDocument.new()
	if not Engine.is_editor_hint():		
		GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	var gltf_state = GLTFState.new()	
	gltf_document.append_from_file(path,gltf_state)		
	var scene = gltf_document.generate_scene(gltf_state).get_children()		
	glb_show_import_window(path, glb_generate_preview(scene, path))	
	
			
#Parse GLB file and prepare a preview of changes to asset library
static func glb_generate_preview(scene:Array, glb_path):		
	var asset_library:MAssetTable = MAssetTable.get_singleton()		
	var collections_to_import = {}	
	for object: Node3D in scene:
		var mesh_name = mesh_node_parse_name(object.name).name
		if "_hlod" in object.name:
			pass
			#if not "hlods" in collections_to_import:
				#collections_to_import["hlods"] = []
			#collections_to_import["hlods"].push_back(object.name.get_slice("_hlod", 0))
			#if object.get_child_count() > 0:				
				#collections_to_import.hlods.push_back( glb_generate_preview(object.get_children(), glb_path) )						
		elif object is ImporterMeshInstance3D or (mesh_name != "" and mesh_name in collections_to_import.keys()):
			glb_import_add_child_to_collection_dictionary(collections_to_import, object)					
		else: 
			var collection_name = collection_parse_name(object.name) 					
			collections_to_import[collection_name] = {"collections":{}}
			for child in object.get_children():				
				var child_mesh_name = mesh_node_parse_name(child.name).name
				if child is ImporterMeshInstance3D or (child_mesh_name != "" and child_mesh_name in collections_to_import[collection_name].collections.keys()):		
					glb_import_add_child_to_collection_dictionary(collections_to_import[collection_name].collections, child)									
				elif "_hlod" in child.name:
					pass #replace with MHlodScene
				else:					
					collections_to_import[collection_name].collections = glb_generate_preview(child.get_children(), glb_path)
	return collections_to_import
	
static func glb_import_add_child_to_collection_dictionary(collections: Dictionary, child):
	var name_data = mesh_node_parse_name(child.name)
	if name_data.lod == -1:			
		child.name += "_lod_0"
	if not name_data.name in collections:
		collections[name_data.name] = {"meshes":[]}
	collections[name_data.name].meshes.push_back(child)	
	collections[name_data.name]["transform"] = child.transform
	
static func glb_import_collections(collections_to_import:Dictionary, glb_path) -> Array[int]: 
	#collections_to_import is structure as follows:
	#collection_name:{
	#	meshes: [ImporterMeshInstance3D], 
	#	collections: {
	#		collection_name: {
	#			meshes: [ImporterMeshInstance3D],
	#			collections: {etc}
	#		}
	#	}
	#}	
	#
	#AssetTable Import Info is structured as follows:
	#{
	#	"glb_paths":{
	#		collection_id: glb_file_path	
	#	}
	#	glb_file_path: {	
	#		collection_name:{
	#			id: collection_id
	#			collections: [sub_collection_name]
	#			meshes: [single_item_collection_id]
	#		}
	#		sub_collection_name:{
	#			id: sub_collection_id
	#			collections: [etc]
	#			meshes: [etc]
	#		}
	#	}
	#	"hlods": {
	#		hlod_name:{
	#			"baker": path_to_baker_scene.tscn
	#		}
	#	}
	var asset_library = MAssetTable.get_singleton()	
	if not "glb_paths" in asset_library.import_info.keys():
		asset_library.import_info["glb_paths"] = {}
	if not glb_path in asset_library.import_info.keys():
		asset_library.import_info[glb_path] = {}
	var result: Array[int] = [] #array of collection ids
	for collection_name in collections_to_import.keys():				
		var collection_id = asset_library.collection_get_id(collection_name)				
		if collection_id == -1:
			collection_id = asset_library.collection_create(collection_name)						
		else:
			asset_library.collection_remove_all_items(collection_id)
			asset_library.collection_remove_all_sub_collection(collection_id)
		#print("collection ", collection_id, " is ", collection_name)
		asset_library.import_info[glb_path][collection_name] = {"id": collection_id}
		asset_library.import_info["glb_paths"][collection_id] = glb_path
		
		if "collections" in collections_to_import[collection_name] and len(collections_to_import[collection_name].collections.keys())>0:
			var collection_names = collections_to_import[collection_name].collections.keys()
			asset_library.import_info[glb_path][collection_name]["collections"] = collection_names
			var sub_collection_ids = glb_import_collections(collections_to_import[collection_name].collections, glb_path)	
			result.append_array(sub_collection_ids)
			#if "transform" in collections_to_import[collection_name].collections.keys():						
			for i in len(sub_collection_ids):				
				var transform = collections_to_import[collection_name].collections[collection_names[i]].transform
				asset_library.collection_add_sub_collection(collection_id, sub_collection_ids[i], transform)
				print(asset_library.collection_get_sub_collections(collection_id))
		if "meshes" in collections_to_import[collection_name]:
			var data = mesh_item_import_from_nodes(collections_to_import[collection_name].meshes)						
			asset_library.import_info[glb_path][collection_name]["meshes"] = data.collection_ids			
			for i in data.collection_ids.size():										
				asset_library.import_info["glb_paths"][data.collection_ids[i]] = glb_path
				#asset_library.collection_add_sub_collection(collection_id, data.collection_ids[i],data.transforms[i])
				#asset_library.collection_add_item(collection_id, MAssetTable.MESH, data.ids[i],data.transforms[i])					
			result.push_back(collection_id)
		if "hlods" in collections_to_import[collection_name].keys():
			for hlod in collections_to_import[collection_name].hlods:
				pass
	asset_library.save()
	return result

static func collection_parse_name(name):
	return name.left(len(name) - len(name.split("_")[-1])-1).to_lower()
	
static func glb_show_import_window(glb_path, collections_to_import):
	var popup = Window.new()
	popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	popup.wrap_controls = true	
	EditorInterface.get_editor_main_screen().add_child(popup)
	var panel = preload("res://addons/m_terrain/asset_manager/ui/import_window.tscn").instantiate()
	panel.file_name = glb_path
	panel.collections_to_import	= collections_to_import
	popup.add_child(panel)
	popup.popup_centered(Vector2i(600,480))
	#asset_library.save()

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
		result.lod = int(name.get_slice("_lod", 1).get_slice("_", 0))
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
