@tool
extends Button

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:		
		if not get_global_rect().has_point(event.position):			
			release_focus()					
			button_pressed = false		

func _toggled(toggle_on):
	var popup:Popup = get_child(0)	
	if toggle_on:				
		var rect = Rect2i(Vector2i(), popup.size)		
		rect.position.x = global_position.x
		if get_viewport_rect().size.y - global_position.y + size.y < global_position.y:
			rect.position.y = global_position.y - popup.size.y
			popup.max_size.y = global_position.y
		else:
			rect.position.y = global_position.y + size.y
			popup.max_size.y = get_viewport_rect().size.y - global_position.y - size.y
		print(rect.position)
		popup.popup(rect)		
	else:
		popup.visible = false
