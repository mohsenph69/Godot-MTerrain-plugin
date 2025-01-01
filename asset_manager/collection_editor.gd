@tool
extends Node3D
var asset_mesh_updater: MAssetMeshUpdater
var timer: Timer
func _notification(what: int):
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		for child in get_children():												
			child.owner = null
	if what == NOTIFICATION_EDITOR_POST_SAVE:
		for child in get_children():
			child.owner = self	
		
func _enter_tree():
	asset_mesh_updater = MAssetMeshUpdater.new()	
	asset_mesh_updater.set_root_node(self)
	timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(update_lod)
	timer.start(2)

func update_lod():	
	asset_mesh_updater.update_auto_lod()		
	
func _exit_tree():
	timer.queue_free()
