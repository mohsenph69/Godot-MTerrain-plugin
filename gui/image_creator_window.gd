@tool
extends Window

@onready var no_terrain_label := $VBoxContainer/no_terrain
@onready var uniform_name_line := $VBoxContainer/uniform_name/uniform_name_line
@onready var format_option := $VBoxContainer/uniform_name2/OptionButton
@onready var uniform_name_empty_error:=$VBoxContainer/no_terrain2
@onready var def_color_picker:= $VBoxContainer/def_color/ColorPickerButton

var region_grid_size:Vector2i
var region_pixel_size:int=0
var data_dir:=""
var is_init = false


func set_terrain(input:MTerrain):
	region_grid_size.x = input.terrain_size.x/input.region_size
	region_grid_size.y = input.terrain_size.x/input.region_size
	region_pixel_size = ((input.region_size*input.get_base_size())/input.get_h_scale()) + 1
	data_dir = input.dataDir
	is_init = true
	no_terrain_label.visible = false

func _on_close_requested():
	queue_free()
	

func _on_create_button_up():
	var format:int = format_option.get_selected_id()
	var uniform_name:String = uniform_name_line.text
	var def_color:Color=def_color_picker.color
	if uniform_name.is_empty():
		printerr("Uniform Name is empty")
		uniform_name_empty_error.visible = true
		return
	else:
		uniform_name_empty_error.visible = false
	for y in range(0,region_grid_size.y):
		for x in range(0,region_grid_size.x):
			var img:Image = Image.create(region_pixel_size,region_pixel_size,false,format)
			img.fill(def_color)
			var file_name = uniform_name + "_x"+str(x)+"_y"+str(y)+".res"
			var file_path = data_dir.path_join(file_name)
			ResourceSaver.save(img,file_path)
	queue_free()








