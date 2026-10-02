@tool
extends EditorScenePostImport
# Godot 4.6.3 does not consume KHR_materials_specular. Restore only zero
# factors explicitly present on this model's two named hair materials.
# Geometry, roughness, lighting, color and Original_vertex_palette are unchanged.
func _post_import(scene: Node) -> Object:
	var f:=FileAccess.open(get_source_file(),FileAccess.READ)
	assert(f != null, "Cannot read source GLB material factors")
	assert(f.get_32()==0x46546c67, "Expected GLB")
	f.get_32()
	f.get_32()
	var length:=f.get_32()
	assert(f.get_32()==0x4e4f534a, "Expected JSON chunk")
	var data:Dictionary=JSON.parse_string(f.get_buffer(length).get_string_from_utf8())
	var names:Dictionary={}
	for m in data.get("materials",[]):
		if m.get("name","") in ["Hair_ink_brown","Hair_layer_subtle"]:
			var extension:Dictionary=m.get("extensions",{}).get("KHR_materials_specular",{})
			if extension.get("specularFactor",1.0)==0.0:names[m.name]=true
	assert(names.size()==2,"The exact two authored zero-specular hair materials must be present")
	var count:=restore(scene,names)
	scene.set_meta("hair_specular_import_restored", count)
	print("CHITANDA_HAIR_IMPORT_RESTORED ",count," surfaces from explicit KHR_materials_specular=0")
	return scene
func restore(n:Node,names:Dictionary)->int:
	var count:=0
	if n is MeshInstance3D:
		for i in n.mesh.get_surface_count():
			var m=n.get_active_material(i)
			if m is StandardMaterial3D and names.has(m.resource_name):
				m=m.duplicate()
				m.metallic_specular=0.0
				n.set_surface_override_material(i,m)
				count+=1
	for child in n.get_children():count+=restore(child,names)
	return count
