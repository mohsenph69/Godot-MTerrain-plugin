extends SceneTree

# Run from a native project with the addon installed at addons/m_terrain:
# godot --headless --path /path/to/project --script res://addons/m_terrain/tests/material_sets_smoke.gd
const MeshImport = preload("res://addons/m_terrain/asset_manager/asset_mesh_import.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	for dimensions in [Vector2i(3, 2), Vector2i(2, 3), Vector2i(1, 2)]:
		var source := ImporterMesh.new()
		for surface in dimensions.y:
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
			source.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var sets: Array = []
		for variant in dimensions.x:
			var row: Array = []
			for surface in dimensions.y:
				row.append("variant_%d_surface_%d" % [variant, surface])
			sets.append(row)
		var result := MeshImport.create(source, sets)
		if not result.ok or result.mesh.material_set_get_count() != dimensions.x or result.mesh.get_surface_count() != dimensions.y or result.material_sets != sets:
			failures.append("variant/surface counts changed: %s" % dimensions)
		for invalid in [[], null, "materials", [sets[0], []], [[42]], ["surface"]]:
			if MeshImport.create(source, invalid).ok:
				failures.append("invalid metadata accepted")
		var empty_names: Array = []
		for surface in dimensions.y:
			empty_names.append("")
		if not MeshImport.create(source, [empty_names]).ok:
			failures.append("unassigned material slot rejected")
	if MeshImport.create(null, [["material"]]).ok:
		failures.append("missing mesh accepted")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("MTERRAIN_MATERIAL_SETS_OK variants=3,2,1 surfaces=2,3,2 invalid_metadata=1")
	quit(0 if failures.is_empty() else 1)
