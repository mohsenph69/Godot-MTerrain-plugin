@tool
extends Window

@onready var fileDialog = $FileDialog
@onready var fileDialog_save_folder = $FileDialog_save
@onready var save_folder_line = $VBoxContainer/save/save_folder_line
@onready var select_file_line: = $VBoxContainer/HBoxContainer/filepath_line
@onready var image_dimension_root: = $VBoxContainer/image_dimension
@onready var image_width_line: = $VBoxContainer/image_dimension/width
@onready var image_height_line: = $VBoxContainer/image_dimension/height
@onready var min_height_root:= $VBoxContainer/min_height
@onready var max_height_root:= $VBoxContainer/max_height
@onready var unform_name_line:=$VBoxContainer/uniform_name/uniform_name_line
@onready var is_heightmap_checkbox:= $VBoxContainer/is_heightmap_checkbox
@onready var min_height_line := $VBoxContainer/min_height/min_height_line
@onready var max_height_line := $VBoxContainer/max_height/max_height_line
@onready var region_size_line:= $VBoxContainer/HBoxContainer2/region_size_line
@onready var width_line:= $VBoxContainer/image_dimension/width
@onready var height_line:= $VBoxContainer/image_dimension/height
@onready var image_format_line:= $VBoxContainer/uniform_name2/image_format_line

var file_path:String
var ext:String
var save_path:String
var region_size:int
var unifrom_name:String
var width:int
var height:int
var min_height:float
var max_height:float
var image_format:int

var is_heightmap:=false

func _on_close_requested():
	queue_free()


func _on_button_button_down():
	fileDialog.visible = true

func _on_file_dialog_files_selected(paths):
	var path:String = paths[0]
	select_file_line.text = path 
	_on_filepath_line_text_changed(path)


func _on_filepath_line_text_changed(new_text:String):
	var ext = new_text.get_extension()
	image_dimension_root.visible = ext == "r16"

func _on_check_button_toggled(button_pressed):
	min_height_root.visible = button_pressed
	max_height_root.visible = button_pressed
	unform_name_line.editable = not button_pressed
	image_format_line.editable = not button_pressed
	is_heightmap = button_pressed
	if(button_pressed):
		unform_name_line.text = "heightmap"
	elif unform_name_line.text == "heightmap":
		unform_name_line.text = ""


func _on_save_folder_button_pressed():
	fileDialog_save_folder.visible = true

func _on_file_dialog_save_dir_selected(dir):
	save_folder_line.text = dir


func get_integer_inside_string(prefix:String,path:String)->int:
	path = path.to_lower()
	var reg = RegEx.new()
	reg.compile(prefix+"(\\d+)")
	var result := reg.search(path)
	if not result:
		return -1
	return result.strings[1].to_int()

func replace_x_y_in_path(x:int,y:int,path:String)->String:
	var reg = RegEx.new()
	var pattern = "(?i)(x)(\\d+)"
	reg.compile(pattern)
	var res = reg.search(path)
	var sub = reg.sub(path, res.strings[1]+str(x))
	pattern = "(?i)(y)(\\d+)"
	reg.compile(pattern)
	res = reg.search(sub)
	return reg.sub(sub, res.strings[1]+str(y))


func _on_import_pressed():
	file_path= select_file_line.text
	ext = select_file_line.text.get_extension()
	save_path= save_folder_line.text
	region_size = region_size_line.text.to_int()
	unifrom_name = unform_name_line.text
	width = width_line.text.to_int()
	height = height_line.text.to_int()
	min_height = min_height_line.text.to_float()
	max_height = max_height_line.text.to_float()
	image_format = image_format_line.text.to_int()
	var x = get_integer_inside_string("x",file_path)
	var y = get_integer_inside_string("y",file_path)
	#In this case there is no tile and we should tile that
	if(x==-1 or y==-1):
		import_no_tile()
	else: #And in this case there is tiled already and regions size will ignored
		import_tile()

func is_valid_image_lenght(input:int):
	if input<3:
		return false
	input -= 1
	while true:
		if input == 1:
			return true
		if input%2!=0:
			return false
		input /=2

func import_no_tile():
	var img:Image
	if ext=="r16":
		img=MRaw16.get_image(file_path,width,height,min_height,max_height,false)
	else:
		img = Image.load_from_file(file_path)
	if not img:
		printerr("Can not load image")
		return
	var img_size = img.get_size()
	if ext!="r16" and is_heightmap:
		img.convert(Image.FORMAT_RF)
		var data = img.get_data().to_float32_array()
		for i in range(0,data.size()):
			data[i] *= (max_height - min_height)
			data[i] += min_height
		img = Image.create_from_data(img_size.x,img_size.y,false,Image.FORMAT_RF, data.to_byte_array())
	if(not is_valid_image_lenght(img_size.x) or not is_valid_image_lenght(img_size.y)):
		printerr("Image size is not valide, Image width and height should be (2^n + 1)")
		return 0
	var modx = (img_size.x-1)%(region_size-1)
	var mody = (img_size.y-1)%(region_size-1)
	if(region_size<33):
		printerr("Region size can not be smaller than 33")
		return
	if(modx!=0 or mody!=0):
		printerr("Region size and image texture does not match")
		return
	var region_grid_size:= Vector2i()
	region_grid_size.x = (img_size.x-1)/(region_size-1)
	region_grid_size.y = (img_size.y-1)/(region_size-1)
	var total_regions = region_grid_size.x*region_grid_size.y
	if(total_regions>8192):
		printerr("make region size bigger, too many regions, region count: "+str(total_regions))
		return
	for y in range(0, region_grid_size.x):
		for x in range(0, region_grid_size.y):
			var r_save_name:String = unifrom_name+"_x"+str(x)+"_y"+str(y)+".res"
			var r_save_path:String = save_path.path_join(r_save_name)
			var pos:=Vector2i(x,y)
			pos *= (region_size-1)
			var rect = Rect2i(pos, Vector2i(region_size,region_size));
			var region_img:= img.get_region(rect)
			if(image_format>=0 and not is_heightmap):
				region_img.convert(image_format)
			ResourceSaver.save(region_img, r_save_path)
			print("saving ", r_save_path)
	queue_free()


func import_tile():
	var x:int=0
	var y:int=0
	while true:
		var r_path = replace_x_y_in_path(x,y,file_path)
		if(not FileAccess.file_exists(r_path)):
			x = 0
			y += 1
			r_path = replace_x_y_in_path(x,y,file_path)
			if(not FileAccess.file_exists(r_path)):
				break
		var img:Image
		if ext=="r16":
			img=MRaw16.get_image(r_path,0,0,min_height,max_height,false)
		else:
			img = Image.load_from_file(file_path)
		if not img:
			printerr("Can not load image")
			return
		var img_size = img.get_size()
		if ext!="r16" and is_heightmap:
			img.convert(Image.FORMAT_RF)
			var data = img.get_data().to_float32_array()
			for i in range(0,data.size()):
				data[i] *= (max_height - min_height)
				data[i] += min_height
		var r_save_name:String = unifrom_name+"_x"+str(x)+"_y"+str(y)+".res"
		var r_save_path:String = save_path.path_join(r_save_name)
		if(image_format>=0 and not is_heightmap):
			img.convert(image_format)
		ResourceSaver.save(img, r_save_path)
		x += 1
		print("saving ", r_save_path)
	queue_free()
