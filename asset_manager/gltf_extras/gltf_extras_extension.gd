@tool
class_name GLTFExtras extends GLTFDocumentExtension

const import_meshes = false

func _import_post(state: GLTFState, root: Node) -> Error:				
	# Add metadata to materials
	var materials_json : Array = state.json.get("materials", [])
	var materials : Array[Material] = state.get_materials()		
			
	# Add metadata to ImporterMeshes
	var meshes_json : Array = state.json.get("meshes", [])
	var meshes : Array[GLTFMesh] = state.get_meshes()
	for i in meshes_json.size():
		if meshes_json[i].has("extras"):
			meshes[i].mesh.set_meta("extras", meshes_json[i]["extras"])				
	
	# Add metadata to nodes
	var nodes_json : Array = state.json.get("nodes", [])
	for i in nodes_json.size():
		var node = state.get_scene_node(i)
		if !node:
			continue			
		if nodes_json[i].has("extras"):
			var extras = nodes_json[i]["extras"]								
			# Handle special case
			if node is ImporterMeshInstance3D:					
				if import_meshes:
					# ImporterMeshInstance3D nodes will be converted later to either
					# MeshInstance3D or StaticBody3D and metadata will be lost
					# A sibling is created preserving the metadata. It can be later 
					# merged back in using a EditorScenePostImport script
					var metadata_node = Node.new()
					metadata_node.set_meta("extras", extras)
					
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
					node.set_meta("extras", extras)					
	return OK

func _export_preflight(state: GLTFState, root: Node):		
	replace_mmesh_lod_with_meshes(root)
	
func replace_mmesh_lod_with_meshes(root):	
	for child in root.get_children():		
		if child is MOctMesh:
			var mesh_lod = child.mesh_lod
			var mesh_nodes_meshes = []
			for i in len(mesh_lod.meshes):			
				if mesh_lod.meshes[i] in mesh_nodes_meshes: continue
				var mesh_node = MeshInstance3D.new()
				mesh_node.mesh = mesh_lod.meshes[i]
				root.add_child(mesh_node)
				mesh_node.owner = root.owner
				mesh_node.name = str(root.name, "_lod_", i)
				mesh_node.set_meta("item_id",child.get_meta("item_id"))
				mesh_nodes_meshes.push_back(mesh_node.mesh)				
			root.remove_child(child)
			child.queue_free()
		replace_mmesh_lod_with_meshes(child)

func _export_node(state: GLTFState, gltf_node: GLTFNode, json: Dictionary, node: Node):				
	if node.has_meta("extras"):
		json["extras"] = node.get_meta("extras")	
	if node.has_meta("collection_id"):
		#json.name = node.collection.resource_name		
		if node.has_meta("extras"):
			json["extras"] = node.get_meta("extras").merged({"collection_id": node.get_meta("collection_id")}, true)
		else:
			json["extras"] = {"collection_id": node.get_meta("collection_id")}
