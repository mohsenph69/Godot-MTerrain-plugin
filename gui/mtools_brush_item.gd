@tool
extends PanelContainer

signal brush_selected
signal brush_edited
signal brush_removed

@onready var label = find_child("label")
@onready var edit= find_child("edit")
@onready var remove = find_child("remove")
var color
var hardness

func _ready():	
	label.pressed.connect(func(): brush_selected.emit())
	visibility_changed.connect(on_resize)
	resized.connect(on_resize)
func set_height_brush(bname, bicon):
	edit.free()
	remove.free()
	label.text = bname
	label.icon = bicon
	
func set_color_brush(layer_group_id, bname, bicon, bhardness, bcolor):
	label.text = bname
	label.icon = bicon if bicon else null
	if bcolor:
		color = bcolor
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = color
		label.set("theme_override_styles/normal", stylebox)
		label.set("theme_override_styles/focus", stylebox)
		label.set("theme_override_styles/hover", stylebox)
		label.set("theme_override_styles/pressed", stylebox)
	else:		
		label.set("theme_override_styles/normal", null)
		label.set("theme_override_styles/focus", null)
		label.set("theme_override_styles/hover", null)
		label.set("theme_override_styles/pressed", null)
	hardness = bhardness
	edit.pressed.connect(edit_brush)
	remove.pressed.connect(remove_brush)	

func set_text_brush(text):
	label.text = text
	label.icon = null
	edit.free()
	remove.free()

func edit_brush():
	var popup = preload("res://addons/m_terrain/gui/mtools_create_color_brush.tscn").instantiate()
	add_child(popup)	
	var bicon = label.icon.resource_path if label.icon else ""
	popup.load_brush(label.text, bicon, hardness, color)
	popup.brush_created.connect(
		func(new_name, new_icon_path, new_hardness, new_color): 
			brush_edited.emit(new_name, new_icon_path, new_hardness, new_color, get_index())
	)

func remove_brush():
	var popup = preload("res://addons/m_terrain/gui/mtools_layer_warning_popup.tscn").instantiate()
	add_child(popup)
	popup.confirmed.connect(func():
		brush_removed.emit(get_index())
		queue_free()		
		get_parent().remove_child(self)
		
		
	)

func on_resize():
	label.set("theme_override_constants/icon_max_width", theme.default_font_size*2)
