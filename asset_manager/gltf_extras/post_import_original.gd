@tool
extends EditorScenePostImport

var verbose = true
var all_extras = false
func _post_import(scene: Node) -> Object:	
	_merge_extras(scene)	
	for node in scene.get_children():
		if node.has_meta("extras"):
			var extras = node.get_meta("extras")
			if extras.keys().has("instance_name"):				
				var new_name = extras["instance_name"]								
				var new_path = find_file("res://import/", new_name)				
				if FileAccess.file_exists(new_path):	
					#print(new_path)									
					var new_scene = load(new_path).instantiate()				
					node.add_sibling(new_scene)
					new_scene.transform = node.transform
					new_scene.owner = node.owner							
					node.get_parent().remove_child(node)
					node.free()					
					new_scene.name = new_name
				else:													
					node.queue_free()
			else:										
				node.queue_free()	
		else:										
			node.queue_free()													
	return scene

func _merge_extras(scene : Node) -> void:	
	var verbose_output = []
	var nodes : Array[Node] = scene.find_children("*" + "_meta", "Node")
	#var all_nodes = scene.find_children("*", "Node")
	#for node in all_nodes:
		#if not node in nodes:
			#node.queue_free()
	verbose_output.append_array(["Metadata nodes:",  nodes])
	for node in nodes:
		var extras = node.get_meta("extras")		
		if !extras:
			verbose_output.append("Node %s contains no 'extras' metadata" % node)
			continue
		var parent = node.get_parent()
		if !parent:
			verbose_output.append("Node %s has no parent" % node)
			continue
		var idx_original = node.get_index() - 1
		if idx_original < 0 or parent.get_child_count() <= idx_original:
			verbose_output.append("Original node index %s is out of bounds. Parent child count: %s" % [idx_original, parent.get_child_count()])
			continue
		var original = node.get_parent().get_child(idx_original)
		if original:			
			verbose_output.append("Setting extras metadata for %s" % original)
			if all_extras:				
				original.set_meta("extras", extras)
			if extras.keys().has("instance_name"):								
				var new_name = extras["instance_name"]
				var new_path = find_file("res://import/", new_name)				
				if FileAccess.file_exists(new_path):										
					var new_scene = load(new_path).instantiate()				
					original.add_sibling(new_scene)
					new_scene.transform = original.transform
					new_scene.owner = original.owner		
					new_scene.name = new_name
					original.get_parent().remove_child(node)
					original.free()
					continue
				else:					
					original.queue_free()
					node.queue_free()
					continue
				if node.has_meta("mesh_extras"):
					if original is MeshInstance3D and original.mesh:
						verbose_output.append("Setting extras metadata for mesh %s" % original.mesh)
						original.mesh.set_meta("extras", node.get_meta("mesh_extras"))
					else:
						verbose_output.append("Metadata node %s has 'mesh_extras' but original %s has no mesh, preserving as 'mesh_extras'" % [node, original])
						original.set_meta("mesh_extras", node.get_meta("mesh_extras"))
			else:
				original.queue_free()
				node.queue_free()
		else:
			verbose_output.append("Original node not found for %s" % node)
		node.queue_free()
	
	if verbose:
		for item in verbose_output:
			print(item)

func find_file(path, new_name):
	for file in DirAccess.get_files_at(path):	
		if file.contains(new_name + ".glb"):
			return path + new_name + ".glb"		
	for dir in DirAccess.get_directories_at(path):
		var result = find_file(str(path, dir), new_name)
		if result:
			return "" || result 
		
