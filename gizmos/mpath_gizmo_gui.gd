@tool
extends Control


@onready var mirror_checkbox = find_child("mirror_checkbox")
@onready var mirror_lenght_checkbox = find_child("mirror_l_checkbox")
@onready var snap_checkbox = find_child("snap")
@onready var mode_option = find_child("mode")
@onready var collapse_btn = find_child("collapse")
@onready var toggle_connection_btn = find_child("toggle_connection")
@onready var connect_btn = find_child("Connect")
@onready var swap_points_btn = find_child("swap_points")
@onready var disconnect_btn = find_child("Disconnect")
@onready var remove_btn = find_child("remove")
@onready var tilt_num = find_child("tilt")
@onready var scale_num = find_child("scale")
@onready var depth_test_checkbox = find_child("depth_test")
@onready var xz_handle_lock = find_child("xz_handle_lock")
@onready var select_lock = find_child("select_lock")
@onready var debug_col = find_child("debug_col")
@onready var sort_increasing_btn = find_child("sort_increasing")
@onready var sort_decreasing_btn = find_child("sort_decreasing")

@onready var show_rest_btn = find_child("show_rest")
@onready var settings_panel = find_child("settings_panel")

var is_show_rest:=false

enum MODE {
	EDIT = 0,
	CREATE = 1,
}

func is_mirror()->bool:
	return mirror_checkbox.button_pressed

func is_mirror_lenght()->bool:
	return mirror_lenght_checkbox.button_pressed

func is_xz_handle_lock()->bool:
	return xz_handle_lock.button_pressed

func is_terrain_snap():
	return snap_checkbox.button_pressed

func get_mode():
	return mode_option.selected


func _input(event):
	if not visible:
		return		
	if Input.is_action_just_pressed( "mpath_toggle_mode" ):
		toggle_mode()
	if Input.is_action_just_pressed( "mpath_toggle_mirror" ):
		mirror_checkbox.button_pressed = not mirror_checkbox.button_pressed
	if Input.is_action_just_pressed( "mpath_toggle_mirror_length" ):
		mirror_lenght_checkbox.button_pressed = not mirror_lenght_checkbox.button_pressed

func _ready():
	tilt_num.__set_name("tilt")
	scale_num.__set_name("scale")
	tilt_num.set_value(0.0)
	scale_num.set_value(1.0)
	tilt_num.set_tooltip_text("Change Tilt\nHotkey: R")
	scale_num.set_tooltip_text("Change Tilt\nHotkey: E")
	settings_panel.visible = false
	
func toggle_mode():
	if mode_option.selected == 0:
		mode_option.selected = 1
	else:
		mode_option.selected = 0

func is_select_lock()->bool:
	return select_lock.button_pressed

func is_debug_col()->bool:
	return debug_col.button_pressed

func _on_show_rest_pressed():
	is_show_rest = not is_show_rest
	settings_panel.visible = is_show_rest
		
