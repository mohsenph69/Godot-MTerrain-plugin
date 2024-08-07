@tool
extends Control

##############################################################
# 							MTools
#	1. m_terrain.gd sets mask, decal, human on enter_tree
#   2. User selects a node
#	   This calls edit_mode_button.init_edit_mode_options()
#      This populates the list of possible edit modes.	   
#	3. User selectes edit mode by clicking on edit_mode_button,
#	   This calls set_edit_mode()
#	   This sets the active_object and current_mode  
#   4. This sets appropriate "layers" (height or paint)
#	   This sets appropriate "brushes" (height, color, grass, nav)
#      If mpath, show mpath menu
#	   If mcurve_mesh, show mcurve_mesh menu
#   5. m_terrain.gd _forward_gui_input() calls the draw() when needed
#
#	NOTE: "popup" panels are just panels. 
#   They appear on button click and we use mouse_exit to hide them. 
#   We use timer to add a delay to prevent accidents
#
#   The popup buttons are also the main scripts for that function
#   e.g. layers_popup_button has all the code to do with layers
#	e.g. brush_popup_button has all the code to do with brushes
#
###############################################################



#region Signals
signal request_save
signal request_info_window
signal request_import_window
signal request_image_creator
signal edit_mode_changed
#endregion

#region UI Controls
@onready var status_bar: Control = find_child("status_bar")
#@onready var save_button: Control = find_child("save_button") #TO DELETE
@onready var paint_panel: Control = find_child("paint_panel")

@onready var options_popup_button: Button = find_child("options_button")

@onready var edit_mode_button: Button = find_child("edit_mode_button")
@onready var layers_popup_button: Button = find_child("layers_button")
@onready var brush_popup_button: Button = find_child("brush_button")
@onready var mask_popup_button: Button = find_child("mask_button")

@onready var mpath_gizmo_gui = find_child("mpath_gizmo_gui")
@onready var mcurve_mesh = find_child("mcurve_mesh")
@onready var brush_size_control: Control = find_child("brush_size")


@onready var popup_buttons = [
	edit_mode_button,
	options_popup_button,
	layers_popup_button,
	brush_popup_button, 	
	mask_popup_button,
]

var current_popup_button: Button = null
var timer
#endregion

var current_edit_mode = &"" # &"", &"sculpt", &"paint"
var active_object = null

var brush_manager:MBrushManager = MBrushManager.new()
var brush_decal # set by m_terrain.gd on enter_tree()
var mask_decal # set by m_terrain.gd on enter_tree()
var human_male # set by m_terrain.gd on enter_tree()

#region Initialisations
func _ready():	
	timer = Timer.new()
	timer.timeout.connect(func(): current_popup_button.button_pressed = false)
	add_child(timer)
	
	for button in popup_buttons:
		init_popup_button_signals(button)	

	edit_mode_button.edit_mode_changed.connect(set_edit_mode)		

func set_brush_decal(new_brush_decal):
	brush_decal = new_brush_decal
	brush_decal.visible = false
	brush_size_control.value_changed.connect(brush_decal.set_brush_size)			

func set_mask_decal(new_mask):
	mask_decal = new_mask
	mask_decal.visible = false
	mask_popup_button.init_masks(mask_decal,  find_child("mask_size"), find_child("mask_rotation"),find_child("mask_cutoff"), find_child("invert_mask_button"))			

func on_node_modified(node):	
	if node is MTerrain or node is MGrass or node is MNavigationRegion3D or node is MPath or node is MCurveMesh:
		update_edit_mode_options()

func update_edit_mode_options():	
	var all_mterrain = get_all_mterrain()
	if all_mterrain.size() != 0:
		edit_mode_button.init_edit_mode_options(all_mterrain)
	else:
		push_warning("get_all_mterrain returning null on editor scene tree changed")

func clear_current_popup_button():
	if current_popup_button:
		current_popup_button.button_pressed = false			

func init_popup_button_signals(popup_button:Button):	
	popup_button.button_pressed = false
	popup_button.toggled.connect(
		func(toggled_on): 
			if toggled_on: 	
				clear_current_popup_button()
				popup_button.get_child(0).visible = true			
				current_popup_button = popup_button
				if not popup_button.mouse_entered.is_connected(_on_mouse_entered_popup):
					popup_button.mouse_entered.connect(_on_mouse_entered_popup)				
			else:
				popup_button.get_child(0).visible = false
				current_popup_button = null
				if not popup_button.mouse_exited.is_connected(_on_mouse_exited_popup):
					popup_button.mouse_exited.connect(_on_mouse_exited_popup)				
	)

func _on_mouse_exited_popup() -> void:
	if current_popup_button:
		timer.one_shot = true	
		timer.start(0.25)

func _on_mouse_entered_popup() -> void:
	if is_instance_valid(timer):
		timer.stop()

#endregion

#region getters
func get_active_mterrain():
	var object = active_object
	if not object:
		var selection = EditorInterface.get_selection().get_selected_nodes()
		if selection.size() == 1:
			object = selection[0]
	if object is MTerrain:
		return object
	if object is MGrass or object is MNavigationRegion3D or object:
		if object.get_parent() is MTerrain:
			return object.get_parent()	
	#This is only used for snapping to MTerrain in MPath:
	if object is MPath or object is MCurveMesh:
		var all_mterrain = get_all_mterrain()
		if all_mterrain.size()>0:
			return all_mterrain[0]
		
func get_all_mterrain(parent=EditorInterface.get_edited_scene_root()):	
	var result = []
	if parent == null: 
		push_warning("trying to get all mterrain, but root is null")
		return []
	for child in parent.get_children():
		if child is MTerrain:
			result.push_back(child)
		for grandchild in child.get_children():
			result.append_array(get_all_mterrain(child))
	return result
	
func get_all_mgrass(root):
	var result = []
	for terrain in get_all_mterrain(root):
		for child in terrain.get_children():
			if child is MGrass:
				result.push_back(child)		
	return result

func get_all_mnavigation(root):
	var result = []
	for terrain in get_all_mterrain(root):
		for child in terrain.get_children():
			if child is MNavigationRegion3D:
				result.push_back(child)		
	return result
	
func get_all_mpath(root):
	var result = []
	for terrain in get_all_mterrain(root):
		for child in terrain.get_children():
			if child is MPath:
				result.push_back(child)		
	return result

#endregion

func set_active_object(object):	
	if active_object == object: return	
	
	#Cleanup active object stuff before setting new active object
	if active_object is MNavigationRegion3D:
		active_object.set_npoints_visible(false)
		
	edit_mode_button.change_active_object(object)	
	#Automatically enter edit mode for mpath
	if object is MPath:
		edit_mode_button.edit_selected(object)
		
func process_input(event):
	if current_edit_mode in [&"sculpt", &"paint"]:
		if event is InputEventKey:			
			brush_popup_button.process_input(event)
			var paint_brush_resize_speed:float=1.0
			var paint_mask_resize_speed:float=1.0
			const max_paint_brush_resize_speed:float=8.0
			const max_mask_brush_resize_speed:float=16.0		
			
			if Input.is_action_just_released("mterrain_mask_size_increase") or Input.is_action_just_released("mterrain_mask_size_decrease"):
				paint_mask_resize_speed=1
			if Input.is_action_just_released("mterrain_brush_size_increase") or Input.is_action_just_pressed("mterrain_brush_size_decrease"):
				paint_brush_resize_speed=1				
			#if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS:
			if Input.is_action_just_pressed("mterrain_brush_size_increase"):				
				paint_brush_resize_speed = min(paint_brush_resize_speed+0.1,max_paint_brush_resize_speed)
				brush_decal.set_brush_size(brush_decal.get_brush_size() + floor(paint_brush_resize_speed))
				brush_size_control.update_value(brush_decal.get_brush_size())
				return true					
			#elif event.keycode == KEY_MINUS:
			elif Input.is_action_just_pressed("mterrain_brush_size_decrease"):				
				paint_brush_resize_speed = min(paint_brush_resize_speed+0.1,max_paint_brush_resize_speed)
				brush_decal.set_brush_size(brush_decal.get_brush_size() - floor(paint_brush_resize_speed))
				brush_size_control.update_value(brush_decal.get_brush_size())
				return true					
			#elif event.keycode == KEY_PERIOD:
			elif Input.is_action_pressed("mterrain_mask_size_increase"):				
				paint_mask_resize_speed = min(paint_mask_resize_speed+0.2,max_mask_brush_resize_speed)
				mask_decal.increase_size(paint_mask_resize_speed)
			#elif event.keycode == KEY_COMMA:
			elif Input.is_action_just_pressed("mterrain_mask_size_decrease"):
				if event.is_pressed():
					paint_mask_resize_speed = min(paint_mask_resize_speed+0.2,max_mask_brush_resize_speed)
					mask_decal.increase_size(-paint_mask_resize_speed)							
			#elif event.keycode == KEY_L and event.pressed:
			elif Input.is_action_just_pressed("mterrain_mask_rotate_clockwise"):
				mask_decal.rotate_image(1)
			#elif event.keycode == KEY_K and event.pressed:
			elif Input.is_action_just_pressed("mterrain_mask_rotate_counter_clockwise"):
				mask_decal.rotate_image(-1)				
			#elif event.keycode == KEY_SEMICOLON and event.pressed:
			elif Input.is_action_just_pressed("mterrain_mask_rotation_reset"):
				mask_decal.reset_image_rotation()
	if active_object is MGrass:
		status_bar.set_grass_label(active_object.get_count())
	else:
		status_bar.disable_grass_label()

#func update_brushes_based_on_heightmap_layer(new_layer):
	#if new_layer == "holes":	
		#brush_list_option.select(hole_brush_id)		
	#elif brush_id == hole_brush_id:
		#brush_list_option.select(raise_brush_id)		

func on_scene_changed(_root):
	set_edit_mode(null)

func request_hide():	
	set_edit_mode(null, null)
	visible = false

func request_show():
	visible = true
	update_edit_mode_options()

func deactivate_editing():	
	if is_instance_valid(edit_mode_button):
		edit_mode_button.text = "edit terrain"
	
	edit_mode_button.exit_edit_mode_button.visible = false
	brush_decal.visible = false
	mask_decal.visible = false	
	mask_popup_button.clear_mask()	
	for mterrain in get_all_mterrain():
		mterrain.disable_brush_mask()
	paint_panel.visible = false
	mpath_gizmo_gui.visible = false
	mcurve_mesh.visible = false
	brush_popup_button.clear_brushes()
	active_object = null
	current_edit_mode = &""
	
func set_edit_mode(object = active_object, mode=current_edit_mode):	
	if object == active_object and current_edit_mode == mode:	
		return
	
	if object==null or mode ==&"": 
		deactivate_editing()
		return	
	active_object = object	
	current_edit_mode = mode
	
	if object is MPath:		
		mpath_gizmo_gui.visible = true
		object.update_gizmos()
	elif object is MCurveMesh:
		mcurve_mesh.set_curve_mesh(object)
		mcurve_mesh.visible = true
		
	edit_mode_changed.emit(object, mode)	
	var active_mterrain = get_active_mterrain()
	if not active_mterrain: return
	active_mterrain.set_brush_manager(brush_manager)
	mask_popup_button.mterrain = active_mterrain
	mask_popup_button.toggle_grass_settings(false)
	
	if object is MTerrain:				
		paint_panel.visible = true
		layers_popup_button.visible = true
		#to do: clean up previous edit mode: grass, nav, and path stuff?, then:		
		for connection in layers_popup_button.get_signal_connection_list("layer_changed"):
			connection.signal.disconnect(connection.callable)					
		
		if mode == &"sculpt":
			layers_popup_button.init_height_layers(object)
			brush_popup_button.init_height_brushes(brush_manager)			
		elif mode == &"paint":
			if object.get_layers_info().size() == 0:
				add_child(preload("res://addons/m_terrain/gui/paint_mode_instructions_popup.tscn").instantiate())
				set_edit_mode(null,null)
				return
			layers_popup_button.init_color_layers(object, brush_popup_button)
			#Colol layers will init there own brushes				
		mask_decal.active_terrain = object
		if not get_active_mterrain().is_grid_created():
			get_active_mterrain().create_grid()
	elif object is MGrass:		
		paint_panel.visible = true
		#clean up previous edit mode: grass, nav, and path stuff, then:	
		layers_popup_button.visible = false
		#init_height_layers(object.get_parent())
		brush_popup_button.init_grass_brushes()
		mask_popup_button.toggle_grass_settings(true)
		mask_decal.active_terrain = active_mterrain
		if not get_active_mterrain().is_grid_created():
			get_active_mterrain().create_grid()
	elif object is MNavigationRegion3D:
		paint_panel.visible = true
		layers_popup_button.visible = false
		brush_popup_button.init_mnavigation_brushes()
		object.set_npoints_visible(true)
		mask_decal.active_terrain = active_mterrain
		if not get_active_mterrain().is_grid_created():
			get_active_mterrain().create_grid()
	
	

func draw(brush_position):		
	if active_object is MGrass:
		active_object.draw_grass(brush_position,brush_decal.radius,brush_popup_button.is_grass_add)
		return true
	elif active_object is MNavigationRegion3D:				
		active_object.draw_npoints(brush_position,brush_decal.radius, brush_popup_button.is_grass_add)
		return true
	elif active_object is MTerrain:		
		if current_edit_mode == &"sculpt":										
			active_object.draw_height(brush_position,brush_decal.radius,brush_popup_button.height_brush_id)
			return true
		elif current_edit_mode == &"paint":					
			active_object.draw_color(brush_position,brush_decal.radius,brush_popup_button.color_brush_name,brush_popup_button.color_brush_uniform)			
			return true
		else:
			push_warning("trying to 'draw' on mterrain, but not in sculpt or paint mode")
	else:
		print("draw mterrain fail: active object is ", active_object.name)	

#region responding to signals
func _on_human_male_toggled(button_pressed):	
	human_male.visible = button_pressed

#func set_save_button_disabled(disabled:bool):
#	save_button.disabled = disabled

#To do: remove this function
func _on_save_pressed():
	var active_terrain = get_active_mterrain()
	if active_terrain:
		active_terrain.save_all_dirty_images()	
	else:
		push_warning("trying to save mterrain, but active_object is wrong")	
	

func _on_info_btn_pressed():
	request_info_window.emit()

func _on_reload_pressed() -> void:
	get_active_mterrain().create_grid()

func _on_heightmap_import_button_pressed() -> void:
	request_import_window.emit()

func _on_heightmap_export_button_pressed() -> void:
	request_import_window.emit()

func _on_splatmap_import_button_pressed() -> void:
	request_import_window.emit()

func _on_image_creator_button_pressed() -> void:
	request_image_creator.emit()
#endregion	
