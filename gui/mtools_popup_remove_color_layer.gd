@tool
extends Window
signal confirmed
func _ready():
	find_child("delete_layer").pressed.connect(func(): confirmed.emit(false))
	find_child("delete_layer_and_image").pressed.connect(func(): confirmed.emit(true))
	find_child("delete_layer").pressed.connect(queue_free)
	find_child("delete_layer_and_image").pressed.connect(queue_free)
	find_child("cancel_button").pressed.connect(queue_free)
	close_requested.connect(queue_free)
