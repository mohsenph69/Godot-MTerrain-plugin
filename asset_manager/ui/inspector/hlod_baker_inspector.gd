@tool
extends VBoxContainer

var object

func _ready():	
	$Bake.pressed.connect(object.bake_to_hlod_resource)		
	$Join.pressed.connect(object.make_joined_mesh)
	if object.has_meta("glb"):
		$Export.disabled = false
		var path = object.get_meta("glb")
		print(path)
		$Export.pressed.connect(AssetIO.glb_export.bind(object, path))
	else:
		$Export.disabled = true
