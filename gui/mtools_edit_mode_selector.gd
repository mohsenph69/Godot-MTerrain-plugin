@tool
extends Button

signal edit_mode_changed

var item_container
var exit_edit_mode_button 
var edit_selected_button
var active_object

func _ready():
	var panel = get_child(0)
	panel.visible = false
	panel.position.y = -panel.size.y -4
	
	item_container = find_child("edit_mode_item_container")
	exit_edit_mode_button = get_node("../edit_mode_exit_button")		
	edit_selected_button = get_node("../edit_selected_button")		
	
	if not edit_selected_button.pressed.is_connected(edit_selected):
		edit_selected_button.pressed.connect(edit_selected)
	edit_selected_button.visible = false
	
	if not exit_edit_mode_button.pressed.is_connected(exit_edit_mode_button_pressed):
		exit_edit_mode_button.pressed.connect(exit_edit_mode_button_pressed)
	if not exit_edit_mode_button.pressed.is_connected(exit_edit_mode_button.hide):	
		exit_edit_mode_button.pressed.connect(exit_edit_mode_button.hide)

func init_edit_mode_options(all_mterrain):	
	if all_mterrain.size() == 0:
		push_error("trying to init edit mode option button but didn't find any mterrain")
	for child in item_container.get_children():
		child.queue_free()
	
	var biggest_button_size = 0
	var button_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for terrain in all_mterrain:			
		var button = Button.new()
		button.text = "Sculpt " + terrain.name		
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.alignment = button_alignment
		#button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		#button.custom_minimum_size.y = 32
		item_container.add_child(button)
		biggest_button_size = max(biggest_button_size, button.size.x)
		button.pressed.connect(func():
			edit_mode_changed.emit(terrain, &"sculpt")
			exit_edit_mode_button.show()
			text = "Sculpt " + terrain.name
		)		
		
		button = Button.new()		
		button.alignment = button_alignment
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
				button.alignment = button_alignment
				item_container.add_child(button)
				biggest_button_size = max(biggest_button_size, button.size.x)
				button.pressed.connect(func():
					edit_mode_changed.emit(child, &"paint")
					exit_edit_mode_button.show()
					text = "Paint " + child.name
				)
			
			if child is MNavigationRegion3D:
				button = Button.new()
				button.text = "Paint " + child.name				
				button.mouse_filter = Control.MOUSE_FILTER_PASS
				button.alignment = button_alignment
				item_container.add_child(button)
				biggest_button_size = max(biggest_button_size, button.size.x)
				button.pressed.connect(switch_to_mnavigation_paint.bind(child))
				button.pressed.connect(exit_edit_mode_button.show)
	
	var all_nodes = EditorInterface.get_edited_scene_root().find_children("*")
	print(all_nodes.size())
	for child in all_nodes:
		var button
		if child is MPath:
			button = Button.new()
			button.text = "Edit " + child.name				
			button.mouse_filter = Control.MOUSE_FILTER_PASS
			button.alignment = button_alignment
			item_container.add_child(button)
			biggest_button_size = max(biggest_button_size, button.size.x)
			button.pressed.connect(func():
				edit_mode_changed.emit(child, &"mpath")
				exit_edit_mode_button.show()
				text = "Edit " + child.name
			)
		if child is MCurveMesh:
			button = Button.new()
			button.text = "Edit " + child.name				
			button.mouse_filter = Control.MOUSE_FILTER_PASS
			button.alignment = button_alignment
			item_container.add_child(button)
			biggest_button_size = max(biggest_button_size, button.size.x)
			button.pressed.connect(func():
				edit_mode_changed.emit(child, &"mcurve_mesh")
				exit_edit_mode_button.show()
				text = "Edit " + child.name
			)
	
	get_child(0).size. x = biggest_button_size + 12	
	
func switch_to_mnavigation_paint(nav):
	text = "Paint " + nav.name
	edit_mode_changed.emit(nav, &"paint")

func change_active_object(object):
	#In future, make it auto-switch to the same edit mode, just for different object
	exit_edit_mode_button_pressed()
	exit_edit_mode()
	edit_selected_button.visible = true
	if object is MTerrain:
		edit_selected_button.text = "click to Sculpt " + object.name
	else:
		edit_selected_button.text = "click to Paint " + object.name		
	active_object = object
	text = "..."
	
func exit_edit_mode_button_pressed():	
	edit_mode_changed.emit(null, &"")
	
func exit_edit_mode():
	exit_edit_mode_button.hide()

func edit_selected():		
	if active_object is MTerrain:
		text = "Sculpt " + active_object.name
		edit_mode_changed.emit(active_object, &"sculpt")		
		edit_selected_button.visible = false			
		exit_edit_mode_button.show()	
	else:
		text = "Paint " + active_object.name
		edit_mode_changed.emit(active_object, &"paint")
		edit_selected_button.visible = false
		exit_edit_mode_button.show()
	
