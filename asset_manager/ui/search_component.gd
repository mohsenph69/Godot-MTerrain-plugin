@tool
extends Control

signal text_changed

@onready var search_box:LineEdit = find_child("search_box")
@onready var search_button:Button = find_child("search_button")
@onready var clear_button:Button = find_child("clear_button")
@export var align_right = false
func _ready():
	if align_right:
		move_child(search_button, -1)
	search_button.pressed.connect(func():
		clear_button.visible = true
		search_box.visible = true
		search_button.visible = false
		search_box.grab_focus()
	)
	clear_button.pressed.connect(func():
		if search_box.text == "":
			search_focus_ended()
			return
		search_box.text = ""
		search_box.grab_focus()
		search_box.focus_exited.connect(search_focus_ended)
		text_changed.emit(search_box.text)
	)	
	search_box.text_changed.connect(func(text):
		text_changed.emit(text)
		if text == "":
			if not search_box.focus_exited.is_connected(search_focus_ended):
				search_box.focus_exited.connect(search_focus_ended)
		else:
			if search_box.focus_exited.is_connected(search_focus_ended):
				search_box.focus_exited.disconnect(search_focus_ended)
			
	)

func search_focus_ended():
	clear_button.visible = false
	search_box.visible = false
	search_button.visible = true
	if search_box.focus_exited.is_connected(search_focus_ended):	
		search_box.focus_exited.disconnect(search_focus_ended)
