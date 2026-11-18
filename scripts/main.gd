extends Node
## Game flow: title -> camp -> crypt floors (room by room) -> victory/defeat -> camp.

const ROOM_WEIGHTS := {"fight": 46, "elite": 14, "treasure": 14, "shrine": 12, "traps": 14}

var world: Node3D
var env: WorldEnvironment
var sun: DirectionalLight3D
var cam: CameraRig
var hud: HUD
var player: Player
var level: Node3D        # current hub or room
var room: Room
var hub: Hub
var state := "title"     # title | hub | run | transition | end
var _nearest: Interactable
var _end_pending := false

# automated play-testing (godot -- --autotest --class=mage --shots=/path --seconds=120)
var autotest := false
var auto_args := {}
var _shot_timer := 0.0
var _shot_n := 0
var _auto_time := 0.0
var _auto_boon_timer := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			auto_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	autotest = auto_args.has("autotest")
	if autotest and auto_args.has("all_meta"):
		# test helper: every building, full mastery, chosen torment level
		for k in Game.BUILDINGS: Game.buildings[k] = true
		for c in Game.MASTERY:
			Game.mastery[c] = {}
			for d in Game.MASTERY[c]: Game.mastery[c][d.id] = int(d.max)
		Game.torment_unlocked = Game.TORMENT_MAX
		Game.torment = int(auto_args.get("torment", "0"))
		for c in Game.CLASSES: Game.unlocked[c] = true
		Game.bank_gold = 20000
		Game.stash.clear()
		Game.equipped.clear()
		for r in [0, 1, 2, 3, 4, 4, 3, 2]:
			Game.stash.append(Game.roll_item(r))
		Game.equip(Game.stash[4].id)
		Game.equip(Game.stash[3].id)
		if auto_args.has("legends"):
			# test helper: equip one legendary per slot with the given powers, e.g. --legends=thorns,phoenix,bone_shatter,vampiric
			var ls: PackedStringArray = auto_args.legends.split(",")
			for i in mini(ls.size(), 4):
				var it := Game.roll_item(4, Game.SLOTS[i])
				it.legend = ls[i]
				Game.stash.append(it)
				Game.equip(it.id)
		Game.restock_shop()
		Game.treasury_level = 3
		Game.torment_clears = {"1": "knight", "2": "mage"}
		Game.torment_cleared = 2
		for m in Game.MATERIAL_ORDER: Game.mats[m] = {"bone": 60, "iron": 40, "essence": 20, "crystal": 8, "shard": 3}[m]
		if auto_args.has("wlegend"):
			# test helper: give the chosen class its legendary weapon
			var cl: String = auto_args.get("class", "knight")
			var w := Game.roll_weapon(4, cl)
			Game.stash.append(w)
			Game.equip(w.id)
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	Fx.world = world
	env = WorldEnvironment.new()
	env.environment = Environment.new()
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	cam = CameraRig.new()
	cam.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(cam)
	hud = HUD.new()
	add_child(hud)
	hud.title_dismissed.connect(_on_title_dismissed)
	hud.boon_picked.connect(_on_boon_picked)
	hud.resume_pressed.connect(_toggle_pause)
	hud.quit_to_camp.connect(_abandon_run)
	hud.end_screen_closed.connect(_go_to_camp)
	hud.upgrades_closed.connect(func():
		_set_player_input(true)
		hud.update_hub()
		if hub:
			hub.refresh_all())
	Game.gold_changed.connect(func(): if state == "hub": hud.update_hub())
	hud.inventory_pressed.connect(hud.open_inventory_from_pause)
	hud.inventory_closed_run.connect(func():
		get_tree().paused = false
		Engine.time_scale = 1.0)
	hud.equipment_changed.connect(_on_equipment_changed)
	_enter_camp(true)
	if autotest and auto_args.has("tour"):
		await _tour()
		return
	if autotest:
		hud.title_root.visible = false
		_on_title_dismissed()
		await get_tree().create_timer(0.5).timeout
		if auto_args.has("hub_shot"):
			# --hub_spots=x,z;x,z  screenshots of camp spots (dev)
			for spot in str(auto_args.get("hub_spots", "0,4")).split(";"):
				var xz: PackedStringArray = spot.split(",")
				player.global_position = Vector3(float(xz[0]), 0, float(xz[1]))
				cam.snap()
				await get_tree().create_timer(1.5).timeout
				await _screenshot("hub")
			if auto_args.has("hub_only"):
				get_tree().quit()
				return
		var cls: String = auto_args.get("class", "knight")
		Game.unlocked[cls] = true
		Game.selected_class = cls
		_start_run()
		if auto_args.has("click_test"):
			# dev: open the pause menu and click buttons with the mouse
			await get_tree().create_timer(3.0).timeout
			_toggle_pause()
			await get_tree().process_frame
			var results := []
			for bname in ["InventoryButton", "Resume"]:
				var b := hud.pause_root.find_child(bname, true, false) as Button
				if bname == "Resume":
					hud.close_equipment()
					await get_tree().process_frame
				var hit := [false]
				b.pressed.connect(func(): hit[0] = true)
				var c := b.get_global_rect().get_center()
				for pressed in [true, false]:
					var ev := InputEventMouseButton.new()
					ev.button_index = MOUSE_BUTTON_LEFT
					ev.pressed = pressed
					ev.position = c
					ev.global_position = c
					get_viewport().push_input(ev)
					await get_tree().process_frame
				results.append("%s=%s" % [bname, hit[0]])
			print("CLICK_TEST ", results, " paused=", get_tree().paused)
			get_tree().quit()
		if auto_args.has("boss_test"):
			# dev: the boss dies while his summons are still up; the exit doors must still open
			await get_tree().create_timer(5.0).timeout
			for i in 3:
				room.spawn_enemy("minion", Vector3(-4 + i * 4, 0, 2))
			await get_tree().create_timer(1.5).timeout
			room.boss.die()
			await get_tree().create_timer(8.0).timeout
			var alive := get_tree().get_nodes_in_group("enemies").size()
			print("BOSS_TEST cleared=%s alive=%d doors_open=%s defeated=%s kinds=%s boss_dead=%s" % [room.is_cleared, alive, room.doors.map(func(d): return d.is_open), room.boss_defeated, get_tree().get_nodes_in_group("enemies").map(func(e): return e.kind + ":" + e.state), is_instance_valid(room.boss) and room.boss.dead])
			get_tree().quit()


# ---------------- environment ----------------

func _set_env(mode: String) -> void:
	var e := env.environment
	e.background_mode = Environment.BG_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 1.1
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 1.6
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.fog_enabled = true
	if mode == "hub":
		e.background_color = Color(0.03, 0.04, 0.09)
		e.ambient_light_color = Color(0.35, 0.4, 0.65)
		e.ambient_light_energy = 0.55
		e.fog_light_color = Color(0.08, 0.1, 0.2)
		e.fog_density = 0.012
		sun.light_color = Color(0.6, 0.7, 1.0)
		sun.light_energy = 0.65
		sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-30), 0)
	else:
		e.background_color = Color(0.01, 0.01, 0.015)
		e.ambient_light_color = Color(0.45, 0.4, 0.5)
		e.ambient_light_energy = 0.45
		e.fog_light_color = Color(0.0, 0.0, 0.0)
		e.fog_density = 0.008
		sun.light_color = Color(0.75, 0.75, 0.9)
		sun.light_energy = 0.35
		sun.rotation = Vector3(deg_to_rad(-62), deg_to_rad(20), 0)


# ---------------- camp ----------------

func _clear_level() -> void:
	Engine.time_scale = 1.0
	if level:
		level.queue_free()
		level = null
	room = null
	hub = null
	if player:
		player.queue_free()
		player = null
	for c in world.get_children():
		c.queue_free()


func _enter_camp(first := false) -> void:
	_clear_level()
	state = "title" if first else "hub"
	_set_env("hub")
	hub = Hub.new()
	world.add_child(hub)
	level = hub
	hub.build()
	hub.enter_crypt.connect(_start_run)
	hub.open_upgrades.connect(func():
		_set_player_input(false)
		Sfx.play("ui_open")
		hud.show_upgrades())
	hub.class_changed.connect(func(_id): _spawn_hub_player(); hud.update_hub())
	hub.open_mastery.connect(func(id):
		_set_player_input(false)
		Sfx.play("ui_open")
		hud.show_mastery(id))
	hub.open_build.connect(func(id):
		_set_player_input(false)
		Sfx.play("ui_open")
		_open_building(id))
	hub.open_armory.connect(func():
		_set_player_input(false)
		Sfx.play("ui_open")
		hud.show_armory())
	hub.open_gambler.connect(func():
		_set_player_input(false)
		Sfx.play("ui_open")
		hud.show_gambler())
	hub.open_torment.connect(func():
		_set_player_input(false)
		Sfx.play("ui_open")
		hud.show_torment())
	_spawn_hub_player()
	cam.use_bounds = true
	cam.bounds = AABB(Vector3(-14, 0, -9), Vector3(28, 0, 17))
	cam.orbit = first
	cam.snap()
	hud.show_run(false)
	hud.show_hub(not first)
	Sfx.music("camp")


func _spawn_hub_player() -> void:
	var pos := Vector3(0, 0, 6)
	if player:
		pos = player.global_position
		player.queue_free()
	player = Player.new()
	world.add_child(player)
	player.global_position = pos
	player.setup(Game.selected_class, true)
	player.camera = cam.camera
	player.input_enabled = state == "hub"
	cam.target = player


func _on_title_dismissed() -> void:
	state = "hub"
	cam.orbit = false
	cam.snap()
	hud.show_hub(true)
	_set_player_input(true)


func _freeze_player() -> void:
	## Stepping through an exit: stop the hero where they stand (past the doorway there is no floor,
	## and walking on would make them fall and the camera bounce).
	if player and is_instance_valid(player):
		player.input_enabled = false
		player.autopilot = Callable()
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)


func _set_player_input(v: bool) -> void:
	if player:
		player.input_enabled = v


# ---------------- run ----------------

func _start_run() -> void:
	if state == "transition":
		return
	Game.start_run(Game.selected_class)
	state = "transition"
	Sfx.play("door")
	await hud.fade_to(1.0, 0.5)
	hud.show_hub(false)
	if autotest and auto_args.has("jump"):
		# debug: jump straight to a floor/room type, e.g. --jump=3:boss
		var parts: PackedStringArray = auto_args.jump.split(":")
		Game.run.floor = int(parts[0])
		Game.run.room = Game.ROOMS_PER_FLOOR - 1 if parts[1] in ["boss", "stairs"] else 1
		Game.run.weapon_tier = 2
		_load_room(parts[1])
	else:
		_load_room("start")
	hud.show_banner("FLOOR %d" % Game.run.floor, HUD.GOLD, 1.5)
	Sfx.play("floor", -4.0)
	await hud.fade_to(0.0, 0.5)


func _pick_exits() -> Array:
	var next_idx: int = Game.run.room + 1
	if next_idx >= Game.ROOMS_PER_FLOOR - 1:
		return ["boss"] if Game.is_boss_floor(int(Game.run.floor)) else ["stairs"]
	var opts := []
	var weights := ROOM_WEIGHTS.duplicate()
	if Game.run.floor == 1 and next_idx == 1:
		weights.erase("elite")
	var count := 2 if randf() < 0.85 else 3
	while opts.size() < count and weights.size() > 0:
		var total := 0
		for k in weights: total += weights[k]
		var r := randi() % total
		for k in weights:
			r -= weights[k]
			if r < 0:
				opts.append(k)
				weights.erase(k)
				break
	return opts


func _load_room(type_: String) -> void:
	var keep_hp: float = Game.run.hp
	_clear_level()
	_set_env("run")
	Game.run.path.append(type_)
	room = Room.new()
	world.add_child(room)
	level = room
	var exits := []
	if type_ == "boss":
		exits = ["leave", "deeper"]
	elif type_ != "stairs":
		exits = _pick_exits()
	room.build(type_, Game.run.floor, exits, randi())
	room.exit_chosen.connect(_on_exit_chosen)
	room.descend.connect(_on_descend)
	room.shrine_used.connect(_on_shrine)
	room.buy_boon.connect(_on_shrine)
	room.boss_killed.connect(_on_boss_killed)
	room.message.connect(func(t): hud.show_banner(t, Color(1, 0.4, 0.3) if t.ends_with("RISES") else HUD.GOLD))
	player = Player.new()
	world.add_child(player)
	player.global_position = room.entrance
	player.setup(Game.run["class"])
	player.hp = keep_hp
	player.camera = cam.camera
	player.face(Vector3.FORWARD, true)
	player.died.connect(_on_player_died)
	if autotest and not auto_args.has("boss_test"):
		player.autopilot = _autopilot
	elif autotest:
		player.invulnerable_until = 9999.0
	cam.target = player
	cam.orbit = false
	var hw := room.w * Room.CELL * 0.5
	var hd := room.d * Room.CELL * 0.5
	cam.use_bounds = true
	# the lower camera sees further south, so keep the follow point well inside the room
	cam.bounds = AABB(Vector3(-hw + 5.0, 0, -hd + 2.0), Vector3(maxf(hw * 2 - 10.0, 0.1), 0, maxf(hd * 2 - 7.5, 0.1)))
	cam.snap()
	hud.show_run(true)
	hud.set_floor_info(Game.run.floor, Game.run.room, type_)
	Sfx.music("boss" if type_ == "boss" else "dungeon")
	state = "run"
	room.start(player)


func _on_exit_chosen(type_: String) -> void:
	if state != "run":
		return
	if room and is_instance_valid(room):
		room.collect_everything()
	_freeze_player()
	if type_ == "leave":
		state = "transition"
		Sfx.play("door")
		await hud.fade_to(1.0, 0.5)
		_end_run(true)
		await hud.fade_to(0.0, 0.5)
		return
	if type_ == "deeper":
		_on_descend()
		return
	state = "transition"
	Sfx.play("door")
	await hud.fade_to(1.0, 0.3)
	Game.run.room += 1
	_load_room(type_)
	await hud.fade_to(0.0, 0.3)


func _on_descend() -> void:
	if state != "run":
		return
	if room and is_instance_valid(room):
		room.collect_everything()
	state = "transition"
	Sfx.play("floor", -4.0)
	await hud.fade_to(1.0, 0.6)
	Game.run.floor += 1
	Game.run.room = 0
	Game.best_floor = max(Game.best_floor, int(Game.run.floor))
	# a breather between floors: a safe room with the travelling merchant
	Game.run.hp = minf(Game.run.max_hp, Game.run.hp + Game.run.max_hp * 0.3)
	_load_room("merchant")
	hud.show_banner("FLOOR %d" % Game.run.floor, HUD.GOLD, 1.5)
	await hud.fade_to(0.0, 0.6)


func _on_shrine() -> void:
	var pool := []
	for k in Game.BOONS:
		if not k in Game.run.boons:
			pool.append(k)
	pool.shuffle()
	var opts := pool.slice(0, 3)
	if opts.is_empty():
		player.heal(player.max_hp)
		if room:
			room.finish_event()
		return
	_set_player_input(false)
	get_tree().paused = true
	hud.show_boons(opts)
	if autotest:
		_auto_boon_timer = 1.0


func _on_boon_picked(id: String) -> void:
	get_tree().paused = false
	Game.apply_boon(id)
	if room and room.room_type == "shrine":
		room.finish_event()
	if player:
		player.max_hp = Game.run.max_hp
		player.hp = Game.run.hp
		_set_player_input(true)
		Fx.sparkle(player.global_position, Color(0.4, 1, 0.8))
	hud.show_banner(Game.BOONS[id].name.to_upper(), Color(0.5, 1, 0.85), 1.2)


func _on_boss_killed() -> void:
	if _end_pending:
		return
	_end_pending = true
	Fx.hitstop(250)
	Fx.shake(1.0, 0.8)
	Game.register_boss_kill()
	var bname := String(Game.BOSSES[Game.boss_for_floor(int(Game.run.floor))].name).to_upper()
	hud.show_banner("%s FALLS" % bname, HUD.GOLD, 2.5)
	Sfx.music("")
	Sfx.play("victory")
	await get_tree().create_timer(3.0).timeout
	_end_pending = false
	if autotest and not auto_args.has("endless") and not auto_args.has("leave"):
		_end_run(true)


func _on_player_died(_a) -> void:
	if _end_pending:
		return
	_end_pending = true
	Sfx.music("", 2.0)
	Sfx.play("defeat")
	hud.show_banner("YOU HAVE FALLEN", Color(1, 0.3, 0.25), 2.0)
	await get_tree().create_timer(2.6).timeout
	_end_run(false)


func _end_run(victory: bool) -> void:
	state = "end"
	var kept := Game.end_run(victory)
	hud.show_end(victory, kept)
	if autotest:
		_screenshot("end")
		if auto_args.has("leave"):
			if is_instance_valid(player):   # simulate a human still holding "up" through the door
				player.autopilot = func(_p): return {"move": Vector3.FORWARD, "attack": false, "skill": false, "dodge": false, "potion": false, "stick": Vector2.ZERO, "aiming": false, "aim_override": Vector3.ZERO}
			for i in 6:
				await get_tree().create_timer(0.25).timeout
				print("AFTER_LEAVE player_y=%.2f cam_y=%.2f" % [player.global_position.y if is_instance_valid(player) else 0.0, cam.camera.global_position.y])
		print("AUTOTEST END victory=%s floor=%d room=%d kills=%d gold=%d time=%.1f" % [victory, Game.run.floor, Game.run.room, Game.run.kills, Game.run.gold, Game.run.time])
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()


func _abandon_run() -> void:
	get_tree().paused = false
	hud.show_pause(false, false)
	if state == "run" or state == "transition":
		var kept := Game.end_run(false)
		hud.show_banner("Kept %d gold" % kept)
	_go_to_camp()


func _go_to_camp() -> void:
	_end_pending = false
	await hud.fade_to(1.0, 0.4)
	_enter_camp(false)
	await hud.fade_to(0.0, 0.4)


# ---------------- per-frame ----------------

func _process(delta: float) -> void:
	if state == "run" and not get_tree().paused:
		Game.run.time += delta
		var b: Enemy = null
		if room and is_instance_valid(room.boss):
			b = room.boss
		hud.update_run(player, b)
	_update_interaction()
	if autotest:
		_autotest_tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and hud.equipment_open():
		_toggle_inventory()
	elif event.is_action_pressed("pause") and state in ["hub", "run"] and not hud.modal_open():
		_toggle_pause()
	elif event.is_action_pressed("pause") and hud.modal_open() and state == "hub":
		hud.close_modal()
		_set_player_input(true)
		if hub:
			hub.refresh_all()
		hud.update_hub()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I and state in ["hub", "run"]:
		_toggle_inventory()
	elif event.is_action_pressed("interact") and _nearest and player and player.input_enabled and not get_tree().paused:
		_nearest.interact(player)


func _open_building(id: String) -> void:
	if not Game.has_building(id):
		hud.show_build(id)
		return
	match id:
		"merchant": hud.show_merchant()
		"alchemist": hud.show_alchemist()
		"blacksmith": hud.show_blacksmith()
		"treasury": hud.show_treasury()
		_: hud.show_build(id)


func _on_equipment_changed() -> void:
	## gear swapped mid-run: re-apply its bonuses to the hero right away
	if player == null or not is_instance_valid(player):
		return
	if state == "hub":
		player.refresh_weapon()
		return
	if state != "run":
		return
	Game.run.hp = player.hp
	Game.refresh_run_gear()
	player.max_hp = Game.run.max_hp
	player.hp = minf(Game.run.hp, player.max_hp)
	player.refresh_weapon()


func _toggle_inventory() -> void:
	if hud.equipment_open():
		hud.close_equipment()
		if state == "hub" and not get_tree().paused:
			_set_player_input(true)
		return
	if hud.modal_open():
		return
	Sfx.play("ui_open")
	if get_tree().paused:
		if hud.pause_root.visible:
			hud.open_inventory_from_pause()
		return
	if state == "run":
		get_tree().paused = true
		hud.show_pause(false, true)
		hud.show_equipment("run")
	else:
		_set_player_input(false)
		hud.show_equipment("hub")


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	hud.show_pause(p, state == "run")
	if not p:
		Engine.time_scale = 1.0


func _update_interaction() -> void:
	var best: Interactable = null
	if player and not player.dead and (state == "hub" or state == "run"):
		var best_d := 99.0
		for it in get_tree().get_nodes_in_group("interactables"):
			var i := it as Interactable
			if not i.enabled or not i.is_inside_tree():
				continue
			var d := i.global_position.distance_to(player.global_position)
			if d < i.radius and d < best_d:
				best_d = d
				best = i
	if best != _nearest:
		if _nearest and is_instance_valid(_nearest):
			_nearest.set_prompt_visible(false)
		_nearest = best
	if _nearest:
		_nearest.set_prompt_visible(true)


# ---------------- automated play-test ----------------

var _bot_last_pos := Vector3.ZERO
var _bot_stuck := 0.0
var _bot_side := 1.0
var _bot_goal := ""
var _bot_tried := {}   # interactables the bot already used (e.g. merchant wares it can't afford)

func _autopilot(p: Player) -> Dictionary:
	var c := _autopilot_inner(p)
	# unstick: if trying to move but not progressing, smash/sidestep
	var mv: Vector3 = c.move
	if mv.length() > 0.1:
		if p.global_position.distance_to(_bot_last_pos) < 0.02:
			_bot_stuck += 1.0 / 60.0
		else:
			_bot_stuck = maxf(0.0, _bot_stuck - 0.05)
		if _bot_stuck > 0.6:
			c.move = (mv + mv.cross(Vector3.UP) * _bot_side * 1.5).normalized()
			c.attack = true
			if c.aim_override == Vector3.ZERO:
				c.aim_override = mv
			if _bot_stuck > 2.0:
				_bot_side = -_bot_side
				_bot_stuck = 0.6
	_bot_last_pos = p.global_position
	return c


func _autopilot_inner(p: Player) -> Dictionary:
	## Crude bot: fights the nearest skeleton, grabs loot, opens chests, walks through doors.
	var cmd := {"move": Vector3.ZERO, "attack": false, "skill": false, "dodge": false, "potion": false,
		"stick": Vector2.ZERO, "aiming": false, "aim_override": Vector3.ZERO}
	if room == null or state != "run":
		return cmd
	var pos := p.global_position
	var target: Node3D = null
	var best := 999.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var dd: float = e.global_position.distance_to(pos)
		if dd < best:
			best = dd
			target = e
	var ranged: bool = p.cls.attack == "ranged"
	_bot_goal = "idle"
	if target:
		_bot_goal = "enemy"
		var to := target.global_position - pos
		to.y = 0
		cmd.aim_override = to.normalized()
		var want := 2.0 if not ranged else 8.0
		if to.length() > want:
			cmd.move = to.normalized()
		elif ranged and to.length() < 4.0:
			cmd.move = -to.normalized()
		cmd.attack = to.length() < (p.cls.get("range", 2.5) + 0.8 if not ranged else 14.0)
		cmd.skill = p.skill_cd <= 0 and to.length() < 7.0
		cmd.dodge = p.hp < p.max_hp * 0.5 and randf() < 0.01
		cmd.potion = p.hp < p.max_hp * 0.35
		return cmd
	# loot
	for c in room.get_children():
		if c is Chest and not c.opened:
			_bot_goal = "chest"
			var to2: Vector3 = c.global_position - pos
			to2.y = 0
			if to2.length() < 2.0:
				c.interact(p)
			else:
				cmd.move = to2.normalized()
			return cmd
		if c is Pickup:
			_bot_goal = "pickup"
			var to3: Vector3 = c.global_position - pos
			to3.y = 0
			if to3.length() > 0.6:
				cmd.move = to3.normalized()
				return cmd
	for c in room.get_children():
		if c is Interactable and c.enabled and not (c is Chest) and not _bot_tried.has(c.get_instance_id()):
			_bot_goal = "interact:" + str(c.prompt)
			var to4: Vector3 = c.global_position - pos
			to4.y = 0
			if to4.length() < 1.5:
				c.interact(p)
				_bot_tried[c.get_instance_id()] = true
			else:
				cmd.move = to4.normalized()
			return cmd
	_bot_goal = "door(%d)" % room.doors.size()
	for door in room.doors:
		if door.is_open and not (door.room_type == "leave" and auto_args.has("endless")):
			var tgt: Vector3 = door.global_position + Vector3(0, 0, -1.2)
			var to5 := tgt - pos
			to5.y = 0
			cmd.move = to5.normalized()
			return cmd
	return cmd


func _autotest_tick(delta: float) -> void:
	delta = delta / maxf(Engine.time_scale, 0.01)
	_auto_time += delta
	_shot_timer -= delta
	if auto_args.has("shots") and _shot_timer <= 0.0 and state == "run":
		_shot_timer = float(auto_args.get("interval", "6"))
		_screenshot("run")
	if _auto_boon_timer > 0:
		_auto_boon_timer -= delta / maxf(Engine.time_scale, 0.01)
		if _auto_boon_timer <= 0 and hud.modal_open():
			if auto_args.has("shots"):
				_screenshot("boon")
			var keys := Game.BOONS.keys().filter(func(k): return not k in Game.run.boons)
			hud.close_modal()
			_on_boon_picked(keys[0])
	if int(_auto_time) != int(_auto_time - delta) and int(_auto_time) % 10 == 0:
		var alive := get_tree().get_nodes_in_group("enemies").size()
		print("AUTOTEST t=%d fps=%d floor=%d room=%d type=%s hp=%.0f kills=%d alive=%d cleared=%s ts=%.2f state=%s goal=%s pos=%s" % [_auto_time, Engine.get_frames_per_second(), Game.run.get("floor", 0), Game.run.get("room", 0), room.room_type if room else "-", Game.run.get("hp", 0), Game.run.get("kills", 0), alive, room.is_cleared if room else false, Engine.time_scale, state, _bot_goal, player.global_position.snapped(Vector3.ONE * 0.1) if player else Vector3.ZERO])
	if _auto_time > float(auto_args.get("seconds", "240")):
		print("AUTOTEST TIMEOUT floor=%d room=%d kills=%d gold=%d hp=%.0f" % [Game.run.floor, Game.run.room, Game.run.kills, Game.run.gold, Game.run.hp])
		get_tree().quit()


func _tour() -> void:
	## Screenshot tour of the title screen and camp (for testing).
	await get_tree().create_timer(2.0).timeout
	_screenshot("title")
	await get_tree().create_timer(1.0).timeout
	hud.title_root.visible = false
	_on_title_dismissed()
	for spot in [Vector3(-9, 0, 4), Vector3(9, 0, 3), Vector3(0, 0, -6)]:
		player.global_position = spot
		cam.snap()
		await get_tree().create_timer(2.0).timeout
		_screenshot("camp")
	_set_player_input(false)
	hud.show_upgrades()
	await get_tree().create_timer(1.0).timeout
	await _screenshot("upgrades")
	hud.show_mastery("mage")
	await get_tree().create_timer(1.0).timeout
	await _screenshot("mastery")
	hud.show_torment()
	await get_tree().create_timer(1.0).timeout
	await _screenshot("torment")
	hud.show_armory()
	await get_tree().create_timer(1.0).timeout
	await _screenshot("armory")
	hud.show_equipment()
	await get_tree().create_timer(1.0).timeout
	await _screenshot("equipment")
	hud.show_gambler()
	await get_tree().create_timer(0.5).timeout
	hud._spin(0.25)
	await get_tree().create_timer(1.2).timeout
	await _screenshot("wheel_spin")
	await get_tree().create_timer(4.0).timeout
	await _screenshot("wheel_result")
	hud._open_chest("royal")
	await get_tree().create_timer(2.0).timeout
	await _screenshot("chest")
	hud.show_blacksmith()
	await get_tree().create_timer(0.6).timeout
	await _screenshot("smith_shop")
	hud._forge_rarity = 4
	hud.show_blacksmith("forge")
	await get_tree().create_timer(0.6).timeout
	await _screenshot("smith_forge")
	hud._forge_rarity = 4
	hud.show_armory("forge")
	await get_tree().create_timer(0.6).timeout
	await _screenshot("armory_forge")
	(hud.modal_root.find_children("*", "Button", true, false).filter(func(b): return b.text == "FORGE")[0] as Button).pressed.emit()
	await get_tree().create_timer(0.6).timeout
	await _screenshot("armory_forged")
	hud.show_merchant()
	await get_tree().create_timer(0.6).timeout
	await _screenshot("merchant")
	Game.buy_brew("fury")
	hud.show_alchemist()
	await get_tree().create_timer(0.6).timeout
	await _screenshot("alchemist")
	hud.show_treasury()
	await get_tree().create_timer(0.6).timeout
	await _screenshot("treasury")
	hud.show_gambler()
	await get_tree().create_timer(0.5).timeout
	await _screenshot("gambler")
	hud.close_modal()
	_toggle_pause()
	await get_tree().create_timer(0.3).timeout
	await _screenshot("pause")
	hud.open_inventory_from_pause()
	await get_tree().create_timer(0.5).timeout
	await _screenshot("inventory")
	hud.close_equipment()
	_toggle_pause()
	hud.close_modal()
	for spot in [Vector3(14, 0, 3.5), Vector3(-13, 0, -5.5)]:
		player.global_position = spot
		cam.snap()
		await get_tree().create_timer(2.0).timeout
		_screenshot("build")
	get_tree().quit()


func _screenshot(tag: String) -> void:
	if not auto_args.has("shots"):
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s_%03d_f%d_r%d.png" % [auto_args.shots, tag, _shot_n, Game.run.get("floor", 0), Game.run.get("room", 0)]
	_shot_n += 1
	img.save_png(path)
	print("SHOT ", path)
