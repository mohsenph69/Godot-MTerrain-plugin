@tool
extends EditorPlugin
var version:String="0.13.0 alpha"
var import_window_res = preload("res://addons/m_terrain/gui/import_window.tscn")
var image_creator_window_res = preload("res://addons/m_terrain/gui/image_creator_window.tscn")

var tools= null
var current_main_screen_name =""

var tsnap = null
var brush_decal=null
var stencil_decal=null
var human_male:MeshInstance3D=null

var raw_img_importer = null
var raw_tex_importer = null

var active_snap_object:Node3D = null
var last_camera_position:Vector3

var collision_ray_step=0.2
var ray_col:MCollision
var col_dis:float
var is_paint_active:bool = false

var action=""

var current_window_info=null


var gizmo_moctmesh
var gizmo_mpath
var gizmo_mpath_gui
var mcurve_mesh_gui

var inspector_mpath

const keyboard_actions = [
		{"name": "toggle_mpath_mode", "keycode": KEY_QUOTELEFT, "pressed": true}
]
const setting_path = 'addons/MTerrain/keymap/'

func add_keymap():
	for action in keyboard_actions:
		var path = setting_path + action.name
		if not ProjectSettings.has_setting(path):
			var a = InputEventKey.new()
			a.keycode = action.keycode
			a.pressed = action.pressed
			ProjectSettings.set_setting(path, [a])
		var events = ProjectSettings.get_setting(path)
		if not InputMap.has_action(action.name):
			InputMap.add_action(action.name)
		for e in events:
			InputMap.action_add_event(action.name, e)
	
func remove_keymap():
	for action in keyboard_actions:
		InputMap.erase_action(action.name)
<<<<<<< HEAD

func _on_main_screen_changed(screen_name):
	current_main_screen_name = screen_name	
	selection_changed()

func _enter_tree():		
	if Engine.is_editor_hint():
		add_keymap()		
		main_screen_changed.connect(_on_main_screen_changed)		
													
		add_tool_menu_item("MTerrain import/export", show_import_window)
		add_tool_menu_item("MTerrain image create/remove", show_image_creator_window)
		
		tools = preload("res://addons/m_terrain/gui/mtools.tscn").instantiate()		
		tools.request_info_window.connect(show_info_window)
		tools.request_import_window.connect(show_import_window)
		tools.request_image_creator.connect(show_image_creator_window)
		tools.edit_mode_changed.connect(select_object)		
		var main_screen = EditorInterface.get_editor_main_screen()
		main_screen.add_child(tools)
		get_tree().node_added.connect(tools.on_node_modified)
		get_tree().node_renamed.connect(tools.on_node_modified)
		get_tree().node_removed.connect(tools.on_node_modified)
		
		#scene_changed.connect(func(a): tools.update_edit_mode_options())
		
		tsnap = load("res://addons/m_terrain/gui/tsnap.tscn").instantiate()
		tsnap.pressed.connect(tsnap_pressed)
		tsnap.visible = false
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,tsnap)
		
		get_editor_interface().get_selection().selection_changed.connect(selection_changed)
		
		brush_decal = preload("res://addons/m_terrain/gui/brush_decal.tscn").instantiate()		
		main_screen.add_child(brush_decal)
=======
	
func _enter_tree():
	add_keymap()
	if Engine.is_editor_hint():
		scene_changed.connect(on_scene_changed)
		add_tool_menu_item("MTerrain import/export", show_import_window)
		add_tool_menu_item("MTerrain image create/remove", show_image_creator_window)
		tools = preload("res://addons/m_terrain/gui/mtools.tscn").instantiate()
		tools.toggle_paint_mode.connect(toggle_paint_mode)
		tools.save_request.connect(save_request)
		tools.create_request.connect(create_request)
		tools.info_window_open_request.connect(info_window_open_request)
		tools.visible = false
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,tools)
		tsnap = load("res://addons/m_terrain/gui/tsnap.tscn").instantiate()
		tsnap.connect("pressed",tsnap_pressed)
		tsnap.visible = false
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,tsnap)
		
		paint_panel = preload("res://addons/m_terrain/gui/paint_panel.tscn").instantiate()
		paint_panel.brush_size_changed.connect(brush_size_changed)
		## ADD and Remove so the ready function will be called
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL,paint_panel)
		remove_control_from_docks(paint_panel)
		get_editor_interface().get_selection().selection_changed.connect(selection_changed)
		brush_decal = preload("res://addons/m_terrain/gui/brush_decal.tscn").instantiate()
>>>>>>> f34e0d2ab77b1b4b0426312c7eb97c6e846d2c92
		brush_decal.visible = false
		tools.set_brush_decal(brush_decal)
		
		stencil_decal = load("res://addons/m_terrain/gui/stencil_decal.tscn").instantiate()
		main_screen.add_child(stencil_decal)
		stencil_decal.visible = false
		tools.set_stencil(stencil_decal)
		
		human_male = load("res://addons/m_terrain/gui/human_male.tscn").instantiate()
		main_screen.add_child(human_male)
		human_male.visible = false
		tools.human_male = human_male
		MTool.enable_editor_plugin()
		###### GIZMO
		gizmo_moctmesh = load("res://addons/m_terrain/gizmos/moct_mesh_gizmo.gd").new()
		gizmo_mpath = load("res://addons/m_terrain/gizmos/mpath_gizmo.gd").new()
		gizmo_mpath_gui = tools.find_child("mpath_gizmo_gui") #load("res://addons/m_terrain/gizmos/mpath_gizmo_gui.tscn").instantiate()
		mcurve_mesh_gui = tools.find_child("mcurve_mesh") #load("res://addons/m_terrain/gizmos/mcurve_mesh_gui.tscn").instantiate()
		add_node_3d_gizmo_plugin(gizmo_moctmesh)
		gizmo_mpath.ur = get_undo_redo()
		add_node_3d_gizmo_plugin(gizmo_mpath)
		#add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,gizmo_mpath_gui)
		gizmo_mpath.set_gui(gizmo_mpath_gui)
		gizmo_mpath.mterrain_plugin = self
		#add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,mcurve_mesh_gui)
		#### Inspector
		inspector_mpath = load("res://addons/m_terrain/inspector/mpath.gd").new()
		inspector_mpath.gizmo = gizmo_mpath
		add_inspector_plugin(inspector_mpath)
<<<<<<< HEAD
		
func _ready() -> void:	
	EditorInterface.set_main_screen_editor("Script")
	EditorInterface.set_main_screen_editor("3D")
	
func _exit_tree():	
=======

func _exit_tree():
	remove_keymap()
>>>>>>> f34e0d2ab77b1b4b0426312c7eb97c6e846d2c92
	if Engine.is_editor_hint():
		remove_keymap()	
		remove_tool_menu_item("MTerrain import/export")
		remove_tool_menu_item("MTerrain image create/remove")		
		brush_decal.queue_free()
		stencil_decal.queue_free()		
		tsnap.queue_free()
		human_male.queue_free()
		
		get_tree().node_added.disconnect(tools.on_node_modified)
		get_tree().node_renamed.disconnect(tools.on_node_modified)
		get_tree().node_removed.disconnect(tools.on_node_modified)
		tools.queue_free()
		
		###### GIZMO
		remove_node_3d_gizmo_plugin(gizmo_moctmesh)
		remove_node_3d_gizmo_plugin(gizmo_mpath)
		#remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,gizmo_mpath_gui)
		#remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,mcurve_mesh_gui)
		### Inspector
		remove_inspector_plugin(inspector_mpath)

func show_import_window():
	var window = import_window_res.instantiate()
	add_child(window)
	if tools.get_active_mterrain() is MTerrain:
		window.init_export(tools.get_active_mterrain())

func show_image_creator_window():	
	if tools.get_active_mterrain() is MTerrain:
		var window = image_creator_window_res.instantiate()
		add_child(window)
		window.set_terrain(tools.get_active_mterrain() )
		

func _forward_3d_gui_input(viewport_camera, event):
	if not is_instance_valid(EditorInterface.get_edited_scene_root()): 
		return AFTER_GUI_INPUT_PASS
	var active_terrain = tools.get_active_mterrain()
	if not active_terrain is MTerrain:
		ray_col = null
	
	for terrain in tools.get_all_mterrain():
		terrain.set_editor_camera(viewport_camera)	
	
	if active_terrain is MTerrain and event is InputEventMouse:				
		var ray:Vector3=viewport_camera.project_ray_normal(event.position)
		var pos:Vector3=viewport_camera.global_position
		ray_col = active_terrain.get_ray_collision_point(pos,ray,collision_ray_step,1000)
		if ray_col.is_collided():			
			col_dis = ray_col.get_collision_position().distance_to(pos)
			tools.status_bar.set_height_label(ray_col.get_collision_position().y)
			tools.status_bar.set_distance_label(col_dis)
			tools.status_bar.set_region_label(active_terrain.get_region_id_by_world_pos(ray_col.get_collision_position()))
			if tools.current_edit_mode in [&"sculpt", &"paint"]:							
				if paint_mode_handle(event):
					return AFTER_GUI_INPUT_STOP			
			if tools.human_male.visible:
				human_male.global_position = ray_col.get_collision_position()
				human_male.visible = true
		else:
			col_dis=1000000
			tools.status_bar.disable_height_label()
			tools.status_bar.disable_distance_label()
			tools.status_bar.disable_region_label()
		if col_dis<1000:
			collision_ray_step = (col_dis + 50)/100
		else:
			collision_ray_step = 3
		tools.set_save_button_disabled(not active_terrain.has_unsave_image())
	######################## HANDLE CURVE GIZMO ##############################
	if gizmo_mpath_gui.visible:
		return gizmo_mpath._forward_3d_gui_input(viewport_camera, event, ray_col)
	######################## HANDLE CURVE GIZMO FINSH ########################	
		
	if tools.process_input(event):
		return AFTER_GUI_INPUT_STOP
		
	
	## Fail paint attempt
	## returning the stop so terrain will not be unselected
	if tools.current_edit_mode == &"paint":		
		if event is InputEventMouseButton:
			if event.button_mask == MOUSE_BUTTON_LEFT:
				return AFTER_GUI_INPUT_STOP

var last_draw_time:int=0

func _handles(object):
	if not Engine.is_editor_hint():
		return false
	if tools.active_object is MNavigationRegion3D:
		if tools.active_object != object:
			tools.active_object.set_npoints_visible(false)
	if object is MPath:
		tools.set_active_object(object)
		tools.request_show()		
		gizmo_mpath_gui.visible = true
		return true
	elif gizmo_mpath_gui:
		gizmo_mpath_gui.visible = false
	if object is MCurveMesh:
		mcurve_mesh_gui.set_curve_mesh(object)
		tools.request_show()	
		return true
	else:
		mcurve_mesh_gui.set_curve_mesh(null)
	active_snap_object = null
	tsnap.visible = false
	
	
	if object is MTerrain:		
		tools.set_active_object(object)			
		tools.request_show()		
		return true
	elif object is MGrass and object.get_parent() is MTerrain:			
		tools.set_active_object(object)
		tools.request_show()			
		return true
	elif object is MNavigationRegion3D and object.get_parent() is MTerrain:
		tools.set_active_object(object)
		tools.request_show()
		return true
	elif object is MCurve and  object.get_parent() is MTerrain:
		tools.set_active_object(object)
		tools.request_show()
		return true
	else:
		tools.request_hide()		
		#TO DO: fix snap tool setting of active terain		
		if object is Node3D:
			for mterrain:MTerrain in tools.get_all_mterrain(EditorInterface.get_edited_scene_root()):
				if mterrain.is_grid_created():
					active_snap_object = object
					tsnap.visible = true
		return false

func selection_changed():
	var selection = get_editor_interface().get_selection().get_selected_nodes()

	#TO DO: decide if this behaviour is good.
	if selection.size() != 1:		
		tools.request_hide()
		gizmo_mpath_gui.visible = false
		mcurve_mesh_gui.set_curve_mesh(null)
		return
		
	if not tools or not is_instance_valid(EditorInterface.get_edited_scene_root()): return
	if not current_main_screen_name == "3D":
		tools.request_hide()
		return	
	if selection	[0] is MTerrain or selection	[0].get_parent() is MTerrain	:
		tools.request_show()	
	else:		
		tools.request_hide()

<<<<<<< HEAD
func show_info_window(active_terrain:MTerrain):
=======
func toggle_paint_mode(input):
	is_paint_active = input
	if active_nav_region:
		active_nav_region.set_npoints_visible(input)
	if input and active_terrain:
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL,paint_panel)
		paint_panel.set_active_terrain(active_terrain)
		if active_grass or active_nav_region:
			paint_panel.set_grass_mode(true)
		else:
			paint_panel.set_grass_mode(false)
	else:
		brush_decal.visible = false
		stencil_decal.visible = false
		remove_control_from_docks(paint_panel)

func create_request():
	find_mterrain().create_grid()
	
func save_request():
	if not is_instance_valid(active_terrain):
		active_terrain = null
		return
	if active_terrain:
		active_terrain.save_all_dirty_images()

func brush_size_changed(value):
	brush_decal.set_brush_size(value)


func _save_external_data():
	if not is_instance_valid(active_terrain):
		active_terrain = null
		return
	if active_terrain:
		active_terrain.save_all_dirty_images()

func info_window_open_request():
>>>>>>> f34e0d2ab77b1b4b0426312c7eb97c6e846d2c92
	if is_instance_valid(current_window_info):
		current_window_info.queue_free()
	current_window_info = load("res://addons/m_terrain/gui/terrain_info.tscn").instantiate()
	add_child(current_window_info)
	current_window_info.generate_info(active_terrain,version)

#To do: fix tsnap pressed - how does it find active_terrain?
func tsnap_pressed(active_terrain:MTerrain):
	if active_terrain and active_snap_object and active_terrain.is_grid_created():
		var h:float = active_terrain.get_height(active_snap_object.global_position)
		active_snap_object.global_position.y = h
	

func select_object(object, mode):
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(object)
	
func paint_mode_handle(event:InputEvent):	
	if ray_col.is_collided():
		brush_decal.visible = true
		brush_decal.set_position(ray_col.get_collision_position())		
		if stencil_decal.visible:
			stencil_decal.set_absolute_terrain_pos(ray_col.get_collision_position())
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if tools.active_object is MGrass:
					tools.active_object.check_undo()
					get_undo_redo().create_action("GrassPaint")
					get_undo_redo().add_undo_method(tools.active_object,"undo")
					get_undo_redo().commit_action(false)
				elif tools.active_object is MNavigationRegion3D:
					pass
				elif tools.active_object is MTerrain: ## Start of painting						
					tools.active_object.set_brush_start_point(ray_col.get_collision_position(),brush_decal.radius)
					#tools.set_active_layer()
					tools.active_object.images_add_undo_stage()
					get_undo_redo().create_action("Sculpting")
					get_undo_redo().add_undo_method(tools.active_object,"images_undo")
					get_undo_redo().commit_action(false)
			else:
				if stencil_decal.is_being_edited:
					stencil_decal.is_being_edited =false
				elif tools.active_object is MGrass:
					tools.active_object.save_grass_data()
				elif tools.active_object is MNavigationRegion3D:
					tools.active_object.save_nav_data()
				elif tools.active_object is MTerrain:
					pass
		if event.button_mask == MOUSE_BUTTON_LEFT:			
			var t = Time.get_ticks_msec()
			var dt = t - last_draw_time			
			last_draw_time = t			
			if tools.draw(ray_col.get_collision_position()):
				return AFTER_GUI_INPUT_STOP 
			
	else:
		brush_decal.visible = false
		stencil_decal.visible = false
		return AFTER_GUI_INPUT_PASS
