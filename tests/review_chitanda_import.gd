extends SceneTree
## Must pass from a clean checkout: no reliance on a developer's imported cache.
var failures: Array[String] = []
var hair_count := 0
var palette_count := 0
var textured_count := 0
var skeleton_count := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	print("CHITANDA_CHECK ","PASS " if ok else "FAIL ",title)
	if not ok: failures.append(title)
func inspect(node: Node):
	if node is Skeleton3D:
		skeleton_count += 1
		check(node.get_bone_count() == 17,"17 authored bones")
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var material = node.get_active_material(index)
			if material is StandardMaterial3D:
				if material.resource_name in ["Hair_ink_brown","Hair_layer_subtle"]:
					hair_count += 1
					check(is_zero_approx(material.metallic_specular),"authored zero hair specular: " + str(node.name))
				if material.resource_name == "Original_vertex_palette":
					palette_count += 1
					check(material.vertex_color_use_as_albedo,"body retains vertex palette")
				if material.albedo_texture != null or material.emission_texture != null:
					textured_count += 1
					check(not material.vertex_color_use_as_albedo,"UV texture uses no vertex-color tint: " + material.resource_name)
	for child in node.get_children(): inspect(child)
func run():
	var config := ConfigFile.new()
	check(config.load("res://assets/characters/chitanda.glb.import") == OK,"tracked import descriptor exists")
	check(config.get_value("params","import_script/path","") == "res://scripts/chitanda_hair_import.gd","source descriptor binds hair adapter")
	check(config.get_value("params","gltf/embedded_image_handling",-1) == 3,"lossless textures stay embedded")
	var model = load("res://assets/characters/chitanda.glb").instantiate()
	root.add_child(model)
	check(model.get_meta("hair_specular_import_restored",0) == 27,"post-import adapter ran on all 27 hair surfaces")
	inspect(model)
	check(hair_count == 27,"exactly 27 zero-specular hair surfaces")
	check(skeleton_count == 1,"one skeleton")
	check(palette_count > 0,"legacy body palette exists")
	check(textured_count >= 3,"skin and both iris textures present")
	var animators = model.find_children("*","AnimationPlayer",true,false)
	check(animators.size() == 1,"one animation player")
	if animators.size() == 1:
		var animator = animators[0]
		var expected := {"idle":73.0/30.0,"walk":33.0/30.0,"run":25.0/30.0}
		var found := {}
		for name in animator.get_animation_list():
			for motion in expected:
				if name.to_lower().ends_with(motion):
					found[motion] = animator.get_animation(name).length
					print("CHITANDA_ANIMATION ",name," length=",found[motion])
					check(absf(found[motion]-expected[motion]) < 0.00001,"authored duration " + motion)
		check(found.size() == 3,"idle/walk/run are importable")
	preload("res://scripts/character_palette.gd").apply(model)
	var corrected := 0
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(i)
			if material is ShaderMaterial and material.resource_name == "Original_vertex_palette_color_space_corrected": corrected += 1
	check(corrected == palette_count,"existing color-space correction still reaches every body surface")
	print("CHITANDA_IMPORT_FAILURES ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
