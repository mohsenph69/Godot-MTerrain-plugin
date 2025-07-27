@tool
class_name AssetIOData extends RefCounted

enum IMPORT_STATE {
	NOT_HANDLE,NO_CHANGE, NEW, CHANGE, REMOVE,
}

var glb_path:String
var blend_file: String
var original_blend_file: String # saved from previous import

var mesh_data: Dictionary # key is mesh_name, value is array of material sets, each set is an array of material names references the materials dictionary
var materials:Dictionary #Key is import material name
var collections:Dictionary
var global_options:Dictionary = get_empty_option()
var forgotten_collections_import_info:Dictionary
var variation_groups: Array #array of array of glb node names
var meta_data:Dictionary
var tags: Dictionary = {"original_tags":[], "current_tags":[], "mode": 0 } #mode 0 = add, mode 1 = overwrite

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
	print_pretty_dic(global_options,"Global Options")
	print_pretty_dic(collections,"Collections")
	#print("Variation Groups ",variation_groups)
	print("\n")

func clear():
	collections.clear()	
	materials.clear()
	mesh_data.clear()
	glb_path = ""

func get_empty_mesh_data()->Dictionary:
	return {
		"material_sets": [],		
		"transform":Transform3D(),
		"name": null,
	}.duplicate()

func get_empty_option()->Dictionary:
	return {
		"meshcutoff":"",
		"colcutoff":"",
		"physics":""
	}.duplicate()

func get_empty_collection()->Dictionary:
	return {
		"options":get_empty_option(),
		"mesh_id":-1,
		"meshes":[],
		"original_meshes":[],
		"mesh_states":[],
		"is_master":false,
		"base_transform":Transform3D(),
		"convex":false,
		"concave":null,
		"collisions":[], # only simple shapes
		"sub_collections":{},
		"original_sub_collections":{},
		"tags": [],
		"original_tags": [],
		"id":-1,
		"is_root":true,
		"ignore":false,
		"state":IMPORT_STATE.NOT_HANDLE
	}.duplicate()

func get_empty_collision_item()->Dictionary:
	return {
		"type":MAssetTable.CollisionType.UNDEF, # box / sphere / cylinder / capsule
		"transform":Transform3D(),
	}.duplicate()

func add_option(collection_name:String,option_name:String,option_value:String)->void:
	if option_name=="collisioncutoff": option_name = "colcutoff"
	if not global_options.has(option_name):
		printerr("Invalid option name "+option_name)
		return
	if collection_name == "_global":
		global_options[option_name] = option_value
		return
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	collections[collection_name]["options"][option_name] = option_value

func get_option(collection_name:String,option_name:String)->String:
	if not global_options.has(option_name):
		printerr("Invalid option name "+option_name)
		return ""
	var c_option = collections[collection_name]["options"]
	var option_value:String = ""
	if not c_option[option_name].is_empty(): option_value = c_option[option_name]
	else:  option_value = global_options[option_name]
	return option_value

func update_collection_mesh(node_name:String,lod:int,mesh:MMesh)->void:
	if not collections.has(node_name):
		collections[node_name] = get_empty_collection()
	if collections[node_name]["meshes"].size() < lod + 1:
		collections[node_name]["meshes"].resize(lod+1)
	collections[node_name]["meshes"][lod] = mesh

func add_master_collection(node_name:String,transform:Transform3D):
	if not collections.has(node_name):
		collections[node_name] = get_empty_collection()
	collections[node_name]["base_transform"] = transform

func add_sub_collection(node_name:String,sub_collection_node_name:String,sub_collection_transform:Transform3D):
	if not collections.has(node_name):
		collections[node_name] = get_empty_collection()
	if not collections[node_name]["sub_collections"].has(sub_collection_node_name):
		collections[node_name]["sub_collections"][sub_collection_node_name] = []
	collections[node_name]["sub_collections"][sub_collection_node_name].push_back(sub_collection_transform)
	collections[node_name]["is_master"] = true

	
func add_mesh_data(sets, mesh:MMesh, mesh_node:Node):							
	if mesh==null:
		return
	if mesh_data.has(mesh):
		printerr("Adding duplicate mesh into mesh data ",mesh_node.name)
		return
	mesh_data[mesh] = get_empty_mesh_data()	
	mesh_data[mesh].name = mesh_node.name 
	mesh_data[mesh].transform = mesh_node.transform
	for set_id in len(sets):
		var material_names = sets[set_id]					
		for material_name in material_names:
			if not materials.has(material_name):
				materials[material_name] = -1
		mesh_data[mesh].material_sets.push_back(material_names)

func add_collision_to_collection(collection_name, collision_type:MAssetTable.CollisionType,col_transform):
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	var item = get_empty_collision_item()
	item.type = collision_type
	item.transform = col_transform
	# item.obj_transform = obj_transform # this will be determine in finilize function
	collections[collection_name]["collisions"].push_back(item)

func add_collision_none_simple(collection_name,shape_name:String,info):
	if not info: return
	if not collections.has(collection_name):
		collections[collection_name] = get_empty_collection()
	if collections[collection_name][shape_name]:
		printerr("Duplicate collision shape of type "+shape_name+" in collection name "+collection_name)
		return
	collections[collection_name][shape_name] = info

func get_collection_id(collection_name:String)->int:	
	if collections.has(collection_name):
		return collections[collection_name]["id"]
	return -1

func update_collection_id(collection_name:String,id:int):
	if collections.has(collection_name):
		collections[collection_name]["id"] = id

func finalize_glb_parse():
	var asset_library = MAssetTable.get_singleton()
	# remove empty master or collissions
	for k in collections:
		if collections[k]["meshes"].is_empty() and collections[k]["sub_collections"].is_empty():
			if not collections[k]["collisions"].is_empty():
				printerr("Collission with name \"%s\" has no matching mesh name or master collection name, so it get removed" % k)
			collections.erase(k)
	# setting the base transform
	for k in collections:
		if collections[k]["is_master"] : continue
		for m in collections[k].meshes:
			if m:
				collections[k]["base_transform"] = mesh_data[m].transform
				break

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
			if not is_mesh_change and is_sub_collection_change:
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
		#####################################
		### Saving and removing ALL meshes ##
		#####################################
		var first_mesh:ArrayMesh = null
		for i in range(MAssetTable.mesh_item_get_max_lod()):
			var mesh_lod_id = mesh_id + i
			var mesh_path = MHlod.get_mesh_path(mesh_lod_id)
			var stop_path = mesh_path.get_basename() + ".stop"
			if FileAccess.file_exists(stop_path): DirAccess.remove_absolute(stop_path)
			if not meshes[i]:
				if FileAccess.file_exists(mesh_path): DirAccess.remove_absolute(mesh_path)
			else:
				if not first_mesh: first_mesh = meshes[i].get_mesh()
				meshes[i].take_over_path(mesh_path)
				meshes[i].resource_name = key
				set_correct_material(meshes[i], mesh_path)
				ResourceSaver.save(meshes[i],mesh_path)
				meshes[i].take_over_path(mesh_path)
		# Adding stop lod if exist
		if not first_mesh:
			printerr("No valid mesh in Collection: \""+key+"\"")
			continue
		var meshcutoff = get_option(key,"meshcutoff")
		if not meshcutoff.is_empty():
			if not meshcutoff.is_valid_int():
				printerr("meshcutoff is not a valid integer")
				continue
			var stop_lod:int = meshcutoff.to_int()
			if stop_lod==0:
				printerr("stop_lod can't be smaller than 1")
				continue
			if stop_lod==-1:
				continue #default
			var stop_path = MHlod.get_mesh_path(mesh_id + stop_lod).get_basename() + ".stop"
			var f = FileAccess.open(stop_path,FileAccess.WRITE)
			f.close()
		#####################################
		### Saving complex collision shapes ##
		#####################################
		var col_path = MHlod.get_collsion_path(mesh_id)
		if FileAccess.file_exists(col_path):
			DirAccess.remove_absolute(col_path)
		if collections[key]["convex"] or collections[key]["concave"]:
			var col_gen_mesh:ArrayMesh = first_mesh
			var col_shape:Shape3D = null
			if collections[key]["convex"]:
				if collections[key]["convex"] is ArrayMesh: col_gen_mesh = collections[key]["convex"]
				col_shape = col_gen_mesh.create_convex_shape(true,true)
			if collections[key]["concave"]:
				if col_shape: printerr("For Collection \""+key+"\" both convex and concave shapes are active saving just convex one")
				else:
					if collections[key]["concave"] is ArrayMesh: col_gen_mesh = collections[key]["concave"]
					col_shape = col_gen_mesh.create_trimesh_shape()
			if not col_shape: printerr("No col Shape to save!")
			else:
				ResourceSaver.save(col_shape,col_path)
				col_shape.take_over_path(col_path)
	return OK

func set_correct_material(mmesh:MMesh, mesh_path):
	if not mmesh: return
	if not mesh_data.has(mmesh):
		printerr("mesh data does not exist")
		return
	var material_sets_names = mesh_data[mmesh]["material_sets"]		
	if material_sets_names.size()==0:
		return
	var import_info :=MAssetTable.get_singleton().import_info
	var first_material_set_names = material_sets_names[0]
	var set_count = mmesh.material_set_get_count()	
	for set_num in set_count:
		var current_material_name:Array
		# if does not exist using first set of material always
		if material_sets_names.size() > set_num:
			current_material_name = material_sets_names[set_num]
		else:
			current_material_name = first_material_set_names
		if len(mmesh.material_set_get(0)) != current_material_name.size():
			print("mmesh slot count issue: ", mmesh.material_set_get(0), " is not equal to ", current_material_name.size())
		for surface_index in current_material_name.size():
			var material_name = current_material_name[surface_index]
			if not materials.has(material_name):
				continue
			var material_id = int(round(materials[material_name]))
			if material_id < 0:
				continue
			var material_path = import_info["__materials"][material_id]["path"]
			mmesh.surface_set_material(set_num,surface_index,material_path)

# will return the information which is need to save with glb_path in import_info in AssetTable
func get_glb_import_info():
	var result:Dictionary = {}
	for key in collections:
		result[key] = {"mesh_id":-1,"sub_collections":{}, "id":-1}
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
		result[key]["id"] = collections[key]["id"]	
	for key in forgotten_collections_import_info:
		if result.has(key):
			printerr("Result has key ",key)
			continue
		result[key] =  forgotten_collections_import_info[key]
	result["__metadata"] = meta_data
	result["__materials"] = materials
	result["__import_time"] = (Time.get_unix_time_from_system())
	result["__tags"] = tags['current_tags']		
	result["__global_options"] = global_options
	result["__original_blend_file"] = blend_file
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
		var original_sub_collections:Dictionary = info[collection_glb_name]["sub_collections"]		
		#for sub_collection_name in original_sub_collections:
		#	var t = asset_library.collection_get_sub_collections_transform(collection_id,original_sub_collections[sub_collection_name])
		#	collections[collection_glb_name]["original_sub_collections"][sub_collection_name] = t
		collections[collection_glb_name]["id"] = collection_id
		collections[collection_glb_name]["original_meshes"] = original_meshes
		if collection_id >= 0 and asset_library.has_collection(collection_id):
			collections[collection_glb_name]["original_tags"] = asset_library.collection_get_tags(collection_id)
	add_metadata_to_data(info["__metadata"], meta_data)
	if "__materials" in info:
		for key in info["__materials"]:
			if materials.has(key):
				materials[key] = info["__materials"][key]
	if "__tags" in info:
		tags['original_tags'] = info["__tags"] # array of tag_id
	if "__global_options" in info:
		for key in global_options.keys():
			if not key in info["__global_options"]: continue
			global_options["original_" + key] = info["__global_options"][key]			 
	if "__original_blend_file" in info:
		original_blend_file = info["__original_blend_file"]
		
func add_metadata_to_data(old:Dictionary, new:Dictionary):
	var result = old.duplicate()
	for key in new:
		result[key] = new[key]
	return result


func get_changed_hlods():
	if not DirAccess.dir_exists_absolute(MAssetTable.get_hlod_res_dir()): return
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
		AssetIOBaker.rebake_hlod(hlod)
	MHlodScene.awake()
	
	
static func rebake_hlods_for_meshes(mesh_ids):
	var mhlod = MHlod.new()
	var used_ids = mhlod.get_used_mesh_ids()
	for mesh_id in mesh_ids:
		used_ids.has(mesh_id)
