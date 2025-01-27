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
var collections:Dictionary
var forgotten_collections_import_info:Dictionary
var variation_groups: Array #array of array of glb node names
var meta_data:Dictionary

func import_state_str(_state:int) -> String:
		if _state==0:return "NOT_HANDLE"
		elif _state==1:return "NO_CHANGE"
		elif _state==2:return "New"
		elif _state==3:return "CHANGE"
		elif _state==4:return "Remove"
		return "Unkonw " + str(_state)

func print_pretty_dic(dic:Dictionary,dic_name:String="Dictionary",tab_count:int=0):
	var root_tab:=""
	for i in range(tab_count):
		root_tab += "    "
	var tabs = root_tab + "    "
	print(root_tab,dic_name,":{")
	for k in dic:
		var val = dic[k]
		if typeof(val) == TYPE_DICTIONARY:
			print_pretty_dic(val,str(k),tab_count+1)
		else:
			if k == "state":
				val = import_state_str(val)
			elif k == "mesh_states":
				val = val.map(func(a): return import_state_str(a))
			print(tabs,k,": ",val)
	print(root_tab,"}")

func print_data():
	print("\n---------- Asset data ------------")
	print_pretty_dic(mesh_data,"Mesh Data")
	print_pretty_dic(materials,"Materials")
	print_pretty_dic(collections,"Collections")
	print_pretty_dic(meta_data,"Meta Data")
	print("Variation Groups ",variation_groups)
	print("\n")

func clear():
	collections.clear()	
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
		"meshes": [] #array of MMesh that use this material...should be converted to ids later
	}.duplicate()

#func get_empty_mesh_item()->Dictionary:
	#return {
		#"mesh_nodes":[],
		#"meshes":[],
		#"original_meshes":[],		
		#"id":-1,
		#"material_set_id": -1,
		#"ignore":false,
		#"state":IMPORT_STATE.NOT_HANDLE,
		#"mesh_state":[]
	#}.duplicate()
		
func get_empty_collection()->Dictionary:
	return {
		"mesh_id":-1,
		"meshes":[],
		"original_meshes":[],
		"mesh_states":[],
		"collision_items":[],
		"original_collision_items":[],
		"sub_collections":{},
		"original_sub_collections":{},
		"stop_lod":-1,
		"original_stop_lod":-1,
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

func add_possible_stop_lod(node_name:String,lod:int):
	if not collections.has(node_name):
		collections[node_name] = get_empty_collection()
	if collections[node_name]["meshes"].size() - 1 < lod:
		collections[node_name]["stop_lod"] = lod

func update_collection_mesh(node_name:String,lod:int,mesh:MMesh)->void:
	if not collections.has(node_name):
		collections[node_name] = get_empty_collection()
	if collections[node_name]["meshes"].size() < lod + 1:
		collections[node_name]["meshes"].resize(lod+1)
	collections[node_name]["meshes"][lod] = mesh
	if collections[node_name]["meshes"].size() > collections[node_name]["stop_lod"]:
		collections[node_name]["stop_lod"] = -1

func add_sub_collection(node_name:String,sub_collection_node_name:String,sub_collection_transform:Transform3D):
	if not collections.has(node_name):
		collections[node_name] = get_empty_collection()
	collections[node_name]["sub_collections"][sub_collection_node_name] = sub_collection_transform

	
func add_mesh_data(sets, mesh:MMesh, mesh_item_name):						
	if mesh==null:
		return
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

func finalize_glb_parse():
	return
	var asset_library = MAssetTable.get_singleton()		
	for key in collections:
		var current_collection = collections[key]
		var max_material_set = 1
		var meshes:Array = current_collection["meshes"]
		for i in meshes:
			var __m:MMesh = meshes[i]
			if not __m: continue
			max_material_set = max(max_material_set,__m.material_set_get_count())
		print("max_material_set ",max_material_set)

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

func add_original_collisions(collection_name:String,transform:Transform3D)->void:
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	collections[collection_name]["original_collision_items"] = transform


# After add_original stuff generating import tags base on the difference between these new and original
func generate_import_tags():	
	for key in collections: #key = collection_name
		if collections[key]["id"] == -1:
			collections[key]["state"] = IMPORT_STATE.NEW
			for m in collections[key]["meshes"]:
				if m: collections[key]["mesh_states"].push_back(IMPORT_STATE.NEW)
				else: collections[key]["mesh_states"].push_back(IMPORT_STATE.NO_CHANGE)
		elif collections[key]["meshes"].size()==0 and collections[key]["sub_collections"].size()==0:
			collections[key]["state"] = IMPORT_STATE.REMOVE
			for m in collections[key]["meshes"]:
				if m: collections[key]["mesh_states"].push_back(IMPORT_STATE.REMOVE)
				else: collections[key]["mesh_states"].push_back(IMPORT_STATE.NO_CHANGE)
		else:
			var current_meshes:Array= collections[key]["meshes"].duplicate()
			var original_meshes:Array= collections[key]["original_meshes"]
			current_meshes.resize(MAssetTable.mesh_item_get_max_lod())
			original_meshes.resize(MAssetTable.mesh_item_get_max_lod())
			var is_mesh_change = false
			for i in range(MAssetTable.mesh_item_get_max_lod()):
				var cm:MMesh = current_meshes[i]
				var om:MMesh = original_meshes[i]
				if cm == null and om == null:
					collections[key]["mesh_states"].push_back(IMPORT_STATE.NO_CHANGE)
					continue
				if om == null:
					collections[key]["mesh_states"].push_back(IMPORT_STATE.NEW)
					is_mesh_change = true
					continue
				if cm == null:
					collections[key]["mesh_states"].push_back(IMPORT_STATE.REMOVE)
					is_mesh_change = true
					continue
				if om.is_same_mesh(cm):
					collections[key]["mesh_states"].push_back(IMPORT_STATE.NO_CHANGE)
					continue
				else:
					collections[key]["mesh_states"].push_back(IMPORT_STATE.CHANGE)
					is_mesh_change = true
			var is_sub_collection_change = collections[key]["sub_collections"] == collections[key]["original_sub_collections"]
			var is_stop_lod_change = collections[key]["stop_lod"]==collections[key]["original_stop_lod"]
			if not is_mesh_change and is_sub_collection_change and is_stop_lod_change:
				collections[key]["state"] = IMPORT_STATE.NO_CHANGE
			else:
				collections[key]["state"] = IMPORT_STATE.CHANGE

func save_meshes()->int:
	var asset_library = MAssetTable.get_singleton()
	if not DirAccess.dir_exists_absolute(MHlod.get_mesh_root_dir()):
		DirAccess.make_dir_recursive_absolute(MHlod.get_mesh_root_dir())
	for key in collections:
		var meshes:Array= collections[key]["meshes"]
		var mesh_states = collections[key]["mesh_states"]
		var mesh_id = -1
		if collections[key]["mesh_id"]<0 and meshes.size() > 0:
			mesh_id = MAssetTable.get_last_free_mesh_id_and_increase()
			collections[key]["mesh_id"] = mesh_id
		else: # even for remove we need mesh_id
			mesh_id = collections[key]["mesh_id"]
		var original_meshes:Array= collections[key]["original_meshes"]
		meshes.resize(MAssetTable.mesh_item_get_max_lod())
		original_meshes.resize(MAssetTable.mesh_item_get_max_lod())
		for i in range(MAssetTable.mesh_item_get_max_lod()):
			var mesh_lod_id = mesh_id + i
			var mesh_path = MHlod.get_mesh_path(mesh_lod_id)
			var stop_path = mesh_path.get_basename() + ".stop"
			if FileAccess.file_exists(stop_path): DirAccess.remove_absolute(stop_path)
			if not meshes[i]:
				if FileAccess.file_exists(mesh_path): DirAccess.remove_absolute(mesh_path)
			else:
				set_correct_material(meshes[i])
				ResourceSaver.save(meshes[i],mesh_path)
				meshes[i].take_over_path(mesh_path)
		# Adding stop lod if exist
		if collections[key]["stop_lod"] != -1:
			var stop_path = MHlod.get_mesh_path(mesh_id + collections[key]["stop_lod"]).get_basename() + ".stop"
			var f = FileAccess.open(stop_path,FileAccess.WRITE)
			f.close()
	return OK

func set_correct_material(mmesh:MMesh):
	if not mmesh: return
	if not mesh_data.has(mmesh):
		printerr("mesh data does not exist")
		return
	var material_sets_names = mesh_data[mmesh]["material_sets"]
	print(material_sets_names)
	return
	if material_sets_names.size()==0:
		return
	var import_info :=MAssetTable.get_singleton().import_info
	var first_material_set_names = material_sets_names[0]
	var set_count = mmesh.material_set_get_count()
	for set_num in range(set_count):
		var current_material_name
		# if does not exist using first set of material always
		if material_sets_names.size() > set_num:
			current_material_name = material_sets_names[set_num]
		else:
			current_material_name = first_material_set_names
		for surface_index in current_material_name.size():
			var material_name = current_material_name[surface_index]
			if not materials.has(material_name):
				continue
			var material_id = materials[material_name]["material"]
			var original_material_id = materials[material_name].original_material if materials[material_name].has("original_material") else -1
			if material_id == -1:
				continue
			var material_path = import_info["__materials"][material_id]["path"]
			print(set_num, )
			mmesh.surface_set_material(set_num,surface_index,material_path)
			# Remove this mmesh from old material mmesh list
			print(materials[material_name].original_material)
			if original_material_id != -1 and import_info['__materials'][original_material_id].meshes.has(mmesh.resource_path):
				import_info['__materials'][original_material_id].meshes.erase(mmesh.resource_path)
			# Add this mmesh to new material mmesh list
			import_info['__materials'][material_id].meshes.push_back(mmesh.resource_path)

# will return the information which is need to save with glb_path in import_info in AssetTable
func get_glb_import_info():
	var result:Dictionary = {}
	for key in collections:
		result[key] = {"mesh_id":-1,"sub_collections":{},"collision_items":[], "id":-1}
		result[key]["mesh_id"] = collections[key]["mesh_id"]
		if collections[key]["ignore"]: 
			result[key]["ignore"] = true
		if collections[key]["state"] == IMPORT_STATE.REMOVE:
			# keep this here as we want to keep mesh_id even when remove
			# id also must remain -1
			continue
		for collection_name in collections[key]["sub_collections"]:
			if not collections.has(collection_name): continue
			result[key]["sub_collections"][collection_name] = get_collection_id(collection_name)
		for original_collision_item in collections[key].collision_items:
			var collision_item = original_collision_item.duplicate()
			collision_item.mesh = null
			result[key].collision_items.push_back(collision_item)					
		result[key]["id"] = collections[key]["id"]	
	for key in forgotten_collections_import_info:
		if result.has(key):
			printerr("Result has key ",key)
			continue
		result[key] =  forgotten_collections_import_info[key]
	result["__materials"] = {}
	for key in materials:				
		result["__materials"][key] = {"path":materials[key].material, "meshes":materials[key].meshes}
	result["__metadata"] = meta_data
	result["__import_time"] = (Time.get_unix_time_from_system())
	return result
		
#Add original mesh and collection data to asset_data
func add_glb_import_info(info:Dictionary)->void:
	var asset_library := MAssetTable.get_singleton()
	for collection_glb_name in info:
		if collection_glb_name.begins_with("__"): continue
		if not collections.has(collection_glb_name):
			if info[collection_glb_name]["id"] == -1:
				forgotten_collections_import_info[collection_glb_name] = info[collection_glb_name]
				continue # A forgotten glb name
			else:
				collections[collection_glb_name] = get_empty_collection()
		var collection_id = info[collection_glb_name]["id"]
		#print("add id  ",collection_glb_name,info[collection_glb_name])
		#if collection_id < 0: # Can be a long removed collection we should keep mesh_id
			#pass
		var mesh_id = info[collection_glb_name]["mesh_id"]
		collections[collection_glb_name]["mesh_id"] = mesh_id
		var original_meshes:=[]
		if mesh_id!=-1:
			original_meshes = MAssetTable.mesh_item_meshes_no_replace(mesh_id)
			collections[collection_glb_name]["original_stop_lod"] = MAssetTable.mesh_item_get_stop_lod(mesh_id)
		var original_sub_collections:Dictionary = info[collection_glb_name]["sub_collections"]		
		for sub_collection_name in original_sub_collections:
			var t = asset_library.collection_get_sub_collections_transform(collection_id,original_sub_collections[sub_collection_name])
			collections[collection_glb_name]["original_sub_collections"][sub_collection_name] = t
		collections[collection_glb_name]["original_collision_items"] = collections[collection_glb_name].collision_items
		collections[collection_glb_name]["id"] = collection_id
		collections[collection_glb_name]["original_meshes"] = original_meshes
		if collection_id >= 0 :
			collections[collection_glb_name]["original_tags"] = asset_library.collection_get_tags(collection_id)
	add_metadata_to_data(info["__metadata"], meta_data)
	if "__materials" in info:
		for key in info["__materials"]:
			if key in materials:
				materials[key].original_material = info["__materials"][key].path
				materials[key].material = info["__materials"][key].path
	
func add_metadata_to_data(old:Dictionary, new:Dictionary):
	var result = old.duplicate()
	for key in new:
		result[key] = new[key]
	return result


func get_changed_hlods():
	var hlod_to_rebake: Array[MHlod] = []
	for hlod_path in DirAccess.get_files_at( MAssetTable.get_hlod_res_dir() ):
		var hlod = load(hlod_path)
		var used_ids = hlod.get_used_mesh_ids()
		for collection in collections:
			if collections[collection].mesh_id != -1 and used_ids.has(collections[collection].mesh_id):
				hlod_to_rebake.push_back(hlod)
	if len(hlod_to_rebake) == 0: return
	MHlodScene.sleep()
	for hlod in hlod_to_rebake:
		rebake_hlod(hlod)
	MHlodScene.awake()
		

static func rebake_hlod(hlod:MHlod):
	var baker: HLod_Baker= load(hlod.baker_path).instantiate()
	EditorInterface.get_base_control().add_child(baker)
	baker.bake_to_hlod_resource()
	baker.queue_free()
	
	
static func rebake_hlods_for_meshes(mesh_ids):
	var mhlod = MHlod.new()
	var used_ids = mhlod.get_used_mesh_ids()
	for mesh_id in mesh_ids:
		used_ids.has(mesh_id)
