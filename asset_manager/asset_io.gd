@tool
class_name AssetIO extends Object

const LOD_COUNT = 8

#region GLB	
static func glb_load(asset_library:MAssetTable, path, paths_loaded=[]):
	glb_update_objects(asset_library, path)

static func glb_export(root_node, path = str("res://asset_manager/export/", root_node.name.to_lower(), ".glb") ):
	var gltf_document= GLTFDocument.new()
	var gltf_save_state = GLTFState.new()
	gltf_document.append_from_scene(root_node, gltf_save_state)
	#var path = "res://asset_manager/TEST_EXPORT.gltf"	
	var error = gltf_document.write_to_filesystem(gltf_save_state, path)	

static func glb_update_objects(asset_library:MAssetTable, path):
	var gltf_document = GLTFDocument.new()
	if not Engine.is_editor_hint():
		GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	var gltf_state = GLTFState.new()
	gltf_document.append_from_file(path,gltf_state)
	var current_collection
	var scene = gltf_document.generate_scene(gltf_state).get_children()	
	for object in scene:
		var extras = object.get_meta("extras")
		if "static_body" in extras:
			var collection_id = asset_library.collection_get_id(object.name.to_lower())
			if collection_id == -1:			
				collection_id = asset_library.collection_create(object.name.to_lower())								
			var mesh_children = []						
			asset_library.collection_remove_all_items(collection_id)
			for child in object.get_children():
				if child is ImporterMeshInstance3D:
					mesh_children.push_back(child)					
				else:
					var child_extras = child.get_meta("extras")
					if "collision_box" in child_extras:
						pass
					elif "collision_sphere" in child_extras:
						pass
					elif "collection_id" in child_extras:
						asset_library.collection_add_sub_collection(collection_id, child_extras.collection_id, child.transform)						
			var data = import_mesh_item_from_nodes(asset_library, mesh_children)			
			for i in data.ids.size():				
				asset_library.collection_add_item(collection_id, MAssetTable.MESH, data.ids[i],data.transforms[i])			

static func import_mesh_item_from_nodes(asset_library:MAssetTable, nodes):
	var mesh_item_ids = []
	var mesh_item_names = []
	var mesh_item_transforms = []
	for child:Node in nodes:			
		if not child.get_parent(): continue				
		if "_lod_" in child.name:				
			var all_mesh_lod_nodes = child.get_parent().find_children(str(child.name.split("_lod_")[0], "_lod_*"))												
			all_mesh_lod_nodes = all_mesh_lod_nodes.filter(func(a): if a is MeshInstance3D or a is ImporterMeshInstance3D: return true)
			all_mesh_lod_nodes.sort_custom(func(a,b): return true if int(a.name.to_lower().split("_lod_")[1]) < int(b.name.to_lower().split("_lod_")[1]) else false)							
			if child in all_mesh_lod_nodes:					
				if child != all_mesh_lod_nodes[0]:
					#print("mesh lod not first but: ", all_mesh_lod_nodes.find(child))
					continue							
				#print("mesh lod first but: ", child.name, " in ", all_mesh_lod_nodes)
					
				var mesh_hash_array = []				
				var meshes = []
				#Save Meshes using hash
				for mesh_node in all_mesh_lod_nodes:
					var current_lod = int(mesh_node.name.to_lower().split("_lod_")[1])
					var mesh = mesh_node.mesh if mesh_node is MeshInstance3D else mesh_node.mesh.get_mesh()																		
					var all_surfaces = []
					for i in mesh.get_surface_count():
						all_surfaces.push_back(mesh.surface_get_arrays(i))
					var mesh_hash = hash(all_surfaces)						
					var mesh_save_path = str("res://addons/m_terrain/asset_manager/example_asset_library/import/",mesh_hash, ".res")
					if not FileAccess.file_exists(mesh_save_path):
						mesh.resource_path = mesh_save_path
						ResourceSaver.save(mesh, mesh_save_path)
					else:
						mesh = load(mesh_save_path)
					while len(mesh_hash_array) < current_lod:
						if len(mesh_hash_array) == 0:
							mesh_hash_array.push_back(0)
						else:
							mesh_hash_array.push_back(mesh_hash_array.back())
					mesh_hash_array.push_back(mesh_hash)
					meshes.push_back(mesh)
								
				#Fill empty lod with last mesh
				var last_mesh = mesh_hash_array[-1]
				while mesh_hash_array.size() < LOD_COUNT:
					mesh_hash_array.push_back(mesh_hash_array[-1])
									
				#Add Mesh Item								
				var mesh_item_id = asset_library.mesh_item_find_by_info(mesh_hash_array, mesh_hash_array.map(func(a): return 0), mesh_hash_array.map(func(a): return -1))
				if mesh_item_id == -1:
					print("doesn't have mesh item")
					mesh_item_id = asset_library.mesh_item_add(mesh_hash_array, mesh_hash_array.map(func(a): return 0), mesh_hash_array.map(func(a): return -1))										
				else:
					print("has mesh item", mesh_item_id)
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
			asset_library.collection_add_item(collection_id, MAssetTable.MESH, mesh_item_ids[i], Transform3D())
	return {"ids":mesh_item_ids, "transforms": mesh_item_transforms}

#endregion
#region Mesh Item
static func mesh_item_get_mesh_resources(mesh_id): #return meshes[.res]		
	var asset_library = load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))	
	if asset_library.has_mesh_item(mesh_id):
		var meshes = []	
		var data = asset_library.mesh_item_get_info(mesh_id)		
		for mesh_hash in data.mesh:		
			var path = str("res://addons/m_terrain/asset_manager/example_asset_library/import/", mesh_hash, ".res")			
			if FileAccess.file_exists(path):
				meshes.push_back(load(path))
			else:
				meshes.push_back(null)
		return meshes
		
static func mesh_item_save_from_resources(mesh_id, meshes, materials)->int:	
	var asset_library = load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))		
	var mesh_hash_array = []	
	var mesh_hash_index_array = []
	var mesh_hash_index = 0
	
	for mesh in meshes:				
		var mesh_hash = hash_mesh(mesh)
		var is_saved = false
		while not is_saved:
			var mesh_save_path = str("res://addons/m_terrain/asset_manager/example_asset_library/import/",mesh_hash,".res")
			if not FileAccess.file_exists(mesh_save_path):
				mesh.resource_path = mesh_save_path
				ResourceSaver.save(mesh, mesh_save_path)
				is_saved = true
				mesh_hash_index_array.push_back(mesh_hash_index)
			else:			
				var existing_mesh = load(mesh_save_path)			
				var existing_mesh_hash = hash_mesh(existing_mesh)						
				if existing_mesh_hash == mesh_hash:
					mesh_hash_index_array.push_back(mesh_hash_index)
					is_saved = true
				else:								
					mesh_hash_index += 1					
		mesh_hash_array.push_back(mesh_hash)
		
	var material_hash_array = []
	var material_hash_index_array = []
	var material_hash_index = 0
	for material in materials:		
		var material_hash = hash_material(material)
		var is_saved = false
		while not is_saved:					
			var material_save_path = str("res://addons/m_terrain/asset_manager/example_asset_library/import/",material_hash, "_", material_hash_index, ".res")			
			if not FileAccess.file_exists(material_save_path):
				material.resource_path = material_save_path
				ResourceSaver.save(material, material_save_path)
				is_saved = true
				material_hash_index_array.push_back(material_hash_index)
			else:			
				var existing_material = load(material_save_path)			
				var existing_material_hash = hash_material(existing_material)						
				if existing_material_hash == material_hash:
					mesh_hash_index_array.push_back(mesh_hash_index)
					is_saved = true
				else:								
					mesh_hash_index += 1					
		material_hash_array.push_back(material_hash)
	if asset_library.has_mesh_item(mesh_id):
		asset_library.mesh_item_update(mesh_id, mesh_hash_array, mesh_hash_index_array, material_hash_array,material_hash_index_array )
	else:
		mesh_id = asset_library.mesh_item_add(mesh_hash_array, mesh_hash_index_array, material_hash_array,material_hash_index_array )
	return mesh_id

static func hash_mesh(mesh):
	var all_surfaces = []
	for i in mesh.get_surface_count():
		all_surfaces.push_back(mesh.surface_get_arrays(i))
	return hash(all_surfaces)

static func hash_material(material):	
	return hash(material)
#endregion
#region Collection
static func collection_save_from_nodes(root_node) -> int: #returns collection_id
	var asset_library:MAssetTable = load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))		
	if root_node is MOctMesh:		
		var material_overrides = root_node.get_meta("material_overrides") if root_node.has_meta("material_overrides") else []	
		var mesh_id = root_node.get_meta("mesh_id") if root_node.has_meta("mesh_id") else -1
		mesh_id = mesh_item_save_from_resources(mesh_id, root_node.mesh_lod.meshes, material_overrides)		
		root_node.set_meta("mesh_id", mesh_id)
		root_node.notify_property_list_changed()
		return root_node.get_meta("collection_id")
	else:		
		var collection_id = root_node.get_meta("collection_id") 
		if collection_id == -1:	return collection_id
		asset_library.collection_remove_all_items(collection_id)
		for child in root_node.get_children():					
			if child.has_meta("mesh_id"):			
				var mesh_id = child.get_meta("mesh_id")
				asset_library.collection_add_item(collection_id, MAssetTable.MESH, mesh_id, child.transform)							
			elif child is CollisionShape3D:
				pass
			elif child.has_meta("mesh_id"):
				var sub_collection_id = child.get_meta("mesh_id")
				asset_library.collection_add_sub_collection(collection_id, sub_collection_id, child.transform)								
		return collection_id
#endregion
	
	
	#assert(not path in paths_loaded)
	#paths_loaded.push_back(path)
	#var gltf_document = GLTFDocument.new()
	#if not Engine.is_editor_hint():
		#GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	#var gltf_state = GLTFState.new()
	#gltf_document.append_from_file(path,gltf_state)
	#var current_collection
	#var scene = gltf_document.generate_scene(gltf_state).get_child(0)	
	#var nodes = [scene]
	#nodes.append_array(scene.get_children())
	#for child:Node in nodes:			
		#if child is ImporterMeshInstance3D:	
			#if not child.get_parent(): continue				
			#if "_lod_" in child.name:				
				#var all_mesh_lod_nodes = child.get_parent().find_children(str(child.name.split("_lod_")[0], "_lod_*"))												
				#all_mesh_lod_nodes = all_mesh_lod_nodes.filter(func(a): if a is MeshInstance3D or a is ImporterMeshInstance3D: return true)
				#all_mesh_lod_nodes.sort_custom(func(a,b): return true if int(a.name.to_lower().split("_lod_")[1]) < int(b.name.to_lower().split("_lod_")[1]) else false)							
				#if child in all_mesh_lod_nodes:					
					#if child != all_mesh_lod_nodes[0]:
						##print("mesh lod not first but: ", all_mesh_lod_nodes.find(child))
						#continue							
					##print("mesh lod first but: ", child.name, " in ", all_mesh_lod_nodes)
						#
					#var mesh_hash_array = []
					#var meshes = []
					##Save Meshes using hash
					#for mesh_node in all_mesh_lod_nodes:
						#var current_lod = int(mesh_node.name.to_lower().split("_lod_")[1])
						#var mesh = mesh_node.mesh if mesh_node is MeshInstance3D else mesh_node.mesh.get_mesh()																		
						#var all_surfaces = []
						#for i in mesh.get_surface_count():
							#all_surfaces.push_back(mesh.surface_get_arrays(i))
						#var mesh_hash = hash(all_surfaces)						
						#var mesh_save_path = str("res://addons/m_terrain/asset_manager/example_asset_library/import/",mesh_hash, ".res")
						#if not FileAccess.file_exists(mesh_save_path):
							#mesh.resource_path = mesh_save_path
							#ResourceSaver.save(mesh, mesh_save_path)
						#else:
							#mesh = load(mesh_save_path)
						#while len(mesh_hash_array) < current_lod:
							#if len(mesh_hash_array) == 0:
								#mesh_hash_array.push_back(0)
							#else:
								#mesh_hash_array.push_back(mesh_hash_array.back())
						#mesh_hash_array.push_back(mesh_hash)
						#meshes.push_back(mesh)
									#
					#var mesh_item_id = asset_library.mesh_item_find_by_info(mesh_hash_array, mesh_hash_array.map(func(a): return 0), mesh_hash_array.map(func(a): return -1), mesh_hash_array.map(func(a): return 0))
					#if mesh_item_id == -1:
						#print("doesn't have mesh item")
						#mesh_item_id = asset_library.mesh_item_add(mesh_hash_array, mesh_hash_array.map(func(a): return 0), mesh_hash_array.map(func(a): return -1), mesh_hash_array.map(func(a): return 0))										
					#else:
						#print("has mesh item")
					#if child.get_parent() is Asset_Collection_Node:
						#var collection_id = child.get_parent().collection_id
						#if not mesh_item_id in asset_library.collection_get_mesh_items_ids(collection_id):							
							#asset_library.collection_add_item(collection_id, MAssetTable.MESH, mesh_item_id, child.transform)															
							#print(asset_library.collection_get_name(collection_id))
							#print(asset_library.collection_get_mesh_items_ids(collection_id))
					#else:
						#print(child.get_parent() )
					#var moct_mesh = MOctMesh.new()
					#for meta in child.get_meta_list():
						#moct_mesh.set_meta(meta, child.get_meta(meta))
					#var mmesh_lod = MMeshLod.new()					
					#mmesh_lod.meshes = meshes												
					#moct_mesh.mesh_lod = mmesh_lod
					#child.replace_by.call_deferred(moct_mesh)
					#moct_mesh.name = child.name
					#moct_mesh.transform = child.transform				
		#if child.has_meta("extras"):						
			#var extras = child.get_meta("extras")			
			#if "static_body" in extras:				
				#var collection_id = -1
				#if "collection" in extras:					
					#if asset_library.has_collection(extras["collection"]):
						#collection_id = extras["collection"]
				#else:					
					#collection_id = asset_library.collection_get_id(child.name+ "_Xc")
					#print(collection_id)
				#if collection_id == -1:					
					#collection_id = asset_library.collection_create(child.name)
				#child.set_meta("collection_id", collection_id)
				#child.set_script(preload("res://addons/m_terrain/asset_manager/collection.gd"))						
				#child.collection_id = collection_id
			#elif "collection" in extras:		
				#child.set_script(preload("res://addons/m_terrain/asset_manager/collection.gd"))						
				#child.collection_id = extras.collection
				#if child.get_child_count() > 0:
					#var collection_id = asset_library.collection_create(child.name) if not asset_library.has_collection(extras.collection) else extras.collection
					#child.set_meta("collection_id", collection_id)					
				#elif child.get_parent().has_meta("collection_id"):
					#asset_library.collection_add_sub_collection(child.get_parent().get_meta("collection_id"), extras["collection"], child.transform)				
					#
			#elif "hlod" in extras:
				#if child == scene: continue
				#for grandchild in child.get_children():
					#child.remove_child(grandchild)
					#grandchild.queue_free()
				#child.set_script(preload("res://addons/m_terrain/asset_manager/hlod_baker.gd"))
				#child.scene_file_path = ""#asset_library.hlod_get_baker_path()
					#
			#elif "glb" in extras:
				#var glb_path = "res://addons/m_terrain/asset_manager/example_asset_library/export/" + extras["glb"]
				#print(glb_path)
				#update_from_glb(asset_library, glb_path, paths_loaded.duplicate())
				#child.set_script(preload("res://addons/m_terrain/asset_manager/collection.gd"))
				##child.collection_id = asset_library.collection_get_id()
			#else:
				#print(extras)
	#if scene.has_meta("extras"):
		#var extras = scene.get_meta("extras")
		#if "hlod" in extras:
			#for child in scene.find_children("*"):
				#child.owner = scene
			#scene.set_script(preload("res://addons/m_terrain/asset_manager/hlod_baker.gd"))
			#var packed_scene = PackedScene.new()
			#packed_scene.pack(scene)			
			#ResourceSaver.save(packed_scene, "res://addons/m_terrain/asset_manager/example_asset_library/hlods/" + scene.name + ".tscn")
	#scene.queue_free()
	#ResourceSaver.save(asset_library, asset_library.resource_path)	
	#return
	
#func get_root_node_name_from_glb(path):
	#var gltf_document = GLTFDocument.new()
	#var gltf_state = GLTFState.new()
	#gltf_document.append_from_file(path,gltf_state)
	#return gltf_state.get_nodes()[gltf_state.root_nodes[0]].original_name

static func reload_collection(node, collection_id):
	var overrides = node.get_meta("overrides") if node.has_meta("overrides") else {}
	var new_root = collection_instantiate(collection_id)	
	for node_name in overrides:	
		new_root.get_node(node_name).transform = overrides[node_name].transform					

	if is_instance_valid(new_root):
		var old_meta = {}
		for meta in node.get_meta_list():
			old_meta[meta] = node.get_meta(meta)
		node.replace_by(new_root)
		new_root.name = node.name
		node.free()		
		for meta in old_meta:
			new_root.set_meta(meta, old_meta[meta])		
	else:
		new_root = null
	return new_root
	
static func collection_instantiate(collection_id)->Node3D:
	var asset_library:MAssetTable = load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))				
	if not asset_library.has_collection(collection_id):
		print("collection doesn't exist")
		#TODO: CHECK IF THERE"S A GLB THAT NEEDS TO BE LOADED
		return null
	var node
	if collection_id in asset_library.tag_get_collections(0):
		node = MOctMesh.new()
		var mesh_id = asset_library.collection_get_mesh_items_ids(collection_id)[0]
		node.set_meta("mesh_id", mesh_id)
		node.set_meta("collection_id", collection_id)
		node.mesh_lod = MMeshLod.new()	
		node.mesh_lod.meshes = mesh_item_get_mesh_resources(mesh_id)
		node.name = asset_library.collection_get_name(collection_id)									
		return node
	else:
		node = Node3D.new()
		node.name = asset_library.collection_get_name(collection_id)							
		node.set_meta("collection_id", collection_id)
		var item_ids = asset_library.collection_get_mesh_items_ids(collection_id)		
		var items_info = asset_library.collection_get_mesh_items_info(collection_id)
		for i in item_ids.size():						
			var mesh_item = MOctMesh.new()			
			var mesh_id = item_ids[i]
			mesh_item.set_meta("mesh_id", mesh_id)			
			var single_item_collection_ids = asset_library.tag_get_collections_in_collections(asset_library.mesh_item_find_collections(mesh_id), 0)			
			if len(single_item_collection_ids) == 0: push_error("single item collection doesn't exist! mesh_id: ", mesh_id)
			mesh_item.set_meta("collection_id", single_item_collection_ids[0])								
			var mesh_item_name = asset_library.collection_get_name(single_item_collection_ids[0])
			mesh_item.mesh_lod = MMeshLod.new()	
			mesh_item.mesh_lod.meshes = mesh_item_get_mesh_resources(mesh_id)															
			mesh_item.transform = items_info[i].transform									
			node.add_child(mesh_item)
			mesh_item.name = mesh_item_name
		var sub_collections = asset_library.collection_get_sub_collections(collection_id)
		for id in sub_collections:
			var sub_collection = Node3D.new()
			sub_collection.set_meta("collection_id", id)
			node.add_child(sub_collection)		
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
		print("loaded collection for ", root.name)		
		var new_root = reload_collection(root, root.get_meta("collection_id"))		
		return new_root if is_instance_valid(new_root) else null
	else:
		for child in root.get_children():
			if child.has_meta("collection_id"):
				reload_collection(child, child.get_meta("collection_id"))	
		return root

#static func collection_prompt_save_changes(nodes:Array):
	#var asset_library:MAssetTable = load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))
	#var popup = preload("res://addons/m_terrain/asset_manager/ui/save_changes_popup.tscn").instantiate()
	#EditorInterface.get_editor_main_screen().add_child(popup)
	#popup.name = "save_changes_popup"
	#popup.focus_exited.connect(func():								
		#popup.queue_free()
	#)	
	#popup.prompt_label.text = str("Save Changes to ", nodes.map( func(a): return a.name.trim_suffix("*")), "?")
	#popup.continue_button.pressed.connect(popup.queue_free)
	#popup.discard_button.pressed.connect(func():
		#for child in nodes:
			#AssetIO.reload_collection(child, child.get_meta("collection_id"))
		#popup.queue_free()
	#)
	#popup.new_button.pressed.connect(func():	
		#for child in nodes:
			#child.set_meta("collection_id", asset_library.collection_create(child.name))
			#AssetIO.collection_save_from_nodes(child)
		#popup.queue_free()		
	#)
	#popup.override_button.pressed.connect(func():
		#for child in nodes:
			#child.set_meta("overrides", {
				#"transform":child.transform									
			#})
		#popup.queue_free()
	#)
	#popup.update_button.pressed.connect(func():								
		#for child in nodes:
			#AssetIO.collection_save_from_nodes(child)
		#popup.queue_free()
	#)							
	#popup.popup_centered()
