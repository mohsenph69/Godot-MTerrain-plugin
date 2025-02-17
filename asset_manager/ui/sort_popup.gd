@tool
extends Control

signal sort_mode_changed

@onready var sort_type_list = find_child("sort_type_list")

var button_group = preload("res://addons/m_terrain/asset_manager/ui/sort_button_group.tres")
var sort_mode

func _ready():
	#if not EditorInterface.get_edited_scene_root() or EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return
	if not is_instance_valid(sort_type_list): return
	for button in sort_type_list.get_children():
		button.button_group = button_group
	button_group.pressed.connect(func(button):		
		if sort_mode != button.name:
			sort_mode = button.name
			sort_mode_changed.emit(button.name)		
	)
