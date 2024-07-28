@tool
extends VBoxContainer


@onready var mirror_checkbox:=$HBoxContainer/mirror_checkbox
@onready var mirror_lenght_checkbox:=$HBoxContainer/mirror_l_checkbox
@onready var snap_checkbox:=$HBoxContainer/snap
@onready var mode_option:=$HBoxContainer/mode
@onready var collapse_btn:=$HBoxContainer/collapse
@onready var toggle_connection_btn:=$HBoxContainer/toggle_connection
@onready var connect_btn:=$HBoxContainer/Connect
@onready var swap_points_btn:=$HBoxContainer3/swap_points
@onready var disconnect_btn:=$HBoxContainer/Disconnect
@onready var remove_btn:=$HBoxContainer/remove
@onready var tilt_num:=$HBoxContainer2/tilt
@onready var scale_num:=$HBoxContainer2/scale
@onready var depth_test_checkbox:=$HBoxContainer3/depth_test
@onready var xz_handle_lock:=$HBoxContainer3/xz_handle_lock
@onready var select_lock:=$HBoxContainer3/select_lock
@onready var debug_col:=$HBoxContainer3/debug_col
@onready var sort_increasing_btn:=$HBoxContainer3/sort_increasing
@onready var sort_decreasing_btn:=$HBoxContainer3/sort_decreasing

@onready var show_rest_btn:=$HBoxContainer/show_rest
@onready var col2:=$HBoxContainer2
@onready var col3:=$HBoxContainer3


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
	if event is InputEventKey:
		if event.pressed:
			if  event.keycode == KEY_QUOTELEFT:
				toggle_mode()
			elif event.keycode == KEY_M:
				mirror_checkbox.button_pressed = not mirror_checkbox.button_pressed
			elif event.keycode == KEY_L:
				mirror_lenght_checkbox.button_pressed = not mirror_lenght_checkbox.button_pressed

func _ready():
	tilt_num.__set_name("tilt")
	scale_num.__set_name("scale")
	tilt_num.set_value(0.0)
	scale_num.set_value(1.0)
	tilt_num.set_tooltip_text("Change Tilt\nHotkey: R")
	scale_num.set_tooltip_text("Change Tilt\nHotkey: E")

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
	col2.visible = is_show_rest
	col3.visible = is_show_rest
	if is_show_rest:
		show_rest_btn.text = "<"
	else:
		show_rest_btn.text = ">"
