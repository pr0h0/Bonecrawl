extends Node3D
## Dev tool: opens a DESCEND door and screenshots its spinning icon at several moments.
func _ready():
	var d := ExitDoor.new()
	add_child(d)
	d.setup("stairs")
	d.set_visible_info(true)
	var cam = Camera3D.new(); add_child(cam); cam.position = Vector3(0, 9.0, 6.0); cam.look_at(Vector3(0, 5.0, 0.6)); cam.fov = 40
	var sun = DirectionalLight3D.new(); sun.rotation = Vector3(-0.8, 0.4, 0); add_child(sun)
	var we = WorldEnvironment.new(); var e = Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.1,0.1,0.12); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6,0.6,0.6); we.environment = e; add_child(we)
	var out: String = OS.get_cmdline_user_args()[0]
	for i in 4:
		await get_tree().create_timer(0.65).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, i])
	get_tree().quit()
