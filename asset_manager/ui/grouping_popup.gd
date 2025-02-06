@tool
extends Control
signal group_selected

@onready var group_list = find_child("group_list")

var button_group:ButtonGroup #= load("res://addons/m_terrain/asset_manager/ui/grouping_button_group.tres")

func _ready():
	#if not EditorInterface.get_edited_scene_root() or EditorInterface.get_edited_scene_root() == self or EditorInterface.get_edited_scene_root().is_ancestor_of(self): return
	visible = false
	button_group = ButtonGroup.new()	
	group_list.get_child(0).button_group = button_group
	update_grouping_options()
	button_group.pressed.connect( select_group )
	visibility_changed.connect(	update_grouping_options )	

func select_group(button):	
	group_selected.emit(button.name)

func update_grouping_options():	
	if not visible: return		
	var groups = MAssetTable.get_singleton().group_get_list()	
	var group_names = []
	for child in group_list.get_children():		
		if not child.name in groups and not child.name == "None":
			child.queue_free()
		else:
			group_names.push_back(child.name)	
	for group in groups:
		if not group in group_names:
			var button = Button.new()
			button.text = group
			button.name = group
			button.toggle_mode = true
			button.button_group = button_group
			group_list.add_child(button)
			
			
