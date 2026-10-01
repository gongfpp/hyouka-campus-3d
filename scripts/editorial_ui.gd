extends CanvasLayer
const CharacterPalette = preload("res://scripts/character_palette.gd")
## Native, local-only editorial UI. Portraits render the existing in-game GLBs.
const PAPER := Color("f4f0e4")
const INK := Color("25473e")
const MUTED := Color("6d786c")
const LINE := Color("c3c8b5")
const ACCENT := Color("97734c")
const PORTRAITS := {"oreki":Color("c8cbb5"), "chitanda":Color("d8d1c9"), "satoshi":Color("c4d4cc"), "mayaka":Color("e1cabe")}
var root: Control
var hud: Control
var location_card: PanelContainer
var progress_card: PanelContainer
var header: Label
var subheader: Label
var status: Label
var prompt: Label
var prompt_card: PanelContainer
var hints: PanelContainer
var hint_label: Label
var panel: PanelContainer
var panel_box: VBoxContainer
var body_scroll: ScrollContainer
var scrim: ColorRect
var page_tag: Label
var close_button: Button
var screen_kind := "menu"
var hints_expanded := false
var character_grid: GridContainer
var active_tween: Tween
var close_requested: Callable
var ui_font: Font

func setup(font: Font, on_close: Callable) -> void:
	ui_font = font
	close_requested = on_close
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme(font)
	add_child(root)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	location_card = PanelContainer.new()
	location_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location_card.add_theme_stylebox_override("panel", _box(Color(0.95,0.94,0.88,0.92),LINE,14,9))
	hud.add_child(location_card)
	var location := VBoxContainer.new()
	location.add_theme_constant_override("separation",2)
	location_card.add_child(location)
	location.add_child(label("放课后  /  KAMIYAMA",11,MUTED))
	header = label("",21,INK)
	location.add_child(header)
	subheader = label("",13,MUTED)
	location.add_child(subheader)
	progress_card = PanelContainer.new()
	progress_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_card.add_theme_stylebox_override("panel",_box(Color(0.95,0.94,0.88,0.9),LINE,12,8))
	hud.add_child(progress_card)
	status = label("",13,INK)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_card.add_child(status)
	prompt_card = PanelContainer.new()
	prompt_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_card.add_theme_stylebox_override("panel", _box(INK,Color("547568"),20,11))
	hud.add_child(prompt_card)
	prompt = label("",18,PAPER)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_card.add_child(prompt)
	hints = PanelContainer.new()
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.add_theme_stylebox_override("panel", _box(Color(0.95,0.94,0.88,0.9),LINE,12,8))
	hud.add_child(hints)
	hint_label = label("",12,INK)
	hints.add_child(hint_label)
	_update_hints()
	scrim = ColorRect.new()
	scrim.color = Color(0.10,0.16,0.13,0.25)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(scrim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PAPER,Color("adb6a0"),24,19))
	root.add_child(panel)
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation",12)
	panel.add_child(wrapper)
	var top := HBoxContainer.new()
	wrapper.add_child(top)
	page_tag = label("古典部  /  放课后手册",11,MUTED)
	page_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(page_tag)
	close_button = Button.new()
	close_button.text = "返回  Esc"
	close_button.theme_type_variation = "QuietButton"
	close_button.custom_minimum_size = Vector2(88,30)
	close_button.add_theme_font_size_override("font_size",12)
	close_button.pressed.connect(func(): close_requested.call())
	top.add_child(close_button)
	wrapper.add_child(separator())
	body_scroll = ScrollContainer.new()
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.follow_focus = true
	wrapper.add_child(body_scroll)
	panel_box = VBoxContainer.new()
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_theme_constant_override("separation",10)
	body_scroll.add_child(panel_box)
	root.resized.connect(_layout)
	_layout()

func _theme(font: Font) -> Theme:
	var result := Theme.new()
	result.default_font = font
	result.default_font_size = 17
	result.set_color("font_color","Label",INK)
	result.set_color("font_shadow_color","Label",Color.TRANSPARENT)
	for type in ["Button","QuietButton","PrimaryButton","CharacterButton"]:
		if type != "Button": result.set_type_variation(type,"Button")
		var normal := _box(Color("ececde"),LINE,14,10)
		var hover := _box(Color("e0e6d7"),Color("72907c"),14,10)
		var pressed := _box(Color("d0ddc9"),INK,14,10)
		if type == "QuietButton":
			normal = _box(Color(0,0,0,0),Color(0,0,0,0),10,5)
		elif type == "PrimaryButton":
			normal = _box(INK,INK,14,10)
			hover = _box(Color("365e4f"),Color("365e4f"),14,10)
			pressed = _box(Color("1b372e"),Color("1b372e"),14,10)
		elif type == "CharacterButton":
			normal = _box(Color("eaeadd"),LINE,10,10)
			hover = _box(Color("dce5d4"),Color("65816d"),10,10)
			pressed = _box(Color("cbdac5"),INK,10,10)
		result.set_stylebox("normal",type,normal)
		result.set_stylebox("hover",type,hover)
		result.set_stylebox("pressed",type,pressed)
		result.set_stylebox("disabled",type,_box(Color("e8e6dd"),Color("cfcec4"),14,10))
		var focus := _box(Color.TRANSPARENT,ACCENT,0,0)
		focus.set_border_width_all(2)
		focus.expand_margin_left = 3
		focus.expand_margin_top = 3
		focus.expand_margin_right = 3
		focus.expand_margin_bottom = 3
		result.set_stylebox("focus",type,focus)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			result.set_color(state,type,PAPER if type == "PrimaryButton" else INK)
		result.set_color("font_disabled_color",type,Color("8c8f84"))
		result.set_color("font_outline_color",type,Color.TRANSPARENT)
	result.set_stylebox("separator","HSeparator",_box(LINE,LINE,0,0))
	result.set_constant("separation","HSeparator",1)
	result.set_stylebox("scroll","VScrollBar",_box(Color("e3e5d7"),Color.TRANSPARENT,1,1))
	result.set_stylebox("grabber","VScrollBar",_box(Color("9aa98f"),Color.TRANSPARENT,3,3))
	result.set_stylebox("grabber_highlight","VScrollBar",_box(MUTED,Color.TRANSPARENT,3,3))
	result.set_stylebox("grabber_pressed","VScrollBar",_box(INK,Color.TRANSPARENT,3,3))
	return result

func _box(background: Color, border: Color, margin_x: int, margin_y: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box

func label(text: String, size: int = 17, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",color)
	return result

func paragraph(text: String, size: int = 16) -> Label:
	var result := label(text,size,MUTED)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_constant_override("line_spacing",5)
	return result

func separator() -> HSeparator:
	return HSeparator.new()

func present(title: String, description: String, kind: String) -> void:
	if active_tween: active_tween.kill()
	screen_kind = kind
	character_grid = null
	for node in panel_box.get_children():
		panel_box.remove_child(node)
		node.queue_free()
	body_scroll.scroll_vertical = 0
	page_tag.text = "古典部  /  放课后手册" if kind == "menu" else "古典部  /  " + title
	var title_label := label(title,44 if kind == "menu" else 28,INK)
	panel_box.add_child(title_label)
	if not description.is_empty(): panel_box.add_child(paragraph(description))
	hud.hide()
	scrim.show()
	panel.show()
	_layout()
	panel.modulate.a = 0.0
	active_tween = create_tween()
	active_tween.tween_property(panel,"modulate:a",1.0,0.16).set_trans(Tween.TRANS_SINE)

func dismiss() -> void:
	if active_tween: active_tween.kill()
	panel.hide()
	scrim.hide()
	hud.show()
	panel.modulate.a = 1.0
	var focused := root.get_viewport().gui_get_focus_owner()
	if focused: focused.release_focus()

func add_button(text: String, callback: Callable, primary := false, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 42
	button.theme_type_variation = "PrimaryButton" if primary else "Button"
	button.pressed.connect(callback)
	(parent if parent else panel_box).add_child(button)
	return button

func focus_first() -> void:
	_focus_first.call_deferred()

func _focus_first() -> void:
	if not panel.visible: return
	var buttons := panel_box.find_children("*","Button",true,false)
	for item in buttons:
		if not item.disabled:
			item.grab_focus()
			return
	close_button.grab_focus()

func add_note(text: String) -> void:
	panel_box.add_child(separator())
	panel_box.add_child(paragraph(text,12))

func toggle_hints() -> void:
	hints_expanded = not hints_expanded
	_update_hints()
	_layout()

func _update_hints() -> void:
	hint_label.text = "WASD 移动   Shift 奔跑   鼠标 视角   滚轮 距离\nE 观察 / 进入   J 手记   C 角色   Esc 菜单   H 收起" if hints_expanded else "J 手记   C 角色   Esc 菜单   H 操作提示"

func set_prompt(text: String) -> void:
	prompt.text = text
	prompt_card.visible = not text.is_empty()
	_layout_hud()

func _layout() -> void:
	if not root: return
	var view := root.size
	if view.x < 1: view = get_viewport().get_visible_rect().size
	var margin := 24.0 if view.x > 900 else 16.0
	var width := minf(440.0 if screen_kind == "menu" else (1020.0 if screen_kind == "characters" else 820.0),view.x - margin * 2)
	var desired_height := 590.0 if screen_kind == "menu" else (340.0 if screen_kind == "reset" else (420.0 if screen_kind in ["observation","travel"] else 610.0))
	if screen_kind == "characters" and view.x / view.y < 1.15: desired_height = 950.0
	var height := minf(desired_height,view.y - margin * 2)
	panel.size = Vector2(width,height)
	panel.position = Vector2(margin if screen_kind == "menu" else (view.x-width)/2,(view.y-height)/2)
	if character_grid:
		character_grid.columns = 2 if view.x / view.y < 1.15 else 4
		for card in character_grid.get_children():
			card.custom_minimum_size.x = (width - 64.0 - float(character_grid.columns-1)*12.0)/float(character_grid.columns)
	_layout_hud()

func _layout_hud() -> void:
	if not hud: return
	var view := root.size
	location_card.position = Vector2(20,18)
	location_card.size = Vector2.ZERO
	progress_card.size = Vector2.ZERO
	progress_card.position = Vector2(view.x - progress_card.get_combined_minimum_size().x - 20,20)
	hints.size = Vector2.ZERO
	hints.position = Vector2(20,view.y - hints.get_combined_minimum_size().y - 18)
	prompt_card.size = Vector2.ZERO
	var prompt_size := prompt_card.get_combined_minimum_size()
	prompt_card.position = Vector2((view.x-prompt_size.x)/2,view.y-prompt_size.y-(92 if hints_expanded else 62))

func add_character_cards(characters: Dictionary, selected: String, callback: Callable) -> void:
	character_grid = GridContainer.new()
	character_grid.add_theme_constant_override("h_separation",12)
	character_grid.add_theme_constant_override("v_separation",12)
	panel_box.add_child(character_grid)
	var number := 0
	for id in characters:
		number += 1
		var card := Button.new()
		card.name = "Character_" + id
		card.theme_type_variation = "CharacterButton"
		card.custom_minimum_size = Vector2(180,285)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.disabled = not ResourceLoader.exists("res://assets/characters/%s.glb" % id)
		card.tooltip_text = characters[id] + (" · 当前同行者" if id == selected else " · 选择并返回探索")
		character_grid.add_child(card)
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 11
		content.offset_right = -11
		content.offset_top = 11
		content.offset_bottom = -11
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation",5)
		card.add_child(content)
		var meta := label("0%d  /  古典部" % number,11,MUTED)
		content.add_child(meta)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size.y = 175
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(portrait)
		if not card.disabled:
			var viewport := _portrait(id)
			card.add_child(viewport)
			portrait.texture = viewport.get_texture()
		content.add_child(separator())
		content.add_child(label(characters[id],19,INK))
		content.add_child(label("当前同行  ✓" if id == selected else ("角色暂不可用" if card.disabled else "选择同行  →"),12,MUTED))
		card.pressed.connect(func(): callback.call(id))
	_layout()

func _portrait(id: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "Portrait_" + id
	viewport.size = Vector2i(320,320)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.msaa_3d = Viewport.MSAA_2X
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = PORTRAITS[id]
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("f7f2e5")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	viewport.add_child(environment)
	var model: Node3D = load("res://assets/characters/%s.glb" % id).instantiate()
	CharacterPalette.apply(model)
	viewport.add_child(model)
	model.rotation_degrees.y = 168
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.2
	camera.position = Vector3(0,1.15,3.0)
	viewport.add_child(camera)
	camera.rotation.x = -atan2(0.05,3.0)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25,-25,0)
	key.light_color = Color("fff0db")
	key.light_energy = 0.75
	viewport.add_child(key)
	return viewport
