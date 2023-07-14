@tool
extends Decal
class_name MBrushDecal


func set_brush_size(input:float):
	size.x = input
	size.z = input

func get_brush_size()->float:
	return size.x

func change_brush_color(input:Color):
	modulate = input
