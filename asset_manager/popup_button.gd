@tool
extends Button
@export var centered := false

func _input(event: InputEvent):		
	return
	if event is InputEventMouse:			
		if not get_global_rect().has_point(event.global_position) or not get_child(0).get_global_rect().has_point(event.global_position):						
			if event is InputEventMouseButton and event.pressed:
				release_focus()					
				button_pressed = false		
		elif event is InputEventMouseButton:
			get_viewport().set_input_as_handled()

func _ready():
	focus_exited.connect(func():
		check_focus.call_deferred()
	)
		
func check_focus():
	var focus = get_viewport().gui_get_focus_owner()
	if not focus or not is_ancestor_of(focus):		
		button_pressed = false
	
	
func _toggled(toggle_on):
	var popup = get_child(0)	
	popup.visible=toggle_on
	popup.position.y = -popup.size.y -10
	#if toggle_on:		
		#popup.visible = true		
		#var rect = Rect2i(Vector2i(), popup.size)				
		#if get_viewport_rect().size.y - global_position.y + size.y < global_position.y:			
			#popup.max_size.y = global_position.y
			#rect.position.y = -popup.size.y -10
		#else:
			#rect.position.y = 10 #global_position.y + size.y
			#popup.max_size.y = get_viewport_rect().size.y - global_position.y - size.y		
		#rect.position.x = position.x # if not centered else (get_viewport_rect().size.x - rect.size.x)/2
		#popup.popup(rect)			
	#else:
		#popup.visible = false
		#
#func _toggled(toggle_on):
	#var popup:Popup = get_child(0)	
	#if toggle_on:		
		#popup.visible = true		
		#var rect = Rect2i(Vector2i(), popup.size)				
		#if get_viewport_rect().size.y - global_position.y + size.y < global_position.y:			
			#popup.max_size.y = global_position.y
			#rect.position.y = global_position.y - popup.size.y	 -10
		#else:
			#rect.position.y = global_position.y + size.y
			#popup.max_size.y = get_viewport_rect().size.y - global_position.y - size.y		
		#rect.position.x = global_position.x if not centered else (get_viewport_rect().size.x - rect.size.x)/2
		#popup.popup(rect)			
	#else:
		#popup.visible = false
