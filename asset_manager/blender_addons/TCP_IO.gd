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

static func start_timer():	
	if not timer:		
		timer = Timer.new()
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
	selection = EditorInterface.get_selection()	
	scene_root = EditorInterface.get_edited_scene_root()	
	if not selection.selection_changed.is_connected(updated_selected_nodes):
		selection.selection_changed.connect(updated_selected_nodes)
	if not scene_root.child_entered_tree.is_connected(node_added):
		scene_root.child_entered_tree.connect(node_added)	
	
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
	if scene_root.child_entered_tree.is_connected(node_added):
		scene_root.child_entered_tree.disconnect(node_added)	
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
	## INCLUUDED:
	## - Transform
	## - Node class
	## - asset identifier if needed
	var result = {"position": node.position, "rotation": node.rotation, "scale": node.scale}
	if not diff_only:
		result["type"]=node.get_class()
		if node is MAssetMesh:
			if node.collection_id in MAssetTable.get_singleton().collection_get_list():
				result["blend_file"] = AssetIO.get_blend_path_from_collection_id(node.collection_id)
				result["glb_name"] = AssetIO.get_asset_glb_name_from_collection_id(node.collection_id)		
	return result
	
static func node_added(node:Node):	
	if not node.owner == scene_root: return
	if not scene_root.is_ancestor_of(node): return		
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
	if next_state.has("__selected_objects"):
		if next_state["__selected_objects"].has(old_node_path):
			next_state["__selected_objects"].erase(old_node_path)
		next_state["__selected_objects"].push_back(node_path)
	if last_state.has("__selected_objects"):
		if last_state["__selected_objects"].has(old_node_path):
			last_state["__selected_objects"].erase(old_node_path)
		last_state["__selected_objects"].push_back(node_path)
	node.set_meta("original_name", node.name)

static func has_node_state_changed(node, path):
	if last_state.has(path) or not last_state[path].has("rotation"): return true
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
			var node = scene_root.get_node(path) if str(path) != "_root" else scene_root
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
	next_state["__selected_objects"] = selection.get_selected_nodes().map(func(a): return scene_root.get_path_to(a) if not a == scene_root else "_root")		
	last_selection = next_state["__selected_objects"]
	
static func update_client_list():	
	if server.is_connection_available():
		var client := server.take_connection()
		clients.push_back(client)
		print("New connection from:", client.get_connected_host(),":",client.get_connected_port() )		
		var message = pack_data(last_state) 		
		client.put_data(message)
		
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
			var message = client.get_data( message_length )
			var data = JSON.parse_string(message)
			print(data)
			return
			if not data: return
			for key in data:
				if key == "__selected_objects":
					var new_selected_nodes = data[key].map(func(path): return scene_root.get_node(path))
					var current_selected_nodes = selection.get_selected_nodes()
					for node in new_selected_nodes:
						if not node in current_selected_nodes:
							current_selected_nodes.push_back(node)
					for node in current_selected_nodes:
						if not node in new_selected_nodes:
							current_selected_nodes.erase(node)
				elif key == "__renamed":
					for old_name in data[key].keys():
						var node = scene_root.get_node(old_name)
						node.name = data[key][old_name]
				else:
					var node = scene_root.get_node(key) if key != "_root" else scene_root
					for prop in data[key].keys():
						if prop == "position":
							node.position = data[key][prop]
						if prop == "rotation":							
							node.rotation = data[key][prop]
						if prop == "scale":							
							node.scale = str_to_var(data[key][prop])
								
static func send_update():	
	if not next_state: 		
		return		
	var c = get_clients()
	if len(c) == 0: return	
	if next_state.has("__selected_objects") and last_state.has("__selected_objects") and next_state["__selected_objects"] == last_state["__selected_objects"]: 
		next_state.erase("__selected_objects")							
	for path in next_state.keys():				
		if str(path).begins_with("__"): continue				
		if next_state.has(path):			
			for key in next_state[path]:
				last_state[path][key] = next_state[path][key]	
	var message = pack_data(next_state)
	for client in c:			
		client.put_data(message)	
	next_state = {}	

static func int_to_bytes(i: int)->PackedByteArray:
	var data := PackedByteArray()
	data[0] = i & 0xFF
	data[1] = (i >> 8) & 0xFF
	data[2] = (i >> 16) & 0xFF
	data[3] = (i >> 24) & 0xFF		
	return data
	
static func pack_data(state): #->PackedByteArray:
	#var PACKET_SIZE = 2048
	var message = JSON.stringify( state )
	var file = FileAccess.open("res://massets_editor/tmp.json",FileAccess.WRITE)
	file.store_string(message)
	file.close()
	var data := PackedInt32Array([len(message)]).to_byte_array()
	data.append_array(message.to_utf8_buffer())
	return data
	# PROTOCOL
	# Start with 4 bytes = 255 each to signal packet start
	# Next byte = data type (removed, renamed, selected_objects, etc)
	# Next byte (or 2?) = count of next array
	# Next X Bytes = data (depends of type)	
	#data.resize(PACKET_SIZE)
	data[0] = 255
	data[1] = 255
	data[2] = 255
	data[3] = 255	
	var byte_offset := 4	
	if state.has("__removed"):
		data[byte_offset] = DATA_TYPE.REMOVED
		byte_offset += 1					
		data[byte_offset] = len(state["__removed"]) #TODO is 1 byte enough for this?
		byte_offset += 1
		for i in len(state["__removed"]):			
			data.append_array(state["__removed"][i])
			data.append(0)	
			byte_offset += len(state["__removed"][i]) + 1			
	if state.has("__renamed"):
		data[byte_offset] = DATA_TYPE.RENAMED
		byte_offset += 1
		data[byte_offset] = len(state["__renamed"].keys()) #TODO is 1 byte enough for this?
		byte_offset += 1
		for key in state["__renamed"].keys():			
			data.append_array(key)
			data.append(0)	
			data.append_array(state["__renamed"][key])
			data.append(0)	
			byte_offset += len(key) + 1 + len(state["__renamed"][key]) + 1			
	if state.has("__selected_objects"):
		data[byte_offset] = DATA_TYPE.SELECTED_OBJECTS
		byte_offset += 1
		data[byte_offset] = len(state["__selected_objects"].keys()) #TODO is 1 byte enough for this?
		byte_offset += 1
		for key in state["__renamed"].keys():			
			data.append_array(key)
			data.append(0)	
			data.append_array(state["__renamed"][key])
			data.append(0)	
			byte_offset += len(key) + 1 + len(state["__renamed"][key]) + 1			
	for key in state:
		if key.begins_with("__"): continue
		
	return data
