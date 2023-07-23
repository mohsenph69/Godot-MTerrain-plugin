@tool
extends VBoxContainer
class_name MPaintPanel

@onready var brush_type_checkbox:=$brush_type
@onready var brush_list_option:=$brush_list
@onready var brush_slider:=$brush_size/brush_slider
@onready var brush_lable:=$brush_size/lable
@onready var heightmap_layers:=$heightmap_layers


signal brush_size_changed

var float_prop_element=preload("res://addons/m_terrain/gui/control_prop_element/float.tscn")
var float_range_prop_element=preload("res://addons/m_terrain/gui/control_prop_element/float_range.tscn")
var bool_element = preload("res://addons/m_terrain/gui/control_prop_element/bool.tscn")
var int_element = preload("res://addons/m_terrain/gui/control_prop_element/int.tscn")
var int_enum_element = preload("res://addons/m_terrain/gui/control_prop_element/int_enum.tscn")

var brush_manager:MBrushManager = MBrushManager.new()
var is_color_brush:=true
var brush_id:int=-1
var active_heightmap_layer:="background"
var active_terrain:MTerrain

var brush_size:float

var property_element_list:Array

func _ready():
	_on_brush_type_toggled(false)
	change_brush_size(50)

func set_active_terrain(input:MTerrain):
	active_terrain = input
	update_heightmap_layers()

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


func change_brush_size(value):
	brush_slider.value = value

func _on_brush_slider_value_changed(value):
	brush_size = value
	brush_slider.max_value = 100*pow(value,0.3)
	brush_lable.text = "brush size "+str(value).pad_decimals(1)
	emit_signal("brush_size_changed",value)



### Layers
func update_heightmap_layers():
	if not active_terrain: return
	heightmap_layers.clear()
	## Background image always exist
	## and it does not conatin in this input
	## so we add that by ourself here
	heightmap_layers.add_item("background")
	var inputs = active_terrain.get_heightmap_layers()
	for i in range(0,inputs.size()):
		heightmap_layers.add_item(inputs[i])
	heightmap_layers.select(0)
	


func _on_heightmap_layer_item_selected(index):
	print(index)
	active_heightmap_layer = heightmap_layers.get_item_text(index)
	if not active_terrain:
		printerr("No active terrain")
		return
	print("active_heightmap_layer ",active_heightmap_layer)
	active_terrain.set_active_layer_by_name(active_heightmap_layer)
