@tool 
extends Button

@export var brush_mask_controller: ItemList

var active_terrain
@onready var mask_cutoff_control = find_child("mask_cutoff")
@onready var mask_invert:BaseButton = find_child("invert_mask_button")

func _ready():
	var panel = get_child(0)
	panel.visible = false
	panel.position.y = -panel.size.y
	panel.size.x = get_viewport().size.x - global_position.x
		
func init_mask_settings():
	mask_cutoff_control.value_changed.connect(update_mask_cutoff)	
	mask_invert.toggled.connect(func(toggled): brush_mask_controller.invert_selected_image())

func update_mask_cutoff(value):	
	active_terrain.set_mask_cutoff(value)		
