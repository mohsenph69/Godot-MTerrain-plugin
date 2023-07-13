@tool
extends HBoxContainer
class_name MTools


signal toggle_paint_mode
var active_paint_mode := false



func _on_paint_mode_toggled(button_pressed):
	active_paint_mode = button_pressed
	emit_signal("toggle_paint_mode",button_pressed)
