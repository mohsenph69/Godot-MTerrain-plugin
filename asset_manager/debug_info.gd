@tool
extends Button

@onready var tree:Tree = get_child(0)
var last_update:int= 0
var tree_items = {}	

func _toggled(toggled_on):
	set_process(toggled_on)
	tree.visible = toggled_on
	
func _ready():
	tree.visible = false
	tree.set_column_custom_minimum_width(1, 75)	
	tree.set_column_expand(1, false)
	var data = MHlodScene.get_debug_info()	
	var root: TreeItem = tree.create_item()
	for key in data:
		var item := root.create_child()
		tree_items[key] = item
		item.set_text(0, key)
		item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
			
func _process(delta):
	if not is_node_ready() or not is_visible_in_tree(): return			
	if abs(Time.get_ticks_msec() - last_update) > 1000:
		last_update = Time.get_ticks_msec()
		var data = MHlodScene.get_debug_info()		
		for key in data:
			var item = tree_items[key]
			item.set_text(1, str(data[key]))
