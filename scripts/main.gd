extends Node3D

const Player = preload("res://scripts/player.gd")
const EditorialUI = preload("res://scripts/editorial_ui.gd")
const Telemetry = preload("res://scripts/telemetry.gd")
const CHARACTERS := {"oreki":"折木奉太郎", "chitanda":"千反田爱瑠", "satoshi":"福部里志", "mayaka":"伊原摩耶花"}
const SCENES := {
	"yard": {"title":"神山高校 · 放课后", "subtitle":"沿操场向北，走入特别栋", "visual":"Hyouka_Schoolyard_VIS.glb", "collision":"Hyouka_Schoolyard_COLLISION.glb", "spawn":Vector3(0, 0.2, 15)},
	"corridor": {"title":"特别栋 · 走廊", "subtitle":"教室、部室与楼梯之间", "visual":"corridor_v2_visual.glb", "collision":"corridor_v2_collision.glb", "spawn":Vector3(0, 0.08, 6.25)},
	"class": {"title":"普通教室", "subtitle":"空下来的座位，留下了下午的光", "visual":"class_v2_visual.glb", "collision":"class_v2_collision.glb", "spawn":Vector3(3.45, 0.08, -3.12)},
	"club": {"title":"地学准备室 · 古典部", "subtitle":"在安静的桌边，留意微小的线索", "visual":"club_v2_visual.glb", "collision":"club_v2_collision.glb", "spawn":Vector3(1.1, 0.08, 2.72)},
	"chitanda": {"title":"千反田家", "subtitle":"榻榻米、缘侧与庭院", "visual":"chitanda_visual.glb", "collision":"chitanda_collision.glb", "spawn":Vector3(0, 0.18, 11)},
	"oreki": {"title":"折木家", "subtitle":"街边住宅与日常的客厅", "visual":"oreki_visual.glb", "collision":"oreki_collision.glb", "spawn":Vector3(2.8, 0.18, 7)}
}
var world: Node3D
var player: CharacterBody3D
var scene_id := "yard"
var character_id := "oreki"
var visited: Array = []
var observed: Array = []
var points: Array[Dictionary] = []
var telemetry = Telemetry.new()
var ui: EditorialUI
var header: Label
var subheader: Label
var status: Label
var prompt: Label
var panel: PanelContainer
var panel_box: VBoxContainer
var loading: Label
var nearest := -1
var started := false
var panel_open := true
var modal_kind := "menu"
var modal_parent := "resume"
var save_timer := 0.0
var scene_age := 0.0
var font: Font
var last_safe := Vector3.ZERO
var materials := 0
var labels_3d: Array[Label3D] = []
var sand_texture: NoiseTexture2D
var smoke_mode := false
var saved_position: Variant = null

func _ready() -> void:
	if "--ui-review" in OS.get_cmdline_user_args():
		get_window().title = "HYOUKA / Editorial UI Review"
	for entry in [["forward",KEY_W],["back",KEY_S],["left",KEY_A],["right",KEY_D],["run",KEY_SHIFT],["interact",KEY_E],["menu",KEY_ESCAPE],["journal",KEY_J],["characters",KEY_C],["hints",KEY_H]]:
		if not InputMap.has_action(entry[0]):
			InputMap.add_action(entry[0])
			var event := InputEventKey.new()
			event.physical_keycode = entry[1]
			InputMap.action_add_event(entry[0], event)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	sand_texture = NoiseTexture2D.new()
	sand_texture.width = 256
	sand_texture.height = 256
	sand_texture.seamless = true
	sand_texture.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0,Color(0.67,0.65,0.59))
	ramp.set_color(1,Color(1,0.98,0.89))
	sand_texture.color_ramp = ramp
	font = load("res://assets/fonts/KamiyamaSans.otf")
	_build_light()
	player = Player.new()
	add_child(player)
	_build_ui()
	_load_save()
	_load_scene(scene_id, saved_position)
	player.set_character(character_id)
	_show_start()
	if "--smoke" in OS.get_cmdline_user_args():
		smoke_mode = true
		_run_smoke.call_deferred()
	if "--capture-tour" in OS.get_cmdline_user_args():
		smoke_mode = true
		_capture_tour.call_deferred()

func _build_light() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("81a8c2")
	sky_mat.sky_horizon_color = Color("e2e5db")
	sky_mat.ground_horizon_color = Color("dbdccb")
	sky_mat.ground_bottom_color = Color("899776")
	sky.sky_material = sky_mat
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("e5e8e0")
	settings.ambient_light_energy = 0.30
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color("fff0d6")
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)

func _load_scene(id: String, custom_spawn: Variant = null) -> void:
	if not SCENES.has(id):
		id = "yard"
	scene_id = id
	points.clear()
	labels_3d.clear()
	nearest = -1
	if world:
		remove_child(world)
		world.queue_free()
	world = Node3D.new()
	world.name = "Environment"
	add_child(world)
	var data: Dictionary = SCENES[id]
	for mode in ["visual", "collision"]:
		var path: String = "res://assets/environments/" + data[mode]
		if not ResourceLoader.exists(path):
			telemetry.record("load_error", {"scene":id, "asset":mode})
			continue
		var root: Node3D = load(path).instantiate()
		world.add_child(root)
		if mode == "collision":
			_collision(root)
		else:
			_tune_materials(root)
	if id != "yard":
		var fill := OmniLight3D.new()
		fill.position = Vector3(0, 2.4, 0)
		fill.light_color = Color("fff4df")
		fill.light_energy = 0.4
		fill.omni_range = 14
		world.add_child(fill)
	_setup_points(id)
	player.global_position = custom_spawn if custom_spawn is Vector3 else data.spawn
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	if id == "class":
		player.yaw = PI / 2
	player.pitch = -0.16
	player.distance = 3.6 if id in ["yard", "chitanda", "oreki"] else 2.3
	last_safe = data.spawn
	if custom_spawn is Vector3:
		_validate_spawn.call_deferred(id)
	scene_age = 0
	if not visited.has(id):
		visited.append(id)
	header.text = data.title
	subheader.text = data.subtitle
	telemetry.record("scene_enter", {"scene":id})
	_update_status()

func _validate_spawn(expected_scene: String) -> void:
	await get_tree().physics_frame
	if scene_id != expected_scene:
		return
	var candidate := player.global_position
	var query := PhysicsRayQueryParameters3D.create(candidate + Vector3(0,0.35,0), candidate - Vector3(0,0.5,0),1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.5:
		player.global_position = SCENES[scene_id].spawn
		player.velocity = Vector3.ZERO
		telemetry.record("restore_recovery", {"scene":scene_id})

func _collision(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		node.create_trimesh_collision()
		node.visible = false
	for child in node.get_children():
		_collision(child)

func _tune_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		# Camera-only geometry closes gaps in intentionally simplified movement colliders.
		var camera_body := StaticBody3D.new()
		camera_body.collision_layer = 4
		camera_body.collision_mask = 0
		var camera_shape := CollisionShape3D.new()
		camera_shape.shape = node.mesh.create_trimesh_shape()
		camera_body.add_child(camera_shape)
		node.add_child(camera_body)
		for index in node.mesh.get_surface_count():
			var material = node.get_active_material(index)
			if material is StandardMaterial3D:
				var name_lower: String = material.resource_name.to_lower()
				var tones := {"olive linoleum":Color("687057"),"dark walnut":Color("554132"),"honey birch":Color("ad8753"),"aged red walnut":Color("755445"),"teaching globe":Color("548a94"),"house_earth":Color("8d8871"),"house_stone":Color("929381"),"house_wood":Color("786147"),"house_tatami":Color("a7ab77"),"house_darkwood":Color("493d32"),"house_plaster":Color("d0cdb8"),"house_paper":Color("d6d4b9"),"house_lightwood":Color("aa8a5c"),"house_tile":Color("67726b"),"house_concrete":Color("979d90")}
				for key in tones:
					if name_lower.contains(key):
						material.albedo_color = tones[key]
						break
				if name_lower.contains("compacted_sand"):
					material.albedo_color = Color("a89870")
					material.albedo_texture = sand_texture
					material.uv1_triplanar = true
					material.uv1_scale = Vector3(0.25,0.25,0.25)
				material.roughness = maxf(material.roughness, 0.65)
				material.metallic = minf(material.metallic, 0.25)
				materials += 1
	for child in node.get_children():
		_tune_materials(child)

func _point(id: String, title: String, position: Vector3, text: String, destination := "", arrival: Variant = null, radius := 1.9) -> void:
	points.append({"id":id,"title":title,"position":position,"text":text,"destination":destination,"arrival":arrival,"radius":radius})
	var marker := Label3D.new()
	marker.text = ("◇ " if destination.is_empty() else "↗ ") + title
	marker.font = font
	marker.font_size = 38
	marker.pixel_size = 0.0035
	marker.position = position + Vector3(0, 1.7, 0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = false
	marker.modulate = Color("fff1c7") if destination.is_empty() else Color("c8f6e6")
	marker.outline_size = 10
	world.add_child(marker)
	labels_3d.append(marker)

func _barrier(position: Vector3, size: Vector3, visible_panel := false) -> void:
	var body := StaticBody3D.new()
	body.position = position
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	world.add_child(body)
	if visible_panel:
		var mesh := MeshInstance3D.new()
		var surface := BoxMesh.new()
		surface.size = size
		mesh.mesh = surface
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("7b8d82")
		material.roughness = 0.9
		mesh.material_override = material
		body.add_child(mesh)

func _setup_points(id: String) -> void:
	match id:
		"yard":
			_point("school_gate", "进入教学楼", Vector3(0,0,-43.0), "", "corridor", null, 4.0)
			_point("offsite", "放课后出校", Vector3(-61,0,30), "选择校外目的地。两处住宅属于独立场景；与校园的交通连接为游玩设计。", "travel", null, 5.0)
			_point("yard_track", "操场边线", Vector3(0,0,12), "白线把一大片空地分成了不同的节奏。放课后的操场安静下来，教室窗户仍映着天光。", "", null, 4.0)
			_point("yard_facade", "校舍窗格", Vector3(-18,0,-41), "重复的窗格让校舍显得很长。往入口走，可以到达走廊，再寻找普通教室与地学准备室。", "", null, 4.0)
			# Invisible safety perimeter sits at the edge of the supplied grounds.
			_barrier(Vector3(80,4,-25),Vector3(1,10,230))
			_barrier(Vector3(-85,4,-25),Vector3(1,10,230))
			_barrier(Vector3(0,4,70),Vector3(180,10,1))
			_barrier(Vector3(0,4,-110),Vector3(180,10,1))
		"corridor":
			_point("yard_return", "返回操场", Vector3(0,0,7.2), "", "yard", Vector3(0,0.2,-40))
			_point("class_door", "普通教室", Vector3(-1.08,0,-4.85), "", "class", null, 1.25)
			_point("club_door", "地学准备室", Vector3(1.08,0,-4.85), "", "club", null, 1.25)
			_point("notice", "走廊公告", Vector3(0,0,1.5), "公告栏上的纸张整齐又略显陈旧。通向教室、部室的连接和这段楼梯，是根据场景观感补足的可玩区域。")
			_point("landing", "楼梯平台", Vector3(0.48,2.82,-11.1), "登上平台，走廊的长度才显现出来。上层未展示的教室尚未开放；原路下楼即可返回。")
			# Close asset door voids behind interaction thresholds; E handles transitions.
			_barrier(Vector3(-1.52,1.5,-4.85),Vector3(0.12,3,2.0),true)
			_barrier(Vector3(1.52,1.5,-4.85),Vector3(0.12,3,2.0),true)
			_barrier(Vector3(0,4,-12),Vector3(3,4,0.2),true)
		"class":
			_point("class_exit", "返回走廊", Vector3(3.6,0,-3.12), "", "corridor", Vector3(-0.65,0.1,-4.0), 1.15)
			_point("blackboard", "黑板与讲台", Vector3(-1.4,0,-3.6), "擦过的黑板留着浅浅的粉痕。站在讲台边望过去，每排桌椅都像一条重复却不完全相同的线。")
			_point("window", "窗边座位", Vector3(-3.5,0,0), "窗边能看见校园的另一种轮廓。这里没有待完成的课题，只有值得慢慢观察的光与木纹。", "", null, 1.25)
			_barrier(Vector3(4.18,1.5,-3.12),Vector3(0.12,3,1.8),true)
			_barrier(Vector3(4.18,1.5,3.12),Vector3(0.12,3,1.8),true)
		"club":
			_point("club_exit", "返回走廊", Vector3(1.08,0,3.05), "", "corridor", Vector3(0.65,0.1,-4.0), 1.1)
			_point("anthology", "桌上的文集", Vector3(0.2,0,0.7), "旧纸页有一种安静的重量。桌面上的物件只提供观察：这个原型还没有实现推理主线。", "", null, 1.4)
			_point("specimens", "标本与书柜", Vector3(-1.5,0,-2.5), "地学准备室原本的用途仍留在角落：标本、标签和排成一列的书。古典部的日常就发生在这些物件之间。", "", null, 1.5)
			_barrier(Vector3(1.1,1.5,3.6),Vector3(1.5,3,0.12),true)
		"chitanda":
			_point("chitanda_return", "返回校园", Vector3(0,0,10.5), "", "yard", Vector3(-60,0.2,28), 2.8)
			_point("tatami", "榻榻米与茶席", Vector3(1.5,0.5,3), "格栅、木梁与榻榻米让房间显得格外安静。茶席与庭院依动画展示区域制作，未展示的完整宅邸没有在此复原。", "", null, 2.0)
			_point("garden", "缘侧的庭院", Vector3(4,0.1,4.8), "从缘侧望向庭院，石、树和水面层层叠在一起。沿开放的障子门可以回到茶席。", "", null, 2.2)
		"oreki":
			_point("oreki_return", "返回校园", Vector3(2.8,0,6.5), "", "yard", Vector3(-60,0.2,28), 2.2)
			_point("living", "客厅茶几", Vector3(2.1,0.4,0.7), "沙发、遥控器和茶几让这里像一个被暂时按下暂停键的下午。住宅内部连接依据可玩性推定。", "", null, 1.8)
			_point("kitchen", "餐厨一角", Vector3(-3.5,0.4,1.5), "从客厅穿过开口，可以走到餐厨区域。楼上的房间未开放，外观并不意味着每扇窗后都能进入。", "", null, 1.8)

func _build_ui() -> void:
	ui = EditorialUI.new()
	add_child(ui)
	ui.setup(font, _back)
	header = ui.header
	subheader = ui.subheader
	status = ui.status
	prompt = ui.prompt
	panel = ui.panel
	panel_box = ui.panel_box

func _clear_panel(title: String, description: String, kind := "page", parent := "resume") -> void:
	panel_open = true
	modal_kind = kind
	modal_parent = parent
	player.enabled = false
	player.velocity = Vector3.ZERO
	# Freeze physics AND animation, while the UI and character-card viewports stay live.
	player._update_camera()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.present(title,description,kind)
	ui.close_button.visible = kind != "menu" or started

func _button(text: String, callback: Callable, primary := false) -> Button:
	return ui.add_button(text,callback,primary)

func _back() -> void:
	if not panel_open:
		_show_start()
	elif modal_kind == "menu":
		if started: _resume()
	elif modal_parent == "menu":
		_show_start()
	else:
		_resume()

func _submenu_parent() -> String:
	return "menu" if panel_open and modal_kind == "menu" else "resume"

func _show_start() -> void:
	_clear_panel("冰菓", "放课后的神山\nAFTER SCHOOL IN KAMIYAMA", "menu")
	panel_box.add_child(ui.separator())
	panel_box.add_child(ui.paragraph("把脚步放慢一些。\n在熟悉的校园里，留意微小的不同。",16))
	_button("继续探索  →" if started or visited.size() > 1 or observed.size() > 0 else "走进放课后的校园  →", _resume, true)
	_button("同行者    /    " + CHARACTERS[character_id], _show_characters)
	_button("观察手记    /    %02d 处记录" % observed.size(), _show_journal)
	var utilities := HBoxContainer.new()
	utilities.add_theme_constant_override("separation",8)
	panel_box.add_child(utilities)
	var about: Button = ui.add_button("关于与操作",_show_about,false,utilities)
	about.theme_type_variation = "QuietButton"
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reset: Button = ui.add_button("重新开始",_confirm_reset,false,utilities)
	reset.theme_type_variation = "QuietButton"
	ui.add_note("非官方同人探索原型\n六处场景 · 四位同行者 · 进度仅保存在此设备")
	ui.focus_first()

func _resume() -> void:
	started = true
	panel_open = false
	modal_kind = ""
	ui.dismiss()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_save()

func _show_characters() -> void:
	var parent := _submenu_parent()
	if panel_open and modal_kind == "characters":
		_back()
		return
	_clear_panel("选择同行者", "同一段放课后，换一个同行的身影。切换保留当前位置与观察手记。", "characters", parent)
	ui.add_character_cards(CHARACTERS,character_id,func(id: String):
		character_id = id
		player.set_character(id)
		telemetry.record("character_select", {"character":id})
		_update_status()
		_resume())
	ui.add_note("头像直接渲染当前游戏角色模型。Tab / 方向键选择，Enter 确认，Esc 返回。")
	ui.focus_first()

func _show_journal() -> void:
	var parent := _submenu_parent()
	if panel_open and modal_kind == "journal":
		_back()
		return
	_clear_panel("观察手记", "到访 %02d / 06    ·    观察 %02d 处" % [visited.size(),observed.size()], "journal", parent)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",24)
	grid.add_theme_constant_override("v_separation",8)
	panel_box.add_child(grid)
	var index := 0
	for id in SCENES:
		index += 1
		var row := VBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(row)
		row.add_child(ui.label("%02d    %s" % [index,"已到访" if visited.has(id) else "尚未到访"],11,EditorialUI.MUTED))
		row.add_child(ui.label(SCENES[id].title,17,EditorialUI.INK if visited.has(id) else EditorialUI.MUTED))
		row.add_child(ui.separator())
	panel_box.add_child(ui.label("校园里的路线",18,EditorialUI.INK))
	panel_box.add_child(ui.paragraph("操场北侧入口 → 走廊 → 普通教室 / 地学准备室\n操场西南「放课后出校」→ 两处住宅\n靠近地点标记后按 E；楼梯可登至平台。",14))
	if observed.is_empty():
		panel_box.add_child(ui.paragraph("手记还是空白的。靠近场景里的观察点，按 E 留下第一条记录。",14))
	else:
		panel_box.add_child(ui.label("已收录的片段",18,EditorialUI.INK))
		# The existing save contains observation IDs. Display their existing titles without new state.
		var names := {"yard_track":"操场边线","yard_facade":"校舍窗格","notice":"走廊公告","landing":"楼梯平台","blackboard":"黑板与讲台","window":"窗边座位","anthology":"桌上的文集","specimens":"标本与书柜","tatami":"榻榻米与茶席","garden":"缘侧的庭院","living":"客厅茶几","kitchen":"餐厨一角"}
		var titles: PackedStringArray = []
		for id in observed:
			if names.has(id): titles.append(names[id])
		panel_box.add_child(ui.paragraph("  /  ".join(titles),14))
	_button("返回菜单" if parent == "menu" else "合上手记，继续探索  →",_back,true)
	ui.focus_first()

func _show_about() -> void:
	_clear_panel("慢慢走，仔细看", "关于这个放课后", "about", "menu")
	panel_box.add_child(ui.label("操作",20,EditorialUI.INK))
	panel_box.add_child(ui.paragraph("WASD 移动 · Shift 奔跑 · 鼠标转视角 · 滚轮调整镜头\nE 观察 / 进入 · J 手记 · C 同行者 · Esc 菜单 / 返回\nH 展开或收起操作提示 · Tab / 方向键选择 · Enter 确认",15))
	panel_box.add_child(ui.separator())
	panel_box.add_child(ui.paragraph("校园和住宅为独立场景。六处场景以动画画面为视觉依据；完整连接、楼梯与隐蔽区域为可玩性推定，并非全校园一比一复刻。未开放区域不可探索，尚未制作推理主线。",15))
	panel_box.add_child(ui.paragraph("自动保存在此设备。埋点仅保留最近 200 条角色、场景、互动和加载错误事件，不记录身份或坐标，不上传任何服务器。",15))
	panel_box.add_child(ui.paragraph("本项目为非官方同人研究原型。原作及角色权利归各权利方所有。",13))
	_button("返回菜单", _show_start, true)
	_button("清空本地事件记录", func(): telemetry.clear(); _show_start())
	ui.focus_first()

func _confirm_reset() -> void:
	_clear_panel("重新开始？", "将清空本设备的探索进度。角色选择保留。", "reset", "menu")
	_button("保留进度，返回菜单",_show_start,true)
	_button("确认重新开始", func():
		visited.clear()
		observed.clear()
		_load_scene("yard")
		_resume())
	ui.focus_first()

func _travel() -> void:
	_clear_panel("放课后的去处", "选择校外目的地。住宅入口附近可返回校园。", "travel")
	_button("01    拜访千反田家", func(): _load_scene("chitanda"); _resume(),true)
	_button("02    拜访折木家", func(): _load_scene("oreki"); _resume())
	_button("留在校园", _resume)
	ui.focus_first()

func _interact() -> void:
	if nearest < 0 or nearest >= points.size():
		return
	var point: Dictionary = points[nearest]
	telemetry.record("interaction", {"scene":scene_id,"point":point.id})
	if point.destination == "travel":
		_travel()
	elif not point.destination.is_empty():
		_load_scene(point.destination,point.arrival)
		_save()
	else:
		if not observed.has(point.id):
			observed.append(point.id)
		_update_status()
		_clear_panel(point.title, "观察记录  /  " + SCENES[scene_id].title, "observation")
		panel_box.add_child(ui.paragraph(point.text,19))
		ui.add_note("已收录到观察手记。按 J 可再次查看地点与记录。")
		_button("合上手记，继续探索  →", _resume, true)
		ui.focus_first()
		_save()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12 and "--ui-review" in OS.get_cmdline_user_args():
		_capture_ui_frame.call_deferred()
		return
	if event.is_action_pressed("menu"):
		_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal") and (not panel_open or modal_kind in ["menu","journal"]):
		_show_journal()
	elif event.is_action_pressed("characters") and (not panel_open or modal_kind in ["menu","characters"]):
		_show_characters()
	elif event.is_action_pressed("hints") and not panel_open:
		ui.toggle_hints()
	elif event.is_action_pressed("interact") and not panel_open:
		_interact()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not panel_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if not player:
		return
	if not panel_open: scene_age += delta
	nearest = -1
	var best := INF
	for i in points.size():
		var distance: float = player.global_position.distance_to(points[i].position)
		if i < labels_3d.size():
			labels_3d[i].visible = distance > 2.3 and player.camera.global_position.distance_to(labels_3d[i].global_position) > 4.0 and distance < (65.0 if scene_id == "yard" else 10.0)
		if distance < points[i].radius and distance < best:
			best = distance
			nearest = i
	ui.set_prompt("E    " + points[nearest].title if nearest >= 0 and not panel_open else "")
	if player.global_position.y < -4 or absf(player.global_position.x) > 150 or absf(player.global_position.z) > 180:
		player.global_position = last_safe
		player.velocity = Vector3.ZERO
		telemetry.record("recovery", {"scene":scene_id})
	if player.is_on_floor() and scene_age > 1:
		last_safe = player.global_position
	save_timer += delta
	if save_timer > 10 and started and not smoke_mode:
		save_timer = 0
		_save()

func _update_status() -> void:
	status.text = CHARACTERS[character_id] + "\n到访 %02d / 06   ·   手记 %02d" % [visited.size(),observed.size()]
	ui._layout_hud()

func _save() -> void:
	if smoke_mode:
		return
	var file := FileAccess.open("user://progress.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version":1,"scene":scene_id,"character":character_id,"visited":visited,"observed":observed,"position":[player.position.x,player.position.y,player.position.z]}))
	else:
		telemetry.record("save_error")

func _load_save() -> void:
	if not FileAccess.file_exists("user://progress.json"):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://progress.json"))
	if not data is Dictionary or data.get("version") != 1:
		telemetry.record("save_invalid")
		return
	if data.get("scene") is String and SCENES.has(data.scene):
		scene_id = data.scene
	var pos = data.get("position")
	if pos is Array and pos.size() == 3 and pos.all(func(v): return (v is float or v is int) and is_finite(float(v))):
		var candidate := Vector3(float(pos[0]),float(pos[1]),float(pos[2]))
		if absf(candidate.x) < 100 and absf(candidate.z) < 150 and candidate.y > -0.1 and candidate.y < 8:
			saved_position = candidate + Vector3(0,0.04,0)
	if data.get("character") is String and CHARACTERS.has(data.character):
		character_id = data.character
	if data.get("visited") is Array:
		for id in data.visited:
			if id is String and SCENES.has(id) and not visited.has(id):
				visited.append(id)
	if data.get("observed") is Array:
		for id in data.observed:
			if id is String and id.length() < 60 and not observed.has(id):
				observed.append(id)

func _run_smoke() -> void:
	var report := {"engine":Engine.get_version_info().string,"scenes":[],"characters":[],"passed":true}
	_resume()
	for id in SCENES:
		_load_scene(id)
		for frame in 90:
			await get_tree().physics_frame
		var stable: bool = player.is_on_floor() and player.global_position.y > -1
		report.scenes.append({"id":id,"grounded":stable,"position":str(player.global_position),"points":points.size()})
		if not stable:
			report.passed = false
	for id in CHARACTERS:
		var loaded: bool = player.set_character(id)
		var motions: Array = []
		for animator in player.animators:
			for motion in animator.get_animation_list():
				motions.append(motion)
		var complete := loaded
		for required in ["idle","walk","run"]:
			if not motions.any(func(value): return String(value).to_lower().ends_with(required)):
				complete = false
		report.characters.append({"id":id,"asset_loaded":loaded,"animations":motions,"complete":complete})
		if not complete:
			report.passed = false
		await get_tree().process_frame
	var output := FileAccess.open("res://tests/smoke_result.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	print("SMOKE_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if report.passed else 1)

func _capture_tour() -> void:
	_resume()
	DirAccess.make_dir_recursive_absolute("res://artifacts/screenshots_final")
	for id in SCENES:
		_load_scene(id)
		if id == "club":
			player.global_position = Vector3(1.2,0.1,2.1)
			player.yaw = 0.28
		if id == "chitanda":
			player.global_position = Vector3(0,0.5,5.2)
		if id == "oreki":
			player.global_position = Vector3(2.5,0.5,1.8)
			player.yaw = 1.1
		for frame in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/screenshots_final/" + id + ".png")
	_load_scene("yard")
	_show_start()
	for frame in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/screenshots_final/menu.png")
	_show_characters()
	for frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/screenshots_final/characters.png")
	_show_start()

func _capture_ui_frame() -> void:
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/ui-redesign/%s-%s.png" % [modal_kind if panel_open else "hud",str(Time.get_unix_time_from_system()).replace(".","-")]
	get_viewport().get_texture().get_image().save_png(path)
	print("UI_SCREENSHOT ",path)
