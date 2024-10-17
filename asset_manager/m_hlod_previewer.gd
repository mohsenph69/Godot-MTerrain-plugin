@tool 
extends MHlodScene
var timer: Timer
var asset_mesh_updater: MAssetMeshUpdater

func _enter_tree():
	asset_mesh_updater = MAssetMeshUpdater.new()	
	asset_mesh_updater.set_root_node(self)
	timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(update_lod)
	timer.start(1)
	for child in get_children():
		if child is Node3D:
			child.owner = self

func update_lod():	
	asset_mesh_updater.update_auto_lod()		
	
func _exit_tree():
	timer.queue_free()
