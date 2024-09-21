class_name Asset_Manager_IO extends Object

static func get_asset_library():	
	if not ProjectSettings.has_setting("addons/m_terrain/asset_libary_path"):
		ProjectSettings.set_setting("addons/m_terrain/asset_libary_path", "res://addons/m_terrain/asset_manager/example_asset_library/asset_library.res")	
	var path = ProjectSettings.get_setting("addons/m_terrain/asset_libary_path")
	var asset_library
	if FileAccess.file_exists(path):
		asset_library = load(path)
	if not asset_library is MAssetTable:			
		asset_library = MAssetTable.new()
		ResourceSaver.save(asset_library, path)
	return asset_library
	
static func export_to_glb(root_node, path = str("res://asset_manager/export/", root_node.name.to_lower(), ".glb") ):
	var gltf_document= GLTFDocument.new()
	var gltf_save_state = GLTFState.new()
	gltf_document.append_from_scene(root_node, gltf_save_state)
	#var path = "res://asset_manager/TEST_EXPORT.gltf"	
	var error = gltf_document.write_to_filesystem(gltf_save_state, path)	

static func update_objects_from_glb(asset_library:MAssetTable, path):
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
			#asset_library.collection_add_item(collection_id, MAssetTable.MESH, mesh_id, child.transform)						

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
								
				#Add Mesh Item
				var mesh_item_id = asset_library.mesh_item_find_by_info(mesh_hash_array, mesh_hash_array.map(func(a): return 0), mesh_hash_array.map(func(a): return -1), mesh_hash_array.map(func(a): return 0))
				if mesh_item_id == -1:
					print("doesn't have mesh item")
					mesh_item_id = asset_library.mesh_item_add(mesh_hash_array, mesh_hash_array.map(func(a): return 0), mesh_hash_array.map(func(a): return -1), mesh_hash_array.map(func(a): return 0))										
				else:
					print("has mesh item", mesh_item_id)
				mesh_item_ids.push_back(mesh_item_id)				
				mesh_item_names.push_back(child.name.split("_lod_")[0].to_lower())
				mesh_item_transforms.push_back(child.transform)
	#Create single item collections	
	for i in mesh_item_ids.size():
		var name = mesh_item_names[i] + "_mesh"
		var collection_id = asset_library.collection_get_id(name)
		if collection_id == -1:
			collection_id = asset_library.collection_create(name)
			asset_library.collection_add_tag(collection_id,0)
			asset_library.collection_add_item(collection_id, MAssetTable.MESH, mesh_item_ids[i], Transform3D())
	return {"ids":mesh_item_ids, "transforms": mesh_item_transforms}
	
	
	
static func update_from_glb(asset_library:MAssetTable, path, paths_loaded=[]):
	update_objects_from_glb(asset_library, path)
	return
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
