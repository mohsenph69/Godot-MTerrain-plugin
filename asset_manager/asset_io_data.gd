@tool
class_name AssetIOData extends RefCounted

enum IMPORT_STATE {
	NOT_HANDLE,NO_CHANGE, NEW, CHANGE, REMOVE, 
}

var mesh_items:Dictionary
var collision_items:Dictionary
var collections:Dictionary
var glb_path:String
var meta_data:Dictionary

func clear():
	mesh_items.clear()
	collections.clear()
	glb_path = ""

func get_empty_mesh_item()->Dictionary:
	return {
		"mesh_nodes":[],
		"meshes":[],
		"original_meshes":[],
		"id":-1,
		"ignore":false,
		"state":IMPORT_STATE.NOT_HANDLE,
		"mesh_state":[]
	}.duplicate()
		
func get_empty_collection()->Dictionary:
	return {
		"mesh_items":{},
		"collision_items":{},
		"sub_collections":{},
		"original_mesh_items":{},
		"original_sub_collections":{},
		"id":-1,
		"is_root":true,
		"ignore":false,
		"state":IMPORT_STATE.NOT_HANDLE
	}.duplicate()

func get_empty_collision_item()->Dictionary:
	return {
		"type":[], # box / sphere / cylinder / capsule / concave / mesh
		"transform":[],
		"original_meshe":[],
		"id":-1,
		"ignore":false,
		"state":IMPORT_STATE.NOT_HANDLE,		
	}.duplicate()

# collection[name]["collision_items"] = [ ]

func update_mesh_items_id(name:String,id:int):
	mesh_items[name]["id"] = id

func get_mesh_items_id(name:String):
	if mesh_items.has(name):
		return mesh_items[name]["id"]
	return -1

func add_mesh_item(name:String,lod:int,node:Node)->void:
	if not mesh_items.has(name):
		mesh_items[name] = get_empty_mesh_item()
	if mesh_items[name]["mesh_nodes"].size() <= lod:
		mesh_items[name]["mesh_nodes"].resize(lod + 1)
	if node is ImporterMeshInstance3D:
		mesh_items[name]["mesh_nodes"][lod] = node

func add_mesh_to_collection(collection_name:String, mesh_name:String, is_root:bool):
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	collections[collection_name]["mesh_items"][mesh_name] = Transform3D()
	collections[collection_name]["is_root"] = is_root

func get_collection_id(collection_name:String)->int:
	if collections.has(collection_name):
		return collections[collection_name]["id"]
	return -1

func update_collection_id(collection_name:String,id:int):
	if collections.has(collection_name):
		collections[collection_name]["id"] = id

#func update_mesh_to_collection(name:String,id:int):
#	collections[name]["id"] = id

func add_sub_collection(collection_name:String,sub_collection_name:String,transform:Transform3D):
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	collections[collection_name]["sub_collections"][sub_collection_name] = transform

### Do some checking
#filling meshes with IDS

#if collection is_root is active local_transform should be used base on the lowest avaliable lod mesh node

func finalize_glb_parse():
	var asset_library = MAssetTable.get_singleton()	
	############
	## MESHES ##
	############	
	for mesh_item_name in mesh_items.keys():
		# fill meshes with mesh_id	
		var mesh_nodes = mesh_items[mesh_item_name]["mesh_nodes"]
		var meshes:=[]
		for mesh_node in mesh_nodes:
			if mesh_node == null or not mesh_node is ImporterMeshInstance3D or mesh_node.mesh == null:
				meshes.push_back(-1)
				continue
			var mesh:Mesh = mesh_node.mesh.get_mesh()
			var mesh_id = asset_library.mesh_get_id(mesh)
			if mesh_id == -1: ## then is a new mesh
				meshes.push_back(mesh)
				continue
			meshes.push_back(mesh_id)
		mesh_items[mesh_item_name]["meshes"] = meshes
	
	#################
	## COLLECTIONS ##
	#################
	for collection_name in collections:			
		var collection_mesh_items = collections[collection_name]["mesh_items"]
		var collection_collision_items = collections[collection_name]["collision_items"]
		var sub_collections = collections[collection_name]["sub_collections"]
		#check if all the collection name which used as sub_collection exist otherwise generate error
		for sub_collection_name in sub_collections:
			if not sub_collection_name in collections:
				push_error("finalise glb error: subcollection ", sub_collection_name, " does not exist, but is needed for collection ", collection_name )		
		check_for_infinite_recursion_in_collections()				
		#Fix Mesh Transforms #		
		if not collections[collection_name]["is_root"]:
			for mesh_name in collection_mesh_items:
				collections[collection_name]["mesh_items"][mesh_name] = find_mesh_item_transform(mesh_name)
		else:			
			for collision in collection_collision_items:
				pass
	#############################################
	## Remove things that are no longer needed ##
	#############################################
	for mesh_name in mesh_items:
		mesh_items[mesh_name].erase("mesh_nodes")

func check_for_infinite_recursion_in_collections(checked_collections = []):		
	for name in collections:
		if name in checked_collections:			
			return true
		checked_collections.push_back(name)
		for sub_collection_name in collections[name]["sub_collections"]:
			if check_for_infinite_recursion_in_collections(checked_collections):
				push_error("infinite recursion in subcollections: ", checked_collections.duplicate())
				return
						
func find_mesh_item_transform(mesh_name:String)->Transform3D:
	if mesh_items.has(mesh_name):
		var mesh_nodes = mesh_items[mesh_name]["mesh_nodes"]
		for mesh in mesh_nodes:
			if is_instance_valid(mesh) and mesh is Node3D:
				return mesh.transform
	return Transform3D()

func add_original_mesh_item(name:String,id:int)->void:
	var asset_library := MAssetTable.get_singleton()
	if not mesh_items.has(name):
		mesh_items[name] = get_empty_mesh_item()
	if not mesh_items[name]["original_meshes"].is_empty():
		#print("Existtt ")
		return # already set
	var mesh_info = asset_library.mesh_item_get_info(id)
	var mesh_arr:Array = mesh_info["mesh"]
	mesh_items[name]["original_meshes"] = mesh_arr
	mesh_items[name]["id"] = id

func add_original_mesh_to_collection(collection_name:String,mesh_name:String,transform:Transform3D):
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	collections[collection_name]["original_mesh_items"][mesh_name] = transform

func add_original_sub_collection(collection_name:String,sub_collection_name:String,transform:Transform3D)->void:
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	collections[collection_name]["original_sub_collections"][sub_collection_name] = transform

# After add_original stuff generating import tags base on the difference between these new and original
func generate_import_tags():
	#### ITEM MESH
	for mesh_item_name in mesh_items:
		if mesh_items[mesh_item_name]["id"] == -1: # new mesh
			mesh_items[mesh_item_name]["state"] = IMPORT_STATE.NEW
		elif mesh_items[mesh_item_name]["meshes"].size() == 0: # remove mesh
			mesh_items[mesh_item_name]["state"] = IMPORT_STATE.REMOVE
		else: # can be update or no_change
			var meshes:Array = mesh_items[mesh_item_name]["meshes"]
			var original_meshes:Array = mesh_items[mesh_item_name]["original_meshes"]
			var is_same = true
			for i in range(meshes.size()):
				if i < original_meshes.size():
					var state = compare_mesh(meshes[i],original_meshes[i])
					if state != IMPORT_STATE.NO_CHANGE:
						is_same = false
					mesh_items[mesh_item_name]["mesh_state"].push_back(state)
					continue
				mesh_items[mesh_item_name]["mesh_state"].push_back(IMPORT_STATE.NEW)
				is_same = false
			if original_meshes.size() > meshes.size():
				is_same = false
				for i in range(original_meshes.size(),meshes.size()):
					mesh_items[mesh_item_name]["mesh_state"].push_back(IMPORT_STATE.REMOVE)
			#print("IS Same ",is_same)
			if is_same:
				mesh_items[mesh_item_name]["state"] = IMPORT_STATE.NO_CHANGE
			else:
				mesh_items[mesh_item_name]["state"] = IMPORT_STATE.CHANGE
	############################
	#### Collections
	###########################
	for key in collections: #key = collection_name
		if collections[key]["mesh_items"].size() == 0 and collections[key]["sub_collections"].is_empty():
			collections[key]["state"] = IMPORT_STATE.REMOVE
		elif collections[key]["id"] == -1:
			collections[key]["state"] = IMPORT_STATE.NEW
		elif collections[key]["mesh_items"] == collections[key]["original_mesh_items"] and collections[key]["sub_collections"] == collections[key]["original_sub_collections"]:
			collections[key]["state"] = IMPORT_STATE.NO_CHANGE
		else:
			collections[key]["state"] = IMPORT_STATE.CHANGE

func compare_mesh(new_mesh,original_mesh)->IMPORT_STATE:
	if typeof(new_mesh) == TYPE_OBJECT:
		if original_mesh >= 0:
			return IMPORT_STATE.CHANGE
		return IMPORT_STATE.NEW
	## other wise the type should be INT
	if new_mesh == original_mesh:
		return IMPORT_STATE.NO_CHANGE
	if new_mesh >= 0 and original_mesh >=0:
		return IMPORT_STATE.CHANGE
	if new_mesh < 0:
		return IMPORT_STATE.REMOVE
	return IMPORT_STATE.NOT_HANDLE

func save_unsaved_meshes(mesh_item_name:String):
	var asset_library = MAssetTable.get_singleton()
	if not mesh_item_name in mesh_items:
		push_error("trying to save meshes for a mesh item whose name does not exist")
		return 
	var meshes = mesh_items[mesh_item_name]["meshes"]
	for i in range(meshes.size()):
		if meshes[i] is Mesh:
			var path = asset_library.mesh_get_path(meshes[i])
			ResourceSaver.save(meshes[i],path)
			meshes[i] = asset_library.mesh_get_id(meshes[i])
	mesh_items[mesh_item_name]["meshes"] = meshes

# will return the information which is need to save with glb_path in import_info in AssetTable
func get_glb_import_info():
	var result:Dictionary
	for key in collections:
		print("Getting ------------------- ",key)
		if collections[key]["state"] == IMPORT_STATE.REMOVE:
			continue
		result[key] = {"mesh_items":{},"sub_collections":{},"id":-1}
		for mk in collections[key]["mesh_items"]:
			if not mesh_items.has(mk): continue
			result[key]["mesh_items"][mk] = mesh_items[mk]["id"]
		for ck in collections[key]["sub_collections"]:
			if not collections.has(ck): continue
			result[key]["sub_collections"][ck] = get_collection_id(ck)
		result[key]["id"] = collections[key]["id"]
	return result

func set_glb_import_info(info:Dictionary)->void:
	var asset_library := MAssetTable.get_singleton()
	for collection_glb_name in info:
		var collection_id = info[collection_glb_name]["id"]
		if collection_id < 0:
			push_error(collection_id," Invalid collection ID in set_glb_import_info")
			continue
		var original_meshes:Dictionary= info[collection_glb_name]["mesh_items"]
		var original_sub_collections:Dictionary= info[collection_glb_name]["sub_collections"]
		for mesh_name in original_meshes:
			add_original_mesh_item(mesh_name,original_meshes[mesh_name])
			add_original_mesh_to_collection(collection_glb_name, mesh_name, asset_library.collection_get_item_transform(collection_id, MAssetTable.MESH, original_meshes[mesh_name]))
		for sub_collection_name in original_sub_collections:
			add_original_sub_collection(collection_glb_name,sub_collection_name,asset_library.collection_get_sub_collections_transform(collection_id,original_sub_collections[sub_collection_name]))
		collections[collection_glb_name]["id"] = collection_id
