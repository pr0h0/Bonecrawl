extends Node3D
## Dev tool: fires a player arrow and a skeleton arrow in several directions and screenshots them mid-flight.
func _ready():
	var P = preload("res://scripts/objects/projectile.gd")
	var dirs = [Vector3(1,0,0), Vector3(0,0,-1), Vector3(-1,0,1).normalized(), Vector3(1,0,1).normalized()]
	var i = 0
	for kind in ["arrow", "enemy_arrow"]:
		for d in dirs:
			var p = P.new(); p.kind = kind; p.direction = d; p.speed = 0.0001; p.life = 99.0
			add_child(p)
			p.global_position = Vector3(-6 + i * 1.7, 1.0, 0)
			var l = Label3D.new(); l.text = kind.substr(0, 5) + "\n" + str(d.snapped(Vector3.ONE * 0.1)); l.pixel_size = 0.004; l.position = Vector3(-6 + i * 1.7, 0.1, 1.2); add_child(l)
			i += 1
	var cam = Camera3D.new(); add_child(cam); cam.position = Vector3(0, 9, 7); cam.look_at(Vector3(0, 1, 0)); cam.fov = 60
	var sun = DirectionalLight3D.new(); sun.rotation = Vector3(-1.0, 0.3, 0); add_child(sun)
	var we = WorldEnvironment.new(); var e = Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.3,0.3,0.35); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.7,0.7,0.7); we.environment = e; add_child(we)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
