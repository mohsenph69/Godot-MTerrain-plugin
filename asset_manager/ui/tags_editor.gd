@tool
extends Control

signal tag_changed
signal tag_option_removed
signal tag_option_renamed

@onready var tag_list = find_child("tags_list")
var editable = true
var selectable = true

func get_tag_array():
	var arr = []
	for item in tag_list.get_children():
		if item.checkbox.button_pressed:
			arr.push_back(item.tag_id)
	return arr
	
func _ready():
	if EditorInterface.get_edited_scene_root() == self: return

	var asset_library:MAssetTable = MAssetTable.get_singleton() #load(ProjectSettings.get_setting("addons/m_terrain/asset_libary_path"))		

	var search:LineEdit = find_child("search")
	search.text_changed.connect(func(new_text):		
		for tag in tag_list.get_children():
			tag.visible = tag.tag_id in asset_library.tag_names_begin_with(new_text) or new_text == ""
	)

func set_options(tag_data): #{tag_name: tag_id}	
	if not is_instance_valid(tag_list): await ready
	for child in tag_list.get_children():
		tag_list.remove_child(child)
		child.queue_free()
	var biggest_size = 0
	for tag in tag_data:
		if tag_data[tag] == 0: continue
		var control = preload("res://addons/m_terrain/asset_manager/ui/tag_list_item.tscn").instantiate()
		control.set_editable(editable)
		tag_list.add_child(control)
		control.tag_id = tag_data[tag]
		control.set_tag_name(tag)
		control.checkbox.disabled = not selectable #or tag_data[tag] == 0
		control.checkbox.button_up.connect(toggle_tag.bind(control.checkbox, tag_data[tag]))
		biggest_size = max(biggest_size, control.size.x)
		control.tag_renamed.connect(func(id,new_name):
			tag_option_renamed.emit(id, new_name)	
		)
		control.tag_removed.connect(func(id):
			tag_option_removed.emit(id)
		)
	if get_window() != EditorInterface.get_editor_main_screen().get_window():
		get_window().size.x = biggest_size
			
func toggle_tag(button, tag):	
	tag_changed.emit(tag, button.button_pressed)	
							
func set_tags_from_data(tags: PackedInt32Array): #data: Array[int32]
	if not is_instance_valid(tag_list): await ready	
	for control in tag_list.get_children():											
		control.checkbox.button_pressed = control.tag_id in tags		
