@tool
extends PanelContainer

@onready var cancel_button:Button = find_child("cancel_button")
@onready var import_button:Button = find_child("import_button")
@onready var import_label:Label = find_child("import_label")
@onready var node_container = find_child("node_container")

var asset_data:AssetIOData

func _ready():
	if get_parent() is Window:
		get_parent().close_requested.connect(get_parent().queue_free)
	cancel_button.pressed.connect(func():
		if get_parent() is Window:
			get_parent().queue_free()
	)
	if asset_data == null:
		return
	var asset_library = MAssetTable.get_singleton()
	#import_label.text = "Importing " + asset_data.glb_path.split("/")[-1] + "\n"
	#import_label.text += "\n----------- Mesh Items -------------\n"
	#import_label.text += str(asset_data.mesh_items)
	#import_label.text += "\n----------- Collections -------------\n"
	#import_label.text += str(asset_data.collections)
	
	import_button.pressed.connect(func():						
		AssetIO.glb_import_commit_changes()		
		if get_parent() is Window:
			get_parent().queue_free()
	)
	#var preview_dictionary_label = find_child("preview_dictionary_label")
	#preview_dictionary_label.text = str(preview_dictionary).erase(0,2).replace("{", "{\n").replace("}", "\n}").replace("}, ", "},\n")	
	var tree: Tree = %preview_dictionary_tree
	tree.item_edited.connect(func():				
		var item := tree.get_selected()	
		item.propagate_check(0)
	)
	tree.check_propagated_to_item.connect(func(item:TreeItem,column):		
		var node = item.get_metadata(column)
		if node.has("import_state") and node.import_state.has("ignore"):
			node.import_state.ignore = not item.is_checked(column)
			update_label()
		#if not preview_dictionary.has(item_name):
		#	print(item_name, " not in ", preview_dictionary.keys())
		#preview_dictionary[item_name].ignore = item.is_checked(0)
		
	)
	tree.set_column_expand(0,true)
	tree.set_column_expand(1,false)		
	tree.set_column_custom_minimum_width(1,120)
	tree.item_selected.connect(update_label)
	var root = tree.create_item()	
	root.set_text(0, asset_data.glb_path)
	for key in asset_data.collections:		
		if asset_data.collections[key].has("is_root"):
			build_tree(key, root)
	return
	
func update_label():
	var tree: Tree = %preview_dictionary_tree				
	var item = tree.get_selected()
	var node_name = item.get_text(0)
	%preview_dictionary_label.text = str(asset_data.collections[node_name]).erase(0,2).replace("{", "{\n").replace("}", "\n}").replace("}, ", "},\n")	
	
func build_tree(node_name:String, root:TreeItem):	
	var item := root.create_child()		
	var node = asset_data.collections[node_name] if asset_data.collections.has(node_name) else {}
	
	item.set_cell_mode(0,TreeItem.CELL_MODE_CHECK)		
	item.set_editable(0, true)
	item.set_text(0, node_name)		
	item.set_metadata(0, node)		
	var suffix = ""	
	if node.has("import_state"):
		if node.import_state.has("ignore"):				
			item.set_checked(0, not node.import_state["ignore"])							
		if node.import_state.has("state") and node.import_state.state > 0:				
			suffix += "" + AssetIO.IMPORT_STATE.keys()[node.import_state.state]			
	if node.has("tag_as_hidden"):			
		item.set_custom_color(0, Color(1,1,1,0.4))			
	
	item.set_text(1, suffix)
	if node.has("collections"):		
		for key in node.collections:			
			build_tree(key, item)
	#if node.has("meshes"):
		#for i in len(node.meshes):
			#build_mesh_items(node.meshes[i], i, node_name, item)

#func build_mesh_items(mesh, i, node_name, root:TreeItem):
	#var node = preview_dictionary[node_name]
	#var item := root.create_child()		
	#item.set_cell_mode(0,TreeItem.CELL_MODE_CHECK)		
	#item.set_editable(0, true)
	#if node.has("import_state"):
		#if node.import_state.has("ignore"):				
			#item.set_checked(0, not node.import_state["ignore"])							
	#item.set_text(0, str("lod ", i))
	#item.set_metadata(0, mesh)		
	#item.set_text(1, AssetIO.IMPORT_STATE.keys()[ preview_dictionary[node_name].import_state.mesh_states[i] ])
