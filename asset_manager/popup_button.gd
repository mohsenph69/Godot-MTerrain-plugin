@tool
extends Button
@export var centered := false
func _input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:		
		if not get_global_rect().has_point(event.position):			
			release_focus()					
			button_pressed = false		

func _toggled(toggle_on):
	var popup:Popup = get_child(0)	
	if toggle_on:		
		popup.visible = true		
		var rect = Rect2i(Vector2i(), popup.size)				
		if get_viewport_rect().size.y - global_position.y + size.y < global_position.y:			
			popup.max_size.y = global_position.y
			rect.position.y = global_position.y - popup.size.y	 -10
		else:
			rect.position.y = global_position.y + size.y
			popup.max_size.y = get_viewport_rect().size.y - global_position.y - size.y		
		rect.position.x = global_position.x if not centered else (get_viewport_rect().size.x - rect.size.x)/2
		popup.popup(rect)			
	else:
		popup.visible = false
