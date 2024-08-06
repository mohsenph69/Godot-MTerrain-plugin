#MASK BUTTON
@tool
extends Button

@onready var mask_container = find_child("mask_list")
var mask_cutoff_control
var mask_decal
var mask_clear_button
var mterrain:MTerrain # this is set when MTools is changing edit mode 

func _ready():
	var panel = get_child(0)
	panel.visible = false
	panel.position.y = -panel.size.y
	panel.size.x = get_viewport().size.x - global_position.x
	panel.gui_input.connect(fix_gui_input)
	mask_clear_button = $"../mask_clear_button"
	mask_clear_button.visible = false


func fix_gui_input(event:InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()


func init_masks(mask, mask_size_control, mask_rotation_control, new_mask_cutoff_control:Control, mask_invert_button:BaseButton):			
	mask_cutoff_control = new_mask_cutoff_control
	mask_clear_button.pressed.connect(clear_mask)
	mask_container.load_images(mask)	
	mask_decal = mask
	mask_container.item_selected.connect(start_mask_placement)	
	mask_size_control.value_changed.connect(change_mask_size)
	mask_rotation_control.value_changed.connect(change_mask_rotation)
	mask_cutoff_control.value_changed.connect(change_mask_cutoff)
	mask_invert_button.pressed.connect(mask_container.invert_selected_image)

func clear_mask():	
	var current_selection = mask_container.get_selected_items()
	if current_selection.size()==0: return
	mask_clear_button.visible = false
	mask_decal.visible = false 
	mask_decal.is_being_edited = false
	#change_mask_cutoff(0)
	if current_selection[0] != 0:
		mask_container.select(0)
		mask_decal.set_mask(null,null)
		icon = mask_container.get_item_icon(0)
		text = ""
		clear_mask()
	

func change_mask_size(value):
	mask_decal.set_size(value)
	
func change_mask_rotation(value):
	mask_decal.set_image_rotation(value)
	
func change_mask_cutoff(value):
	mterrain.set_mask_cutoff(value)	
	
func start_mask_placement(id):
	if id == 0: 
		clear_mask()
		return
	mask_clear_button.visible = true
	mask_decal.visible = true
	mask_decal.is_being_edited = true
	icon = mask_decal.active_tex
	text = ""
	
func toggle_grass_settings(toggle_on):
	mask_cutoff_control.visible = toggle_on
	mterrain.set_mask_cutoff(mask_cutoff_control.slider.value)

