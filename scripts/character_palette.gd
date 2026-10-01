extends RefCounted
## Preserve glTF source bytes and palette values; correct only the renderer boundary.
const PALETTE_SHADER = preload("res://shaders/character_palette.gdshader")
static func apply(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var source = node.get_active_material(surface)
			if source is StandardMaterial3D and source.resource_name == "Original_vertex_palette" and source.vertex_color_use_as_albedo:
				var material := ShaderMaterial.new()
				material.resource_name = "Original_vertex_palette_color_space_corrected"
				material.shader = PALETTE_SHADER
				material.set_shader_parameter("palette_roughness",source.roughness)
				material.set_shader_parameter("palette_metallic",source.metallic)
				material.set_shader_parameter("palette_specular",source.metallic_specular)
				node.set_surface_override_material(surface,material)
	for child in node.get_children(): apply(child)
