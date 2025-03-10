@tool
extends PanelContainer

@onready var add_baker_button:Button = find_child("add_baker_button")
@onready var add_decal_button:Button = find_child("add_decal_button")
@onready var add_packed_scene_button:Button = find_child("add_packed_scene_button")

func _ready():	
	
	add_baker_button.pressed.connect(func():
		AssetIOBaker.create_baker_scene()
		AssetIO.asset_placer.add_asset_finished(false)		
	)
	add_packed_scene_button.pressed.connect(func():
		AssetIO.create_packed_scene()
		AssetIO.asset_placer.add_asset_finished()		
	)
	add_decal_button.pressed.connect(func():
		var decal = AssetIO.create_decal()		
		AssetIO.asset_placer.assets_changed.emit( decal )
		AssetIO.asset_placer.add_asset_finished()				
	)
