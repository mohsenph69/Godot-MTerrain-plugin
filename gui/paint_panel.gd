@tool
extends VBoxContainer
class_name MPaintPanel

@onready var brush_type_checkbox:=$brush_type
@onready var brush_list_option:=$brush_list
@onready var brush_size:=$brush_size

signal brush_size_changed

var float_prop_element=preload("res://addons/m_terrain/gui/control_prop_element/float.tscn")
var float_range_prop_element=preload("res://addons/m_terrain/gui/control_prop_element/float_range.tscn")
var bool_element = preload("res://addons/m_terrain/gui/control_prop_element/bool.tscn")
var int_element = preload("res://addons/m_terrain/gui/control_prop_element/int.tscn")
var int_enum_element = preload("res://addons/m_terrain/gui/control_prop_element/int_enum.tscn")

var brush_manager:MBrushManager = MBrushManager.new()
var is_color_brush:=true
var brush_id:int=-1

var property_element_list:Array

func _ready():
	_on_brush_type_toggled(false)
	brush_size.call_deferred("set_name","brush size")
	brush_size.min = 0.25
	brush_size.max = 4000

func _on_brush_type_toggled(button_pressed):
	is_color_brush = button_pressed
	brush_list_option.clear()
	if button_pressed:
		brush_type_checkbox.text = "Color brush"
		_on_brush_list_item_selected(-1)
	else:
		brush_type_checkbox.text = "Height brush"
		var brushe_names = brush_manager.get_height_brush_list()
		for n in brushe_names:
			brush_list_option.add_item(n)
			_on_brush_list_item_selected(0)


func _on_brush_list_item_selected(index):
	clear_property_element()
	if index < -1: return
	brush_id = index
	var brush_props:Array
	if is_color_brush:
		pass
	else:
		brush_props = brush_manager.get_height_brush_property(brush_id)
	for p in brush_props:
		create_props(p)



func create_props(dic:Dictionary):
	var element
	if dic["type"]==TYPE_FLOAT:
		var rng = dic["max"] - dic["min"]
		if dic["hint"] == "range":
			element = float_range_prop_element.instantiate()
			element.set_min(dic["min"])
			element.set_max(dic["max"])
			element.set_step(dic["hint_string"].to_float())
		else:
			element = float_prop_element.instantiate()
			element.min = dic["min"]
			element.max = dic["max"]
	elif dic["type"]==TYPE_BOOL:
		element = bool_element.instantiate()
	elif dic["type"]==TYPE_INT:
		if dic["hint"] == "enum":
			element = int_enum_element.instantiate()
			element.set_options(dic["hint_string"])
		else:
			element = int_element.instantiate()
			element.set_min(dic["min"])
			element.set_max(dic["max"])
	add_child(element)
	element.connect("prop_changed",Callable(self,"prop_change"))
	element.set_value(dic["default_value"])
	element.set_name(dic["name"])
	property_element_list.append(element)



func clear_property_element():
	for e in property_element_list:
		if is_instance_valid(e):
			e.queue_free()
	property_element_list = []

func prop_change(prop_name,value):
	if is_color_brush:
		pass
	else:
		brush_manager.set_height_brush_property(prop_name,value,brush_id)
