@tool
extends Control

@onready var list:ItemList = find_child("ItemList")
var callbacks := []
	
func setup(button_icons: Array, button_callbacks: Array):
	callbacks = button_callbacks
	list.clear()
	list.item_selected.connect(process_selection)
	for icon in button_icons:
		list.add_icon_item(icon)
	
func process_selection(id):
	if len(callbacks)<id:
		callbacks[id].call()

func add_brush(icon, callback):
	list.add_icon_item(icon)
	callback.push_back(callback)

	
