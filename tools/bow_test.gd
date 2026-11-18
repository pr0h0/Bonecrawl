extends Node3D
## Dev tool: ranger with the bow attached at different rotations, side by side.
func _ready():
	var rots := [Vector3.ZERO, Vector3(0, PI, 0), Vector3(0, 0, PI), Vector3(PI, 0, 0)]
	var x := -4.5
	for r in rots:
		var c := Models.character("res://assets/characters/adventurers/Ranger.glb")
		add_child(c); c.position = Vector3(x, 0, 0); c.rotation.y = 1.0
		var ico := c.find_child("Icosphere", true, false)
		if ico: ico.visible = false
		Models.attach(c, Models.WEAPON % "bow_withString", "handslot.l", Transform3D(Basis.from_euler(r), Vector3.ZERO))
		var ap: AnimationPlayer = c.get_node("AnimationPlayer")
		ap.play("ranged/Ranged_Bow_Aiming_Idle"); ap.seek(0.3, true); ap.speed_scale = 0
		var l = Label3D.new(); l.text = str(r); l.pixel_size = 0.006; l.position = Vector3(x, 2.6, 0); add_child(l)
		x += 3.0
	var cam = Camera3D.new(); add_child(cam); cam.position = Vector3(0, 3.5, 7); cam.look_at(Vector3(0, 1.2, 0)); cam.fov = 55
	var sun = DirectionalLight3D.new(); sun.rotation = Vector3(-0.7, 0.4, 0); add_child(sun)
	var we = WorldEnvironment.new(); var e = Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.2,0.2,0.25); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6,0.6,0.6); we.environment = e; add_child(we)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
