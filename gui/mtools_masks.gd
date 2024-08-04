#MASK BUTTON
@tool
extends Button

@onready var brush_container = find_child("brush_masks")
var mask_settings_container
var mask_decal
var mterrain:MTerrain # this is set when MTools is changing edit mode 
func _ready():
	var panel = get_child(0)
	panel.visible = false
	panel.position.y = -panel.size.y
	panel.size.x = get_viewport().size.x - global_position.x
	
	
func init_masks(mask, mask_cutoff_control:Control, mask_invert_button:BaseButton):			
	brush_container.load_images(mask)	
	mask_decal = mask
	brush_container.item_selected.connect(start_mask_placement)	
	mask_cutoff_control.value_changed.connect(change_mask_cutoff)
	mask_invert_button.pressed.connect(brush_container.invert_selected_image)

func change_mask_cutoff(value):
	mterrain.set_mask_cutoff(value)	
	
func start_mask_placement(_id):
	mask_decal.visible = true
	mask_decal.is_being_edited = true
