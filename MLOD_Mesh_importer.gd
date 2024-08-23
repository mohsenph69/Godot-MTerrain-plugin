@tool
extends GLTFDocumentExtension

func _import_post(state:GLTFState, root:Node):
	if not "MMeshLod" in root.name: 
		return
	
	var meshes_json : Array = state.json.get("meshes", [])
	var meshes : Array[GLTFMesh] = state.get_meshes()
	
	var result: MMeshLod = MMeshLod.new()	
	result.meshes = meshes.map(func(a): return a.mesh.get_mesh())
	
	ResourceSaver.save(result, str(state.base_path, "/", root.name, ".res"))		
		
