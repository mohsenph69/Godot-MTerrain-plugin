@tool
extends Popup

signal filter_changed

@onready var all_button = find_child("all_button")
@onready var clear_button = find_child("clear_button")
@onready var tag_list = find_child("tag_list")

var current_filter = []

func _ready():
	all_button.toggled.connect(func(toggle_on):
		if toggle_on:
			all_button.text = "match all"			
		else:
			all_button.text = "match any"
		filter_changed.emit(current_filter, all_button.button_pressed)
	)	
	tag_list.set_editable(false)
	tag_list.tag_changed.connect(update_filter)
	clear_button.pressed.connect(func():
		current_filter = []
		tag_list.set_options()		
		filter_changed.emit(current_filter, all_button.button_pressed)
		if all_button.button_pressed:
			tag_list.set_tags_from_data(current_filter)
		else:
			tag_list.set_tags_from_data(MAssetTable.get_singleton().tag_get_names().keys())
		
	)
	visibility_changed.connect(init_options)

func init_options():
	if visible:	
		tag_list.set_options()		
		tag_list.set_tags_from_data(current_filter)
		
func update_filter(tag_id, toggled_on ):
	if toggled_on:
		if not tag_id in current_filter:
			current_filter.push_back(tag_id)
	else:
		if tag_id in current_filter:
			current_filter.erase(tag_id)
	current_filter.sort()	
	filter_changed.emit(current_filter, all_button.button_pressed)
