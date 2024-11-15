@tool
extends Popup

signal resources_selected

@onready var select_button:Button = find_child("select_button")
@onready var cancel_button:Button = find_child("cancel_button")
@onready var list:Tree = find_child("Tree")
@onready var search = find_child("search")

var types = []# ["StandardMaterial3D", "ShaderMaterial", "ORMMaterial3D"]:
var select_multiple = false

func _ready():
	if select_multiple:
		list.select_mode = Tree.SELECT_MULTI
	else:
		list.select_mode = Tree.SELECT_ROW
		
	list.set_column_expand(0, false)
	list.set_column_custom_minimum_width(0, 64)	
	search.text_changed.connect(filter_tree)
	var root := list.create_item()	
	build_tree(root)
	select_button.pressed.connect(func():
		var result = []
		var current_item = list.get_next_selected(null)
		while current_item:
			result.push_back(current_item.get_text(1))
			current_item = list.get_next_selected(current_item)
		resources_selected.emit(result)
		queue_free()
	)
	cancel_button.pressed.connect(queue_free)

func filter_tree(text):
	for item:TreeItem in list.get_root().get_children():
		item.visible = text in item.get_text(1) or text ==""

func build_tree(root:TreeItem, path:="res://"):
	for file in DirAccess.get_files_at(path):
		var current_path = path.path_join(file)
		if not EditorInterface.get_resource_filesystem().get_file_type(current_path) in types: continue
		var resource = load(current_path)
		var item := root.create_child()		
		item.set_text(1, current_path)				
		EditorInterface.get_resource_previewer().queue_resource_preview(current_path, self, "update_icon_preview", item)				
	for folder in DirAccess.get_directories_at(path):
		build_tree(root, path.path_join(folder))
	
	
func update_icon_preview(path, preview,thumbnail, data:TreeItem):
	data.set_icon(0, preview)
	
