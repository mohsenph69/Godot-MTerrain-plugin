@tool
extends Button
@export var centered := false

func _ready():
	focus_exited.connect(func():
		check_focus.call_deferred()
	)
		
func check_focus():
	var focus = get_viewport().gui_get_focus_owner()
	if not focus or not is_ancestor_of(focus):		
		button_pressed = false			
	elif is_ancestor_of(focus):
		get_tree().create_timer(0.15).timeout.connect(grab_focus)		
	
func _toggled(toggle_on):
	var popup = get_child(0)	
	popup.visible=toggle_on
	popup.position.y = -popup.size.y -10
	
