@tool 
extends SubViewport

var mesh
@onready var joined_mesh_preview_camera_pivot = %joined_mesh_preview_camera_pivot
@onready var joined_mesh_preview_camera = %joined_mesh_preview_camera

var rotating = false

func _ready():
	%joined_mesh_preview.mesh = mesh	
	
func on_thumbnail_gui_input(event: InputEvent):
	if event is InputEventMouseButton: 
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			joined_mesh_preview_camera.position -= joined_mesh_preview_camera.basis.z
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			joined_mesh_preview_camera.position += joined_mesh_preview_camera.basis.z
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				rotating = true
			else:
				rotating = false
	elif event is InputEventMouseMotion:
		if rotating:
			joined_mesh_preview_camera_pivot.rotation.y -= event.relative.x / 100
			joined_mesh_preview_camera_pivot.rotation.x = clamp(joined_mesh_preview_camera_pivot.rotation.x - event.relative.y / 100, -0.7,1)				
