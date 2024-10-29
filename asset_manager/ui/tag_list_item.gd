@tool
extends PanelContainer

signal tag_removed
signal tag_renamed

@onready var line_edit:LineEdit = find_child("LineEdit")
@onready var checkbox:Control = find_child("CheckBox")

var current_name
var tag_id

func _ready():	
	$HBoxContainer/remove.pressed.connect(func():
		tag_removed.emit(tag_id)
		queue_free()
	)
	$HBoxContainer/rename.pressed.connect(func():		
		for child in get_parent().get_children():			
			child.toggle_editing(child == self)			
	)
	line_edit.text_submitted.connect(func(new_text):		
		toggle_editing(false)
		tag_renamed.emit(tag_id, new_text)		
		current_name = new_text
	)	
	line_edit.gui_input.connect(func(event):
		if line_edit.editable and event is InputEventMouseButton and event.pressed:
			checkbox.button_pressed = not checkbox.button_pressed
	)

func set_editable(toggle_on):
	if not toggle_on:
		$HBoxContainer/rename.visible = false
		$HBoxContainer/remove.visible = false

func toggle_editing(toggle_on):
	line_edit.editable = toggle_on
	if toggle_on:
		line_edit.grab_focus()
	
func set_tag_name(text):
	line_edit.text = text
	current_name = text
