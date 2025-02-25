@tool
class_name TCPIO extends Object

enum DATA_TYPE {REMOVED, RENAMED, SELECTED_OBJECTS, MASSET }

static var server: TCPServer  
static var clients: Array[StreamPeerTCP]
static var port:int

static var last_selection = []
static var last_state = {} # state at time of last send... sent when client first connects
static var next_state = {} # state to send next

static var scene_root: Node
static var selection: EditorSelection

static var timer: Timer
static var last_update: int
const TIMER_INTERVAL = 0.9

static var auto = false
static var show_controls = false

static var debug = true

static func start_timer():	
	if not timer:		
		timer = Timer.new()
		if Engine.is_editor_hint():					
			EditorInterface.get_edited_scene_root().add_child(timer)
			timer.timeout.connect(on_timer)
	timer.start(TIMER_INTERVAL)

static func on_timer():	
	update_client_list()		
	if Time.get_ticks_msec()-last_update > TIMER_INTERVAL:
		last_update = Time.get_ticks_msec()
		receive_messages()		
		send_update()
		
static func init_variables():
	if timer: timer.start(TIMER_INTERVAL)
	clients = []	
	last_state = {}			
	next_state = {}					
	if Engine.is_editor_hint():
		selection = EditorInterface.get_selection()	
		scene_root = EditorInterface.get_edited_scene_root()			
		if not selection.selection_changed.is_connected(updated_selected_nodes):
			selection.selection_changed.connect(updated_selected_nodes)	
		if not scene_root.get_tree().node_added.is_connected(node_added):									
			scene_root.get_tree().node_added.connect(node_added)	
	
	scene_root.set_meta("original_name", scene_root.name)
	if not scene_root.renamed.is_connected(node_renamed.bind(scene_root)):
		scene_root.renamed.connect(node_renamed.bind(scene_root))					
	last_state["_root"] = get_node_state(scene_root)
	for node:Node3D in scene_root.find_children("*"):
		node.set_meta("original_name", node.name)
		if not node.renamed.is_connected(node_renamed.bind(node)):
			node.renamed.connect(node_renamed.bind(node))				
		if not node.tree_exiting.is_connected(node_exiting_tree.bind(node)):
			node.tree_exiting.connect(node_exiting_tree.bind(node))
		last_state[scene_root.get_path_to(node)] = get_node_state(node)			

static func de_init_variables():
	if timer: timer.stop()
	if selection.selection_changed.is_connected(updated_selected_nodes):
		selection.selection_changed.disconnect(updated_selected_nodes)
	if scene_root.get_tree().node_added.is_connected(node_added):			
		scene_root.get_tree().node_added.disconnect(node_added)	
	for node:Node in scene_root.find_children("*"):
		if node.renamed.is_connected(node_renamed.bind(node)):
			node.renamed.disconnect(node_renamed.bind(node))	
		if node.tree_exiting.is_connected(node_exiting_tree.bind(node)):
			node.tree_exiting.disconnect(node_exiting_tree.bind(node))
		node.remove_meta("original_name")
	if scene_root.renamed.is_connected(node_renamed.bind(scene_root)):
		scene_root.renamed.disconnect(node_renamed.bind(scene_root))	
	scene_root.remove_meta("original_name")	

static func start_server(port = 9997):	
	init_variables()			
	server = TCPServer.new()
	var err = server.listen(port, "127.0.0.1")
	if err != OK:
		print("Failed to listen on port:", port)
		return
	print("Godot TCP server listening on 127.0.0.1:", port)			

#func _exit_tree():
	#stop_server()

static func stop_server():
	print("Godot TCP server stopped")
	for client: StreamPeerTCP in clients:
		client.disconnect_from_host()
	clients = []
	server.stop()
	server = null
	de_init_variables()	
	if timer:
		timer.queue_free()
	timer = null
		
static func get_node_path(node:Node):
	return scene_root.get_path_to(node)

static func get_node_state(node:Node, diff_only=false):	
	if not node: return
	## INCLUUDED:
	## - Transform
	## - Node class
	## - asset identifier if needed
	var result = {"position": node.position, "rotation": node.rotation, "scale": node.scale}
	if not diff_only:
		if node is MAssetMesh: 
			result["type"] = TCPSerializer.TYPES.MASSET_MESH
			if node.collection_id in MAssetTable.get_singleton().collection_get_list():
				result["blend_file"] = AssetIO.get_blend_path_from_collection_id(node.collection_id)
				result["glb_name"] = AssetIO.get_asset_glb_name_from_collection_id(node.collection_id)					
		elif node is CollisionShape3D: 
			result["type"] = TCPSerializer.TYPES.COLLISION_SHAPE
			if node.shape is BoxShape3D: result["shape"] = {"type": TCPSerializer.TYPES.BOX, "x": node.shape.size.x, "y": node.shape.size.y, "z": node.shape.size.z}
			if node.shape is SphereShape3D: result["shape"] = {"type": TCPSerializer.TYPES.SPHERE, "radius": node.shape.radius}
			if node.shape is CapsuleShape3D: result["shape"] = {"type": TCPSerializer.TYPES.CAPSULE, "radius": node.shape.radius, "height": node.shape.height}
			if node.shape is CylinderShape3D: result["shape"] = {"type": TCPSerializer.TYPES.CYLINDER, "radius": node.shape.radius, "height": node.shape.height}			
		elif node is HLod_Baker: 
			result["type"] = TCPSerializer.TYPES.BAKER
		elif node is SpotLight3D:
			result["type"] = TCPSerializer.TYPES.SPOT_LIGHT
		elif node is OmniLight3D: 
			result["type"] = TCPSerializer.TYPES.POINT_LIGHT
		elif node is DirectionalLight3D: 
			result["type"] = TCPSerializer.TYPES.DIRECTIONAL_LIGHT
		else: result["type"] = TCPSerializer.TYPES.NONE
		if node.has_meta("meshcutoff"):result["meshcutoff"] = node.get_meta("meshcutoff")
		if node.has_meta("colcutoff"):result["colcutoff"] = node.get_meta("colcutoff")
		if node.has_meta("variation_layers"):result["variation_layers"] = node.get_meta("variation_layers")
	return result
	
static func node_added(node:Node):			
	return
	if not node.owner == scene_root: 		
		return	
	if not is_instance_valid(scene_root):				
		scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root.is_ancestor_of(node): 				
		print(node.name, " is not descendant of scene root: ", scene_root.name)
		return			
	print("NODE ADDED ", node.name)
	node.set_meta("original_name", node.name)	
	if not node.renamed.is_connected(node_renamed.bind(node)):
		node.renamed.connect(node_renamed.bind(node))		
	if not node.tree_exiting.is_connected(node_exiting_tree.bind(node)):
		node.tree_exiting.connect(node_exiting_tree.bind(node))	
	var path = scene_root.get_path_to(node)
	last_state[path] = get_node_state(node)	
	next_state[path] = last_state[path]		
	
static func node_exiting_tree(node:Node):
	if not scene_root == EditorInterface.get_edited_scene_root(): return	
	if not scene_root.is_ancestor_of(node): return	
	if not next_state.has("__removed"):
		next_state["__removed"] = []
	next_state["__removed"].push_back(get_node_path(node))	
	last_state.erase(get_node_path(node))	
	next_state.erase(get_node_path(node))
	if node.renamed.is_connected(node_renamed.bind(node)):
		node.renamed.disconnect(node_renamed.bind(node))		
	if node.tree_exiting.is_connected(node_exiting_tree.bind(node)):
		node.tree_exiting.disconnect(node_exiting_tree.bind(node))
		
static func node_renamed(node):
	var original_name = node.get_meta("original_name")
	if node.name == original_name: return
	if not next_state.has("__renamed"):
		next_state["__renamed"] = {}	
	var node_path = get_node_path(node)	
	var old_node_path = NodePath(str(get_node_path(node)).trim_suffix(node.name) + original_name)
	next_state["__renamed"][old_node_path] = node_path
	if next_state.has(old_node_path):
		next_state[node_path] = next_state[old_node_path]
		next_state.erase(old_node_path)	
	if last_state.has(old_node_path):
		last_state[node_path] = last_state[old_node_path]
		last_state.erase(old_node_path)	
	if next_state.has("__selected"):
		if next_state["__selected"].has(old_node_path):
			next_state["__selected"].erase(old_node_path)
		next_state["__selected"].push_back(node_path)
	if last_state.has("__selected"):
		if last_state["__selected"].has(old_node_path):
			last_state["__selected"].erase(old_node_path)
		last_state["__selected"].push_back(node_path)
	node.set_meta("original_name", node.name)

static func has_node_state_changed(node, path):	
	if not last_state.has(path) or not last_state[path].has("rotation"): return true
	if node.position != last_state[path].position or node.rotation != last_state[path].rotation or node.scale != last_state[path].scale: return true
	if node is MAssetMesh:		
		if last_state[path].has("collection_id") and node.collection_id != last_state[path].collection_id: return true
	return false

static func updated_selected_nodes():
	# before updating, check if selected object's transforms have changed		
	var nodes_to_update = {}
	var updated_nodes = {}
	if last_selection:		
		for path in last_selection:								
			if not path: continue #ERROR
			var node = scene_root if str(path) == "_root" else scene_root.get_node(path) if scene_root.has_node(path) else null
			if not node: continue
			if has_node_state_changed(node, path): 			
				if not next_state.has(path):
					next_state[path] = {}	
				next_state[path] = get_node_state(node, true)												
				if not updated_nodes.has(node):
					updated_nodes[node] = path
				if nodes_to_update.has(node):
					nodes_to_update.erase(node)
				for child in node.find_children("*"):
					if updated_nodes.has(child):
						nodes_to_update[child] = get_node_path(child)
		for node in nodes_to_update:
			if not next_state.has(nodes_to_update[node]):
				next_state[nodes_to_update[node]] = {}	
			next_state[nodes_to_update[node]] = get_node_state(node, true)												
	# Update selection			
	next_state["__selected"] = selection.get_selected_nodes().map(func(a): return scene_root.get_path_to(a) if not a == scene_root else "_root")		
	last_selection = next_state["__selected"]
	
static func update_client_list():	
	if server.is_connection_available():
		var client := server.take_connection()
		clients.push_back(client)
		print("New connection from:", client.get_connected_host(),":",client.get_connected_port() )		
		var message = pack_data(last_state) 		
		client.put_data(message)
		#	print(last_state)
		return true	
		
static func get_clients():
	for client in clients:
		client.poll()
		if client.get_status() == 0:
			clients.erase(client)
			continue
	return clients

static func receive_messages():
	for client: StreamPeerTCP in get_clients():
		if client.get_available_bytes() > 0:
			var message_length = client.get_u32()																					
			unpack_data(client.get_data( message_length -4)[1])			
								
static func send_update():	
	if not next_state: 		
		return		
	var c = get_clients()
	if len(c) == 0: return	
	if next_state.has("__selected") and last_state.has("__selected") and next_state["__selected"] == last_state["__selected"]: 
		next_state.erase("__selected")							
	for path in next_state.keys():				
		if str(path).begins_with("__"): continue				
		if next_state.has(path):			
			for key in next_state[path]:
				if last_state.has(path):
					last_state[path][key] = next_state[path][key]		
	var message = pack_data(next_state)	
	for client in c:			
		client.put_data(message)	
		#print(next_state)
	next_state = {}	

static func create_node(dict, nodepath):
	if not dict[nodepath].has("type"): push_error("trying to create new node, but it has not type: ", nodepath)
	var node
	if dict[nodepath]["type"] == TCPSerializer.TYPES.MASSET_MESH: 
		node = MAssetMesh.new()
		if not dict[nodepath].has("blend_file") or not dict[nodepath].has("glb_name"):
			push_warning("trying to create new MAssetMesh node, but not blend_path/glb_name was given" )
		else:
			node.collection_id = AssetIO.get_collection_id_from_blend_file_and_glb_name(dict[nodepath]["blend_file"], dict[nodepath]["glb_name"])							
	if dict[nodepath]["type"] == TCPSerializer.TYPES.COLLISION_SHAPE: 
		node = CollisionShape3D.new()
	if dict[nodepath]["type"] == TCPSerializer.TYPES.SPOT_LIGHT: 
		node = SpotLight3D.new()
	if dict[nodepath]["type"] == TCPSerializer.TYPES.POINT_LIGHT: 
		node = OmniLight3D.new()
	if dict[nodepath]["type"] == TCPSerializer.TYPES.DIRECTIONAL_LIGHT: 
		node = DirectionalLight3D.new()
	if dict[nodepath]["type"] == TCPSerializer.TYPES.BAKER: 
		node = HLod_Baker.new()
	## ASSIGN CORRECT PARENT		
	var path = NodePath(nodepath)
	var parent_path = path.slice(0, -1)
	var parent = scene_root.get_node(parent_path) if scene_root.has_node(parent_path) else null
	if not parent:
		push_error("trying to create new node, but parent doesn't exists: ", parent_path)
	parent.add_child(node)
	node.owner = scene_root
	node.name = path.get_name(path.get_name_count()-1)
	return node

static func unpack_data(data):
	var serializer = TCPSerializer.new()
	serializer.data = data
	serializer.unpack()			
	var dict = serializer.dict
	if not dict: return
	for key in dict:
		if key == "__selected":
			var new_selected_nodes = dict[key].map(func(path): return scene_root.get_node(path))
			var current_selected_nodes = selection.get_selected_nodes()
			for node in new_selected_nodes:
				if not node in current_selected_nodes:
					current_selected_nodes.push_back(node)
			for node in current_selected_nodes:
				if not node in new_selected_nodes:
					current_selected_nodes.erase(node)
		elif key == "__renamed":
			for old_name in dict[key].keys():
				var node = scene_root.get_node(old_name)
				node.name = dict[key][old_name]
		else:
			var node = scene_root if key == "_root" else scene_root.get_node(key) if scene_root.has_node(key) else create_node(dict, key)
			for prop in dict[key].keys():
				if prop == "position":
					node.position = dict[key][prop]
				if prop == "rotation":							
					node.rotation = dict[key][prop]
				if prop == "scale":							
					node.scale = dict[key][prop]	
								
static func pack_data(state): #->PackedByteArray:
	var serializer = TCPSerializer.new()
	serializer.dict = state
	serializer.pack()	
	return serializer.data	
