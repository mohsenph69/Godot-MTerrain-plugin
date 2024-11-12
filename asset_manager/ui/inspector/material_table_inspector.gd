@tool
extends HFlowContainer
var material_table: MMaterialTable = MMaterialTable.get_singleton()

func _enter_tree():		
	if EditorInterface.get_edited_scene_root() == self: return

	for id in material_table.table:			
		var texture_rect = TextureRect.new()
		add_child(texture_rect)
		var thumbnail = AssetIO.get_thumbnail(AssetIO.get_thumbnail_path(id, false))
		if thumbnail:
			texture_rect.texture = thumbnail
		else:
			AssetIO.generate_material_thumbnail(id)
			update_material_icon(texture_rect, id)
			
		
func _ready():
	if EditorInterface.get_edited_scene_root() == self: return

	if get_child_count()>1:
		$Label.queue_free()
		
func _can_drop_data(at_position: Vector2, data: Variant):
	if "files" in data:
		for file in data.files:
			var resource = load(file)
			if resource is Material:
				return true

func _drop_data(at_position: Vector2, data: Variant):
	var materials = []
	for file in data.files:
		var resource = load(file)
		if resource is Material:
			var id = material_table.find_material_id(file)
			if id == -1:
				id = material_table.add_material(file)
				var texture_rect = TextureRect.new()
				add_child(texture_rect)
				AssetIO.generate_material_thumbnail(id)
				var thumbnail = AssetIO.get_thumbnail(AssetIO.get_thumbnail_path(id, false))
				if not thumbnail:
					update_material_icon(texture_rect, id)
				else:
					texture_rect.texture = thumbnail
				
	if has_node("Label"):
		$Label.queue_free()
	notify_property_list_changed()
			#materials.push_back(resource)
	
func update_material_icon(texture_rect:TextureRect, id):
	var thumbnail = AssetIO.get_thumbnail(AssetIO.get_thumbnail_path(id, false))
	if thumbnail:				
		texture_rect.texture = thumbnail
	else:		
		await get_tree().create_timer(0.5).timeout.connect(update_material_icon.bind(texture_rect, id))
