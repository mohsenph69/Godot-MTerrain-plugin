@tool
extends Node3D

func _notification(what: int):
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		for child in get_children():			
			if child.has_meta("collection_id"):
				AssetIO.collection_save_from_nodes(child)
			child.owner = null
	if what == NOTIFICATION_EDITOR_POST_SAVE:
		for child in get_children():
			child.owner = self	
		
			
