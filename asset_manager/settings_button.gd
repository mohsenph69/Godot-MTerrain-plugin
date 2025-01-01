@tool 
extends Button

var settings

func _ready():
	settings = preload("res://addons/m_terrain/asset_manager/ui/asset_library_settings.tscn").instantiate()
	add_child(settings)
	settings.visible = false
	settings.find_child("close_settings_button").pressed.connect(func():button_pressed = not button_pressed)
	
	
func _toggled(toggled_on):
	if toggled_on:					
		if settings.get_parent():
			remove_child(settings)
		EditorInterface.get_editor_main_screen().get_parent().add_child(settings)
		settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
		settings.size_flags_stretch_ratio = 100000000000		
		settings.visible = true
	else:
		EditorInterface.get_editor_main_screen().get_parent().remove_child(settings)
		settings.visible = false
		add_child(settings)
		
