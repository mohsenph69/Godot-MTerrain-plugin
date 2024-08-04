@tool
extends BoxContainer
signal value_changed
@onready var slider = $VSlider
@onready var textbox = $LineEdit


func _ready():
	slider.value_changed.connect(update_value)
	textbox.text_submitted.connect(update_value)
	
func update_value(new_value):
	var changed = false
	if slider.value != float(new_value): 
		slider.value = float(new_value)
		changed = true
	if textbox.text != str(new_value): 
		textbox.text = str(new_value)	
		changed = true
	if changed:
		value_changed.emit(new_value)
