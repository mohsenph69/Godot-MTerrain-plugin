@tool
extends Button

signal rename_req
var wbtn:Window = null
var mouse_in_rename_btn:=false
var baker

func _ready():
	custom_minimum_size = Vector2(24,24)
	theme_type_variation = "button_layer_toggle"
	toggle_mode = true
	
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not baker is HLod_Baker: return
			var dialog = preload("res://addons/m_terrain/asset_manager/ui/inspector/variation_layers/variation_layers_dialog.tscn").instantiate()
			dialog.baker = baker			
			add_child(dialog)
			dialog.focus_layer(get_index())
			return
			
			#if wbtn==null and event.pressed:
				#var rbtn= Button.new()
				#wbtn = Window.new()
				#wbtn.borderless = true
				#wbtn.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
				#wbtn.transparent = true
				#wbtn.popup_window = true
				#rbtn.text = "rename"
				#rbtn.z_index = 10
				#rbtn.pressed.connect(func():
					#emit_signal("rename_req"); 
					#free_rename_button()
				#)
				#rbtn.mouse_entered.connect(func():mouse_in_rename_btn = true)
				#rbtn.mouse_exited.connect(func():mouse_in_rename_btn = false)
				#wbtn.add_child(rbtn)
				#add_child(wbtn)
				#wbtn.position = event.global_position				
			#return

func _input(event: InputEvent) -> void:
	if mouse_in_rename_btn:
		return
	if event.is_pressed() and (event is InputEventMouseButton or event is InputEventKey):
		free_rename_button()

func free_rename_button():
	if wbtn!=null:
		wbtn.queue_free()
		wbtn = null

func _toggled(toggled_on):
	release_focus()
