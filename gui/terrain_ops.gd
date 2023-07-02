extends OptionButton

var mterrain:MTerrain = null

func _on_item_selected(index):
	if mterrain == null:
		selected = 0
		return
	if index == 1:
		mterrain.restart_grid()
	elif index == 2:
		mterrain.create_grid()
	elif index == 3:
		mterrain.remove_grid()
	selected = 0
