class_name Player
extends Actor
## The adventurer. Handles input, class attacks/skills, dodge, potions and interaction.

signal skill_used
signal potion_used

const PROJECTILE := preload("res://scripts/objects/projectile.gd")

var cls: Dictionary
var class_id := ""
var attack_cd := 0.0
var skill_cd := 0.0
var dodge_cd := 0.0
var dodging_until := 0.0
var dodge_dir := Vector3.ZERO
var attacking_until := 0.0
var pending_hits: Array = []    # [time, callable]
var shield_until := 0.0
var spin_until := 0.0
var spin_tick := 0.0
var stealth_until := 0.0
var ambush_ready := false
var aim_dir := Vector3.FORWARD
var camera: Camera3D
var input_enabled := true
var in_hub := false
var autopilot: Callable          # optional AI driver used for automated tests
var _step_timer := 0.0
var weapon_node: Node3D
var _weapon_tier_shown := -1
var _weapon_rarity := -1        # rarity of the equipped class weapon (-1 = starting weapon)
# combat depth: 3-hit combo, dash strike out of a dodge, perfect-dodge counter
var combo := 0
var _last_attack_t := -9.0
var dash_strike_until := 0.0
var counter_until := 0.0
var _bump_time := 0.0


## Legendary power active this run (never in camp).
func L(id: String) -> bool:
	return not in_hub and Game.has_legend(id)


## Class mastery level (bought at camp). 0 in the hub.
func m(id: String) -> int:
	if in_hub:
		return 0
	return Game.mastery_level(class_id, id)


func setup(class_id_: String, hub := false) -> void:
	class_id = class_id_
	in_hub = hub
	cls = Game.CLASSES[class_id]
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	add_capsule(0.45, 1.8)
	setup_model("res://assets/characters/adventurers/%s.glb" % cls.model, 1.0)
	_equip()
	if hub:
		max_hp = cls.hp
		hp = max_hp
	else:
		max_hp = Game.run.max_hp
		hp = Game.run.hp
	move_speed = cls.speed * (1.0 + 0.08 * m("fleet"))
	play("general/Idle_A")


func _equip() -> void:
	var tier: int = Game.run.get("weapon_tier", 0) if not in_hub else 0
	_weapon_tier_shown = tier
	# the equipped class weapon (bought, dropped or forged) replaces the starting one
	var r_model: String = cls.weapon_r
	var l_model: String = cls.weapon_l
	var cw: Dictionary = Game.CLASS_WEAPONS[class_id]
	var wpn: Dictionary = Game.equipped.get(Game.weapon_key(class_id), {})
	_weapon_rarity = -1
	if not wpn.is_empty():
		_weapon_rarity = int(wpn.rarity)
		var mdl: String = cw.models[_weapon_rarity]
		if cw.hand == "handslot.r":
			r_model = mdl
		else:
			l_model = mdl
		if class_id == "rogue":
			l_model = mdl
	var r_node: Node3D = null
	var l_node: Node3D = null
	if r_model != "":
		var rp := Game.weapon_path(r_model)
		r_node = Models.attach(model, rp, "handslot.r", Game.weapon_offset(rp))
	if l_model != "":
		# bows are turned so the string faces the archer (see Game.weapon_offset)
		var lp := Game.weapon_path(l_model)
		l_node = Models.attach(model, lp, "handslot.l", Game.weapon_offset(lp))
	weapon_node = r_node if cw.hand == "handslot.r" else l_node
	if _weapon_rarity == 4 and weapon_node:
		var gl := OmniLight3D.new()
		gl.light_color = Game.RARITY_COLORS[4]
		gl.light_energy = 1.2
		gl.omni_range = 2.2
		weapon_node.add_child(gl)
	_tint_weapon(tier)


func refresh_weapon() -> void:
	## Re-attach weapons after the equipped class weapon changed (inventory mid-run).
	var sk := Models.skeleton_of(model)
	if sk:
		for c in sk.get_children():
			if c is BoneAttachment3D and c.bone_name in ["handslot.r", "handslot.l"]:
				c.queue_free()
	_equip()


func _tint_weapon(tier: int) -> void:
	## Weapons glow: run sharpening (uncommon green, rare blue) or the equipped weapon's rarity colour.
	if weapon_node == null:
		return
	var colors := [Color(0, 0, 0), Color(0.2, 0.9, 0.3), Color(0.4, 0.5, 1.0)]
	var col := Color(0, 0, 0, 0)
	if _weapon_rarity >= 2:
		col = Game.RARITY_COLORS[_weapon_rarity]
	elif tier > 0:
		col = colors[tier]
	for m in Models.meshes_of(weapon_node):
		if col.a == 0.0:
			(m as MeshInstance3D).material_overlay = null
		else:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(col.r, col.g, col.b, 0.35)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			(m as MeshInstance3D).material_overlay = mat


func _physics_process(delta: float) -> void:
	time += delta
	if dead:
		apply_motion(Vector3.ZERO, delta)
		return
	attack_cd -= delta
	skill_cd -= delta
	dodge_cd -= delta
	_process_pending_hits()
	if not in_hub:
		Game.run.hp = hp
		if Game.run.weapon_tier != _weapon_tier_shown:
			_weapon_tier_shown = Game.run.weapon_tier
			_tint_weapon(_weapon_tier_shown)

	var cmd := _read_input()
	var move: Vector3 = cmd.move
	_update_aim(cmd)

	var speed := move_speed * float(Game.run.get("speed_mult", 1.0) if not in_hub else 1.0)
	var desired := Vector3.ZERO

	if time < dodging_until:
		desired = dodge_dir * speed * 2.6
		apply_motion(desired, delta)
		_smash_bumped(delta)
		return

	if input_enabled:
		if cmd.dodge and dodge_cd <= 0.0 and not in_hub:
			_start_dodge(move if move.length() > 0.1 else forward())
			apply_motion(dodge_dir * speed * 2.6, delta)
			return
		if cmd.potion and not in_hub:
			use_potion()
		if cmd.attack and attack_cd <= 0.0 and time >= spin_until and time >= shield_until and not in_hub:
			_attack()
		if cmd.skill and skill_cd <= 0.0 and not in_hub:
			_skill()

	var slow := 1.0
	if time < attacking_until:
		slow = 0.35 if cls.attack == "melee" else 0.55
	if time < shield_until:
		slow = 0.3
	if time < spin_until:
		slow = 0.75
		_spin_damage(delta)
	desired = move * speed * slow

	# facing: aim while attacking/blocking, otherwise movement direction
	if time < attacking_until or time < shield_until or (cmd.aiming and not in_hub):
		face(aim_dir, false, delta, 20.0)
	elif move.length() > 0.1:
		face(move, false, delta)

	# animation
	if time < spin_until:
		play("melee/Melee_2H_Attack_Spinning")
	elif time < shield_until:
		play("melee/Melee_Blocking")
	elif move.length() > 0.1:
		play_loop("move/Running_A", 0.15, 1.0 + (speed - 6.0) * 0.05)
		_step_timer -= delta
		if _step_timer <= 0:
			_step_timer = 0.32
			Sfx.play("step", -14.0)
	else:
		play_loop("general/Idle_A")

	if time < stealth_until:
		tint(Color(0.15, 0.15, 0.25), 0.55)
	elif time < counter_until:
		tint(Color(1.0, 0.8, 0.3), 0.25 + 0.15 * sin(time * 20.0))
	elif counter_until > 0.0:
		counter_until = 0.0
		tint(Color.WHITE, 0.0)

	apply_motion(desired, delta)
	if not in_hub:
		_smash_bumped(delta)


func _read_input() -> Dictionary:
	if autopilot.is_valid():
		return autopilot.call(self)
	var move := Vector3.ZERO
	if input_enabled:
		var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		move = Vector3(v.x, 0, v.y)
		if move.length() > 1.0:
			move = move.normalized()
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	return {
		"move": move,
		"attack": input_enabled and Input.is_action_pressed("attack"),
		"skill": input_enabled and Input.is_action_just_pressed("skill"),
		"dodge": input_enabled and Input.is_action_just_pressed("dodge"),
		"potion": input_enabled and Input.is_action_just_pressed("potion"),
		"stick": stick,
		"aiming": stick.length() > 0.3,
		"aim_override": Vector3.ZERO,
	}


func _update_aim(cmd: Dictionary) -> void:
	## Aim follows movement: you attack the way you walk. Standing still keeps the last facing.
	## (A gamepad right stick can still aim independently; the mouse does not aim.)
	if cmd.get("aim_override", Vector3.ZERO) != Vector3.ZERO:
		aim_dir = (cmd.aim_override as Vector3).normalized()
		return
	var stick: Vector2 = cmd.stick
	if stick.length() > 0.3:
		aim_dir = Vector3(stick.x, 0, stick.y).normalized()
		return
	if time < _locked_until and _locked_aim != Vector3.ZERO:
		aim_dir = _locked_aim
		return
	var m: Vector3 = cmd.move
	if m.length() > 0.1:
		aim_dir = m.normalized()
	else:
		aim_dir = forward()


var _locked_aim := Vector3.ZERO   # facing held for the duration of an attack
var _locked_until := 0.0

const AIM_ASSIST_ANGLE := 25.0   # degrees either side; keyboard gives 8 directions 45 deg apart
const AIM_ASSIST_RANGE := 16.0

## Ranged classes only: bend the shot toward the best enemy near the aim line.
func _assisted_aim(dir: Vector3) -> Vector3:
	if cls.attack != "ranged" or in_hub:
		return dir
	var best: Node3D = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.get("state") == "spawning":
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		var dist := to.length()
		if dist < 0.3 or dist > AIM_ASSIST_RANGE:
			continue
		var ang := rad_to_deg(dir.angle_to(to / dist))
		if ang > AIM_ASSIST_ANGLE:
			continue
		var score := ang + dist * 0.8   # prefer targets close to the line, then closer ones
		if score < best_score:
			best_score = score
			best = e
	if best == null:
		return dir
	var t := best.global_position - global_position
	t.y = 0
	return t.normalized()


# ---------------- combat ----------------

func damage_value(mult := 1.0) -> Dictionary:
	var dmg: float = cls.dmg * Game.WEAPON_TIER_MULT[Game.run.weapon_tier] * float(Game.run.dmg_mult) * mult
	dmg *= 1.0 + 0.10 * m("heavy_hands") + 0.12 * m("arcane_focus")
	dmg *= randf_range(0.9, 1.1)
	if Game.has_legend("berserker") and hp < max_hp * 0.4:
		dmg *= 1.3
	var crit := randf() < float(Game.run.get("crit", 0.08))
	if time < counter_until:
		crit = true                 # perfect-dodge counter: guaranteed crit
	if crit:
		dmg *= 1.8
	return {"dmg": dmg, "crit": crit}


func _attack() -> void:
	aim_dir = _assisted_aim(aim_dir)
	var cd: float = float(cls.cd) * (1.0 - 0.08 * m("quickdraw"))
	_locked_aim = aim_dir
	_locked_until = time + cd * 0.9
	# chain: attacks in quick succession build a combo; the third is a heavy finisher
	if time - _last_attack_t < cd + 0.45:
		combo = (combo + 1) % 3
	else:
		combo = 0
	_last_attack_t = time
	var finisher := combo == 2
	var mult := 1.0
	if finisher:
		mult *= 1.7
		cd *= 1.25
	if time < dash_strike_until:
		mult *= 1.5                 # dash strike: attacking right out of a dodge
		dash_strike_until = 0.0
		Fx.text(global_position + Vector3.UP * 2.6, "DASH STRIKE", Color(0.6, 0.9, 1.0), 34)
	attack_cd = cd
	attacking_until = time + cd * 0.9
	face(aim_dir, true)
	var clip: String = cls.anim
	if finisher and cls.has("finisher"):
		clip = cls.finisher
	var anim_speed := clampf(clip_length(clip) / maxf(cd * 1.15, 0.2), 1.0, 2.6)
	play(clip, 0.05, anim_speed, cd * 0.95)
	var hit_t: float = cls.hit_time
	if cls.attack == "melee":
		Sfx.play("swing_heavy" if class_id == "barbarian" or finisher else "swing", -4.0)
		_schedule(hit_t, _melee_hit.bind(mult, finisher))
	else:
		Sfx.play(cls.get("shot_sfx", "bow" if class_id == "ranger" else "magic"), -4.0)
		_schedule(hit_t, _ranged_shot.bind(mult, finisher))


func _schedule(delay: float, fn: Callable) -> void:
	pending_hits.append([time + delay, fn])


func _process_pending_hits() -> void:
	var still: Array = []
	for p in pending_hits:
		if time >= p[0]:
			if not dead:
				(p[1] as Callable).call()
		else:
			still.append(p)
	pending_hits = still


func _melee_hit(extra := 1.0, finisher := false) -> void:
	var range_: float = cls.range + (0.5 if finisher else 0.0)
	var half_arc: float = deg_to_rad((cls.arc + (50.0 if finisher else 0.0)) * 0.5)
	var fwd := forward()
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		var dist := to.length()
		if dist > range_ + e.radius:
			continue
		if dist > 0.3 and fwd.angle_to(to.normalized()) > half_arc:
			continue
		var mult := extra
		var crit_forced := false
		if class_id == "rogue":
			# backstab: attacking from behind the enemy
			var e_fwd: Vector3 = e.forward()
			if e_fwd.dot(to.normalized()) > 0.3:
				mult *= 2.5 + 0.5 * m("assassin")
				crit_forced = true
		if ambush_ready:
			mult *= 3.0
			crit_forced = true
		if L("skullsplitter") and randf() < 0.2:
			mult *= 3.0
			crit_forced = true
			Fx.shake(0.3, 0.12)
		var dv := damage_value(mult)
		var knock := (5.0 if class_id != "barbarian" else 8.0) * (2.2 if finisher else 1.0)
		var applied: float = e.take_damage(dv.dmg, global_position, knock, self)
		if applied > 0:
			hit_any = true
			if finisher and not e.dead and e.has_method("stagger"):
				e.call("stagger", 0.45)
			if m("poison") > 0 and not e.dead:
				e.call("add_dot", 4.0, 3.0, Color(0.5, 1.0, 0.3))
			if L("widowfang") and not e.dead:
				e.call("add_dot", 10.0, 4.0, Color(0.6, 0.2, 0.9))
			Fx.number(e.global_position + Vector3.UP * 2.2, applied, Color(1, 0.9, 0.4) if (dv.crit or crit_forced) else Color(1, 1, 1), dv.crit or crit_forced)
			Fx.hit(e.global_position + Vector3.UP * 1.1 - to.normalized() * 0.3, dv.crit or crit_forced or class_id == "barbarian")
	for b in get_tree().get_nodes_in_group("breakables"):
		var to2: Vector3 = b.global_position - global_position
		to2.y = 0
		if to2.length() < range_ + 0.6 and (to2.length() < 0.5 or fwd.angle_to(to2.normalized()) < half_arc):
			b.call("smash")
	if hit_any and finisher and class_id == "paladin" and (L("dawnbreaker") or m("judgement") > 0):
		var c := global_position + fwd * range_ * 0.6
		_smite(c, 2.5 if L("dawnbreaker") else 1.0, 2.6)
	if hit_any:
		ambush_ready = false
		stealth_until = 0.0
		tint(Color.WHITE, 0.0)
		Sfx.play("hit_bone", -2.0)
		Fx.shake((0.18 if class_id != "barbarian" else 0.35) * (1.8 if finisher else 1.0), 0.12)
		Fx.hitstop((45 if class_id != "barbarian" else 70) + (40 if finisher else 0))
		counter_until = minf(counter_until, 0.001)


func _ranged_shot(extra := 1.0, finisher := false) -> void:
	aim_dir = _assisted_aim(aim_dir)   # re-check at release: the target may have moved during the draw
	_locked_aim = aim_dir
	var dv := damage_value(extra)
	var shots: Array = []
	if m("twin_bolts") > 0:
		shots.append(_fire(aim_dir.rotated(Vector3.UP, deg_to_rad(6)), dv))
		shots.append(_fire(aim_dir.rotated(Vector3.UP, deg_to_rad(-6)), damage_value(extra)))
	else:
		shots.append(_fire(aim_dir, dv))
	if finisher:
		# the third shot is charged: it pierces and hits harder
		for p in shots:
			p.set("pierce", int(p.get("pierce")) + 2)
			(p as Node3D).scale = Vector3.ONE * 1.5
	counter_until = minf(counter_until, 0.001)
	if L("stormstring"):
		for ang in [-12.0, 12.0]:
			_fire(aim_dir.rotated(Vector3.UP, deg_to_rad(ang)), damage_value(0.8))


func _fire(dir: Vector3, dv: Dictionary, kind := "", speed := -1.0) -> Node3D:
	var p := PROJECTILE.new()
	p.kind = kind if kind != "" else cls.projectile
	p.speed = speed if speed > 0 else cls.proj_speed
	p.damage = dv.dmg
	p.crit = dv.crit
	p.from_player = true
	p.direction = dir
	p.source = self
	if p.kind == "arrow":
		p.pierce = m("piercing")
	if p.kind == "bolt" and L("lichstaff"):
		p.explode_radius = 2.2
	if p.kind == "thorn":
		p.pierce = m("thornweave")
	if class_id == "engineer" and L("dragonmaw"):
		p.ignite = true
	get_parent().add_child(p)
	p.global_position = global_position + Vector3.UP * 1.25 + dir * 0.8
	return p


func _skill() -> void:
	aim_dir = _assisted_aim(aim_dir)
	skill_cd = float(cls.skill_cd) * float(Game.run.cd_mult)
	skill_used.emit()
	match cls.skill:
		"shield_wall":
			var dur := 1.6 + 0.5 * m("bulwark")
			shield_until = time + dur
			face(aim_dir, true)
			if L("oathkeeper"):
				heal(max_hp * 0.15)
				Fx.heal(global_position)
			Sfx.play("block")
			_schedule(dur, _shield_bash)
		"whirlwind":
			spin_until = time + 1.8 + 0.6 * m("cyclone")
			spin_tick = 0.0
			Sfx.play("swing_heavy")
		"volley":
			face(aim_dir, true)
			play("ranged/Ranged_Bow_Release", 0.05, 1.4, 0.35)
			Sfx.play("bow")
			var n := 7 + 2 * m("quiver")
			var spread := 60.0 + 8.0 * m("quiver")
			for i in n:
				var ang := deg_to_rad(-spread * 0.5 + i * spread / (n - 1))
				var d := aim_dir.rotated(Vector3.UP, ang)
				var arrow := _fire(d, damage_value(0.9))
				if m("hunters_mark") > 0:
					arrow.set("slow_on_hit", true)
		"fireball":
			face(aim_dir, true)
			play("ranged/Ranged_Magic_Summon", 0.05, 1.5, 0.45)
			Sfx.play("magic")
			var dv := damage_value(3.0)
			var fb := _fire(aim_dir, dv, "fireball", 14.0)
			fb.set("explode_radius", 3.6 + 0.8 * m("inferno"))
			fb.set("burning", m("burning_ground") > 0)
		"smoke_bomb":
			play("general/Throw", 0.05, 1.6, 0.3)
			Fx.smoke(global_position)
			Sfx.play("dodge")
			stealth_until = time + 3.0 + 1.0 * m("shadow_step")
			ambush_ready = true
			invulnerable_until = time + 0.6
			_start_dodge(aim_dir, 0.25 + 0.1 * m("shadow_step"))
			for e in get_tree().get_nodes_in_group("enemies"):
				e.call("lose_target", 2.5)
		"consecrate":
			play("melee/Melee_Block_Attack", 0.05, 1.3, 0.4)
			Sfx.play("boon", -2.0)
			Fx.flash_light(global_position + Vector3.UP, Color(1, 0.85, 0.4), 6.0, 7.0, 0.4)
			var z := HolyZone.new()
			z.radius = 4.0 + 1.0 * m("radiance")
			z.duration = 4.0 + 1.5 * m("hallowed")
			z.owner_player = self
			get_parent().add_child(z)
			z.global_position = Vector3(global_position.x, 0.0, global_position.z)
		"entangle":
			face(aim_dir, true)
			play("ranged/Ranged_Magic_Summon", 0.05, 1.5, 0.4)
			Sfx.play("magic")
			var target_pos := global_position + aim_dir * 5.0
			var r := 3.6
			var held := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.dead:
					continue
				var dd: Vector3 = e.global_position - target_pos
				dd.y = 0
				if dd.length() < r:
					e.call("root", 2.2 + 0.75 * m("overgrowth"))
					if m("bramble") > 0:
						e.call("add_dot", 8.0, 2.2 + 0.75 * m("overgrowth"), Color(0.4, 0.9, 0.3))
					held += 1
			if m("regrowth") > 0 and held > 0:
				heal(4.0 * held)
			Fx.ring(target_pos, r, 0.35, Color(0.4, 0.9, 0.3, 0.6))
			Fx.burst(target_pos + Vector3.UP * 0.3, Color(0.35, 0.8, 0.25), 40, 5.0, 0.2, 0.8, -6.0, r)
			_spawn_vines(target_pos, r, 2.2 + 0.75 * m("overgrowth"))
		"turret":
			play("general/Interact", 0.05, 1.6, 0.35)
			Sfx.play("door", -6.0)
			var maxn := 2 if m("twin_turret") > 0 else 1
			var existing := get_tree().get_nodes_in_group("turrets")
			while existing.size() >= maxn:
				existing[0].call("expire")
				existing.remove_at(0)
			var t := Turret.new()
			t.owner_player = self
			t.duration = 10.0 + 3.0 * m("durable")
			t.interval = 0.5 / (1.0 + 0.2 * m("overclock")) / (2.0 if L("dragonmaw") else 1.0)
			t.shrapnel = m("shrapnel") > 0
			get_parent().add_child(t)
			t.global_position = Vector3(global_position.x, 0.0, global_position.z) + aim_dir * 1.4


func _spawn_vines(center: Vector3, r: float, life: float) -> void:
	## Thorny tendrils that mark the rooted area.
	var root := Node3D.new()
	get_parent().add_child(root)
	root.global_position = Vector3(center.x, 0, center.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.55, 0.2)
	for i in 14:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.12
		cm.height = randf_range(0.8, 1.5)
		cm.radial_segments = 5
		mi.mesh = cm
		mi.material_override = mat
		var a := randf() * TAU
		var d := sqrt(randf()) * r
		mi.position = Vector3(cos(a) * d, cm.height * 0.5 - 0.1, sin(a) * d)
		mi.rotation = Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
		mi.scale = Vector3(1, 0.01, 1)
		root.add_child(mi)
		create_tween().tween_property(mi, "scale", Vector3.ONE, 0.2)
	var tw := root.create_tween()
	tw.tween_interval(life)
	tw.tween_property(root, "scale", Vector3(1, 0.01, 1), 0.3)
	tw.tween_callback(root.queue_free)


func _smite(center: Vector3, mult: float, radius: float) -> void:
	## Holy pillar (Paladin's Judgement mastery / Dawnbreaker).
	Fx.flash_light(center + Vector3.UP * 2.0, Color(1, 0.9, 0.5), 8.0, radius * 3.0, 0.3)
	Fx.burst(center + Vector3.UP * 0.3, Color(1, 0.9, 0.5), 30, 7.0, 0.18, 0.6, 4.0, radius * 0.5)
	Fx.ring(center, radius, 0.25, Color(1, 0.9, 0.5, 0.6))
	Sfx.play("magic", -2.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.global_position.distance_to(center) > radius:
			continue
		var dv := damage_value(mult)
		var a: float = e.take_damage(dv.dmg, center, 6.0, self)
		if a > 0:
			Fx.number(e.global_position + Vector3.UP * 2.4, a, Color(1, 0.9, 0.5), true)


func _shield_bash() -> void:
	play("melee/Melee_Block_Attack", 0.05, 1.4, 0.4)
	Sfx.play("swing_heavy")
	var fwd := forward()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		if to.length() < 3.2 and fwd.angle_to(to.normalized()) < deg_to_rad(70):
			var dv := damage_value(2.2 * (2.0 if L("oathkeeper") else 1.0))
			var a: float = e.take_damage(dv.dmg, global_position, 14.0, self)
			if m("stun_bash") > 0 and not e.dead:
				e.call("stun", 1.5)
			if a > 0:
				Fx.number(e.global_position + Vector3.UP * 2.2, a, Color(1, 0.9, 0.4), true)
				Fx.hit(e.global_position + Vector3.UP, true)
	Fx.shake(0.4, 0.15)


func _spin_damage(delta: float) -> void:
	spin_tick -= delta
	if spin_tick > 0:
		return
	spin_tick = 0.3
	var hit := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		if to.length() < 3.3:
			var dv := damage_value(0.75)
			var a: float = e.take_damage(dv.dmg, global_position, 7.0 if m("vortex") == 0 else 0.0, self)
			if m("vortex") > 0 and not e.dead:
				e.knockback += -to.normalized() * 6.0   # pull towards the barbarian
			if a > 0:
				hit = true
				if m("bloodlust") > 0:
					hp = minf(max_hp, hp + 3.0)
				Fx.number(e.global_position + Vector3.UP * 2.2, a)
				Fx.hit(e.global_position + Vector3.UP)
	for b in get_tree().get_nodes_in_group("breakables"):
		if b.global_position.distance_to(global_position) < 3.3:
			b.call("smash")
	Sfx.play("swing_heavy", -6.0)
	if hit:
		Sfx.play("hit_bone", -3.0)
		Fx.shake(0.15, 0.1)


func _start_dodge(dir: Vector3, duration := 0.32) -> void:
	dir.y = 0
	dodge_dir = dir.normalized() if dir.length() > 0.01 else forward()
	dodging_until = time + duration
	dash_strike_until = dodging_until + 0.4
	if not in_hub and _is_perfect_dodge():
		Fx.slowmo(0.3, 420)
		Fx.text(global_position + Vector3.UP * 2.8, "PERFECT!", Color(1, 0.85, 0.3), 52)
		Fx.flash_light(global_position + Vector3.UP, Color(1, 0.85, 0.4), 4.0, 5.0, 0.4)
		Sfx.play("boon", -6.0)
		counter_until = time + 1.6     # next hit is a guaranteed crit
		dodge_cd = 0.0
		duration += 0.08
	invulnerable_until = maxf(invulnerable_until, time + duration + 0.05)
	if counter_until <= time:
		dodge_cd = 0.75 * float(Game.run.get("dodge_mult", 1.0)) if not in_hub else 0.75
	face(dodge_dir, true)
	play("moveadv/Dodge_Forward", 0.05, 1.5, duration)
	Sfx.play("dodge", -4.0)
	Fx.dust(global_position, 8)
	pending_hits.clear()
	attacking_until = 0.0


func _is_perfect_dodge() -> bool:
	## Dodging just before a blow lands: an enemy within reach is about to strike, or a shot is about to hit.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.get("state") != "windup":
			continue
		var left: float = float(e.get("state_until")) - float(e.get("time"))
		if left <= 0.3 and e.global_position.distance_to(global_position) < float(e.get("data").get("range", 2.0)) + 2.0:
			return true
	for p in get_tree().get_nodes_in_group("enemy_projectiles"):
		var to: Vector3 = global_position - p.global_position
		to.y = 0
		if to.length() < 3.0 and (p.get("direction") as Vector3).dot(to.normalized()) > 0.7:
			return true
	return false


func _smash_bumped(delta: float) -> void:
	## Barrels and crates never trap you: roll into them, or keep pushing for a moment, and they break.
	var bumped: Node = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c is Node and (c as Node).is_in_group("breakables"):
			bumped = c
			break
	if bumped == null:
		_bump_time = 0.0
		return
	_bump_time += delta
	if time < dodging_until or _bump_time > 0.25:
		bumped.call("smash")
		_bump_time = 0.0


func use_potion() -> void:
	if Game.run.potions <= 0 or hp >= max_hp:
		Sfx.play("ui_error", -6.0)
		return
	Game.run.potions -= 1
	heal(max_hp * float(Game.run.get("potion_heal", 0.4)))
	play("general/Use_Item", 0.05, 1.6, 0.4)
	Sfx.play("drink")
	potion_used.emit()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	if not in_hub:
		Game.run.hp = hp
	Fx.heal(global_position)
	Fx.number(global_position + Vector3.UP * 2.3, amount, Color(0.4, 1, 0.5))


func on_kill() -> void:
	if not in_hub:
		Game.run.kills += 1
		if Game.run.lifesteal > 0:
			hp = minf(max_hp, hp + Game.run.lifesteal)
		if Game.has_legend("vampiric"):
			hp = minf(max_hp, hp + max_hp * 0.04)


func modify_incoming(amount: float, from: Vector3, source: Node) -> float:
	if time < shield_until:
		var to := from - global_position
		to.y = 0
		if to.length() < 0.01 or forward().angle_to(to.normalized()) < deg_to_rad(80):
			Sfx.play("block")
			Fx.hit(global_position + Vector3.UP * 1.2 + forward() * 0.6)
			if source and source.has_method("reflect"):
				source.call("reflect", self)
			if m("riposte") > 0:
				skill_cd = maxf(0.0, skill_cd - 0.6)
			return amount * 0.0
	if time < stealth_until:
		amount *= 0.5
	return amount * float(Game.run.get("dmg_taken_mult", 1.0))


func on_hurt(amount: float) -> void:
	if Game.has_legend("thorns"):
		_thorns(amount)
	Sfx.play("hurt")
	Fx.shake(0.35, 0.18)
	Fx.number(global_position + Vector3.UP * 2.3, amount, Color(1, 0.3, 0.25))
	invulnerable_until = time + 0.45
	flash(Color(1, 0.2, 0.2), 0.6)
	if not anim_locked():
		play("general/Hit_A", 0.05, 1.5, 0.25)
	Game.run.hp = hp


func _thorns(amount: float) -> void:
	## reflect a share of melee damage to adjacent attackers
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and e.global_position.distance_to(global_position) < 3.6 and e.get("state") in ["windup", "recover", "lunge", "spin"]:
			var a: float = e.take_damage(amount * 0.4, global_position, 2.0, null)
			if a > 0:
				Fx.number(e.global_position + Vector3.UP * 2.2, a, Color(0.9, 0.5, 1.0))


func die() -> void:
	if dead:
		return
	if not in_hub and Game.has_legend("phoenix") and not Game.run.get("phoenix_used", false):
		Game.run.phoenix_used = true   # once per run (the player node is rebuilt every room)
		hp = max_hp * 0.4
		Game.run.hp = hp
		invulnerable_until = time + 2.0
		Fx.explosion(global_position, 3.0)
		Fx.text(global_position + Vector3.UP * 2.6, "PHOENIX!", Color(1, 0.6, 0.15), 70)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(global_position) < 5.0:
				e.knockback += (e.global_position - global_position).normalized() * 14.0
		Sfx.play("boon")
		return
	super.die()
	pending_hits.clear()
	play("general/Death_A", 0.1, 1.0, 99.0)
	Sfx.play("death")
