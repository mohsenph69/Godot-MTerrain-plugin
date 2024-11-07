@tool
extends Control

@onready var tab_container = find_child("tab_container")

func _ready():
	select_tab("manage_groups")
	%manage_groups_button.pressed.connect(select_tab.bind("manage_groups"))
	%manage_tags_button.pressed.connect(select_tab.bind("manage_tags"))	
	%manage_glbs_button.pressed.connect(select_tab.bind("manage_glbs"))	
	
func select_tab(tab_name):
	for child in tab_container.get_children():
		child.visible = child.name == tab_name	
