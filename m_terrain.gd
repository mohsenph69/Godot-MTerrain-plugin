@tool
extends EditorPlugin

var import_window_res = preload("res://addons/m_terrain/gui/import_window.tscn")
var image_creator_window_res = preload("res://addons/m_terrain/gui/image_creator_window.tscn")
var tools= null
var paint_panel=null
var brush_decal=null
var human_male:MeshInstance3D=null

var raw_img_importer = null
var raw_tex_importer = null
var active_terrain:MTerrain = null
var active_grass:MGrass = null
var active_nav_region:MNavigationRegion3D = null
var last_camera_position:Vector3

var collision_ray_step=0.2
var ray_col:MCollision
var col_dis:float
var is_paint_active:bool = false

var action=""

func _enter_tree():
	if Engine.is_editor_hint():
		add_tool_menu_item("MTerrain importer", Callable(self,"show_import_window"))
		add_tool_menu_item("MTerrain image creator", Callable(self,"show_image_creator_window"))
		tools = preload("res://addons/m_terrain/gui/mtools.tscn").instantiate()
		tools.toggle_paint_mode.connect(Callable(self,"toggle_paint_mode"))
		tools.save_request.connect(Callable(self,"save_request"))
		tools.visible = false
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,tools)
		paint_panel = preload("res://addons/m_terrain/gui/paint_panel.tscn").instantiate()
		paint_panel.brush_size_changed.connect(Callable(self,"brush_size_changed"))
		get_editor_interface().get_selection().selection_changed.connect(Callable(self,"selection_changed"))
		brush_decal = preload("res://addons/m_terrain/gui/brush_decal.tscn").instantiate()
		brush_decal.visible = false
		get_editor_interface().get_editor_main_screen().add_child(brush_decal)
		human_male = preload("res://addons/m_terrain/gui/human_male.tscn").instantiate()
		get_editor_interface().get_editor_main_screen().add_child(human_male)


func _exit_tree():
	if Engine.is_editor_hint():
		remove_tool_menu_item("MTerrain importer")
		remove_tool_menu_item("MTerrain image creator")
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,tools)
		remove_control_from_docks(paint_panel)
		brush_decal.queue_free()
		human_male.queue_free()

func show_import_window():
	var window = import_window_res.instantiate()
	add_child(window)

func show_image_creator_window():
	var window = image_creator_window_res.instantiate()
	add_child(window)
	if active_terrain:
		window.set_terrain(active_terrain)

func _forward_3d_gui_input(viewport_camera, event):
	if active_terrain and event is InputEventMouse:
		active_terrain.set_editor_camera(viewport_camera)
		var ray:Vector3=viewport_camera.project_ray_normal(event.position)
		var pos:Vector3=viewport_camera.global_position
		ray_col = active_terrain.get_ray_collision_point(pos,ray,collision_ray_step,1000)
		if ray_col.is_collided():
			col_dis = ray_col.get_collision_position().distance_to(pos)
			tools.set_height_lable(ray_col.get_collision_position().y)
			tools.set_distance_lable(col_dis)
			if tools.active_paint_mode:
				if paint_mode_handle(event) == AFTER_GUI_INPUT_STOP:
					return AFTER_GUI_INPUT_STOP
			if tools.human_male_active:
				human_male.global_position = ray_col.get_collision_position()
				human_male.visible = true
		else:
			col_dis=1000000
			tools.disable_height_lable()
			tools.disable_distance_lable()
		if col_dis<1000:
			collision_ray_step = (col_dis + 50)/100
		else:
			collision_ray_step = 3
		tools.set_save_button_disabled(not active_terrain.has_unsave_image())
	if event is InputEventKey:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS:
			var size = paint_panel.brush_size + 1
			paint_panel.change_brush_size(size)
			return AFTER_GUI_INPUT_STOP
		if event.keycode == KEY_MINUS:
			var size = paint_panel.brush_size - 1
			paint_panel.change_brush_size(size)
			return AFTER_GUI_INPUT_STOP
	if not tools.human_male_active:
		human_male.visible = false
	if active_grass:
		tools.set_grass_label(active_grass.get_count())
	else:
		tools.disable_grass_lable()
	
	

func paint_mode_handle(event:InputEvent):
	if ray_col.is_collided():
		brush_decal.visible = true
		brush_decal.set_position(ray_col.get_collision_position())
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					if active_grass:
						pass
					elif active_nav_region:
						pass
					elif active_terrain:
						paint_panel.set_active_layer()
				else:
					if active_grass:
						active_grass.save_grass_data()
					elif active_nav_region:
						active_nav_region.save_nav_data()
					elif active_terrain:
						pass
		if event.button_mask == MOUSE_BUTTON_LEFT:
			if active_grass:
				active_grass.draw_grass(ray_col.get_collision_position(),brush_decal.radius,paint_panel.is_grass_add)
				return AFTER_GUI_INPUT_STOP
			if active_nav_region:
				active_nav_region.draw_npoints(ray_col.get_collision_position(),brush_decal.radius,paint_panel.is_grass_add)
				return AFTER_GUI_INPUT_STOP
			if paint_panel.is_color_brush:
				active_terrain.draw_color(ray_col.get_collision_position(),brush_decal.radius,paint_panel.current_color_brush,paint_panel.current_uniform)
				return AFTER_GUI_INPUT_STOP
			active_terrain.draw_height(ray_col.get_collision_position(),brush_decal.radius,paint_panel.brush_id)
			return AFTER_GUI_INPUT_STOP
	else:
		brush_decal.visible = false
		return AFTER_GUI_INPUT_PASS

func _handles(object):
	if not Engine.is_editor_hint():
		return false
	if is_instance_valid(active_nav_region):
		if active_nav_region != object:
			if active_nav_region:
				active_nav_region.set_npoints_visible(false)
	else:
		active_nav_region = null
	if object.has_method("create_grid"):
		active_terrain = object
		active_terrain.set_brush_manager(paint_panel.brush_manager)
		tools.visible = true
		if is_paint_active:
			paint_panel.set_grass_mode(false)
		active_grass = null
		active_nav_region = null
		return true
	elif object.has_method("draw_grass"):
		if object.get_parent().has_method("create_grid"):
			active_grass = object
			tools.visible = true
			active_nav_region = null
			if is_paint_active:
				paint_panel.set_grass_mode(true)
			active_terrain = object.get_parent()
			return true
	elif object.has_method("draw_npoints"):
		if object.get_parent().has_method("create_grid"):
			active_nav_region = object
			tools.visible = true
			active_grass = null
			if is_paint_active:
				paint_panel.set_grass_mode(true)
			if is_paint_active:
				active_nav_region.set_npoints_visible(true)
			active_terrain = object.get_parent()
			return true
	active_grass = null
	tools.visible = false
	return false


func selection_changed():
	var selection := get_editor_interface().get_selection()

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
		remove_control_from_docks(paint_panel)

func save_request():
	if active_terrain:
		active_terrain.save_all_dirty_images()

func brush_size_changed(value):
	brush_decal.set_brush_size(value)


func _save_external_data():
	if active_terrain:
		active_terrain.save_all_dirty_images()
