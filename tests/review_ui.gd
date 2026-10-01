extends SceneTree
var game
var failures: Array[String] = []
func _initialize(): call_deferred("run")
func frames(n: int):
	for i in n: await physics_frame
func check(condition: bool, title: String):
	print("UI_CHECK ","PASS " if condition else "FAIL ",title)
	if not condition: failures.append(title)
func run():
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.smoke_mode = true
	await frames(3)
	check(game.panel_open and game.modal_kind == "menu" and not game.player.enabled,"initial menu")
	game._show_characters()
	await frames(3)
	check(game.ui.character_grid.get_child_count() == 4,"four model preview cards")
	for card in game.ui.character_grid.get_children():
		check(card.find_children("Portrait_*","SubViewport",true,false).size() == 1,"portrait " + card.name)
	game._back()
	check(game.modal_kind == "menu" and not game.started,"Esc child returns to initial menu")
	await frames(3)
	# Exercise viewport hit testing rather than calling a callback directly.
	var start_button = game.panel_box.find_children("*","Button",true,false)[0]
	var screen_point = start_button.get_global_transform_with_canvas() * (start_button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = screen_point
	root.push_input(motion,true)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen_point
	root.push_input(down,true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = screen_point
	root.push_input(up,true)
	await frames(3)
	check(not game.panel_open,"mouse start button hit test")
	game._resume()
	await frames(60)
	check(game.player.is_on_floor(),"resume enables physics")
	game._show_start()
	var before = game.player.global_position
	var animation_before = game.player.animators[0].current_animation_position
	await frames(30)
	check(game.player.global_position.distance_to(before) < 0.001,"pause freezes position")
	check(is_equal_approx(game.player.animators[0].current_animation_position,animation_before),"pause freezes animation")
	for index in 12:
		game._show_journal()
		await frames(1)
		check(game.modal_kind == "journal" and game.modal_parent == "menu","journal from menu " + str(index))
		game._back()
		check(game.modal_kind == "menu","journal back " + str(index))
		game._back()
		check(not game.panel_open and game.player.enabled,"resume " + str(index))
		game._show_characters()
		await frames(1)
		check(game.modal_parent == "resume","direct character return")
		game._back()
		check(not game.panel_open,"close characters")
		game._show_start()
	game._show_characters()
	await frames(1)
	before = game.player.global_position
	game.ui.character_grid.get_child(1).pressed.emit()
	check(game.character_id == "chitanda" and not game.panel_open,"select character returns to exploration")
	check(game.player.global_position.distance_to(before) < 0.001,"selection preserves location")
	check(game.player.visual.get_child_count() == 1,"selection retains one visual")
	game._show_start()
	game._confirm_reset()
	game._back()
	check(game.modal_kind == "menu","cancel reset preserves menu")
	game._resume()
	game._show_journal()
	game._back()
	check(not game.panel_open,"journal direct Escape resumes")
	game.ui.toggle_hints()
	check(game.ui.hints_expanded,"hints expand")
	game.ui.toggle_hints()
	check(not game.ui.hints_expanded,"hints collapse")
	for size in [Vector2i(1280,720),Vector2i(800,900),Vector2i(1600,600)]:
		root.size = size
		await frames(3)
		game._show_characters()
		await frames(3)
		var rect = game.panel.get_rect()
		check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= game.ui.root.size.x+1 and rect.end.y <= game.ui.root.size.y+1,"panel fits " + str(size))
		game._back()
	print("UI_FAILURES ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
