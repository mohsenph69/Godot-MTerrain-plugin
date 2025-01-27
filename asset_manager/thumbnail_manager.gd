class_name ThumbnailManager extends Node

static var thumbnail_queue := [] # {resource, caller, callback}
static var generating_thumbnail := false
func _process(delta):
	if len(thumbnail_queue)==0: return
	if generating_thumbnail:
		return
	var data = thumbnail_queue.pop_back()			
	var _rp = EditorInterface.get_resource_previewer()		
	generating_thumbnail = true
	_rp.queue_edited_resource_preview(data.resource,self,"handle_generate_thumbnail",data)
	
func handle_generate_thumbnail(path, preview, thumbnail_preview,data):				
	data["texture"] = preview	
	data.callback.call(data)	
	generating_thumbnail = false
	
	
