@tool
extends EditorPlugin

var importer

func _enter_tree() -> void:
	
	
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	GLTFDocument.unregister_gltf_document_extension(importer)
	pass		
