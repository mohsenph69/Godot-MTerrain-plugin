@tool
extends Tree

func _init():	
	var root = create_item()
	for text in ["Mesh", "HLOD", "PackedScene", "Decal", "Light"]:
		var item = root.create_child()		
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_text(0, text)
		item.set_checked(0, true)
		item.set_editable(0,true)
