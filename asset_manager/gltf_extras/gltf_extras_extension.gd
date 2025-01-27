@tool
class_name GLTFExtras extends GLTFDocumentExtension

const import_meshes = false

func _import_post(state: GLTFState, root: Node) -> Error:				
	#THIS CODE IS FOR AUTO REIMPORTING Joined meshes... but i		
	if "_joined_mesh" in root.name:					
		var baker_path = state.base_path.path_join(root.name.split("_joined_mesh")[0]+".tscn" )
		if not ResourceLoader.exists(baker_path):
			return OK
		var baker:PackedScene = load(baker_path)
		var scene_state:SceneState = baker.get_state()
		var joined_mesh_id
		for i in scene_state.get_node_property_count(0):
			var prop_name = scene_state.get_node_property_name(0,i)
			if prop_name == "joined_mesh_id":
				joined_mesh_id = scene_state.get_node_property_value(0,i)						
		var joined_mesh_nodes = root.find_children("*_joined_mesh*")				
		AssetIOBaker.import_join_mesh_auto(state.base_path.path_join(root.name + ".glb"), joined_mesh_nodes, joined_mesh_id)		
		return OK
	# Add metadata to materials
	var materials_json : Array = state.json.get("materials", [])
	var materials : Array[Material] = state.get_materials()		
	
	# Add metadata to ImporterMeshes
	var meshes_json : Array = state.json.get("meshes", [])
	var meshes : Array[GLTFMesh] = state.get_meshes()
	for i in meshes_json.size():		
		if meshes_json[i].has("extras"):		
			for meta in meshes_json[i]["extras"]:			
				meshes[i].mesh.set_meta(meta, meshes_json[i]["extras"][meta])				
	
	# Add metadata to nodes
	var nodes_json : Array = state.json.get("nodes", [])
	for i in nodes_json.size():
		var node = state.get_scene_node(i)
		if !node:
			continue			
		if nodes_json[i].has("extras"):
			var extras = nodes_json[i]["extras"]											
			node.set_meta("extras", true)
			# Handle special case
			if node is ImporterMeshInstance3D:					
				for meta in extras:
					node.set_meta(meta, extras[meta])
				if import_meshes:
					# ImporterMeshInstance3D nodes will be converted later to either
					# MeshInstance3D or StaticBody3D and metadata will be lost
					# A sibling is created preserving the metadata. It can be later 
					# merged back in using a EditorScenePostImport script
					var metadata_node = Node.new()
					for meta in extras:
						metadata_node.set_meta(meta, extras[meta])
					
					# Meshes are also ImporterMeshes that will be later converted either
					# to ArrayMesh or some form of collision shape. 
					# We'll save it as another metadata item. If the mesh is reused we'll 
					# have duplicated info but at least it will always be accurate
					if node.mesh and node.mesh.has_meta("extras"):						
						metadata_node.set_meta("mesh_extras", node.mesh.get_meta("extras"))
					
					# Well add it as sibling so metadata node always follows the actual metadata owner
					node.add_sibling(metadata_node)
					node.get_parent().move_child(metadata_node, metadata_node.get_index()-1)
					# Make sure owner is set otherwise it won't get serialized to disk						
					metadata_node.owner = node.owner
					# Add a suffix to the generated name so it's easy to find
					metadata_node.name += "_meta"
			# In all other cases just set_meta
			else:
				if not extras.is_empty():
					for meta in extras:
						node.set_meta(meta, extras[meta])						
	var glb_path = state.base_path.path_join(state.filename + ".glb")
	#if MAssetTable.get_singleton().import_info.has(glb_path):
		#AssetIO.glb_load_assets(state, root.duplicate(), glb_path, {}, true )	
	return OK
	
func _export_preflight(state: GLTFState, root: Node):			
	root.owner = null
	replace_mmesh_lod_with_meshes(root, root)		
	
func replace_mmesh_lod_with_meshes(scene_root, root):		
	return
	for child in root.get_children():		
		if child is MAssetMesh:											
			child.get_mes
			var mesh_nodes_meshes = []
			for i in len(child.meshes.meshes):			
				if child.meshes.meshes[i] in mesh_nodes_meshes: continue
				if child.meshes.meshes[i] == null: continue
				var mesh_node = MeshInstance3D.new()
				mesh_node.mesh = child.meshes.meshes[i]
				child.add_sibling(mesh_node)
				mesh_node.transform = child.transform
				mesh_node.owner = scene_root
				mesh_node.name = str(root.name, "_lod_", i)
				mesh_node.set_meta("item_id",child.get_meta("mesh_id"))
				mesh_nodes_meshes.push_back(mesh_node.mesh)								
			root.remove_child(child)
			child.queue_free()
		replace_mmesh_lod_with_meshes(scene_root, child)

func _export_node(state: GLTFState, gltf_node: GLTFNode, json: Dictionary, node: Node):							
	var extras = {}
	for meta in node.get_meta_list():
		extras[meta] = node.get_meta(meta)
	json["extras"] = extras #node.get_meta("extras")	
