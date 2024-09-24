@tool
extends PanelContainer

signal group_removed
signal group_renamed
signal group_selected

@onready var line_edit:LineEdit = find_child("LineEdit")

var current_name

var selected = false

func _ready():	
	$HBoxContainer/remove.pressed.connect(func():
		group_removed.emit(current_name)
		queue_free()
	)
	$HBoxContainer/rename.pressed.connect(func():		
		for child in get_parent().get_children():			
			child.toggle_editing(child == self)			
	)
	line_edit.text_submitted.connect(func(new_text):		
		toggle_editing(false)
		group_renamed.emit(current_name, new_text)		
		current_name = new_text
	)
	line_edit.gui_input.connect(func(event):
		if line_edit.editable == false and event is InputEventMouseButton and event.pressed:
			line_edit.release_focus()			
			item_clicked()
	)
	line_edit.draw.connect(draw)
	

func toggle_editing(toggle_on):
	line_edit.editable = toggle_on
	if toggle_on:
		line_edit.grab_focus()
		line_edit.mouse_default_cursor_shape = CursorShape.CURSOR_IBEAM
	else:
		line_edit.mouse_default_cursor_shape = CursorShape.CURSOR_POINTING_HAND
	
func set_group_name(text):
	line_edit.text = text
	current_name = text

func item_clicked():
	for child in get_parent().get_children():	
		child.selected = child == self
		child.update_selection()
		child.toggle_editing(false)
	group_selected.emit(current_name)
	
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:		
		item_clicked()	

func draw():
	if selected:
		line_edit.draw_style_box(preload("res://addons/m_terrain/gui/styles/stylebox_selected.tres"), Rect2(Vector2(0,0), size))

func update_selection():
	line_edit.queue_redraw()	
