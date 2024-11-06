@tool
extends Popup

signal filter_changed

@onready var all_button = find_child("all_button")
@onready var clear_button = find_child("clear_button")
@onready var tags_control = find_child("Tags")

var current_filter = []

func _ready():
	all_button.toggled.connect(func(toggle_on):
		if toggle_on:
			all_button.text = "match all"			
		else:
			all_button.text = "match any"
		filter_changed.emit(current_filter, all_button.button_pressed)
	)	
	tags_control.editable = false	
	tags_control.tag_changed.connect(update_filter)
	clear_button.pressed.connect(func():
		if all_button.button_pressed:
			tags_control.set_tags_from_data([])
		else:
			tags_control.set_tags_from_data(owner.asset_library.tag_get_names().keys())
	)
	#visibility_changed.connect(init_options)

func init_options():
	if visible:	
		tags_control.set_options(owner.asset_library.tag_get_names())		
		tags_control.set_tags_from_data(current_filter)
		
func update_filter(tag_id, toggled_on ):
	if toggled_on:
		if not tag_id in current_filter:
			current_filter.push_back(tag_id)
	else:
		if tag_id in current_filter:
			current_filter.erase(tag_id)
	current_filter.sort()	
	filter_changed.emit(current_filter, all_button.button_pressed)
