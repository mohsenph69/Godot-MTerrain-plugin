@tool
extends Button

signal edit_mode_changed

var item_container
var exit_edit_mode_button 

func _ready():
	var panel = get_child(0)
	panel.visible = false
	panel.position.y = -panel.size.y
	
	item_container = find_child("edit_mode_item_container")
	exit_edit_mode_button = get_node("../edit_mode_exit_button")		
	if not exit_edit_mode_button.pressed.is_connected(edit_mode_changed.emit.bind(null, &"")):
		exit_edit_mode_button.pressed.connect(edit_mode_changed.emit.bind(null, &""))
	if not exit_edit_mode_button.pressed.is_connected(exit_edit_mode_button.hide):	
		exit_edit_mode_button.pressed.connect(exit_edit_mode_button.hide)

func init_edit_mode_options(all_mterrain):	
	if all_mterrain.size() == 0:
		push_error("trying to init edit mode option button but didn't find any mterrain")
	for child in item_container.get_children():
		child.queue_free()
	
	for terrain in all_mterrain:			
		var button = Button.new()
		button.text = "Sculpt " + terrain.name
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		#button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		#button.custom_minimum_size.y = 32
		item_container.add_child(button)
		button.pressed.connect(func():
			edit_mode_changed.emit(terrain, &"sculpt")
			exit_edit_mode_button.show()
			text = "Sculpt " + terrain.name
		)		
		
		button = Button.new()
		button.text = "Paint " + terrain.name
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		item_container.add_child(button)
		button.pressed.connect(func():
			edit_mode_changed.emit(terrain, &"paint")
			exit_edit_mode_button.show()
			text = "Paint " + terrain.name
		)
		for child in terrain.get_children():
			if child is MGrass:
				button = Button.new()
				button.text = "Paint " + child.name
				button.mouse_filter = Control.MOUSE_FILTER_PASS
				item_container.add_child(button)
				button.pressed.connect(func():
					edit_mode_changed.emit(child, &"paint")
					exit_edit_mode_button.show()
					text = "Paint " + child.name
				)
			if child is MPath:
				button = Button.new()
				button.text = "Edit " + child.name
				button.mouse_filter = Control.MOUSE_FILTER_PASS
				item_container.add_child(button)
				button.pressed.connect(func():
					edit_mode_changed.emit(child, &"mpath")
					exit_edit_mode_button.show()
					text = "Edit " + child.name
				)
			if child is MCurveMesh:
				button = Button.new()
				button.text = "Edit " + child.name
				button.mouse_filter = Control.MOUSE_FILTER_PASS
				item_container.add_child(button)
				button.pressed.connect(func():
					edit_mode_changed.emit(child, &"mcurve_mesh")
					exit_edit_mode_button.show()
					text = "Edit " + child.name
				)
			if child is MNavigationRegion3D:
				button = Button.new()
				button.text = "paint " + child.name
				button.mouse_filter = Control.MOUSE_FILTER_PASS
				item_container.add_child(button)
				button.pressed.connect(edit_mode_changed.emit.bind(child, &"paint"))
				button.pressed.connect(exit_edit_mode_button.show)
		
		
func change_active_object(object):
	pass

func exit_edit_mode():
	exit_edit_mode_button.hide()
