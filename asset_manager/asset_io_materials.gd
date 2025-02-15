class_name AssetIOMaterials extends Object
	
static func get_material_table()->Dictionary:
	var asset_library := MAssetTable.get_singleton()	
	if not asset_library: return {}
	if not asset_library.import_info.has("__materials"):
		asset_library.import_info["__materials"] = {}
	return asset_library.import_info["__materials"]

static func update_material_table(material_table:Dictionary):
	var asset_library := MAssetTable.get_singleton()	
	if not asset_library: push_error("trying to update material table, but asset library doesn't exist yet")
	asset_library.import_info["__materials"] = material_table
	asset_library.save()

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

static func get_material_by_name(mname:String)->Material:	
	var materials = get_material_table()
	for id in materials:
		if materials[id].name == mname:
			return load(materials[id]["path"])
	return null
	
static func get_material_name(material:Material)->String:
	var mid:int= get_material_id(material)
	if mid >= 0:
		var materials:= get_material_table()
		return materials[mid]["name"]
	return ""

static func rename_material(id, new_name):	
	var material_table = get_material_table()		
	material_table[id].name = new_name
	update_material_table(material_table)
		
static func update_material(id, material:Material):		
	var material_table = get_material_table()		
	if material.resource_name.is_empty(): 
		material.resource_name = material.resource_path.get_file().get_slice(".",0)
		ResourceSaver.save(material)
	##################
	## New Material ##
	##################		
	if id == -1:
		id = 0		
		while material_table.has(id):
			id += 1
		material_table[id] = {"path": material.resource_path, "name":material.resource_name}		 				
		return		
	#######################
	## Existing Material ##
	#######################	
	## 1. Update path in material table 
	material_table[id].path = material.resource_path
	material_table[id].name = material.resource_name
	
	## 2. Reimport all glb that use this material	
	var glb_to_reimport = get_glbs_using_material(id)
	update_material_table(material_table)	
	for glb in glb_to_reimport:
		AssetIO.glb_load(glb, {}, true)

static func get_glbs_using_material(material_id):
	var import_info = MAssetTable.get_singleton().import_info	
	var glb_to_reimport = []	
	for glb_path in import_info:				
		if glb_path in glb_to_reimport: continue
		if glb_path.begins_with("__"): continue		
		if not import_info[glb_path].has("__materials"):continue	
		for id in import_info[glb_path]["__materials"].values():
			if id == material_id:	
				glb_to_reimport.push_back(glb_path)	
				break									
	return glb_to_reimport
	
static func find_material_by_name(material_name):
	var material_table = get_material_table()
	for id in material_table:	
		if material_table[id].name.matchn(material_name):
			return id	
	return -1	

static func remove_material(id):	
	var material_table = get_material_table()
	if material_table.has(id):	
		var glbs = get_glbs_using_material(id)
		if len(glbs) > 0:
			push_error("cannot remove material from table: still in use by ", len(material_table[id].meshes) , " meshes")
			#TODO: prevent user from trying to delete material that's still in use
			return
		material_table.erase(id)
		var thumbnail_path = MAssetTable.get_asset_thumbnails_dir().path_join(str("material_", id, ".dat"))
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

static func get_physics():	
	var dir_path = MHlod.get_physics_settings_dir()
	var dir = DirAccess.open(dir_path)
	var out:Dictionary
	if not dir:
		return out
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		var fpath = dir_path.path_join(fname)
		fname = dir.get_next()
		var s:MHlodCollisionSetting = load(fpath)
		if out.has(s.name):
			printerr("Duplicate Physcis Setting name Please change the name mannually and restart Godot"+fpath)
			continue
		if s:
			out[s.name] = s
	return out

static func get_physics_ids():
	var dir_path = MHlod.get_physics_settings_dir()
	var dir = DirAccess.open(dir_path)
	var out:Dictionary
	if not dir:
		return out
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		var fpath = dir_path.path_join(fname)
		fname = dir.get_next()
		var s:MHlodCollisionSetting = load(fpath)
		if out.has(s.name):
			printerr("Duplicate Physcis Setting name Please change the name mannually and restart Godot"+fpath)
			continue
		if s:
			out[s.name] = s.resource_path.to_int()
	return out
