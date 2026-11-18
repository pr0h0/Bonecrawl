extends Node3D
## Dev tool: new characters in a row, plus every fantasy weapon on a grid. args: <out.png> <chars|weapons>
func _ready():
	var a := OS.get_cmdline_user_args()
	var cam = Camera3D.new(); add_child(cam)
	if a[1] == "chars":
		var list = [["res://assets/characters/skeletons/Skeleton_Golem.glb", "general/Idle_A"], ["res://assets/characters/skeletons/Necromancer.glb", "general/Idle_A"],
			["res://assets/characters/bosses/Vampire.glb", "general/Idle_A"], ["res://assets/characters/bosses/BlackKnight.glb", "melee/Melee_2H_Idle"],
			["res://assets/characters/adventurers/Druid.glb", "general/Idle_A"], ["res://assets/characters/adventurers/Engineer.glb", "general/Idle_A"],
			["res://assets/characters/adventurers/Paladin_with_Helmet.glb", "general/Idle_A"], ["res://assets/characters/skeletons/Skeleton_Warrior.glb", "general/Idle_A"]]
		var x := -10.5
		for it in list:
			var c := Models.character(it[0]); add_child(c); c.position = Vector3(x, 0, 0)
			var ap: AnimationPlayer = c.get_node("AnimationPlayer"); ap.play(it[1])
			var l = Label3D.new(); l.text = it[0].get_file().get_basename() + ("\nLARGE" if Models.is_large(c) else ""); l.pixel_size = 0.006; l.position = Vector3(x, 3.6, 0); add_child(l)
			print(it[0].get_file(), " aabb=", Models.aabb_of(it[0]))
			x += 3.0
		cam.position = Vector3(0, 3.5, 13); cam.look_at(Vector3(0, 1.5, 0)); cam.fov = 60
	else:
		var files := []
		for f in DirAccess.get_files_at("res://assets/fantasy_weapons"):
			if f.ends_with(".gltf"): files.append(f)
		files.sort()
		var i := 0
		for f in files:
			var m: Node3D = load("res://assets/fantasy_weapons/" + f).instantiate(); add_child(m)
			var box := Models.aabb_of("res://assets/fantasy_weapons/" + f)
			var s := 1.6 / maxf(box.size.x, maxf(box.size.y, box.size.z))
			m.scale = Vector3.ONE * s
			var px := (i % 10) * 2.2 - 9.9; var pz := (i / 10) * 2.6 - 6.0
			m.position = Vector3(px, 0, pz) - box.get_center() * s + Vector3(0, 0.8, 0)
			var l = Label3D.new(); l.text = f.get_basename(); l.pixel_size = 0.004; l.position = Vector3(px, 0.05, pz + 1.0); l.rotation.x = -PI / 2; add_child(l)
			i += 1
		cam.position = Vector3(0, 18, 4); cam.look_at(Vector3(0, 0, -0.5)); cam.fov = 60
	var sun = DirectionalLight3D.new(); sun.rotation = Vector3(-0.8, 0.4, 0); add_child(sun)
	var we = WorldEnvironment.new(); var e = Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.2,0.2,0.25); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6,0.6,0.6); we.environment = e; add_child(we)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(a[0])
	get_tree().quit()
