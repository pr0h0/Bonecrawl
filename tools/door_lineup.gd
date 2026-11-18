extends Node3D
## Dev tool: renders candidate door pieces side by side, saves a screenshot, quits.
func _ready():
	var names = ["wall_gate", "wall_gateDoor", "wall_door", "wallSingle_door", "wall_doorway", "door", "door_gate"]
	var x = -18.0
	for n in names:
		var p = "res://assets/dungeon/%s.gltf.glb" % n
		if not ResourceLoader.exists(p):
			print("missing ", n); continue
		var m = load(p).instantiate()
		add_child(m)
		m.position = Vector3(x, 0, 0)
		var l = Label3D.new(); l.text = n; l.pixel_size = 0.01; l.position = Vector3(x, 5, 0.5); add_child(l)
		x += 6.5
	var cr = load("res://assets/halloween/crypt.gltf").instantiate()
	add_child(cr); cr.position = Vector3(0, 0, -12); cr.rotation.y = PI
	var cam = Camera3D.new(); add_child(cam); cam.position = Vector3(0, 15.5, 16); cam.look_at(Vector3(0, 1, -2)); cam.fov = 55
	var sun = DirectionalLight3D.new(); sun.rotation = Vector3(-0.8, 0.4, 0); add_child(sun)
	var we = WorldEnvironment.new(); var e = Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.2,0.2,0.25); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6,0.6,0.6); we.environment = e; add_child(we)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
