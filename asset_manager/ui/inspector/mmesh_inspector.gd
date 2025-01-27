@tool
extends Control

var mmesh:MMesh

func _ready():
	var _rp = EditorInterface.get_resource_previewer()			
	_rp.queue_edited_resource_preview(mmesh.get_mesh(),self,"handle_generate_thumbnail",null)

func handle_generate_thumbnail(path, preview, thumbnail_preview,data):	
	%mmesh_thumbnail.texture = preview
