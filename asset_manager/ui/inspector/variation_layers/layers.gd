@tool
extends GridContainer

signal layer_renamed
signal value_changed 

var baker:HLod_Baker #optional
var layer_btn = preload("./layer_btn.gd")
const layer_count:=16
var is_init := false
var max_value:int = 0
var current_renaming_bit := -1

var btns:Array # button bit in order
@export var value:int:
	set(input):
		value = input
		set_value(value)
	get():
		return get_value()

@export var layer_names:PackedStringArray:
	set(input):
		layer_names = input
		update_layer_names()

@onready var rename_dialog: ConfirmationDialog = find_child("rename_dialog")

func _ready():		
	init_layers()
	if layer_names.size() != layer_count:
		layer_names.resize(layer_count)
	update_layer_names()

func _init()-> void:
	max_value = 0
	for i in range(0,layer_count):
		max_value |= 1 << i


func init_layers()->void:	
	for i in layer_count:
		var b: Button = layer_btn.new()
		if baker:
			b.baker = baker
		b.toggle_mode = true				
		b.toggled.connect(button_pressed.bind(i))		
		btns.push_back(b)
		add_child(b)

func update_layer_names():
	var s = min(layer_names.size(),btns.size())
	for i in range(0,s):
		var b:Button= btns[i]		
		b.tooltip_text = layer_names[i] if layer_names[i] else str(i)

func button_pressed(toggle:bool,bit:int):
	if bit >= btns.size():
		push_error("Invalid Bit")
		return	
	if Input.is_key_pressed(KEY_CTRL):		
		value_changed.emit(int(pow(2, bit)))		
		for i in len(btns):
			btns[i].set_pressed_no_signal(i == bit)
	else:
		value_changed.emit(get_value())		
	
func set_value(val:int)->void:
	if val > max_value:
		push_warning("value ",val,"is bigger than max value ", max_value, " some bits will be ignored")
	for i in range(0,btns.size()):
		var b:Button = btns[i]
		b.button_pressed = val & (1 << i)			

func get_value()->int:
	var val:int = 0
	for i in range(0,btns.size()):
		var b:Button = btns[i]
		if b.button_pressed:
			val |= 1 << i	
	return val
