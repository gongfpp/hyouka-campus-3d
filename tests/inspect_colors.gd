extends SceneTree
func _initialize():
	for id in ["chitanda","oreki"]:
		var model = load("res://assets/characters/%s.glb" % id).instantiate()
		inspect(model,id)
		model.free()
	quit()
func inspect(node: Node,id: String):
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat = node.get_active_material(i)
			var colors = node.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
			var unique = {}
			for c in colors: unique[str(c)] = true
			print("MATERIAL ",id," ",mat.resource_name," albedo=",mat.albedo_color," use_vc=",mat.vertex_color_use_as_albedo," srgb=",mat.vertex_color_is_srgb," unique=",unique.keys())
	for c in node.get_children(): inspect(c,id)
