extends Node3D
## Dev tool: renders promo key art. args: <out.png> <mode: wide|cover|icon> <w> <h>
var mode := "wide"

func _ready():
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	mode = a[1]
	get_window().size = Vector2i(int(a[2]), int(a[3]))
	get_viewport().transparent_bg = mode == "icon"
	_env()
	if mode == "icon":
		_icon_scene()
	else:
		_scene()
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()


func _env():
	var we = WorldEnvironment.new(); var e = Environment.new()
	if mode == "icon":
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.09, 0.05, 0.1)
	else:
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.03, 0.025, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.35, 0.5)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.6
	we.environment = e; add_child(we)
	var sun = DirectionalLight3D.new(); sun.rotation = Vector3(-0.9, 0.5, 0); sun.light_energy = 0.3
	sun.light_color = Color(0.7, 0.75, 1.0); sun.shadow_enabled = true; add_child(sun)


func _char(model: String, pos: Vector3, rot_y: float, clip: String, t: float, r := "", l := "", sc := 1.0, skel := false) -> Node3D:
	var path := ("res://assets/characters/skeletons/%s.glb" if skel else "res://assets/characters/adventurers/%s.glb") % model
	var c := Models.character(path)
	add_child(c)
	c.position = pos; c.rotation.y = rot_y; c.scale = Vector3.ONE * sc
	var ico := c.find_child("Icosphere", true, false)
	if ico: ico.visible = false
	var pfx := Models.SKEL_PROP if skel else Models.WEAPON
	if r != "": Models.attach(c, pfx % r, "handslot.r")
	if l != "": Models.attach(c, pfx % l, "handslot.l", Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) if l.begins_with("bow") else Transform3D.IDENTITY)
	var ap: AnimationPlayer = c.get_node("AnimationPlayer")
	ap.play(clip); ap.seek(t, true); ap.speed_scale = 0.0
	return c


func _light(pos: Vector3, col: Color, e: float, r: float):
	var l = OmniLight3D.new(); l.position = pos; l.light_color = col; l.light_energy = e; l.omni_range = r
	l.shadow_enabled = true; add_child(l)


func _scene():
	# floor
	for x in range(-5, 6):
		for z in range(-5, 3):
			var n := "tileBrickB_medium" if (x * 7 + z * 3) % 4 == 0 else "tileBrickA_medium"
			var t := Models.dungeon(n)
			t.position = Vector3(x * 4, -1.06 if n == "tileBrickA_medium" else -1.0, z * 4); add_child(t)
	# back wall with door + pillars + torches
	for x in range(-5, 6):
		var w := Models.dungeon("wall_door" if x == 0 else "wall")
		w.position = Vector3(x * 4, 0, -12); add_child(w)
		for yy in [4, 8]:
			var w2 := Models.dungeon("wall"); w2.position = Vector3(x * 4, yy, -12); add_child(w2)
	for x in [-6.0, 6.0, -13.0, 13.0]:
		var p := Models.dungeon("pillar"); p.position = Vector3(x, 0, -9.5); add_child(p)
	for x in [-3.0, 3.0, -10.0, 10.0]:
		var t := Models.dungeon("torchWall"); t.position = Vector3(x, 2.4, -11.6); add_child(t)
		_light(Vector3(x, 2.8, -10.8), Color(1.0, 0.55, 0.2), 3.0, 7.0)
	for p in [["barrel", Vector3(-9, 0, -8)], ["chest_rare", Vector3(8.5, 0, -7.5)], ["coinsLarge", Vector3(7.2, 0, -6.4)], ["crateDark", Vector3(-11, 0, -6)]]:
		var m := Models.dungeon(p[0]); m.position = p[1]; add_child(m)
	# Bone King + court
	var king := _char("Skeleton_Warrior", Vector3(0, 0, -6.5), 0.0, "melee/Melee_2H_Attack_Chop", 0.45, "Skeleton_Axe", "Skeleton_Shield_Large_B", 2.1, true)
	_glow_eyes(king, Color(1, 0.3, 0.1))
	_light(Vector3(0, 3.5, -4.5), Color(1.0, 0.3, 0.1), 5.0, 9.0)
	_char("Skeleton_Minion", Vector3(-4.2, 0, -4.2), 0.5, "special/Skeletons_Walking", 0.3, "Skeleton_Blade", "", 1.0, true)
	_char("Skeleton_Rogue", Vector3(4.4, 0, -4.0), -0.5, "melee/Melee_Dualwield_Attack_Stab", 0.3, "Skeleton_Blade", "Skeleton_Blade", 1.0, true)
	var sm := _char("Skeleton_Mage", Vector3(7.2, 0, -7.6), -0.4, "ranged/Ranged_Magic_Spellcasting", 0.5, "Skeleton_Staff", "", 1.0, true)
	_glow_eyes(sm, Color(0.6, 0.4, 1))
	var golem := _char("Skeleton_Golem", Vector3(-7.4, 0, -7.6), 0.45, "melee/Melee_2H_Attack", 0.35, "Skeleton_Golem_Axe", "", 0.95, true)
	_glow_eyes(golem, Color(1, 0.5, 0.15))
	var necro := _char("Necromancer", Vector3(-3.0, 0, -8.6), 0.2, "ranged/Ranged_Magic_Summon", 0.5, "Skeleton_Staff", "", 1.0, true)
	_glow_eyes(necro, Color(0.4, 1, 0.5))
	_light(Vector3(-3.0, 2.5, -7.6), Color(0.35, 1.0, 0.45), 2.5, 5.0)
	# eight heroes in front of the court, turned toward the viewer, ready to fight
	var sp := 1.62
	var heroes := [
		["Ranger", "ranged/Ranged_Bow_Aiming_Idle", 0.3, "", "bow_withString", 0.9],
		["Druid", "ranged/Ranged_Magic_Spellcasting", 0.4, "druid_staff", "", 0.6],
		["Knight", "melee/Melee_Blocking", 0.3, "sword_1handed", "shield_badge_color", 0.35],
		["Paladin_with_Helmet", "melee/Melee_Blocking", 0.3, "paladin_hammer", "paladin_shield", 0.15],
		["Rogue_Hooded", "melee/Melee_Dualwield_Attack_Stab", 0.15, "dagger", "dagger", -0.05],
		["Barbarian", "melee/Melee_2H_Idle", 0.3, "axe_2handed", "", -0.25],
		["Engineer", "ranged/Ranged_1H_Aiming", 0.3, "crossbow_1handed", "", -0.5],
		["Mage", "ranged/Ranged_Magic_Spellcasting", 0.6, "staff", "", -0.7],
	]
	for i in heroes.size():
		var h: Array = heroes[i]
		var x := (i - 3.5) * sp
		_char(h[0], Vector3(x, 0, 2.2 + (0.8 if i % 2 == 1 else 0.0)), h[5], h[1], h[2], h[3], h[4])
	_light(Vector3(5.7, 2.2, 3.4), Color(0.4, 0.6, 1.0), 2.5, 5.0)
	_light(Vector3(0, 4.5, 8), Color(1.0, 0.85, 0.7), 3.0, 12.0)
	var cam = Camera3D.new(); add_child(cam)
	if mode == "cover":
		cam.position = Vector3(0, 6.4, 13.6); cam.fov = 50
		cam.look_at(Vector3(0, 2.9, -2.2))
	else:
		cam.position = Vector3(0, 6.0, 13.0); cam.fov = 40
		cam.look_at(Vector3(0, 2.3, -3.0))


func _glow_eyes(c: Node3D, col: Color):
	for eyes in c.find_children("*Eyes*", "MeshInstance3D", true, false):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col; m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = 3.0
		(eyes as MeshInstance3D).material_override = m


func _icon_scene():
	var king := _char("Skeleton_Warrior", Vector3(0, 0, 0), 0.25, "melee/Melee_2H_Idle", 0.2, "Skeleton_Axe", "", 1.0, true)
	_glow_eyes(king, Color(1, 0.35, 0.1))
	_light(Vector3(0.8, 2.4, 1.5), Color(1.0, 0.75, 0.55), 2.5, 5.0)
	_light(Vector3(-1.2, 2.0, -0.5), Color(1.0, 0.3, 0.1), 3.0, 4.0)
	var cam = Camera3D.new(); add_child(cam)
	cam.position = Vector3(0.45, 2.35, 3.6); cam.fov = 30
	cam.look_at(Vector3(0.0, 1.85, 0))
