@tool
extends Button

@onready var container = find_child("brush_masks")
var stencil_decal
func _ready():
	var panel = get_child(0)
	panel.visible = false
	panel.position.y = -panel.size.y
	panel.size.x = get_viewport().size.x - global_position.x
	
	
func init_masks(stencil):			
	container.load_images(stencil)
	stencil_decal = stencil
	container.item_selected.connect(start_stencil_placement)
	
func start_stencil_placement(_id):
	stencil_decal.visible = true
	stencil_decal.is_being_edited = true
