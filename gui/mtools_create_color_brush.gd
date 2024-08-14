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
		brush_created.emit(brush_name.text, color.color, hardness) 
		queue_free())
	close_requested.connect(queue_free)	
	files_dropped.connect(on_files_dropped)

func on_files_dropped(files):
	icon.text = files[0]
