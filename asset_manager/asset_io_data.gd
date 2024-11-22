@tool
class_name AssetIOData extends RefCounted

enum IMPORT_STATE {
	NOT_HANDLE,NO_CHANGE, NEW, CHANGE, REMOVE,
}
enum COLLISION_TYPE {
	BOX,SPHERE,CYLINDER, CAPSULE, CONVEX, MESH
}

var glb_path:String
var blend_file: String

var mesh_data: Dictionary # key is mesh_name, value is array of material sets, each set is an array of material names references the materials dictionary
var materials:Dictionary #Key is import material name
var mesh_items:Dictionary
var collections:Dictionary

var meta_data:Dictionary

func clear():
	collections.clear()	
	mesh_items.clear()	
	materials.clear()
	mesh_data.clear()
	glb_path = ""

func get_empty_mesh_data()->Dictionary:
	return {
		"material_sets": [],
		"original_material_sets": null,		
		"mesh_id": null,
		"name": null,
		"mesh_item_users": []
	}.duplicate()

func get_empty_material()->Dictionary:
	return {
		"material": null,
		"original_material": null,		
		"meshes": [] #array of meshes that use this material...should be converted to ids later
	}.duplicate()

func get_empty_mesh_item()->Dictionary:
	return {
		"mesh_nodes":[],
		"meshes":[],
		"original_meshes":[],		
		"id":-1,
		"material_set_id": -1,
		"ignore":false,
		"state":IMPORT_STATE.NOT_HANDLE,
		"mesh_state":[]
	}.duplicate()
		
func get_empty_collection()->Dictionary:
	return {
		"mesh_items":{},
		"collision_items":[],
		"sub_collections":{},
		"original_mesh_items":{},
		"original_sub_collections":{},
		"original_collision_items":[],
		"tags": [],
		"original_tags": [],
		"id":-1,
		"is_root":true,
		"ignore":false,
		"state":IMPORT_STATE.NOT_HANDLE
	}.duplicate()

func get_empty_collision_item()->Dictionary:
	return {
		"type":null, # box / sphere / cylinder / capsule / concave / mesh
		"transform":[],
		"mesh": null, #only exists if mesh type
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

func add_mesh_item(name:String,lod:int,node:Node, set_id:int)->void:
	if not mesh_items.has(name):
		mesh_items[name] = get_empty_mesh_item()
	if mesh_items[name]["mesh_nodes"].size() <= lod:
		mesh_items[name]["mesh_nodes"].resize(lod + 1)
	if node is ImporterMeshInstance3D:
		mesh_items[name]["mesh_nodes"][lod] = node	
	mesh_items[name].material_set_id = set_id
	
func add_mesh_data(sets, mesh:Mesh, mesh_item_name):						
	if not mesh_data.has(mesh): 
		mesh_data[mesh] = get_empty_mesh_data()	
		mesh_data[mesh].name = mesh.resource_name
		for set_id in len(sets):
			var material_names = sets[set_id]
			for material_name in material_names:
				if not materials.has(material_name):
					materials[material_name] = get_empty_material()
				materials[material_name].meshes.push_back(mesh)
			mesh_data[mesh].material_sets.push_back(material_names)
	mesh_data[mesh].mesh_item_users.push_back(mesh_item_name)
					
func add_mesh_item_to_collection(collection_name:String, mesh_item_name:String, is_root:bool):
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	collections[collection_name]["mesh_items"][mesh_item_name] = Transform3D()
	collections[collection_name]["is_root"] = is_root

func add_collision_to_collection(collection_name, collision_type:COLLISION_TYPE, transform, mesh:Mesh=null):
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	var item = get_empty_collision_item()
	item.type = collision_type
	item.transform = transform
	if is_instance_valid(mesh):
		if collision_type == COLLISION_TYPE.CONVEX:
			item.mesh = mesh.create_convex_shape() #array of points
		else:
			item.mesh = mesh
	collections[collection_name]["collision_items"].push_back(item)
	
func get_collection_id(collection_name:String)->int:	
	if collections.has(collection_name):
		return collections[collection_name]["id"]
	return -1

func update_collection_id(collection_name:String,id:int):
	if collections.has(collection_name):
		collections[collection_name]["id"] = id

func add_sub_collection(collection_name:String,sub_collection_name:String,transform:Transform3D):
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	if not collections[collection_name]["sub_collections"].has(sub_collection_name):
		collections[collection_name]["sub_collections"][sub_collection_name] = []		
	collections[collection_name]["sub_collections"][sub_collection_name].push_back(transform)

func finalize_glb_parse():
	var asset_library = MAssetTable.get_singleton()		
	################
	## MESH ITEMS ##
	################
	for mesh_item_name in mesh_items.keys():
		# fill meshes with mesh_id	
		var mesh_nodes = mesh_items[mesh_item_name]["mesh_nodes"]
		var meshes:=[]
		for mesh_node in mesh_nodes:			
			if mesh_node == null or not mesh_node is ImporterMeshInstance3D or mesh_node.mesh == null:
				meshes.push_back(-1)
				continue			
			var mesh: Mesh = mesh_node.mesh.get_mesh()			
			mesh.resource_name = mesh.resource_name.get_slice(glb_path.get_file().get_slice(".", 0) + "_", 1)						
			var mmesh:= MMesh.new()									
			mmesh.create_from_mesh( mesh )
			mmesh.resource_name = mesh.resource_name				
			var mesh_id = asset_library.mesh_get_id(mmesh)
			if mesh_id == -1: ## then is a new mesh
				meshes.push_back(mesh) #mmesh)
				continue
			meshes.push_back(mesh_id)			
			if not mesh_item_name in mesh_data[mesh].mesh_item_users:
				mesh_data[mesh].mesh_item_users.push_back(mesh_item_name)
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
			if "::" in sub_collection_name and ".glb" in sub_collection_name:				
				var node_name = sub_collection_name.get_slice("::", 0)
				var glb_path = sub_collection_name.get_slice("::", 1)
				if not glb_path in asset_library.import_info:
					push_error("finalize glb parse error: subcollection is trying to reference a glb path that has not been imported yet: ", glb_path)
					sub_collections.erase(sub_collection_name)
				if not node_name in asset_library.import_info[glb_path]:
					push_error("finalize glb parse error: subcollection is trying to reference an asset in external glb file, but glb_node_name does not exist: ", sub_collection_name)																			
					sub_collections.erase(sub_collection_name)
			elif not sub_collection_name in collections:
				push_error("finalise glb error: subcollection ", sub_collection_name, " does not exist, but is needed for collection ", collection_name )
		check_for_infinite_recursion_in_collections(collection_name)
		#Fix Mesh Transforms...if collection is_root is active local_transform should be used base on the lowest avaliable lod mesh node		
		if not collections[collection_name]["is_root"]:
			for mesh_name in collection_mesh_items:
				collections[collection_name]["mesh_items"][mesh_name] = find_mesh_item_transform(mesh_name)
		#else: # FIX COLLISION transform for root level meshes... should be relative to first lod
			#for collision in collection_collision_items:
				#pass
	
	#############################################
	## Remove things that are no longer needed ##
	#############################################
	for mesh_name in mesh_items:
		mesh_items[mesh_name].erase("mesh_nodes")

func check_for_infinite_recursion_in_collections(name, checked_collections = []):
	var asset_library = MAssetTable.get_singleton()
	if name in checked_collections:
		return true
	if "::" in name:
		var node_name = name.get_slice("::", 0)
		var glb_path = name.get_slice("::", 1)					
		checked_collections.push_back(name)
		for sub_collection_name in asset_library.import_info[glb_path][node_name]["sub_collections"]:
			if check_for_infinite_recursion_in_collections(sub_collection_name, checked_collections.duplicate()):
				push_error("infinite recursion in subcollections: ", checked_collections)
				return
	else:		
		checked_collections.push_back(name)
		for sub_collection_name in collections[name]["sub_collections"]:
			if check_for_infinite_recursion_in_collections(sub_collection_name, checked_collections.duplicate()):
				push_error("infinite recursion in subcollections: ", checked_collections)
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
		return # already set by added by a different node
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
	if not collections[collection_name]["original_sub_collections"].has(sub_collection_name):
		collections[collection_name]["original_sub_collections"][sub_collection_name] = []
	collections[collection_name]["original_sub_collections"][sub_collection_name].push_back(transform)

func add_original_collisions(collection_name:String,transform:Transform3D)->void:
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	collections[collection_name]["original_collision_items"] = transform


# After add_original stuff generating import tags base on the difference between these new and original
func generate_import_tags():	
	##############
	## MATERIAL ##
	##############
	for material_name in materials:
		if materials[material_name].original_material != null:
			materials[material_name].material = materials[material_name].original_material
			continue
		else:			
			var material_id = get_material_id_by_name(material_name)
			if material_id != null:			
				materials[material_name].material = material_id
			else:			
				materials[material_name].material = null #materials[material_name].glb_material						
	###############
	## ITEM MESH ##
	###############
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
				for i in range(meshes.size(), original_meshes.size()):
					mesh_items[mesh_item_name]["mesh_state"].push_back(IMPORT_STATE.REMOVE)			
			if is_same:
				mesh_items[mesh_item_name]["state"] = IMPORT_STATE.NO_CHANGE
			else:
				mesh_items[mesh_item_name]["state"] = IMPORT_STATE.CHANGE	
	#################
	## Collections ##
	#################
	for key in collections: #key = collection_name
		if collections[key]["mesh_items"].size() == 0 and collections[key]["sub_collections"].is_empty():
			collections[key]["state"] = IMPORT_STATE.REMOVE
		elif collections[key]["id"] == -1:
			collections[key]["state"] = IMPORT_STATE.NEW
		else: 	
			collections[key]["state"] = IMPORT_STATE.CHANGE		
			if collections[key]["mesh_items"] != collections[key]["original_mesh_items"]: continue 
			if collections[key]["sub_collections"] != collections[key]["original_sub_collections"]:	continue
			if check_if_mesh_items_are_changed(collections[key]["mesh_items"], ):
				continue
				
			collections[key]["state"] = IMPORT_STATE.NO_CHANGE			

func check_if_mesh_items_are_changed(mesh_item_names):
	for mesh_item_name in mesh_item_names:
		if mesh_items[mesh_item_name].state != IMPORT_STATE.NO_CHANGE:
			return true			
func get_material_id_by_name(material_name):
	var material_table = AssetIO.get_material_table()
	var ids = material_table.keys()
	for i in len(ids):
		var path = material_table[ ids[i] ].path
		if material_name.to_lower() == path.get_file().get_slice(".", 0).to_lower():			
			return i		
	return null

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
						
func save_unsaved_meshes()->int:
	var asset_library = MAssetTable.get_singleton()	
	var meshes = mesh_data.keys()
	var result = {}
	for i in len(meshes):
		var mesh = meshes[i]		
		if not mesh is Mesh:
			push_error("save unsaved meshes: mesh_data dictionary has a key that is not a mesh")
		var mmesh = MMesh.new()
		mmesh.create_from_mesh(mesh)		
		var is_first = true # make sure we use existing set 0 which was created automatically during MMesh.new()
		for material_set in mesh_data[mesh].material_sets:				
			var set_id = mmesh.add_material_set() if not is_first else 0
			is_first = false				
			for j in len(material_set): 					
				var material_name = material_set[j]					
				var material_id = materials[material_name].material
				if material_id in [-1, null]:
					mmesh.surface_set_material(set_id, j, "")		
				else:
					var material_path = AssetIO.get_material_table()[material_id].path
					mmesh.surface_set_material(set_id, j, material_path)						
		var mesh_id = asset_library.mesh_add(mmesh)		
		result[mesh_id] = mesh_data[mesh]		
		## Replace mesh with mesh id inside mesh_items dictionary		
		for mesh_item_name in mesh_data[mesh].mesh_item_users:			
			var index = mesh_items[mesh_item_name]["meshes"].find(mesh)
			mesh_items[mesh_item_name]["meshes"][index] = mesh_id
	mesh_data = result
	return OK

# will return the information which is need to save with glb_path in import_info in AssetTable
func get_glb_import_info():
	var result:Dictionary = {}
	for key in collections:
		#print("Getting ------------------- ",key)
		if collections[key]["state"] == IMPORT_STATE.REMOVE:
			continue
		result[key] = {"mesh_items":{},"sub_collections":{},"collision_items":[], "id":-1}
		for mesh_name in collections[key]["mesh_items"]:
			if not mesh_items.has(mesh_name): continue
			result[key]["mesh_items"][mesh_name] = mesh_items[mesh_name]["id"]
		for collection_name in collections[key]["sub_collections"]:
			if not collections.has(collection_name): continue
			result[key]["sub_collections"][collection_name] = get_collection_id(collection_name)
		for original_collision_item in collections[key].collision_items:
			var collision_item = original_collision_item.duplicate()
			collision_item.mesh = null
			result[key].collision_items.push_back(collision_item)					
		result[key]["id"] = collections[key]["id"]	
	result["__materials"] = {}
	for key in materials:				
		result["__materials"][key] = {"path":materials[key].material, "meshes":materials[key].meshes}
	result["__metadata"] = meta_data
	return result
		
#Add original mesh and collection data to asset_data
func add_glb_import_info(info:Dictionary)->void:
	var asset_library := MAssetTable.get_singleton()
	for collection_glb_name in info:
		if collection_glb_name.begins_with("__"): continue
		var collection_id = info[collection_glb_name]["id"]
		if collection_id < 0:
			push_error(collection_id," Invalid collection ID in set_glb_import_info")
			continue
		var original_meshes:Dictionary= info[collection_glb_name]["mesh_items"]
		var original_sub_collections:Dictionary = info[collection_glb_name]["sub_collections"]		
		for mesh_name in original_meshes:
			add_original_mesh_item(mesh_name,original_meshes[mesh_name])
			add_original_mesh_to_collection(collection_glb_name, mesh_name, asset_library.collection_get_item_transform(collection_id, MAssetTable.MESH, original_meshes[mesh_name]))
		for sub_collection_name in original_sub_collections:
			for transform in asset_library.collection_get_sub_collections_transform(collection_id, original_sub_collections[sub_collection_name]):
				add_original_sub_collection(collection_glb_name,sub_collection_name,transform)
		collections[collection_glb_name]["original_collision_items"] = collections[collection_glb_name].collision_items
		collections[collection_glb_name]["original_tags"] = asset_library.collection_get_tags(collection_id)
		collections[collection_glb_name]["id"] = collection_id
	add_metadata_to_data(info["__metadata"], meta_data)
	if "__materials" in info:
		for key in info["__materials"]:
			if key in materials:
				materials[key].original_material = info["__materials"][key].path
	
func add_metadata_to_data(old:Dictionary, new:Dictionary):
	var result = old.duplicate()
	for key in new:
		result[key] = new[key]
	return result
