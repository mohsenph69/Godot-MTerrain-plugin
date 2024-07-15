@tool
extends HBoxContainer

signal prop_changed(prop_name,new_value)
signal commit_value(prop_name,old_value,new_value)

var prop_name:String
var value:float
var max:float = 1000000000000000000
var min:float = -100000000000000000

var init_drag_val:float
func set_max(input):
	max=input
	$slide.max_value = max

func set_min(input):
	min=input
	$slide.min_value = min

func set_soft_max(input):
	$slide.max_value = input

func set_soft_min(input):
	$slide.min_value = input

func set_step(input):
	$slide.step = input

func set_name(input:String):
	prop_name = input
	$lable.text = input

func __set_name(input:String):
	prop_name = input
	$lable.text = input

func _set_tooltip_text(input:String):
	$value.tooltip_text = input
	$slide.tooltip_text = input

func set_value(input:float):
	value = input
	$slide.value = input
	$value.text = str(input)

func set_value_no_signal(input:float):
	value = input
	$slide.set_value_no_signal(input)
	$value.text = str(input)

func set_editable(input:bool):
	$value.editable = input
	$slide.editable = input

func _on_value_text_submitted(new_text:String):
	if new_text.is_valid_float():
		var new_value = new_text.to_float()
		if new_value>max:
			new_value = max
		if new_value<min:
			new_value = min
		if new_value != value:
			var old_value = value
			value = new_value
			emit_signal("prop_changed",prop_name,new_value)
			emit_signal("commit_value",prop_name,old_value,new_value)
	$value.release_focus()
	$value.text = str(value)
	


func _on_value_focus_exited():
	_on_value_text_submitted($value.text)


func _on_slide_value_changed(v):
	value = v
	$value.text = str(value)
	emit_signal("prop_changed",prop_name,value)


func _on_slide_drag_started():
	init_drag_val = $slide.value

func _on_slide_drag_ended(value_changed):
	if not value_changed: return
	emit_signal("commit_value",prop_name,init_drag_val,$slide.value)
