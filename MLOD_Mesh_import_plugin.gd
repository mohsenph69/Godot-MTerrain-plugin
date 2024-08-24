@tool
extends EditorImportPlugin

func _get_importer_name():
	return "MLOD_Mesh_Importer"

func _get_visible_name():
	return "MLOD Mesh Importer"

func _get_recognized_extensions():
	return ["gltf", "glb"]

func _get_save_extension():
	return "res"

func _get_resource_type():
	return "MMeshLod"

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary):
	return true
	
func _get_import_order():
	return 0

func _get_preset_count():
	return 1

func _get_preset_name(preset_index):
	return "Default"

func _get_import_options(path, preset_index):
	return []

func _import(source_file, save_path, options, platform_variants, gen_files):	
	var gltf_document_load = GLTFDocument.new()
	var gltf_state_load = GLTFState.new()
	var error = gltf_document_load.append_from_file(source_file, gltf_state_load)
	var mmesh_lod = MMeshLod.new()	
	if error == OK:		
		var gltf_scene_root_node = gltf_document_load.generate_scene(gltf_state_load)
		mmesh_lod.meshes.resize(gltf_state_load.meshes.size())
		for i in gltf_state_load.meshes.size():
			mmesh_lod.meshes[i] =  gltf_state_load.meshes[i].mesh.get_mesh() 
	var filename = save_path + ".glb"
	return ResourceSaver.save(mmesh_lod, filename)	
