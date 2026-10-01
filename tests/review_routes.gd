extends SceneTree
var g
var failures := 0
func _initialize(): call_deferred("run")
func frames(n):
 for i in n: await physics_frame
func walk_to(p):
 var start=g.player.global_position
 for i in 2400:
  var delta=Vector2(p.x-g.player.position.x,p.z-g.player.position.z)
  if delta.length()<.12: break
  var local=Basis(Vector3.UP,-g.player.yaw)*Vector3(delta.x,0,delta.y).normalized()
  g.player.override_move=Vector2(local.x,local.z)
  await physics_frame
 g.player.override_move=Vector2.ZERO
 await frames(20)
 if Vector2(p.x-g.player.position.x,p.z-g.player.position.z).length() > .25 or not g.player.is_on_floor(): failures += 1
 print("QA_WALK to=",p," actual=",g.player.position," error=",Vector2(p.x-g.player.position.x,p.z-g.player.position.z).length()," floor=",g.player.is_on_floor())
func run():
 g=load("res://main.tscn").instantiate(); root.add_child(g); g.smoke_mode=true
 await frames(2)
 for id in ["corridor","chitanda","oreki","class","club","yard"]:
  g._load_scene(id); g.player.enabled=true; await frames(30)
  print("ROUTE ",id)
  var route=[]
  if id=="corridor": route=[Vector3(.48,0,-6),Vector3(.48,2.8,-10.8),Vector3(.48,0,-6),Vector3(0,0,6)]
  if id=="chitanda": route=[Vector3(0,0,7.1),Vector3(0,0,6),Vector3(1.5,0,5),Vector3(1.5,0,1.8),Vector3(3.8,0,1.8)]
  if id=="oreki": route=[Vector3(2.7,0,5),Vector3(1.05,0,4.9),Vector3(1.05,0,3.7),Vector3(2.1,0,2.5),Vector3(2.75,0,0),Vector3(2.1,0,2.5),Vector3(-2.65,0,2.5),Vector3(-3.2,0,1.5)]
  if id=="class": route=[Vector3(3.45,0,-3.9),Vector3(1.3,0,-3.9),Vector3(1.3,0,-4.35),Vector3(-1.4,0,-4.35),Vector3(-3.65,0,-4.35),Vector3(-3.65,0,0),Vector3(-3.65,0,4.15),Vector3(3.45,0,4.15),Vector3(3.45,0,-3.12)]
  if id=="club": route=[Vector3(1.1,0,1.0),Vector3(1.48,0,1.0),Vector3(1.48,0,-2.65),Vector3(-1.5,0,-2.65),Vector3(1.48,0,-2.65),Vector3(1.48,0,1.0),Vector3(1.1,0,2.72)]
  if id=="yard": route=[Vector3(-61,0,30),Vector3(0,0,15),Vector3(0,0,-40)]
  for p in route: await walk_to(p)
 print("QA_ROUTE_FAILURES ",failures)
 quit(0 if failures == 0 else 1)
