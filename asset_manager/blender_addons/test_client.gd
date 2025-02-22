@tool
extends Node3D

enum DATA_TYPE {REMOVED, RENAMED, SELECTED_OBJECTS, OBJECT }

@export var check_connections: bool:
	set(val):
		update_client_list()	
				
@export var send: bool:
	set(val):
		update_client_list()	
		send_update()
		
@export var receive: bool:
	set(val):
		update_client_list()	
		receive_messages()
		
var server: TCPServer  
var clients: Array[StreamPeerTCP]
var port:int
var last_update: int
var realtime: bool
var TIMER_INTERVAL: int

var last_selection = []
var last_state = {} # state at time of last send... sent when client first connects
var next_state = {} # state to send next

var scene_root: Node
var selection: EditorSelection

func _enter_tree():	
	if not is_node_ready():
		await ready
	clients = []
	TIMER_INTERVAL = 0.5	
	last_update = Time.get_ticks_msec()
	last_state = {}			
	next_state = {}		
	realtime = true
	port = 9997
	selection  = EditorInterface.get_selection()	
	scene_root = EditorInterface.get_edited_scene_root()
	
	if not selection.selection_changed.is_connected(updated_selected_nodes):
		selection.selection_changed.connect(updated_selected_nodes)
	if not get_tree().node_added.is_connected(node_added):
		get_tree().node_added.connect(node_added)	
	
	scene_root.set_meta("original_name", scene_root.name)
	if not scene_root.renamed.is_connected(node_renamed.bind(scene_root)):
		scene_root.renamed.connect(node_renamed.bind(scene_root))				
	last_state["_root"] = get_node_state(scene_root)
	for node:Node3D in scene_root.find_children("*"):
		node.set_meta("original_name", node.name)
		if not node.renamed.is_connected(node_renamed.bind(node)):
			node.renamed.connect(node_renamed.bind(node))				
		last_state[scene_root.get_path_to(node)] = get_node_state(node)			
	server = TCPServer.new()
	var err = server.listen(port, "127.0.0.1")
	if err != OK:
		print("Failed to listen on port:", port)
		return
	print("Godot TCP server listening on 127.0.0.1:", port)		
	set_process(realtime)

func _exit_tree():
	for client: StreamPeerTCP in clients:
		client.disconnect_from_host()
	clients = []
	server.stop()
	
	if selection.selection_changed.is_connected(updated_selected_nodes):
		selection.selection_changed.disconnect(updated_selected_nodes)
	if get_tree().node_added.is_connected(node_added):
		get_tree().node_added.disconnect(node_added)	
	for node:Node in scene_root.find_children("*"):
		if node.renamed.is_connected(node_renamed.bind(node)):
			node.renamed.disconnect(node_renamed.bind(node))
		if not node.tree_exiting.is_connected(node_exiting_tree.bind(node)):
			node.tree_exiting.connect(node_exiting_tree.bind(node))

func get_node_path(node):
	return scene_root.get_path_to(node)

func get_node_state(node, diff_only=false):
	var result = {"transform": node.transform}
	if not diff_only:
		result["type"]=node.get_class()
		if node.has_meta("_collection_identifier"):
			var asset_data = node.get_meta("_collection_identifier")
			result["blend_file"] = AssetIO.get_blend_path_from_glb_id(asset_data[0])
			result["glb_name"] = asset_data[1]
	return result
	
func node_added(node):	
	if not scene_root.is_ancestor_of(node): return
	next_state[scene_root.get_path_to(node)] = get_node_state(node)
	if not node.renamed.is_connected(node_renamed.bind(node)):
		node.renamed.connect(node_renamed.bind(node))		
		
func node_exiting_tree(node):
	if not scene_root == EditorInterface.get_edited_scene_root(): return	
	if not scene_root.is_ancestor_of(node): return	
	if not next_state.has("__removed"):
		next_state["__removed"] = []
	next_state["__removed"].push_back(get_node_path(node))	
	if node.renamed.is_connected(node_renamed.bind(node)):
		node.renamed.disconnect(node_renamed.bind(node))		
	if node.tree_exiting.is_connected(node_exiting_tree.bind(node)):
		node.tree_exiting.disconnect(node_exiting_tree.bind(node))
		
func node_renamed(node):
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

func has_node_state_changed(node, path):
	return not last_state.has(path) or not last_state[path].has("transform") or node.transform != last_state[path].transform		

func updated_selected_nodes():
	# before updating, check if selected object's transforms have changed		
	var nodes_to_update = {}
	var updated_nodes = {}
	if last_selection:		
		for path in last_selection:								
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
	
#func fix_selected_objects_root(data):
	#if data.has("__selected_objects"):
		#if data["__selected_objects"].has("."):
			#data["__selected_objects"].erase(".")
			#data["__selected_objects"].push_back("_root")

func update_client_list():	
	if server.is_connection_available():
		var client := server.take_connection()
		clients.push_back(client)
		print("New connection from:", client.get_connected_host(),":",client.get_connected_port() )
		var data = last_state.duplicate(true)
		#fix_selected_objects_root(data)		
		var message = pack_data(data) 
		print(message)	
		client.put_data(message.to_utf8_buffer())
		last_update = Time.get_ticks_msec() + 1000
		
func get_clients():
	for client in clients:
		client.poll()
		if client.get_status() == 0:
			clients.erase(client)
			continue
	return clients

func receive_messages():
	for client in get_clients():
		if client.get_available_bytes() > 0:
			var message = client.get_data( client.get_available_bytes() )[1].get_string_from_utf8()
			var data = JSON.parse_string(message)
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
					var node = scene_root.get_node(key)
					for prop in data[key].keys():
						if prop == "transform":							
							node.transform = str_to_var(data[key][prop])  # TODO format correctly
								
func send_update():	
	if not next_state: 
		print("No next state")
		return		
	var c = get_clients()
	if len(c) == 0: return	
	if next_state.has("__selected_objects") and last_state.has("__selected_objects") and next_state["__selected_objects"] == last_state["__selected_objects"]: 
		next_state.erase("__selected_objects")							
	for path in next_state.keys():				
		if str(path).begins_with("__"): continue				
		if next_state.has(path):			
			last_state[path] = next_state[path]			
	#fix_selected_objects_root(next_state)					
	print(next_state)
	var message = pack_data(next_state)
	for client in c:		
		client.put_data(message.to_utf8_buffer())
	last_update = Time.get_ticks_msec()
	next_state = {}

func pack_data(state)->String: #PackedByteArray:
	return JSON.stringify( state )	
	#var data: PackedByteArray = []
	#data.resize(1024)
	#var byte_offset := 0	
	#if state.has("__removed"):
		#data[byte_offset] = DATA_TYPE.REMOVED
		#byte_offset += 1
		#data[byte_offset] = len(state["__removed"]) #TODO is 1 byte enough for this?
		#byte_offset += 1
		#for i in len(state["__removed"]):			
			#data.append_array(state["__removed"][i])
			#data.append(0)	
			#byte_offset += len(state["__removed"][i]) + 1			
	#if state.has("__renamed"):
		#data[byte_offset] = DATA_TYPE.RENAMED
		#byte_offset += 1
		#data[byte_offset] = len(state["__renamed"].keys()) #TODO is 1 byte enough for this?
		#byte_offset += 1
		#for key in state["__renamed"].keys():			
			#data.append_array(key)
			#data.append(0)	
			#data.append_array(state["__renamed"][key])
			#data.append(0)	
			#byte_offset += len(key) + 1 + len(state["__renamed"][key]) + 1			
	#if state.has("__selected_objects"):
		#data[byte_offset] = DATA_TYPE.SELECTED_OBJECTS
		#byte_offset += 1
		#data[byte_offset] = len(state["__selected_objects"].keys()) #TODO is 1 byte enough for this?
		#byte_offset += 1
		#for key in state["__renamed"].keys():			
			#data.append_array(key)
			#data.append(0)	
			#data.append_array(state["__renamed"][key])
			#data.append(0)	
			#byte_offset += len(key) + 1 + len(state["__renamed"][key]) + 1			
	#for key in state:
		#if key.begins_with("__"): continue
		#
	#return data
	
# REALTIME ONLY
func _process(_delta):		
	update_client_list()		
	if Time.get_ticks_msec()-last_update > TIMER_INTERVAL:
		last_update = Time.get_ticks_msec()
		receive_messages()
		if next_state:
			send_update()
