@tool
extends Window
signal brush_created
@onready var create_button = find_child("create")
@onready var brush_name = find_child("brush_name")
@onready var icon = find_child("icon_path")
@onready var hardness = find_child("hardness")
@onready var color = find_child("color_picker")

func _ready():
	create_button.pressed.connect(func():
		if brush_name.text == "":
			brush_name.text = "new color brush"
		brush_created.emit(brush_name.text, icon.text, hardness.value, color.color) 
		queue_free())
	close_requested.connect(queue_free)	
	color.pressed.connect(func(): 
		var picker = color.get_picker().get_parent()
		picker.position.x+= picker.size.x
		picker.position.y = color.global_position.y + position.y
		)

func load_brush(bname, bicon, bhardness, bcolor):
	brush_name.text = bname
	icon.text = bicon
	hardness.value = bhardness
	color.color = bcolor
	create_button.text = "Update"

