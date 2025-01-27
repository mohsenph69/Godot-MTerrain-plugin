class_name AssetIOMaterials extends Object

#static var material_regex = RegEx.create_from_string("(.*)[_ ]set[_ ]?(\\d+)$")

static func get_material_table():
	var asset_library := MAssetTable.get_singleton()	
	if not asset_library: return null
	if not asset_library.import_info.has("__materials"):
		asset_library.import_info["__materials"] = {}
	return asset_library.import_info["__materials"]

static func update_material_table(material_table:Dictionary):
	var asset_library := MAssetTable.get_singleton()	
	if not asset_library: push_error("trying to update material table, but asset library doesn't exist yet")
	asset_library.import_info["__materials"] = material_table

static func get_material_id(material:Material)->int:
	if not material: return -1
	var path = material.resource_path
	if path.is_empty(): return -1	
	var materials = get_material_table()
	if materials == null: return -1
	for id in materials:
		if materials[id]["path"] == path:
			return id
	return -1

static func get_material(id:int)->Material:	
	var materials = get_material_table()
	if materials.has(id):
		var path = materials[id]["path"]
		if ResourceLoader.exists(path):
			var material = load(path)
			if material is Material:
				return material
	return null

static func update_material(id, path):	
	var material_table = get_material_table()
	var material = load(path)
	if not material is Material:
		push_error("failed adding material to material table: resource is not material")
		return
	if material.resource_name == "": 
		material.resource_name = path.get_file().get_slice(".",0)
		ResourceSaver.save(material)
	##################
	## New Material ##
	##################		
	if id == -1:
		id = 0		
		while material_table.has(id):
			id += 1
		material_table[id] = {"path": path, "meshes": []}		 				
		return		
	#######################
	## Existing Material ##
	#######################
	## 1. Update path in material table 
	material_table[id].path = path
			
	## 2. Update all mmesh resources that use this material
	for mesh_id in material_table[id].keys():
		var mesh_path = MHlod.get_mesh_path(mesh_id)
		if not FileAccess.file_exists(mesh_path): continue
		var mmesh:MMesh = load(mesh_path)
		for set_id in mmesh.material_set_get_count():
			var material_names = mmesh.material_set_get(set_id)
			for i in len(material_names):
				if material_names[i] == path:
					mmesh.surface_set_material(set_id, i, path)
		ResourceSaver.save(mmesh)		
	update_material_table(material_table)	
	
static func remove_material(id):	
	var material_table = get_material_table()
	if material_table.has(id):	
		if len(material_table[id].meshes) > 0:
			push_error("cannot remove material from table: still in use by ", len(material_table[id].meshes) , " meshes")
			#TODO: prevent user from trying to delete material that's still in use
			return
		material_table.erase(id)
		var thumbnail_path = AssetIO.get_thumbnail_path(id, false)
		if FileAccess.file_exists(thumbnail_path):
			DirAccess.remove_absolute( thumbnail_path )
			
	update_material_table(material_table)	

static func get_material_sets_from_surface_names(surface_names:PackedStringArray)->Array:
	var surfaces_sets_count:PackedInt32Array
	surfaces_sets_count.resize(surface_names.size())
	surfaces_sets_count.fill(1)
	var max_set = 1
	var material_regex = RegEx.create_from_string("(.*)[_ ]set[_ ]?(\\d+)$")
	for s in range(surface_names.size()):
		if surface_names[s].is_empty():
			surface_names[s] = "Unnamed"
		else:
			surface_names[s] = AssetIO.blender_end_number_remove(surface_names[s])		
		var reg_res = material_regex.search(surface_names[s])
		if reg_res:
			surface_names[s] = reg_res.strings[1]
			surfaces_sets_count[s] = max(int(reg_res.strings[2]),1)
			if surfaces_sets_count[s] > max_set: max_set = surfaces_sets_count[s]
	var material_sets:=[]
	for i in range(max_set):
		var ext_name:String
		if i!=0: ext_name = "_" + str(i)
		var _mm:PackedStringArray
		for s in range(surface_names.size()):
			_mm.push_back(surface_names[s]+ext_name)
		material_sets.push_back(_mm)
	return material_sets
