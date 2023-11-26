@tool
extends ItemList

const brush_masks_dir:String = "res://addons/m_terrain/brush_masks/"
const allowed_extension:PackedStringArray = ["jpg","jpeg","png","exr","bmp","dds","hdr","tga","svg","webp"]


var stencil=null

var is_loaded:=false
var current_selected_index:int=0

var images:Array
var textures:Array

func _ready():
	clear()



func load_images(_stencil):
	stencil = _stencil
	if is_loaded: return
	clear()
	add_item("NULL")
	var dir = DirAccess.open(brush_masks_dir)
	if not dir:
		printerr("Can not open brush masks directory")
		return
	var files:Array
	dir.list_dir_begin()
	## finding files inside mask directory
	while true:
		var f = dir.get_next()
		if f == "":
			break
		files.push_back(f)
	var files_path:Array
	## Validating files path
	for f in files:
		if allowed_extension.has(f.get_extension()):
			files_path.push_back(brush_masks_dir.path_join(f))
	## Creating image and texture
	for p in files_path:
		var img = Image.load_from_file(p)
		img.convert(Image.FORMAT_RF)
		if img:
			images.push_back(img)
			textures.push_back(ImageTexture.create_from_image(img))
	## Adding items
	for tex in textures:
		add_item("",tex)
	is_loaded = true
	if images.size() > 0:
		stencil.set_mask(null,null)

func get_image():
	if images.size() == 0 : return -1
	return images[current_selected_index]

func get_texture():
	if images.size() == 0 : return -1
	return textures[current_selected_index]

func _on_item_selected(index):
	if index == 0:
		stencil.set_mask(null,null)
		return
	current_selected_index = index
	stencil.set_mask(images[index-1],textures[index-1])


