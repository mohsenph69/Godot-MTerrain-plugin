#IMPORT WINDOW HLOD SCENE

# SCENARIOS:
# - first time import scene, all assets exist
# - first time import scene, some assets missing
# - second time reimport, all assets exist
# - second time reimport, some assets missing


@tool
extends PanelContainer

@onready var cancel_button:Button = find_child("cancel_button")
@onready var import_button:Button = find_child("import_button")
@onready var node_container = find_child("node_container")

var baker_node: Node #baker node
var asset_library = MAssetTable.get_singleton()
var material_table_items = {}

var invalid_materials := []

func _ready():
	#if EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return
	if get_parent() is Window:
		get_parent().close_requested.connect(cancel_import)
	cancel_button.pressed.connect(func():
		if get_parent() is Window:
			cancel_import()
	)
	if not is_instance_valid(baker_node):
		return
	var baker_path = baker_node.get_meta("baker_path")
	import_button.pressed.connect(func():						
		AssetIOBaker.baker_import_commit_changes(baker_node)		
		if get_parent() is Window:
			get_parent().queue_free()
	)
	get_window().title = "Importing scene: " + baker_node.name
	
	var hlod_tree: Tree = %hlod_tree	
	hlod_tree.item_edited.connect(func():				
		var item := hlod_tree.get_selected()			
		item.propagate_check(0)
	)
	hlod_tree.check_propagated_to_item.connect(func(item:TreeItem,column):
		var node = item.get_metadata(0)		
		node.set_meta("ignore", not item.is_checked(0))
	)	
	var root = hlod_tree.create_item()			
	var original_scene = null
	if FileAccess.file_exists(baker_path):
		original_scene = load(baker_path).instantiate()
	init_hlod_tree(root, baker_node, original_scene)	
	if is_instance_valid(original_scene):
		original_scene.queue_free()
	root.set_cell_mode(0, TreeItem.CELL_MODE_STRING)	
	
func init_hlod_tree(tree_root, node:Node3D, original_node:Node3D):
	#Data to display: Node Name, blend file (or glb), asset thumbnail?	
	var tree_node:TreeItem = tree_root.create_child()		
	tree_node.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	var text = ""
	if node:	
		tree_node.set_metadata(0, node)
		tree_node.set_editable(0, true)				
		tree_node.set_checked(0, true)	
		
		if node.has_meta("import_error"):
			text = node.name + " (!) " + node.get_meta("import_error")
		else:
			text = node.name	
		if not "joined_mesh" in node.name:	
			if not original_node: 
				text += " NEW"
			elif node.transform != original_node.transform:
				text += " MODIFIED"	
	else:
		tree_node.set_editable(0, false)				
		tree_node.set_checked(0, false)	
		text =  original_node.name + " (REMOVED)"
	tree_node.set_text(0, text)								
	for child in node.get_children():		
		if not child is Node3D: continue
		var name_data = AssetIO.node_parse_name(child)
		if name_data.lod != -1: continue
		var original_child = original_node.find_child(child.name) if original_node else null		
		init_hlod_tree(tree_node, child, original_child)
	if not original_node: return
	for original_child in original_node.get_children():
		if node.find_child(original_node.name) == null:
			init_hlod_tree(tree_node, null, original_child)
	
func validate_can_import():
	import_button.disabled = true
	if len(invalid_materials) == 0:
		import_button.disabled = false

func cancel_import():
	baker_node.queue_free()
	get_parent().queue_free()			
