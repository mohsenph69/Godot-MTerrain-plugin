@tool
class_name Mesh_Item extends MOctMesh

@export var mesh_id = 0:
	set(val):
		if mesh_id == val: return
		if mesh_id == null: return
		mesh_id = val
		load_mesh_item()
		notify_property_list_changed()
@export var material_overrides: Array[Material] = []

var asset_library:MAssetTable = load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))

func _notification(what):
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		if asset_library.has_mesh_item(mesh_id):
			save_changes()

func load_mesh_item():	
	if not mesh_lod: mesh_lod = MMeshLod.new()
	if asset_library.has_mesh_item(mesh_id):
		var data = asset_library.mesh_item_get_info(mesh_id)
		var meshes = []
		for mesh_hash in data.mesh:		
			var path = str("res://addons/m_terrain/asset_manager/example_asset_library/import/", mesh_hash, ".res")			
			if FileAccess.file_exists(path):
				meshes.push_back(load(path))
			else:
				meshes.push_back(null)
		mesh_lod.meshes = meshes	
	else:
		mesh_lod.meshes = []
	print(mesh_lod)

func save_changes():	
	mesh_id = save(asset_library, mesh_id, mesh_lod.meshes, material_overrides)
	print("saved mesh")
	
static func save(asset_library, mesh_id, meshes, materials):	
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
	
