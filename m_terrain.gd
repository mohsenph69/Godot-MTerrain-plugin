@tool
extends EditorPlugin
var version:String="????"

var tools:Control= null

var current_main_screen_name =""

var tsnap = null

var action=""

var current_window_info=null

var gizmo_aabb
var gizmo_moctmesh
var gizmo_mpath
var gizmo_masset_mesh

var inspector_mpath
	
#var MLOD_Mesh_Importer
var asset_browser
var asset_browser_inspector_plugin
var loaded_scenes = []

var gltf_extras_importer

var asset_table:MAssetTable

#region keyboard actions
var default_keyboard_actions 

const setting_path = 'addons/m_terrain/keymap/'

func add_keymap(force_default = false):	
	set_default_keymap()
	for action in default_keyboard_actions:
		var path = setting_path + action.name
		if force_default or not ProjectSettings.has_setting(path):
			var a = InputEventKey.new()
			a.keycode = action.keycode
			a.pressed = action.pressed
			if "shift" in action.keys():
				a.shift_pressed = action.shift				
			ProjectSettings.set_setting(path, a)
		var e = ProjectSettings.get_setting(path)
		if not InputMap.has_action(action.name):			
			InputMap.add_action(action.name)		
		for i in default_keyboard_actions.size():
			if default_keyboard_actions[i].name == action.name:
				default_keyboard_actions[i].keycode = e.keycode
				default_keyboard_actions[i].shift = e.shift_pressed
				default_keyboard_actions[i].ctrl = e.ctrl_pressed
				default_keyboard_actions[i].alt = e.alt_pressed
		InputMap.action_add_event(action.name, e)
	
func remove_keymap():
	for action in default_keyboard_actions:
		InputMap.erase_action(action.name)
#endregion

func init_asset_table():
	var path = MAssetTable.get_asset_table_path()
	if ResourceLoader.exists(path):
		asset_table = ResourceLoader.load(path)
	if not asset_table:
		asset_table = MAssetTable.new()
	MAssetTable.set_singleton(asset_table)

#region init and de-init
func _enter_tree():		
	if Engine.is_editor_hint():
		version = get_plugin_version()
		MTerrainSettings.add_projects_settings()
		init_asset_table()
		var main_screen = EditorInterface.get_editor_main_screen()											
		main_screen_changed.connect(_on_main_screen_changed)		
		tools = load("res://addons/m_terrain/gui/mtools.tscn").instantiate()		
		tools.request_info_window.connect(show_info_window)
		tools.request_import_window.connect(show_import_window)
		tools.request_image_creator.connect(show_image_creator_window)
		tools.edit_mode_changed.connect(select_object)		
		tools.undo_redo = get_undo_redo()			
		main_screen.add_child(tools)		
		
		get_tree().node_added.connect(tools.on_node_modified)
		get_tree().node_renamed.connect(tools.on_node_modified)
		get_tree().node_removed.connect(tools.on_node_modified)
		
		tools.set_brush_decal( load("res://addons/m_terrain/gui/brush_decal.tscn").instantiate()	)
		main_screen.add_child(tools.brush_decal)
		
		tools.set_mask_decal( load("res://addons/m_terrain/gui/mask_decal.tscn").instantiate() )
		main_screen.add_child(tools.mask_decal)
		
		tools.human_male = load("res://addons/m_terrain/gui/human_male.tscn").instantiate()
		main_screen.add_child(tools.human_male)
		tools.human_male.visible = false
		
		EditorInterface.get_selection().selection_changed.connect(selection_changed)
		
		tsnap = load("res://addons/m_terrain/gui/tsnap.tscn").instantiate()
		tsnap.pressed.connect(tsnap_pressed)
		tsnap.visible = false
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,tsnap)				
				
		###### GIZMO
		gizmo_aabb = load("res://addons/m_terrain/gizmos/aabb_gizmo.gd").new()
		add_node_3d_gizmo_plugin(gizmo_aabb)
		gizmo_masset_mesh = load("res://addons/m_terrain/gizmos/masset_mesh_gizmo.gd").new()
		add_node_3d_gizmo_plugin(gizmo_masset_mesh)
		gizmo_moctmesh = load("res://addons/m_terrain/gizmos/moct_mesh_gizmo.gd").new()
		gizmo_mpath = load("res://addons/m_terrain/gizmos/mpath_gizmo.gd").new()
		add_node_3d_gizmo_plugin(gizmo_moctmesh)
		gizmo_mpath.ur = get_undo_redo()
		add_node_3d_gizmo_plugin(gizmo_mpath)		
		gizmo_mpath.set_gui(tools.mpath_gizmo_gui)
		gizmo_mpath.tools = tools
		#### Inspector
		inspector_mpath = load("res://addons/m_terrain/inspector/mpath.gd").new()
		inspector_mpath.gizmo = gizmo_mpath
		add_inspector_plugin(inspector_mpath)
				
		add_keymap()				
		
		asset_browser = load("res://addons/m_terrain/asset_manager/Asset_Placer.tscn").instantiate()		
		#scene_closed.connect(Callable(asset_browser,"scene_closed"))
		add_control_to_bottom_panel(asset_browser, "Assets")
		
		asset_browser_inspector_plugin = load("res://addons/m_terrain/asset_manager/inspector_plugin.gd").new()
		asset_browser_inspector_plugin.asset_placer = asset_browser
		add_inspector_plugin(asset_browser_inspector_plugin)
		gltf_extras_importer = GLTFExtras.new()
		GLTFDocument.register_gltf_document_extension(gltf_extras_importer)		
		init_import_info_settings()
		MTool.enable_editor_plugin()
		
func _ready() -> void:	
	EditorInterface.set_main_screen_editor("Script")
	EditorInterface.set_main_screen_editor("3D")	
	
func _exit_tree():	
	if Engine.is_editor_hint():				
		remove_keymap()	
		remove_tool_menu_item("MTerrain import/export")
		remove_tool_menu_item("MTerrain image create/remove")		
		tools.brush_decal.queue_free()
		tools.mask_decal.queue_free()		
		tsnap.queue_free()
		tools.human_male.queue_free()
		
		get_tree().node_added.disconnect(tools.on_node_modified)
		get_tree().node_renamed.disconnect(tools.on_node_modified)
		get_tree().node_removed.disconnect(tools.on_node_modified)
		tools.queue_free()
		
		###### GIZMO
		remove_node_3d_gizmo_plugin(gizmo_aabb)
		remove_node_3d_gizmo_plugin(gizmo_masset_mesh)
		remove_node_3d_gizmo_plugin(gizmo_moctmesh)
		remove_node_3d_gizmo_plugin(gizmo_mpath)
				
				
		### Inspector
		remove_inspector_plugin(inspector_mpath)						
		remove_control_from_bottom_panel(asset_browser)		
		
		remove_inspector_plugin(asset_browser_inspector_plugin)
		MAssetTable.set_singleton(null)
		GLTFDocument.unregister_gltf_document_extension(gltf_extras_importer)		
#endregion

func _on_main_screen_changed(screen_name):
	current_main_screen_name = screen_name	
	selection_changed()	
	asset_browser.on_main_screen_changed()

#select_object is called when tools changes edit mode
func select_object(object, mode):	
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(object)

func selection_changed():
	if not tools or not is_instance_valid(EditorInterface.get_edited_scene_root()): return
	
	var selection = get_editor_interface().get_selection().get_selected_nodes()
	
	if selection.size() != 1 or not current_main_screen_name == "3D":		
		tools.request_hide()
		#exit edit mode
		return

	tools.on_selection_changed(selection[0])

func _handles(object):
	if not Engine.is_editor_hint(): return false
	if not current_main_screen_name == "3D":
		tools.request_hide()
		return false
	if asset_browser.asset_place_control.need_editor_input:
		return true
	tsnap.visible = false
	if tools.on_handles(object): 		
		return true	
	tsnap.visible = is_instance_valid(tools.active_snap_object)

func _forward_3d_gui_input(viewport_camera, event):
	if not is_instance_valid(EditorInterface.get_edited_scene_root()): 
		return AFTER_GUI_INPUT_PASS
	if asset_browser.asset_place_control.need_editor_input:
		return asset_browser.asset_place_control._forward_3d_gui_input(viewport_camera,event)
	
	if tools.forward_3d_gui_input(viewport_camera, event):		
		return AFTER_GUI_INPUT_STOP
	else:
		return AFTER_GUI_INPUT_PASS
		
func tsnap_pressed():
	var terrains = tools.get_all_mterrain()
	var active_terrain
	for terrain in terrains:
		if terrain.is_grid_created():
			active_terrain = terrain
			break	
	if active_terrain and tools.active_snap_object:		
		var h:float = active_terrain.get_height(tools.active_snap_object.global_position)
		tools.active_snap_object.global_position.y = h
			
func show_import_window():	
	var window = load("res://addons/m_terrain/gui/import_window.tscn").instantiate()
	add_child(window)		
	window.init_export(tools.get_active_mterrain())

func show_image_creator_window():	
	if tools.get_active_mterrain():	
		var window = load("res://addons/m_terrain/gui/image_creator_window.tscn").instantiate()
		add_child(window)		
		window.mterrain = tools.get_active_mterrain()		

func show_info_window(active_terrain = tools.get_active_mterrain()):
	if not active_terrain:
		printerr("No Active Terrain")
		return
	var is_grid_created = active_terrain.is_grid_created()
	if is_instance_valid(current_window_info):
		current_window_info.queue_free()
	if not active_terrain is MTerrain:
		push_error("no active mterrain for info window")
	current_window_info = load("res://addons/m_terrain/gui/terrain_info.tscn").instantiate()
	add_child(current_window_info)	
	if is_grid_created:
		active_terrain.remove_grid()
	current_window_info.generate_info(active_terrain,version, default_keyboard_actions)
	current_window_info.mtools = tools	
	current_window_info.keymap_changed.connect(update_keymap)
	current_window_info.restore_default_keymap_requested.connect(func():
		add_keymap(true)
		current_window_info.create_keymapping_interface(default_keyboard_actions)
	)
	if is_grid_created:
		current_window_info.tree_exiting.connect(active_terrain.create_grid)

func set_default_keymap():
	default_keyboard_actions = [
		{"name": "mterrain_brush_size_increase", "keycode": KEY_BRACKETRIGHT, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mterrain_brush_size_decrease", "keycode": KEY_BRACKETLEFT, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		
		{"name": "mterrain_mask_size_increase", "keycode": KEY_PERIOD, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mterrain_mask_size_decrease", "keycode": KEY_COMMA, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mterrain_mask_rotate_clockwise", "keycode": KEY_L, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mterrain_mask_rotate_counter_clockwise", "keycode": KEY_K, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mterrain_mask_rotation_reset", "keycode": KEY_SEMICOLON, "pressed": true, "shift": false, "ctrl": false, "alt": false},

		{"name": "mterrain_walk_forward", "keycode": KEY_W, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mterrain_walk_backward", "keycode": KEY_S, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mterrain_walk_left", "keycode": KEY_A, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mterrain_walk_right", "keycode": KEY_D, "pressed": true, "shift": false, "ctrl": false, "alt": false},


		{"name": "mpath_toggle_mode", "keycode": KEY_QUOTELEFT, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mpath_toggle_mirror", "keycode": KEY_M, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mpath_toggle_mirror_length", "keycode": KEY_L, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		
		{"name": "mpath_validate", "keycode": KEY_P, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mpath_select_linked", "keycode": KEY_L, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mpath_swap_points", "keycode": KEY_T, "pressed": true, "shift": true, "ctrl": false, "alt": false},
		{"name": "mpath_toggle_connection", "keycode": KEY_T, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mpath_remove_point", "keycode": KEY_BACKSPACE, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mpath_disconnect_point", "keycode": KEY_B, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mpath_connect_point", "keycode": KEY_C, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mpath_tilt_mode", "keycode": KEY_R, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mpath_scale_mode", "keycode": KEY_K, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mpath_lock_zy", "keycode": KEY_X, "pressed": true, "shift": true, "ctrl": false, "alt": false},
		{"name": "mpath_lock_xz", "keycode": KEY_Y, "pressed": true, "shift": true, "ctrl": false, "alt": false},
		{"name": "mpath_lock_xy", "keycode": KEY_Z, "pressed": true, "shift": true, "ctrl": false, "alt": false},
		{"name": "mpath_lock_x", "keycode": KEY_X, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mpath_lock_y", "keycode": KEY_Y, "pressed": true, "shift": false, "ctrl": false, "alt": false},
		{"name": "mpath_lock_z", "keycode": KEY_Z, "pressed": true,  "shift": false, "ctrl": false, "alt": false },
	]
func update_keymap(who, keycode, ctrl, alt, shift):
	var a = InputEventKey.new()
	a.keycode = keycode
	a.pressed = true	
	a.ctrl_pressed = ctrl
	a.alt_pressed = alt
	a.shift_pressed = shift	
	ProjectSettings.set_setting(setting_path + who, a)
	InputMap.action_erase_events(who)
	InputMap.action_add_event(who, a)
	for i in default_keyboard_actions.size():
		if default_keyboard_actions[i].name == who:						
			default_keyboard_actions[i].keycode = keycode
			default_keyboard_actions[i].ctrl = ctrl
			default_keyboard_actions[i].alt = alt
			default_keyboard_actions[i].shift = shift			

static func init_import_info_settings():	
	var import_info = MAssetTable.get_singleton().import_info
	if not import_info.has("__settings"):
		import_info["__settings"] = {}
	if not import_info["__settings"].has("Materials blend file"): 
		import_info["__settings"]["Materials blend file"] = {"value": "", "type":TYPE_STRING, "hint":"path_global"}
	MAssetTable.save()
