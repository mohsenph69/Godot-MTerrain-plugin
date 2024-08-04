@tool
extends Button

func _ready():
	var panel = get_child(0)
	panel.visible = false
	#panel.size.y = 
	panel.position.y = -panel.size.y - 4
