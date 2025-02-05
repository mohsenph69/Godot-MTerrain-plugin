@tool
extends Window

var baker
@onready var cancel_button = find_child("cancel_button")
@onready var confirm_button = find_child("confirm_button")
func _ready():
	close_requested.connect(queue_free)
	cancel_button.pressed.connect(queue_free)
	confirm_button.pressed.connect(confirm_changes)
	for i in 16:
		var layer_name_edit =LineEdit.new()
		layer_name_edit.text = baker.variation_layers[i] if len(baker.variation_layers) > i else str(i)			
		layer_name_edit.text_submitted.connect(func(new_text): confirm_changes())
		%variation_layers_container.add_child(layer_name_edit)
	popup_centered()

func confirm_changes():
	var names: PackedStringArray = []
	for child in %variation_layers_container.get_children():
		names.push_back(child.text)
	baker.variation_layers = names
	queue_free()

func focus_layer(i):
	%variation_layers_container.get_child(i).grab_focus()

func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			queue_free()
		if event.keycode == KEY_ENTER:
			confirm_changes()
