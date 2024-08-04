@tool
extends Button

@onready var container = find_child("brush_masks")

func _ready():
	var panel = get_child(0)
	panel.visible = false
	panel.position.y = -panel.size.y
	panel.size.x = get_viewport().size.x - global_position.x
	
func init_masks(stencil):			
	container.load_images(stencil)
	stencil.visible = true
	stencil.is_being_edited = true
