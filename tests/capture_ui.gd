extends SceneTree
var game
var base := "res://artifacts/ui-redesign/final/"
func _initialize(): call_deferred("run")
func frames(n: int):
	for i in n: await process_frame
func capture(name: String):
	await frames(3)
	await RenderingServer.frame_post_draw
	var path := base + name + ".png"
	root.get_texture().get_image().save_png(path)
	print("UI_CAPTURE ",name," ",root.size," ",game.ui.root.size)
func run():
	DirAccess.make_dir_recursive_absolute(base)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.smoke_mode = true
	root.title = "HYOUKA - UI Evidence Capture"
	await frames(6)
	game._resume()
	await create_timer(1).timeout
	game._show_start()
	await capture("01-menu")
	game._show_characters()
	await capture("02-characters")
	game.ui.character_grid.get_child(1).pressed.emit()
	await capture("03-hud")
	game._show_journal()
	await capture("04-journal")
	game._back()
	game.nearest = 2
	game._interact()
	await capture("05-observation")
	game._resume()
	game._show_start()
	await capture("06-pause")
	game._show_about()
	await capture("07-about")
	game._show_start()
	game._show_characters()
	root.size = Vector2i(800,900)
	await capture("08-characters-narrow")
	root.size = Vector2i(1600,600)
	await capture("09-characters-wide")
	quit()
