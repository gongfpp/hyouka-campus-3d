extends SceneTree
var game
var failures := 0
func _initialize():
 call_deferred("run")
func frames(n):
 for i in n: await physics_frame
func run():
 game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.smoke_mode=true
 game._resume()
 await frames(2)
 for id in game.SCENES:
  game._load_scene(id)
  await frames(60)
  if not game.player.is_on_floor(): failures += 1
  print("QA_SPAWN ",id," ",game.player.global_position," floor=",game.player.is_on_floor())
  for p in game.points.duplicate():
   if p.destination not in ["","travel"]:
    game.player.global_position=p.position+Vector3(0,.1,0)
    await frames(5)
    game.nearest=game.points.find(p)
    game._interact()
    await frames(60)
    if not game.player.is_on_floor(): failures += 1
    print("QA_PORTAL ",id,"/",p.id," -> ",game.scene_id," ",game.player.global_position," floor=",game.player.is_on_floor())
    game._load_scene(id)
    await frames(3)
 game._load_scene("yard")
 game.player.enabled=true
 game.player.override_move=Vector2(0,-1)
 await frames(20)
 game.player.override_move=Vector2.ZERO
 var before=game.player.global_position
 game._show_start()
 await frames(30)
 if (game.player.global_position-before).length() > .02: failures += 1
 print("QA_PAUSE_DRIFT ",game.player.global_position-before)
 for id in game.CHARACTERS:
  before=game.player.global_position
  var yaw=game.player.yaw
  if not game.player.set_character(id): failures += 1
  await frames(1)
  if (game.player.global_position-before).length() > .02 or game.player.yaw != yaw or game.player.visual.get_child_count() != 1: failures += 1
  print("QA_SWITCH ",id," delta=",game.player.global_position-before," yaw=",game.player.yaw-yaw," visuals=",game.player.visual.get_child_count())
 print("QA_DONE")
 print("QA_REGRESSION_FAILURES ",failures)
 quit(0 if failures == 0 else 1)
