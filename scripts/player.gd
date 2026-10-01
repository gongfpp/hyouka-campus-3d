extends CharacterBody3D

var yaw := 0.0
var pitch := -0.16
var distance := 3.6
var enabled := false
var visual: Node3D
var pivot: Node3D
var camera: Camera3D
var animators: Array[AnimationPlayer] = []
var current_motion := ""
var model_id := ""
var override_move := Vector2.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.18
	capsule.height = 1.35
	shape.shape = capsule
	shape.position.y = 0.685
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	pivot = Node3D.new()
	add_child(pivot)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.fov = 65
	camera.current = true
	pivot.add_child(camera)

func set_character(id: String) -> bool:
	for child in visual.get_children():
		visual.remove_child(child)
		child.queue_free()
	animators.clear()
	model_id = id
	var path := "res://assets/characters/%s.glb" % id
	var ready := ResourceLoader.exists(path)
	if ready:
		var model: Node3D = load(path).instantiate()
		model.rotation.y = 0
		visual.add_child(model)
		_find_animators(model)
	else:
		# Honest development marker; replaced by supplied character GLBs.
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.18
		capsule.height = 1.35
		mesh.mesh = capsule
		mesh.position.y = 0.685
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("b7ccad")
		mesh.material_override = mat
		visual.add_child(mesh)
	current_motion = ""
	return ready

func _find_animators(node: Node) -> void:
	if node is AnimationPlayer:
		animators.append(node)
	for child in node.get_children():
		_find_animators(child)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -0.9, 0.55)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(1.3, distance - 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(6.5, distance + 0.3)

func _physics_process(delta: float) -> void:
	var axis := Input.get_vector("left", "right", "forward", "back") if enabled else Vector2.ZERO
	if override_move != Vector2.ZERO:
		axis = override_move
	var running := Input.is_action_pressed("run") and enabled
	var movement := Basis(Vector3.UP, yaw) * Vector3(axis.x, 0, axis.y)
	var speed := 5.8 if running else 2.8
	velocity.x = move_toward(velocity.x, movement.x * speed, delta * 20)
	velocity.z = move_toward(velocity.z, movement.z * speed, delta * 20)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.1
	# Small curbs (<= 0.26 m), never desks or full-height walls.
	var horizontal := Vector3(velocity.x,0,velocity.z) * delta
	if is_on_floor() and horizontal.length() > 0.001 and test_move(global_transform,horizontal):
		var raised := global_transform
		raised.origin.y += 0.26
		if not test_move(global_transform,Vector3(0,0.26,0)) and not test_move(raised,horizontal.normalized() * 0.28):
			var ahead := raised.origin + horizontal.normalized() * 0.28
			var ray := PhysicsRayQueryParameters3D.create(ahead + Vector3(0,0.05,0),ahead - Vector3(0,0.32,0),1)
			var step := get_world_3d().direct_space_state.intersect_ray(ray)
			if not step.is_empty() and step.normal.y > 0.8:
				global_position.y = maxf(global_position.y,float(step.position.y) + 0.025)
	move_and_slide()
	if movement.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-movement.x, -movement.z), delta * 12)
	var motion := "idle" if movement.length() < 0.1 else ("run" if running else "walk")
	if motion != current_motion:
		current_motion = motion
		for animator in animators:
			for name in animator.get_animation_list():
				if name.to_lower().ends_with(motion):
					animator.get_animation(name).loop_mode = Animation.LOOP_LINEAR
					animator.play(name, 0.16)
	_update_camera()

func _update_camera() -> void:
	pivot.global_position = global_position + Vector3(0, 1.10, 0)
	pivot.rotation = Vector3(pitch, yaw, 0)
	var target := pivot.global_position + pivot.global_basis.z * distance
	var effective := distance
	# Five parallel rays approximate the near frustum so door jambs cannot frame a slit.
	for offset in [Vector3.ZERO,pivot.global_basis.x * 0.38,-pivot.global_basis.x * 0.38,Vector3.UP * 0.22,-Vector3.UP * 0.22]:
		var query := PhysicsRayQueryParameters3D.create(pivot.global_position + offset, target + offset, 5)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			effective = minf(effective,maxf(0.18,(pivot.global_position + offset).distance_to(hit.position) - 0.2))
	camera.position = Vector3(0, 0, effective)
	visual.visible = effective > 1.15
