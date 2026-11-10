extends RefCounted

## GLB material sets are rows of surface names: [variant][surface]. Validate
## the complete metadata before constructing the native authoring resource.
static func create(mesh: ImporterMesh, raw_sets: Variant) -> Dictionary:
	if mesh == null or mesh.get_surface_count() == 0:
		return {"ok": false, "error": "missing_mesh_surfaces"}
	if not raw_sets is Array or raw_sets.is_empty():
		return {"ok": false, "error": "missing_material_sets"}
	var sets: Array = []
	for row in raw_sets:
		if not (row is Array or row is PackedStringArray) or row.size() != mesh.get_surface_count():
			return {"ok": false, "error": "material_set_surface_count"}
		var names: Array = []
		for name in row:
			if not name is String:
				return {"ok": false, "error": "material_name_type"}
			names.append(name)
		sets.append(names)
	var imported := MMesh.new()
	imported.create_from_mesh(mesh.get_mesh())
	imported.material_set_resize(sets.size())
	return {"ok": true, "mesh": imported, "material_sets": sets}
