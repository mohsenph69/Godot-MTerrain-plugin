@tool
extends Window

signal resources_selected

@onready var select_button:Button = find_child("select_button")
@onready var cancel_button:Button = find_child("cancel_button")
@onready var list:Tree = find_child("Tree")
@onready var search = find_child("search")
@onready var title_label = find_child("title_label")


var types = []# ["StandardMaterial3D", "ShaderMaterial", "ORMMaterial3D"]:
var select_multiple = false

var existing_materials:PackedStringArray
var exclude_directories:PackedStringArray = ["addons"]

func _exit_tree() -> void:
	MAssetTable.save()

func _ready():
	exclude_directories.push_back(MAssetTable.get_asset_editor_root_dir().get_base_dir().get_file())
	var __materials = AssetIOMaterials.get_material_table()
	for m in  __materials:
		existing_materials.push_back(__materials[m].path)
	if select_multiple:
		list.select_mode = Tree.SELECT_MULTI
	else:
		list.select_mode = Tree.SELECT_ROW
	close_requested.connect(queue_free)	
	list.set_column_expand(0, false)
	list.set_column_custom_minimum_width(0, 64)	
	list.item_activated.connect(select_button_pressed)
	search.text_changed.connect(filter_tree)
	var root := list.create_item()	
	build_tree.call_deferred(root)
	select_button.pressed.connect(select_button_pressed)
	cancel_button.pressed.connect(queue_free)

func select_button_pressed():
	var result = []
	var current_item = list.get_next_selected(null)
	while current_item:
		result.push_back(current_item.get_tooltip_text(1))
		current_item = list.get_next_selected(current_item)
	if select_multiple:
		resources_selected.emit(result)
	else:
		resources_selected.emit(result[0])
	queue_free()

func filter_tree(text):
	for item:TreeItem in list.get_root().get_children():
		item.visible = item.get_text(1).containsn(text) or text =="" #or item.get_tooltip_text(1).containsn(text)s

func build_tree(root:TreeItem, path:="res://"):
	for file in DirAccess.get_files_at(path):
		var current_path = path.path_join(file)
		if not EditorInterface.get_resource_filesystem().get_file_type(current_path) in types: continue
		if current_path in existing_materials: continue
		var resource = load(current_path)
		var item := root.create_child()		
		item.set_text(1, resource.resource_name if not resource.resource_name.is_empty() else current_path)				
		item.set_tooltip_text(1, current_path)				
		EditorInterface.get_resource_previewer().queue_resource_preview(current_path, self, "update_icon_preview", item)				
	for folder in DirAccess.get_directories_at(path):
		if folder in exclude_directories: continue
		build_tree(root, path.path_join(folder))
	
	
func update_icon_preview(path, preview,thumbnail, data:TreeItem):
	data.set_icon(0, preview)
