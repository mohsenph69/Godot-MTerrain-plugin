@tool
extends OptionButton

signal edit_mode_changed

func _ready():
	item_selected.connect(process_item_selection)

func process_item_selection(id):
	if "sculpt" in text.to_lower():
		edit_mode_changed.emit(get_item_metadata(id), &"sculpt")
	elif "paint" in text.to_lower():
		edit_mode_changed.emit(get_item_metadata(id), &"paint")
	else:
		edit_mode_changed.emit(get_item_metadata(id), &"")
		
func change_active_object(object):
	if object.name in text: return
	for i in item_count:
		if object == get_item_metadata(i):
			if "sculpt" in text.to_lower() and "sculpt" in get_item_text(i):
				select(i)
			elif "paint" in text.to_lower() and "paint" in get_item_text(i):
				select(i)
