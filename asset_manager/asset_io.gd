@tool
class_name AssetIO extends Object

############################################
# AssetIO contains all static functions for importing/exporting glb files
# 1. 
#
#
#
#
#

const LOD_COUNT = 8

#region GLB	
static func glb_get_root_node_name(path):
	var gltf_document = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	gltf_document.append_from_file(path,gltf_state)
	return gltf_state.get_nodes()[gltf_state.root_nodes[0]].original_name

static func glb_export(root_node:Node3D, path = str("res://addons/m_terrain/asset_manager/example_asset_library/export/", root_node.name.to_lower(), ".glb") ):
	var asset_library:MAssetTable = MAssetTable.get_singelton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))		
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
	var error = gltf_document.write_to_filesystem(gltf_save_state, path)	
	#print("exported to ", path)
	node.queue_free()	
	
#Load glb file containing one or more assets
static func glb_load_asset(path):
	var asset_library:MAssetTable = MAssetTable.get_singelton()
	var gltf_document = GLTFDocument.new()
	if not Engine.is_editor_hint():		
		GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	var gltf_state = GLTFState.new()	
	gltf_document.append_from_file(path,gltf_state)		
	var scene = gltf_document.generate_scene(gltf_state).get_children()	
	glb_update_objects(scene, path)
	
#Load glb file with sub-scenes and recursive loading
static func glb_load(path, paths_loaded=[]):		
	if path in paths_loaded: return	
	var asset_library:MAssetTable = MAssetTable.get_singelton()
	paths_loaded.push_back(path)	
	var gltf_document = GLTFDocument.new()
	if not Engine.is_editor_hint():		
		GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	var gltf_state = GLTFState.new()	
	gltf_document.append_from_file(path,gltf_state)	
	var nodes_with_glb = gltf_state.json.nodes.filter(func(a): return "extras" in a and "glb" in a.extras)
	for node in nodes_with_glb:		
		var new_path = "res://addons/m_terrain/asset_manager/example_asset_library/export/" + node.extras.glb 		
		if FileAccess.file_exists(new_path):
			glb_load(new_path, paths_loaded)		
		else:
			push_error("trying to load sub-glb that doesn't exist: ", new_path)
	var scene = gltf_document.generate_scene(gltf_state).get_children()	
	glb_update_objects(scene, path)
	
static func get_glb_table()->Dictionary:
	var json_path = "res://massets/collection_to_glb_map.json"	
	if not FileAccess.file_exists(json_path):
		save_glb_table({})		
	return JSON.parse_string( FileAccess.get_file_as_string(json_path) )	
	
static func save_glb_table(data):
	var json_path = "res://massets/collection_to_glb_map.json"	
	var file = FileAccess.open(json_path, FileAccess.WRITE)
	file.store_string( JSON.stringify(data) )		
	
#Parse GLB file and update asset library
static func glb_update_objects(scene, glb_path):		
	var asset_library:MAssetTable = MAssetTable.get_singelton()
	var glb_table = get_glb_table()
	for object: Node3D in scene:		
		var extras = object.get_meta_list() #("extras")		
		if "static_body" in extras:
			var collection_id = object.get_meta("collection_id") if object.has_meta("collection_id") else -1			
			if collection_id == -1:			
				if "glb" in extras:					
					collection_id = asset_library.collection_get_id(glb_get_root_node_name("res://addons/m_terrain/asset_manager/example_asset_library/export/" + object.get_meta("glb")))
				if collection_id == -1:									
					var collection_name = object.name.to_lower()
					collection_id = asset_library.collection_get_id(collection_name)
					if collection_id == -1:
						collection_id = asset_library.collection_create(collection_name)
			glb_table[collection_id] = glb_path
						
			var mesh_children = []						
			asset_library.collection_remove_all_items(collection_id)
			for child in object.get_children():
				if child is ImporterMeshInstance3D:
					mesh_children.push_back(child)					
				else:
					var child_extras = child.get_meta_list()
					if "collision_box" in child_extras:
						pass
					elif "collision_sphere" in child_extras:
						pass
					elif "collection_id" in child_extras:
						asset_library.collection_add_sub_collection(collection_id, child.get_meta(collection_id), child.transform)
			var data = import_mesh_item_from_nodes(asset_library, mesh_children)			
			for i in data.ids.size():				
				asset_library.collection_add_item(collection_id, MAssetTable.MESH, data.ids[i],data.transforms[i])			
		if "hlod_id" in extras:			
			object.set_meta("hlod_id", object.get_meta("hlod_id"))
			object.set_script(preload("res://addons/m_terrain/asset_manager/hlod_baker.gd"))
			object.set_meta("glb", glb_path.split("/")[-1])
			var mesh_children = []
			for child in object.find_children("*", "Node3D", true, false):
				child.owner = object
				if child is ImporterMeshInstance3D:
					mesh_children.push_back(child)					
				if child.has_meta("extras"):				
					var child_extras = child.get_meta_list()
					if "collection" in child_extras:
						child.set_meta("collection_id", child.get_meta("collection"))
					elif "hlod_id" in child_extras:
						if "glb" in child_extras:
							var path = "res://addons/m_terrain/asset_manager/example_asset_library/hlods/"
							path += glb_get_root_node_name("res://addons/m_terrain/asset_manager/example_asset_library/export/" + child.get_meta("glb"))
							path += ".tscn"
							child.scene_file_path = path
							#var new_node = load(path).instantiate() 
							#child.add_sibling(new_node)
							#new_node.owner = object
							#new_node.scene_file_path = path
							#child.get_parent().remove_node(child)
							#for sub_child in new_node.find_children("*"):
							#	sub_child.owner = new_node
						child.set_meta("hlod_id", child.get_meta("hlod_id"))
						#child.replace_by(load( asset_library.hlod_lookup(child_extras.hlod)))
					elif "glb" in child_extras:						
						var path = "res://addons/m_terrain/asset_manager/example_asset_library/export/" + child.get_meta("glb")						
						var new_name = glb_get_root_node_name(path)												
						var collection_id = asset_library.collection_get_id(new_name.to_lower())						
						if collection_id != -1:
							child.set_meta("collection_id", collection_id)
			var data = import_mesh_item_from_nodes(asset_library, mesh_children)			
			for child in mesh_children:
				child.owner = null
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
	save_glb_table(glb_table)
	
static func import_mesh_item_from_nodes(asset_library:MAssetTable, nodes):	
	var mesh_item_ids = []
	var mesh_item_names = []
	var mesh_item_transforms = []
	var sibling_ids = []
		
	var material_table:MMaterialTable = MMaterialTable.get_singelton()
	var material_ids = []
	var existing_material_hashes = {}
	for material_id in material_table.table:		
		existing_material_hashes[hash_material( load(material_table.table[material_id]) )] = material_id
	for child:Node in nodes:			
		if not child.get_parent(): continue				
		if "_lod_" in child.name:				
			var all_mesh_lod_nodes = child.get_parent().find_children(str(child.name.split("_lod_")[0], "_lod_*"))												
			#all_mesh_lod_nodes = all_mesh_lod_nodes.filter(func(a): if a is MeshInstance3D or a is ImporterMeshInstance3D: return true)
			all_mesh_lod_nodes.sort_custom(func(a,b): return true if int(a.name.to_lower().split("_lod_")[1]) < int(b.name.to_lower().split("_lod_")[1]) else false)							
			if child in all_mesh_lod_nodes:					
				if child != all_mesh_lod_nodes[0]:
					#print("mesh lod not first but: ", all_mesh_lod_nodes.find(child))
					continue							
				#print("mesh lod first but: ", child.name, " in ", all_mesh_lod_nodes)
				sibling_ids.push_back(child.get_index())
				var mesh_hash_array = []				
				var mesh_hash_index_array = []
				var meshes = []						
				#Save Meshes using hash
				for mesh_node in all_mesh_lod_nodes:					
					var current_lod = int(mesh_node.name.to_lower().split("_lod_")[1])
					var mesh
					if mesh_node is MeshInstance3D:
						mesh = mesh_node.mesh 
					elif mesh_node is ImporterMeshInstance3D:
						mesh = mesh_node.mesh.get_mesh()						
					else:						
						mesh = null
					var mesh_hash = 0
					var mesh_index = 0				
					if mesh:												
						var all_surfaces = []
						for i in mesh.get_surface_count():
							all_surfaces.push_back(mesh.surface_get_arrays(i))
						mesh_hash = hash(all_surfaces)																					
						var mesh_save_path = MHlod.get_mesh_path(mesh_hash,mesh_index)										
						while FileAccess.file_exists(mesh_save_path):
							var existing_mesh = load(mesh_save_path)						
							var existing_mesh_hash = hash_mesh(existing_mesh)
							if existing_mesh_hash == mesh_hash:	#same mesh -> overwrite
								mesh = existing_mesh								
								break 
							else:
								mesh_index += 1
								mesh_save_path = MHlod.get_mesh_path(mesh_hash,mesh_index)					
						mesh.resource_path = mesh_save_path
						ResourceSaver.save(mesh, mesh_save_path)
											
					while len(mesh_hash_array) < current_lod:
						if len(mesh_hash_array) == 0:
							mesh_hash_array.push_back(0)
							mesh_hash_index_array.push_back(0)
							material_ids.push_back(-1)
						else:
							mesh_hash_array.push_back(mesh_hash_array.back())
							mesh_hash_index_array.push_back(mesh_hash_index_array.back())
							material_ids.push_back(material_ids.back())
					mesh_hash_array.push_back(mesh_hash)
					mesh_hash_index_array.push_back(mesh_index)
					meshes.push_back(mesh)
					
					#Deal with materials					
					
					if mesh_node.has_meta("material_id"):						
						var material_id = mesh_node.get_meta("material_id")
						if int(material_id) in material_table.table:
							material_ids.push_back( material_id )
							print("added material ", material_id)
						else:		
							print(material_id, " not in ", material_table.table, "\n", material_table.table.keys())	
							material_ids.push_back(-1)				
							push_error("mesh is trying to use material_id ", material_id, " from material table, but id doesn't exist")
					elif mesh is Mesh and mesh.get_surface_count() == 1:						
						var material:StandardMaterial3D = mesh.surface_get_material(0)									
						var material_hash = hash_material(material)												
						if material_hash in existing_material_hashes:
							var material_id = existing_material_hashes[material_hash ]
							material_ids.push_back( material_id )
							mesh.surface_set_material(0, load(material_table.table[material_id]))
						elif false:  #if name exists in material table, use that material
							pass
						else:							
							if material.resource_name == "":
								material.resource_name = str("material_", material_hash)
							var path = "res://masset/materials/" + material.resource_name + ".tres"
							ResourceSaver.save(material, path)							
							material_ids.push_back(material_table.add_material(path))						
					else:
						material_ids.push_back(-1)
					
								
				#Fill empty lod with last mesh
				var last_mesh = mesh_hash_array[-1]
				while mesh_hash_array.size() < LOD_COUNT:
					mesh_hash_array.push_back(mesh_hash_array[-1])
					mesh_hash_index_array.push_back(mesh_hash_index_array[-1])
					material_ids.push_back(material_ids[-1])
							
				#Add Mesh Item								
				var mesh_item_id = asset_library.mesh_item_find_by_info(mesh_hash_array, mesh_hash_index_array, material_ids)
				print(material_ids)
				if mesh_item_id == -1:
					#print("doesn't have mesh item")
					mesh_item_id = asset_library.mesh_item_add(mesh_hash_array, mesh_hash_index_array, material_ids)										
				else:	
					asset_library.mesh_item_update(mesh_item_id, mesh_hash_array, mesh_hash_index_array, material_ids)		
					print("has mesh item ", mesh_item_id)
				mesh_item_ids.push_back(mesh_item_id)				
				mesh_item_names.push_back(child.name.split("_lod_")[0].to_lower())
				mesh_item_transforms.push_back(child.transform)
	#Create single item collections	
	for i in mesh_item_ids.size():
		var name = mesh_item_names[i] + "_mesh"		
		var collection_ids = asset_library.tag_get_collections_in_collections(asset_library.mesh_item_find_collections(mesh_item_ids[i]),0)
		if collection_ids.size() == 0:
			var collection_id = collection_ids
			collection_id = asset_library.collection_create(name)			
			asset_library.collection_add_tag(collection_id,0)
			asset_library.collection_add_item(collection_id, MAssetTable.MESH, mesh_item_ids[i], mesh_item_transforms[i])
	return {"ids":mesh_item_ids, "transforms": mesh_item_transforms, "sibling_ids": sibling_ids}
#endregion
#region Mesh Item
static func mesh_item_get_mesh_resources(mesh_id): #return meshes[.res]		
	var asset_library = MAssetTable.get_singelton() #load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))	
	if asset_library.has_mesh_item(mesh_id):
		var meshes = []	
		var data = asset_library.mesh_item_get_info(mesh_id)		
		for mesh_hash in data.mesh:		
			var mesh_index = 0 #TODO replace with mesh index from mesh_item_get_info
			var path = MHlod.get_mesh_path(mesh_hash,mesh_index)
			if FileAccess.file_exists(path):
				meshes.push_back(load(path))
			else:
				meshes.push_back(null)
		return meshes
		
static func mesh_item_save_from_resources(mesh_id, meshes, material_ids)->int:	
	var asset_library = MAssetTable.get_singelton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))		
	var mesh_hash_array = []	
	var mesh_hash_index_array = []	
	
	for mesh in meshes:		
		var mesh_hash_index = 0		
		var mesh_hash = hash_mesh(mesh)
		var is_saved = false
		while not is_saved:
			var mesh_save_path = MHlod.get_mesh_path(mesh_hash,mesh_hash_index)
			if not FileAccess.file_exists(mesh_save_path): #File doesn't exist yet
				mesh.resource_path = mesh_save_path
				ResourceSaver.save(mesh, mesh_save_path)
				mesh_hash_index_array.push_back(mesh_hash_index)
				is_saved = true				
			else:			
				var existing_mesh = load(mesh_save_path)			
				var existing_mesh_hash = hash_mesh(existing_mesh)						
				if existing_mesh_hash == mesh_hash: #File exists, meshes are identical
					mesh_hash_index_array.push_back(mesh_hash_index)
					is_saved = true
				else:	#Hash collision: File exist, different mesh
					mesh_hash_index += 1					
		mesh_hash_array.push_back(mesh_hash)
			
	if asset_library.has_mesh_item(mesh_id):
		asset_library.mesh_item_update(mesh_id, mesh_hash_array, mesh_hash_index_array, material_ids )
	else:
		mesh_id = asset_library.mesh_item_add(mesh_hash_array, mesh_hash_index_array, material_ids )
	return mesh_id

static func hash_mesh(mesh):
	var all_surfaces = []
	for i in mesh.get_surface_count():
		all_surfaces.push_back(mesh.surface_get_arrays(i))
	return hash(all_surfaces)

static func hash_material(material):	
	if material is StandardMaterial3D:
		return hash([material.albedo_texture, material.albedo_color])
	return hash(material)
#endregion
#region Collection
static func collection_save_from_nodes(root_node) -> int: #returns collection_id	
	var asset_library:MAssetTable = MAssetTable.get_singelton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))			
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
				print("added subcollection with position ", child.transform.origin)
		return collection_id
		
static func reload_collection(node:Node3D, collection_id):
	var asset_library:MAssetTable = MAssetTable.get_singelton()# load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))				
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
	var asset_library:MAssetTable = MAssetTable.get_singelton()
	var glb_table = get_glb_table() 
	if not asset_library.has_collection(collection_id):
		print("collection doesn't exist")
		#TODO: CHECK IF THERE"S A GLB THAT NEEDS TO BE LOADED
		return null
	var node	
	if collection_id in asset_library.tag_get_collections(0):
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
			if sub_collections[i] in glb_table:
				sub_collection.set_meta("glb", glb_table[sub_collections[i]])
			sub_collection.transform = sub_collections_transforms[i]
		#for hlod in asset_library.collection_get_sub_hlods(collection_id):
			#var hlod_baker_scene = load().instantiate()
			#add_child(hlod_baker_scene)	
		if str(collection_id) in glb_table:
			node.set_meta("glb", glb_table[str(collection_id)])
			print("set glb meta for node ", node.name)
		save_glb_table(glb_table)
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
