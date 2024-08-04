@tool
extends Button
@onready var brush_settings_container: Control = find_child("brush_settings")

func _ready():
	var panel = get_child(0)
	panel.visible = false
	panel.position.y = -panel.size.y
	panel.size.x = get_viewport().size.x - global_position.x
func _toggled(toggled_on):
	if toggled_on:
		get_child(0).size.x = get_viewport().size.x - global_position.x
