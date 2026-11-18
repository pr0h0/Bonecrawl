extends Node3D
## Dev tool: every class (rows) holding its weapon at each rarity (columns).
func _ready():
	var out: String = OS.get_cmdline_user_args()[0]
	var z := -10.5
	for cid in Game.CLASS_ORDER:
		var cls: Dictionary = Game.CLASSES[cid]
		var cw: Dictionary = Game.CLASS_WEAPONS[cid]
		for r in 5:
			var c := Models.character("res://assets/characters/adventurers/%s.glb" % cls.model)
			add_child(c)
			c.position = Vector3(-6.0 + r * 3.0, 0, z)
			c.rotation.y = 0.5
			var ico := c.find_child("Icosphere", true, false)
			if ico: ico.visible = false
			var rm: String = cls.weapon_r
			var lm: String = cls.weapon_l
			if cw.hand == "handslot.r": rm = cw.models[r]
			else: lm = cw.models[r]
			if cid == "rogue": lm = cw.models[r]
			if rm != "":
				var rp := Game.weapon_path(rm)
				Models.attach(c, rp, "handslot.r", Game.weapon_offset(rp))
			if lm != "":
				var lp := Game.weapon_path(lm)
				Models.attach(c, lp, "handslot.l", Game.weapon_offset(lp))
			var ap: AnimationPlayer = c.get_node("AnimationPlayer")
			ap.play("ranged/Ranged_Bow_Aiming_Idle" if cid == "ranger" else ("melee/Melee_2H_Idle" if cid == "barbarian" else "general/Idle_A"))
			ap.seek(0.3, true)
		var l = Label3D.new(); l.text = cid; l.pixel_size = 0.008; l.position = Vector3(-9.5, 1, z); add_child(l)
		z += 3.0
	var cam = Camera3D.new(); add_child(cam); cam.position = Vector3(0, 16, 14); cam.look_at(Vector3(0, 0.5, 0)); cam.fov = 55
	var sun = DirectionalLight3D.new(); sun.rotation = Vector3(-0.7, 0.4, 0); add_child(sun)
	var we = WorldEnvironment.new(); var e = Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.2,0.2,0.25); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6,0.6,0.6); we.environment = e; add_child(we)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
