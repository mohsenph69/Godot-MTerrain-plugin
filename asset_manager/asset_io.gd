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
	
#Load glb file containing one or more assets
static func glb_load(path):
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	var gltf_document = GLTFDocument.new()
	if not Engine.is_editor_hint():		
		GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	var gltf_state = GLTFState.new()	
	gltf_document.append_from_file(path,gltf_state)		
	var scene = gltf_document.generate_scene(gltf_state).get_children()	
	glb_update_objects(scene, path)
	
#Load glb file with sub-scenes and recursive loading
static func glb_load_with_subscenes(path, paths_loaded=[]):		
	if path in paths_loaded: return	
	var asset_library:MAssetTable = MAssetTable.get_singleton()
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
			glb_load_with_subscenes(new_path, paths_loaded)		
		else:
			push_error("trying to load sub-glb that doesn't exist: ", new_path)
	var scene = gltf_document.generate_scene(gltf_state).get_children()	
	glb_update_objects(scene, path)
		
#Parse GLB file and update asset library
static func glb_update_objects(scene:Array, glb_path):		
	var asset_library:MAssetTable = MAssetTable.get_singleton()	
	for object: Node3D in scene:		
		var extras = object.get_meta_list() #("extras")		
		if object is ImporterMeshInstance3D:
			#Import as mesh asset with single lod, ignore transform
			if not "_lod_" in object.name:
				object.name += "_lod_0"
			var data = import_mesh_item_from_nodes([object])												
		elif "_hlod" in object.name:							
			object.set_script(preload("res://addons/m_terrain/asset_manager/hlod_baker.gd"))											
			var mesh_children = []
			for child in object.get_children():				
				child.owner = object
				if child is ImporterMeshInstance3D:
					mesh_children.push_back(child)					
				else:
					#Check if collection exists
					var collection_id = asset_library.collection_get_id( child.name.split(".")[0] )
					if collection_id != -1:						
						var node = collection_instantiate(collection_id)						
						object.add_child(node)
						node.owner = object
					elif "_hlod" in child.name:
						var node = MHlodScene.new()
						#node.hlod = load()
						child.add_sibling(node)
						child.get_parent().remove_child(child)						
						node.name = child.name
						node.owner = object
						child.queue_free()						
			var data = import_mesh_item_from_nodes(mesh_children)			
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
		else: 
			var collection_id = asset_library.collection_get_id(object.name.split(".")[0])			
			if collection_id == -1:			
				print("collection ", object.name.split(".")[0], " does not exist yet")
				if "glb" in extras:					
					collection_id = asset_library.collection_get_id(glb_get_root_node_name("res://addons/m_terrain/asset_manager/example_asset_library/export/" + object.get_meta("glb")))
				if collection_id == -1:									
					var collection_name = object.name.to_lower()
					collection_id = asset_library.collection_get_id(collection_name)
					if collection_id == -1:
						collection_id = asset_library.collection_create(collection_name)			
						
			var mesh_children = []						
			asset_library.collection_remove_all_items(collection_id)
			for child in object.get_children():
				if "_lod_" in child.name:
					mesh_children.push_back(child)					
				else:
					var child_extras = child.get_meta_list()
					if "collision_box" in child_extras:
						pass
					elif "collision_sphere" in child_extras:
						pass
					elif "collection_id" in child_extras:
						asset_library.collection_add_sub_collection(collection_id, child.get_meta(collection_id), child.transform)
			var data = import_mesh_item_from_nodes(mesh_children)			
			for i in data.ids.size():				
				asset_library.collection_add_item(collection_id, MAssetTable.MESH, data.ids[i],data.transforms[i])					
	var popup = Window.new()
	popup.wrap_controls = true	
	EditorInterface.get_editor_main_screen().add_child(popup)
	var panel = preload("res://addons/m_terrain/asset_manager/ui/import_window.tscn").instantiate()
	panel.file_name = glb_path
	panel.nodes	= scene
	popup.add_child(panel)
	popup.popup_centered(Vector2i(600,480))
	#asset_library.save()
	
static func import_mesh_item_from_nodes(nodes, ignore_transform = true):	
	var asset_library := MAssetTable.get_singleton()
	var mesh_item_ids = []
	var mesh_item_names = []
	var mesh_item_transforms = []
	var sibling_ids = []
		
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
				var mesh_item_array = []								
				var meshes = []						
				#Save Meshes using hash
				for mesh_node in all_mesh_lod_nodes:					
					var current_lod = int(mesh_node.name.to_lower().split("_lod_")[1])
					var mesh:Mesh
					if mesh_node is MeshInstance3D:
						mesh = mesh_node.mesh 
					elif mesh_node is ImporterMeshInstance3D:
						mesh = mesh_node.mesh.get_mesh()						
					else:						
						mesh = null					
					if mesh:																																
						var mesh_save_path = asset_library.mesh_get_path(mesh)																
						if FileAccess.file_exists(mesh_save_path):
							mesh.take_over_path(mesh_save_path)
						else:
							ResourceSaver.save(mesh, mesh_save_path)
											
					while len(mesh_item_array) < current_lod:
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
					#print("doesn't have mesh item")
					mesh_item_id = asset_library.mesh_item_add( mesh_item_array, material_ids)										
				else:	
					asset_library.mesh_item_update(mesh_item_id, mesh_item_array, material_ids)		
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
			var transform = Transform3D() if ignore_transform else mesh_item_transforms[i]
			asset_library.collection_add_item(collection_id, MAssetTable.MESH, mesh_item_ids[i], transform)
	return {"ids":mesh_item_ids, "transforms": mesh_item_transforms, "sibling_ids": sibling_ids}
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
				print("added subcollection with position ", child.transform.origin)
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
