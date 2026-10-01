extends SceneTree
const Palette = preload("res://scripts/character_palette.gd")
var viewports: Array[SubViewport] = []
var chips: Array[SubViewport] = []
var base := "res://artifacts/ui-redesign/final/"
func _initialize(): call_deferred("run")
func viewport() -> SubViewport:
	var v := SubViewport.new()
	v.own_world_3d = true
	v.size = Vector2i(480,480)
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(v)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("d6d7ce")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.6
	environment.environment = settings
	v.add_child(environment)
	var camera := Camera3D.new()
	camera.name = "ColorTestCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.4
	camera.position = Vector3(0,0.8,3)
	v.add_child(camera)
	return v
func run():
	DirAccess.make_dir_recursive_absolute(base)
	var panel := HBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)
	for corrected in [false,true]:
		var v := viewport()
		var model = load("res://assets/characters/chitanda.glb").instantiate()
		model.rotation_degrees.y = 168
		if corrected: Palette.apply(model)
		v.add_child(model)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-25,-25,0)
		light.light_color = Color.WHITE
		light.light_energy = 0.65
		v.add_child(light)
		viewports.append(v)
		var image := TextureRect.new()
		image.texture = v.get_texture()
		panel.add_child(image)
		var chip := viewport()
		chip.size = Vector2i(300,100)
		chip.get_node("ColorTestCamera").position = Vector3(0,0,3)
		chip.get_node("ColorTestCamera").size = 1.0
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-2,-1,0),Vector3(2,-1,0),Vector3(2,1,0),Vector3(-2,1,0)])
		var color := Color(0.90980392,0.5372549,0.32941176)
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray([color,color,color,color])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,2,1,0,3,2])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var surface := MeshInstance3D.new()
		surface.mesh = mesh
		if corrected:
			var shader := Shader.new()
			shader.code = Palette.PALETTE_SHADER.code.replace("render_mode blend_mix,","render_mode unshaded, blend_mix,")
			var material := ShaderMaterial.new()
			material.shader = shader
			surface.material_override = material
		else:
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.vertex_color_use_as_albedo = true
			surface.material_override = material
		chip.add_child(surface)
		chips.append(chip)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var report := {"renderer":RenderingServer.get_current_rendering_method(),"linear_source":[0.90980392,0.5372549,0.32941176],"original":[],"corrected":[]}
	for i in 2:
		var image := viewports[i].get_texture().get_image()
		image.save_png(base + ("color-corrected-neutral.png" if i else "color-original-neutral.png"))
		var chip := chips[i].get_texture().get_image()
		chip.save_png(base + ("chip-corrected.png" if i else "chip-original.png"))
		var pixel := chip.get_pixel(150,50)
		report["corrected" if i else "original"] = [pixel.r,pixel.g,pixel.b]
	print("COLOR_READBACK ",JSON.stringify(report))
	var file := FileAccess.open(base + "color-readback.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	quit()
