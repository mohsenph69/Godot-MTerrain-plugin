@tool
extends Control

signal filter_changed

@onready var all_button:Button = find_child("all_button")
@onready var invert_selection_button:Button = find_child("invert_selection_button")

@onready var clear_button:Button = find_child("clear_filter_button")
@onready var tag_list = find_child("tag_list")
var match_all = false
var current_filter = []

func _ready():
	all_button.pressed.connect(func():
		if match_all:
			all_button.text = "OR"			
		else:
			all_button.text = "AND"
		match_all = not match_all
		filter_changed.emit(current_filter, match_all)
	)		
	invert_selection_button.pressed.connect(func():		
		current_filter = MAssetTable.get_singleton().tag_get_names().values().filter(func(a): return false if a in current_filter else true)		
		filter_changed.emit(current_filter, match_all)		
		tag_list.set_tags_from_data(current_filter)
	)	
	tag_list.set_editable(false)
	tag_list.tag_changed.connect(update_filter)	
	clear_button.pressed.connect(func():					
		current_filter = []
		tag_list.set_tags_from_data(current_filter)
		filter_changed.emit(current_filter, match_all)
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
	filter_changed.emit(current_filter, match_all)
	tag_list.set_tags_from_data.call_deferred(current_filter)
