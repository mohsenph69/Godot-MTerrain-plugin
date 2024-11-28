@tool
extends Window

var baker

func _ready():
	find_child("cancel_button").pressed.connect(queue_free)
	find_child("confirm_button").pressed.connect(func():
		var names: PackedStringArray = []
		for child in %variation_layers_container.get_children():
			names.push_back(child.text)
		baker.variation_layers = names
		queue_free()
	)
	for i in 16:
		var layer_name_edit =LineEdit.new()
		layer_name_edit.text = baker.variation_layers[i] if len(baker.variation_layers) > i else str(i)			
		%variation_layers_container.add_child(layer_name_edit)
	popup_centered()

func focus_layer(i):
	%variation_layers_container.get_child(i).grab_focus()
