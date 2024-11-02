@tool
class_name AssetIOData extends RefCounted

enum IMPORT_STATE {
	NOT_HANDLE,NO_CHANGE, NEW, CHANGE, REMOVE, 
}

var mesh_items:Dictionary
var collections:Dictionary
var glb_path:String
var meta_data:Dictionary

func clear():
	mesh_items.clear()
	collections.clear()
	glb_path = ""

func get_empty_mesh_item()->Dictionary:
	return {"mesh_nodes":[],"meshes":[],"original_meshes":[],"id":-1,"ignore":false,"state":IMPORT_STATE.NOT_HANDLE,"mesh_state":[]}.duplicate()

func get_empty_collection()->Dictionary:
	return {"mesh_items":{},"sub_collections":{},"original_mesh_items":{},"original_sub_collections":{},"id":-1,"is_root":true,"ignore":false,"state":IMPORT_STATE.NOT_HANDLE}.duplicate()

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

func add_mesh_to_collection(collection_name:String,mesh_name:String,is_root:bool):
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

func update_mesh_to_collection(name:String,id:int):
	collections[name]["id"] = id

func add_sub_collection(collection_name:String,sub_collection_name:String,transform:Transform3D):
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	collections[collection_name]["sub_collections"][sub_collection_name] = transform


### Do some checking
#filling meshes with IDS
#check if all the collection name which used as sub_collection exist otherwise generate error
#if collection is_root is active local_transform should be used base on the lowest avaliable lod mesh node
#if collection is_root is not acitive if we have collision collission transform in that collection should be relative to lowest lod mesh node
#Check if we have infinit recursive collections
func finalize_glb_parse():
	var at = MAssetTable.get_singleton()
	# filling meshes with IDS
	var mesh_item_glb_names = mesh_items.keys()
	for mitem_glb_name in mesh_item_glb_names:
		var mesh_nodes = mesh_items[mitem_glb_name]["mesh_nodes"]
		var meshes:=[]
		for mesh_node in mesh_nodes:
			if mesh_node == null or not mesh_node is ImporterMeshInstance3D or mesh_node.mesh == null:
				meshes.push_back(-1)
				continue
			var mesh:Mesh= mesh_node.mesh.get_mesh()
			var mesh_id = at.mesh_get_id(mesh)
			if mesh_id == -1: ## then is a new mesh
				meshes.push_back(mesh)
				continue
			meshes.push_back(mesh_id)
		mesh_items[mitem_glb_name]["meshes"] = meshes
	###########################
	## Correcting Transforms ##
	###########################
	for cname in collections:
		var mitems = collections[cname]["mesh_items"]
		var sub_collections = collections[cname]["sub_collections"]
		if not collections[cname]["is_root"]:
			for mname in mitems:
				collections[cname]["mesh_items"][mname] = find_mesh_item_transform(mname)
	#######################################################################
	# Removing unnessary stuff after this step



func find_mesh_item_transform(mname:String)->Transform3D:
	if mesh_items.has(mname):
		var mesh_nodes = mesh_items[mname]["mesh_nodes"]
		for m in mesh_nodes:
			if is_instance_valid(m) and m is Node3D:
				return m.transform
	return Transform3D()

func add_original_mesh_item(name:String,id:int)->void:
	var at := MAssetTable.get_singleton()
	if not mesh_items.has(name):
		mesh_items[name] = get_empty_mesh_item()
	if not mesh_items[name]["original_meshes"].is_empty():
		#print("Exiusttt ")
		return # already set
	var minfo = at.mesh_item_get_info(id)
	var m_arr:Array = minfo["mesh"]
	mesh_items[name]["original_meshes"] = m_arr
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
	for mitem_glb_name in mesh_items:
		if mesh_items[mitem_glb_name]["id"] == -1: # new mesh
			mesh_items[mitem_glb_name]["state"] = IMPORT_STATE.NEW
		elif mesh_items[mitem_glb_name]["meshes"].size() == 0: # remove mesh
			mesh_items[mitem_glb_name]["state"] = IMPORT_STATE.REMOVE
		else: # can be update or no_change
			var meshes:Array = mesh_items[mitem_glb_name]["meshes"]
			var original_meshes:Array = mesh_items[mitem_glb_name]["original_meshes"]
			var is_same = true
			for i in range(meshes.size()):
				if i < original_meshes.size():
					var state = compare_mesh(meshes[i],original_meshes[i])
					if state != IMPORT_STATE.NO_CHANGE:
						is_same = false
					mesh_items[mitem_glb_name]["mesh_state"].push_back(state)
					continue
				mesh_items[mitem_glb_name]["mesh_state"].push_back(IMPORT_STATE.NEW)
				is_same = false
			if original_meshes.size() > meshes.size():
				is_same = false
				for i in range(original_meshes.size(),meshes.size()):
					mesh_items[mitem_glb_name]["mesh_state"].push_back(IMPORT_STATE.REMOVE)
			print("IS Same ",is_same)
			if is_same:
				mesh_items[mitem_glb_name]["state"] = IMPORT_STATE.NO_CHANGE
			else:
				mesh_items[mitem_glb_name]["state"] = IMPORT_STATE.CHANGE
	############################
	#### Collections
	###########################
	for key in collections:
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

func save_unsave_meshes(mesh_item_uname:String):
	var at = MAssetTable.get_singleton()
	var meshes = mesh_items[mesh_item_uname]["meshes"]
	for i in range(meshes.size()):
		if meshes[i] is Mesh:
			var path = at.mesh_get_path(meshes[i])
			ResourceSaver.save(meshes[i],path)
			meshes[i] = at.mesh_get_id(meshes[i])
	mesh_items[mesh_item_uname]["meshes"] = meshes

# will return the information which is need to save with glb_path in import_info in AssetTable
func get_glb_import_info():
	var result:Dictionary
	for k in collections:
		print("Getting ------------------- ",k)
		if collections[k]["state"] == IMPORT_STATE.REMOVE:
			continue
		result[k] = {"mesh_items":{},"sub_collections":{},"id":-1}
		for mk in collections[k]["mesh_items"]:
			if not mesh_items.has(mk): continue
			result[k]["mesh_items"][mk] = mesh_items[mk]["id"]
		for ck in collections[k]["sub_collections"]:
			if not collections.has(ck): continue
			result[k]["sub_collections"][ck] = get_collection_id(ck)
		result[k]["id"] = collections[k]["id"]
	return result

func set_glb_import_info(info:Dictionary)->void:
	var at := MAssetTable.get_singleton()
	for c_glb_name in info:
		var cid = info[c_glb_name]["id"]
		if cid < 0:
			push_error(cid," Invalid collection ID in set_glb_import_info")
			continue
		var org_meshes:Dictionary= info[c_glb_name]["mesh_items"]
		var org_sub_collections:Dictionary= info[c_glb_name]["sub_collections"]
		for m in org_meshes:
			add_original_mesh_item(m,org_meshes[m])
			add_original_mesh_to_collection(c_glb_name,m,at.collection_get_item_transform(cid,MAssetTable.MESH,org_meshes[m]))
		for sc in org_sub_collections:
			add_original_sub_collection(c_glb_name,sc,at.collection_get_sub_collections_transform(cid,org_sub_collections[sc]))
		collections[c_glb_name]["id"] = cid
