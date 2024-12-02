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
	rename_dialog.canceled.connect(_on_rename_dialog_canceled)
	rename_dialog.confirmed.connect(_on_rename_dialog_confirmed)

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
		b.rename_req.connect(rename_req.bind(i))
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
	value_changed.emit(get_value())	

func rename_req(bit:int):	
	if bit<0 or bit>=layer_names.size():
		return
	current_renaming_bit = bit
	$rename_dialog/rename_line.text = layer_names[bit]
	$rename_dialog.visible = true
	
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


func _input(event: InputEvent)->void:
	if event is InputEventKey:
		if event.keycode==KEY_1 and event.pressed:
			set_value(652)			

func _on_rename_dialog_canceled() -> void:
	current_renaming_bit = -1

func _on_rename_dialog_confirmed() -> void:
	if current_renaming_bit < 0 || current_renaming_bit >= layer_names.size():
		return	
	layer_renamed.emit(current_renaming_bit, $rename_dialog/rename_line.text)	
