@tool
extends Control

signal tag_changed
signal tag_option_removed
signal tag_option_renamed

@onready var tag_list = find_child("tags_list")
var all_tags
var selected_tags = []
var editable = true
var selectable = true

func get_tag_array():
	var arr = []
	for item in tag_list.get_children():
		if item.checkbox.button_pressed:
			arr.push_back(item.tag_id)
	return arr
	
func _ready():
	var search:LineEdit = find_child("search")
	search.text_changed.connect(func(new_text):		
		for tag in tag_list.get_children():
			tag.visible = new_text in tag.text or new_text == ""				
	)

func set_options(tag_data): #{tag_name: tag_id}
	all_tags = tag_data.keys()
	for child in tag_list.get_children():
		tag_list.remove_child(child)
		child.queue_free()
	var biggest_size = 0
	for tag in tag_data:
		var control = preload("res://addons/m_terrain/asset_manager/ui/tag_list_item.tscn").instantiate()
		control.set_editable(editable)
		tag_list.add_child(control)
		control.tag_id = tag_data[tag]
		control.set_tag_name(tag)
		control.checkbox.disabled = not selectable
		control.checkbox.toggled.connect(toggle_tag.bind(tag))
		biggest_size = max(biggest_size, control.size.x)
	get_window().size.x = biggest_size
			
func toggle_tag(toggled, tag):	
	tag_changed.emit(tag, toggled)
	if toggled:
		if not tag in selected_tags:
			selected_tags.push_back(tag)
	else:
		if tag in selected_tags:
			selected_tags.erase(tag)
							
func set_tags_from_data(data: Array): #dada: Array[String]
	selected_tags = []
	for control in tag_list.get_children():							
		if data == null:
			control.checkbox.disabled = true
		else:
			control.checkbox.disabled = false
			control.checkbox.button_pressed = control.line_edit.text in data
			if control.line_edit.text in data:
				selected_tags.push_back(control.line_edit.text)
	
func rename_tag(id, new_name):
	all_tags[id] = new_name
	tag_option_renamed.emit(id, new_name)
