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
static func glb_load(path, metadata={},no_window:bool=false):
	var asset_library:MAssetTable = MAssetTable.get_singleton()
	var gltf_document = GLTFDocument.new()
	if not Engine.is_editor_hint():
		GLTFDocument.register_gltf_document_extension(GLTFExtras.new())
	var gltf_state = GLTFState.new()
	gltf_document.append_from_file(path,gltf_state)
	
	asset_data = AssetIOData.new()
	asset_data.glb_path = path
	asset_data.meta_data = metadata
	#STEP 1: convert gltf file into nodes
	var scene_root = gltf_document.generate_scene(gltf_state)
	var scene = scene_root.get_children()
	generate_asset_data_from_glb(scene)
	asset_data.finalize_glb_parse()
	if asset_library.import_info.has(path):
		asset_data.add_glb_import_info(asset_library.import_info[path])
	asset_data.generate_import_tags()
	scene_root.queue_free() ## Really important otherwise memory leaks
	if no_window:
		glb_import_commit_changes()
	else:
		glb_show_import_window(asset_data)

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
			else:
				push_error(node.name," is two deep level which is not allowed")
		elif active_collection != "__root__": # can be sub collection
			asset_data.add_sub_collection(active_collection,collection_parse_name(node.name),node.transform)

static func glb_import_commit_changes():
	var asset_library = MAssetTable.get_singleton()
	### First Adding Mesh Item order matter as collection depend on mesh_item and not reverse
	var mkeys = asset_data.mesh_items.keys()
	for k in mkeys:
		var minfo = asset_data.mesh_items[k]
		if minfo["ignore"] or minfo["state"] == AssetIOData.IMPORT_STATE.NO_CHANGE:
			continue
		### Handling Remove First
		if minfo["state"] == AssetIOData.IMPORT_STATE.REMOVE:
			asset_library.mesh_item_remove(minfo["id"])
			continue
		### Other State
		asset_data.save_unsaved_meshes(k) ## now all mesh are saved with and integer ID
		var meshes = minfo["meshes"]
		var materials:PackedInt32Array
		## for now later we change
		materials.resize(meshes.size())
		materials.fill(-1)
		if minfo["state"] == AssetIOData.IMPORT_STATE.NEW:			
			var mid = asset_library.mesh_item_add(meshes,materials)
			asset_data.update_mesh_items_id(k,mid)			
		elif minfo["state"] == AssetIOData.IMPORT_STATE.CHANGE:
			if minfo["id"] == -1:
				push_error("something bad happened mesh id should not be -1")
				continue
			asset_library.mesh_item_update(minfo["id"],meshes,materials)
	####### Finish Mesh Item
	#####################################
	### commiting Collections
	#####################################
	var ckeys = asset_data.collections.keys()
	for k in ckeys:
		import_collection(k)
	#####################################
	### Adding Import Info
	#####################################
	asset_library.import_info[asset_data.glb_path] = asset_data.get_glb_import_info()
	#print("\nImport Info\n",asset_library.import_info[asset_data.glb_path])
	MAssetTable.save()

static func import_collection(glb_name:String):
	if not asset_data.collections.has(glb_name) or asset_data.collections[glb_name]["ignore"] or asset_data.collections[glb_name]["state"] == AssetIOData.IMPORT_STATE.NO_CHANGE:
		return
	asset_data.collections[glb_name]["ignore"] = true # this means this collection has been handled
	var cinfo:Dictionary = asset_data.collections[glb_name]
	var asset_library = MAssetTable.get_singleton()
	if cinfo["state"] == AssetIOData.IMPORT_STATE.REMOVE:
		if cinfo["id"] == -1:
			push_error("Invalid collection to remove")
			return
		asset_library.remove_collection(cinfo["id"])
		return
	var mesh_items = cinfo["mesh_items"]
	var cid := -1
	if cinfo["state"] == AssetIOData.IMPORT_STATE.NEW:
		cid = asset_library.collection_create(glb_name)
		asset_data.update_collection_id(glb_name,cid)
	elif cinfo["id"] != -1 and cinfo["state"] == AssetIOData.IMPORT_STATE.CHANGE:
		cid = cinfo["id"]
		asset_library.collection_clear(cid)
	else:
		push_error("Invalid collection!!!")
		return
	###### Adding Mesh Items into Collection
	for m in mesh_items:
		var mid = asset_data.get_mesh_items_id(m)
		if mid == -1:
			push_error("invalid mesh item to insert in collection ",glb_name)
			return
		asset_library.collection_add_item(cid,MAssetTable.MESH,mid,mesh_items[m])
	###### Adding Sub Collection into Collection
	var sub_collections:Dictionary = cinfo["sub_collections"]
	for sub_c_name in sub_collections:
		var sub_c_id = asset_data.get_collection_id(sub_c_name)
		## Trying to import that sub collection and hope to not stuck in infinit loop
		if sub_c_id == -1:
			import_collection(sub_c_name)
		sub_c_id = asset_data.get_collection_id(sub_c_name)
		if sub_c_id == -1:
			push_error("Invalid sub collection ",sub_c_name)
		var sub_c_transform = sub_collections[sub_c_name]
		asset_library.collection_add_sub_collection(cid,sub_c_id,sub_c_transform)
		
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
		var name_data = node_parse_name(child)
		if not name_data.name in mesh_items.keys():
			mesh_items[name_data.name] = []
		mesh_items[name_data.name].push_back(child)

	for item_name in mesh_items.keys():
		sibling_ids.push_back(mesh_items[item_name][0].get_index())
		var mesh_item_array = []
		var meshes = []
		for node in mesh_items[item_name]:
			var name_data = node_parse_name(node)
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

static func mesh_item_get_name(mesh_id):
	for i in len(asset_data.mesh_items.keys()):
		if asset_data.mesh_items.values()[i].id == mesh_id:
			return asset_data.mesh_items.keys()[i]
	return -1	

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


#IF return a dictionary with lod >= 0 the result is mesh
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
	var mesh_ids = asset_library.collection_get_mesh_items_ids(collection_id)
	var sub_collection_ids = asset_library.collection_get_sub_collections(collection_id)	
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
		mesh_item.meshes = MMeshLod.new()
		mesh_item.meshes.meshes = mesh_item_get_mesh_resources(mesh_id)
		mesh_item.transform = items_info[i].transform
		node.add_child(mesh_item)
		mesh_item.name = mesh_item_get_name(mesh_id)
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
