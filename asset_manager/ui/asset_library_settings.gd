@tool
extends Control

@onready var tab_container = find_child("tab_container")
@onready var manage_groups_button = %manage_groups_button
@onready var manage_tags_button = %manage_tags_button
@onready var manage_glbs_button = %manage_glbs_button
@onready var manage_physics_button = %manage_physics_button
@onready var manage_paths_button = %manage_paths_button

#@onready var manage_groups_button = %manage_groups
@onready var manage_tags_control = %manage_tags
#@onready var manage_glbs_button = %manage_glbs_button
#@onready var manage_physics_button = %manage_physics

func _ready():
	select_tab("manage_groups")
	manage_groups_button.pressed.connect(select_tab.bind("manage_groups"))
	manage_tags_button.pressed.connect(select_tab.bind("manage_tags"))	
	manage_glbs_button.pressed.connect(select_tab.bind("manage_glbs"))	
	manage_physics_button.pressed.connect(select_tab.bind("manage_physics"))	
	manage_paths_button.pressed.connect(select_tab.bind("manage_paths"))	
	

func select_tab(tab_name):
	for child in tab_container.get_children():
		child.visible = child.name == tab_name	
