class_name Enemy
extends Actor
## Skeleton enemies. One script, behaviour picked by `kind`:
## minion (swarm melee), warrior (shielded front), rogue (lunging dasher),
## archer (crossbow), mage (caster that revives fallen skeletons), mimic, boss.

const PROJECTILE := preload("res://scripts/objects/projectile.gd")

const TYPES := {
	"minion": {"model": "Skeleton_Minion", "hp": 32, "speed": 3.6, "dmg": 9, "range": 1.7, "cd": 1.3, "windup": 0.45,
		"weapon_r": "Skeleton_Blade", "weapon_l": "", "gold": [1, 3], "anim": "Melee_1H_Attack_Chop"},
	"warrior": {"model": "Skeleton_Warrior", "hp": 75, "speed": 2.9, "dmg": 15, "range": 2.1, "cd": 1.6, "windup": 0.6,
		"weapon_r": "Skeleton_Axe", "weapon_l": "Skeleton_Shield_Large_A", "gold": [3, 6], "anim": "Melee_1H_Attack_Chop", "shield": true},
	"rogue": {"model": "Skeleton_Rogue", "hp": 42, "speed": 5.2, "dmg": 12, "range": 2.0, "cd": 1.6, "windup": 0.5,
		"weapon_r": "Skeleton_Blade", "weapon_l": "Skeleton_Blade", "gold": [2, 4], "anim": "Melee_Dualwield_Attack_Stab", "lunge": true},
	"archer": {"model": "Skeleton_Rogue", "hp": 36, "speed": 3.2, "dmg": 10, "range": 13.0, "cd": 2.3, "windup": 0.7,
		"weapon_r": "Skeleton_Crossbow", "weapon_l": "", "gold": [2, 4], "anim": "Ranged_1H_Shoot", "ranged": "enemy_arrow", "keep": 8.0},
	"mage": {"model": "Skeleton_Mage", "hp": 48, "speed": 3.0, "dmg": 11, "range": 12.0, "cd": 2.6, "windup": 0.8,
		"weapon_r": "Skeleton_Staff", "weapon_l": "", "gold": [3, 6], "anim": "Ranged_Magic_Shoot", "ranged": "enemy_bolt", "keep": 9.0, "reviver": true},
	"boss": {"model": "Skeleton_Warrior", "hp": 1700, "speed": 3.3, "dmg": 20, "range": 3.2, "cd": 1.4, "windup": 0.75,
		"weapon_r": "Skeleton_Axe", "weapon_l": "Skeleton_Shield_Large_B", "gold": [80, 120], "anim": "Melee_2H_Attack_Chop", "scale": 2.1},
}

var kind := "minion"
var data: Dictionary
var target: Player
var radius := 0.5
var attack_timer := 1.0
var state := "spawning"      # spawning | chase | windup | recover | dead | casting
var state_until := 0.0
var elite := false
var lost_target_until := 0.0
var revives_left := 2
var damage_mult := 1.0
var _strafe := 1.0
var _attack_dir := Vector3.FORWARD
var _telegraph: Node3D
var boss_phase := 0
var _boss_move := ""
var corpse_time := 0.0
var revived := false
var room: Node   # owning room (for minion spawns)
var spin_tick := 0.0
var stunned_until := 0.0
var slowed_until := 0.0
var _dots: Array = []          # [until, dps, color]
var _dot_tick := 0.0
var _aim_line: Node3D


func setup(kind_: String, floor_num: int, is_elite := false) -> void:
	kind = kind_
	data = TYPES[kind]
	elite = is_elite
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var sc: float = data.get("scale", 1.0) * (1.25 if elite else 1.0)
	radius = 0.5 * sc
	add_capsule(0.45 * sc, 1.8 * sc)
	setup_model("res://assets/characters/skeletons/%s.glb" % data.model, sc)
	if data.weapon_r != "":
		Models.attach(model, Models.SKEL_PROP % data.weapon_r, "handslot.r")
	if data.weapon_l != "":
		Models.attach(model, Models.SKEL_PROP % data.weapon_l, "handslot.l")
	var scaling := 1.0 + 0.4 * (floor_num - 1)
	damage_mult = (1.0 + 0.25 * (floor_num - 1)) * (1.3 if elite else 1.0)
	if kind == "boss":
		# tuned for floor 3; each endless loop (floor 6, 9...) makes him tougher
		var loop := maxi(0, floor_num / Game.FLOORS - 1)
		scaling = 1.0 + 0.6 * loop
		damage_mult = 1.0 + 0.3 * loop
	var t := Game.torment_level()
	scaling *= 1.0 + 0.3 * t
	damage_mult *= 1.0 + 0.2 * t
	max_hp = data.hp * scaling * (1.8 if elite else 1.0)
	hp = max_hp
	move_speed = data.speed * randf_range(0.92, 1.08) * (1.0 + 0.04 * t)
	attack_timer = randf_range(0.6, 1.4)
	_strafe = 1.0 if randf() < 0.5 else -1.0
	if elite:
		_make_elite_glow(Color(0.7, 0.3, 1.0))
	if kind == "boss":
		_make_elite_glow(Color(1.0, 0.3, 0.1))


func _make_elite_glow(c: Color) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 1.6
	l.omni_range = 3.5
	l.position = Vector3(0, 1.4, 0)
	add_child(l)
	var eyes := model.find_child("*Eyes*", true, false)
	if eyes is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 4.0
		(eyes as MeshInstance3D).material_override = m


func spawn_from_floor() -> void:
	## Skeletons claw out of the ground.
	state = "spawning"
	var clip := "special/Skeletons_Awaken_Floor"
	var t := clip_length(clip)
	play(clip, 0.0, 1.6, t / 1.6)
	state_until = time + t / 1.6
	Fx.dust(global_position, 18)
	Sfx.play("spawn", -6.0)
	invulnerable_until = time + 0.4


func _physics_process(delta: float) -> void:
	time += delta
	if dead:
		corpse_time += delta
		apply_motion(Vector3.ZERO, delta)
		return
	if target == null or not is_instance_valid(target):
		var ps := get_tree().get_nodes_in_group("player")
		target = ps[0] if ps.size() > 0 else null
	_process_status(delta)
	if dead:
		return
	if time < stunned_until and state != "spawning":
		play_loop("general/Hit_B")
		apply_motion(Vector3.ZERO, delta)
		return
	var desired := Vector3.ZERO
	match state:
		"spawning":
			if time >= state_until:
				state = "chase"
				if kind == "boss":
					Sfx.play("boss")
		"chase":
			desired = _chase(delta)
		"windup":
			face(_attack_dir, false, delta, 10.0)
			if kind == "rogue":
				desired = Vector3.ZERO
			if time >= state_until:
				_strike()
		"lunge":
			desired = _attack_dir * 13.0
			if time >= state_until:
				state = "recover"
				state_until = time + 0.5
		"recover":
			if time >= state_until:
				state = "chase"
		"casting":
			if time >= state_until:
				state = "chase"
		"spin":
			desired = (_to_target() * move_speed * 0.9) if target and time >= lost_target_until else Vector3.ZERO
			_boss_spin_damage(delta)
			if time >= state_until:
				state = "recover"
				state_until = time + 0.6
	if time < slowed_until:
		desired *= 0.5
	apply_motion(desired, delta)


func _to_target() -> Vector3:
	if target == null:
		return Vector3.ZERO
	var d := target.global_position - global_position
	d.y = 0
	return d.normalized() if d.length() > 0.01 else Vector3.ZERO


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or e.dead:
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0
		var dist := d.length()
		var min_d: float = radius + e.radius + 0.4
		if dist < min_d and dist > 0.01:
			push += d.normalized() * (min_d - dist) / min_d
	return push


func lose_target(duration: float) -> void:
	lost_target_until = time + duration


func _chase(delta: float) -> Vector3:
	if target == null or target.dead:
		play_loop("general/Idle_B")
		return Vector3.ZERO
	var to := target.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else Vector3.ZERO
	attack_timer -= delta
	if time < lost_target_until:
		# confused: wander slowly
		play_loop("move/Walking_B", 0.2, 0.8)
		var wander := Vector3(sin(time * 0.7 + get_instance_id()), 0, cos(time * 0.9 + get_instance_id()))
		face(wander, false, delta, 4.0)
		return wander * move_speed * 0.35
	var desired := Vector3.ZERO
	if data.has("ranged"):
		var keep: float = data.keep
		if kind == "mage" and data.get("reviver", false) and revives_left > 0 and attack_timer < 1.5:
			var corpse := _find_corpse()
			if corpse:
				_revive(corpse)
				return Vector3.ZERO
		if dist > keep + 1.5:
			desired = dir * move_speed
		elif dist < keep - 2.5:
			desired = -dir * move_speed * 0.8
		else:
			desired = dir.cross(Vector3.UP) * _strafe * move_speed * 0.5
			if randf() < delta * 0.4:
				_strafe = -_strafe
		face(dir, false, delta)
		if attack_timer <= 0.0 and dist < float(data.range) + 2.0:
			_begin_windup(dir)
			return Vector3.ZERO
	else:
		var reach: float = data.range
		if dist > reach * 0.85:
			desired = dir * move_speed
		elif kind == "boss" and dist < 1.6:
			desired = -dir * 1.0
		face(dir, false, delta)
		if attack_timer <= 0.0 and dist < reach + 0.4:
			_begin_windup(dir)
			return Vector3.ZERO
		if kind == "rogue" and attack_timer <= 0.0 and dist < 6.0:
			_begin_windup(dir)
			return Vector3.ZERO
	desired += _separation() * 4.0
	if desired.length() > 0.3:
		var walk := "special/Skeletons_Walking" if kind in ["minion", "warrior", "boss"] else "move/Running_B"
		play_loop(walk, 0.2, clampf(desired.length() / 3.0, 0.7, 1.6))
	else:
		play_loop("general/Idle_B" if kind != "boss" else "melee/Melee_2H_Idle")
	return desired


func _begin_windup(dir: Vector3) -> void:
	_attack_dir = dir
	if kind == "boss":
		_boss_choose()
		return
	state = "windup"
	var w: float = data.windup
	state_until = time + w
	var clip: String = data.anim
	var len_ := clip_length(clip)
	# play so the impact frame (~45% in) lands when the windup ends
	play(clip, 0.08, clampf(len_ * 0.45 / w, 0.6, 2.0), w + 0.3)
	if kind == "rogue":
		flash(Color(1, 0.3, 0.2), 0.4)
	if data.has("ranged"):
		tint(Color(0.5, 1, 0.4) if kind == "mage" else Color(1, 0.8, 0.3), 0.25)
		_show_aim_line(w)


func _strike() -> void:
	attack_timer = float(data.cd) * randf_range(0.85, 1.2)
	tint(Color.WHITE, 0.0)
	_clear_aim_line()
	if kind == "boss":
		_boss_strike()
		return
	if kind == "rogue":
		state = "lunge"
		state_until = time + 0.22
		Sfx.play("swing", -6.0)
		_schedule_lunge_hit()
		return
	state = "recover"
	state_until = time + 0.45
	if data.has("ranged"):
		if target == null:
			return
		var p := PROJECTILE.new()
		p.kind = data.ranged
		p.speed = 12.0 if kind == "mage" else 17.0
		p.damage = data.dmg * damage_mult
		p.from_player = false
		# fire along the direction locked in when the windup began, so the shot can be dodged
		p.direction = _attack_dir
		p.source = self
		get_parent().add_child(p)
		p.global_position = global_position + Vector3.UP * 1.3 * model.scale.x + p.direction * 0.7
		Sfx.play("magic" if kind == "mage" else "bow", -8.0)
		return
	Sfx.play("swing", -8.0)
	_melee_check(data.range + 0.5, 70.0, data.dmg * damage_mult)


func _show_aim_line(duration: float) -> void:
	## Red ground stripe showing exactly where the shot will travel.
	_clear_aim_line()
	var length := 16.0
	var root := Node3D.new()
	get_parent().add_child(root)
	root.global_position = global_position + Vector3.UP * 0.07
	root.look_at(root.global_position + _attack_dir, Vector3.UP)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.02, length)
	mi.mesh = bm
	mi.position = Vector3(0, 0, -length * 0.5 - 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var col := Color(0.4, 1.0, 0.3) if kind == "mage" else Color(1.0, 0.35, 0.2)
	mat.albedo_color = Color(col.r, col.g, col.b, 0.15)
	mi.material_override = mat
	root.add_child(mi)
	var tw := root.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.6, duration)
	_aim_line = root


func _clear_aim_line() -> void:
	if _aim_line and is_instance_valid(_aim_line):
		_aim_line.queue_free()
	_aim_line = null


# ---------------- status effects (mastery) ----------------

func stun(duration: float) -> void:
	if dead or kind == "boss":
		duration *= 0.35
	stunned_until = maxf(stunned_until, time + duration)
	if state == "windup" or state == "lunge":
		state = "recover"
		state_until = time + 0.2
		_clear_aim_line()
		if _telegraph and is_instance_valid(_telegraph):
			_telegraph.queue_free()
	Fx.text(global_position + Vector3.UP * 2.6, "STUNNED", Color(1, 0.95, 0.4), 40)


func slow(duration: float) -> void:
	slowed_until = maxf(slowed_until, time + duration)
	tint(Color(0.4, 0.6, 1.0), 0.25)


func add_dot(dps: float, duration: float, color: Color) -> void:
	for d in _dots:
		if d[2] == color:
			d[0] = maxf(d[0], time + duration)
			d[1] = maxf(d[1], dps)
			return
	_dots.append([time + duration, dps, color])


func _process_status(delta: float) -> void:
	if _dots.is_empty():
		return
	_dot_tick -= delta
	if _dot_tick > 0.0:
		return
	_dot_tick = 0.5
	var keep: Array = []
	for d in _dots:
		if time <= d[0]:
			keep.append(d)
			var dmg: float = d[1] * 0.5
			hp -= dmg
			flash(d[2], 0.45)
			Fx.number(global_position + Vector3.UP * 2.0, dmg, d[2])
			if hp <= 0.0:
				hp = 0.0
				die()
				return
	_dots = keep


func _schedule_lunge_hit() -> void:
	await get_tree().create_timer(0.12, false).timeout
	if not dead:
		_melee_check(2.0, 90.0, data.dmg * damage_mult)


func _melee_check(reach: float, half_arc_deg: float, dmg: float) -> bool:
	if target == null or target.dead:
		return false
	var to := target.global_position - global_position
	to.y = 0
	if to.length() <= reach and (to.length() < 0.5 or forward().angle_to(to.normalized()) < deg_to_rad(half_arc_deg)):
		var applied := target.take_damage(dmg, global_position, 7.0, self)
		if applied > 0:
			Fx.hit(target.global_position + Vector3.UP * 1.1)
		return true
	return false


# ---------------- reviving ----------------

func _find_corpse() -> Enemy:
	var best: Enemy = null
	var best_d := 12.0
	for e in get_tree().get_nodes_in_group("corpses"):
		if not is_instance_valid(e) or e.revived or e.kind == "boss" or e.corpse_time < 1.0:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _revive(corpse: Enemy) -> void:
	revives_left -= 1
	state = "casting"
	state_until = time + 1.4
	attack_timer = float(data.cd)
	face(corpse.global_position - global_position, true)
	play("ranged/Ranged_Magic_Summon", 0.1, 1.0, 1.4)
	Fx.sparkle(global_position + Vector3.UP, Color(0.4, 1, 0.3))
	corpse.revived = true
	await get_tree().create_timer(1.0, false).timeout
	if dead or not is_instance_valid(corpse):
		return
	corpse.resurrect()


func resurrect() -> void:
	remove_from_group("corpses")
	dead = false
	hp = max_hp * 0.5
	add_to_group("enemies")
	collision_layer = 4
	state = "spawning"
	var clip := "special/Skeletons_Death_Resurrect"
	var t := clip_length(clip)
	play(clip, 0.1, 1.2, t / 1.2)
	state_until = time + t / 1.2
	Fx.sparkle(global_position + Vector3.UP, Color(0.4, 1, 0.3))
	Sfx.play("spawn", -4.0)
	if room and room.has_method("enemy_revived"):
		room.enemy_revived(self)


# ---------------- boss ----------------

func _boss_choose() -> void:
	var to_t := target.global_position.distance_to(global_position) if target else 99.0
	var r := randf()
	if boss_phase < 2 and hp < max_hp * (0.66 if boss_phase == 0 else 0.33):
		boss_phase += 1
		_boss_move = "summon"
	elif to_t > 6.0 and r < 0.4:
		_boss_move = "leap"
	elif r < 0.3 and boss_phase >= 1:
		_boss_move = "spin"
	else:
		_boss_move = "slam"
	state = "windup"
	match _boss_move:
		"slam":
			var w := 0.85 if boss_phase < 2 else 0.65
			state_until = time + w
			play("melee/Melee_2H_Attack_Chop", 0.08, clip_length("melee/Melee_2H_Attack_Chop") * 0.5 / w, w + 0.5)
			_telegraph = Fx.ring(global_position + _attack_dir * 2.4, 2.8, w)
		"leap":
			state_until = time + 0.9
			play("melee/Melee_1H_Attack_Jump_Chop", 0.08, 1.0, 1.4)
			var land := target.global_position
			_attack_dir = (land - global_position).normalized()
			_telegraph = Fx.ring(land, 3.2, 0.9)
			var tw := create_tween()
			tw.tween_interval(0.3)
			tw.tween_property(self, "global_position", Vector3(land.x, global_position.y, land.z) - _attack_dir * 1.2, 0.55).set_trans(Tween.TRANS_QUAD)
		"spin":
			state_until = time + 0.5
			play("melee/Melee_2H_Attack_Spin", 0.08, 1.0, 0.6)
			_telegraph = Fx.ring(global_position, 3.6, 0.5, Color(1, 0.5, 0.1, 0.5))
		"summon":
			state_until = time + 1.3
			play("ranged/Ranged_Magic_Summon", 0.1, 1.0, 1.4)
			Sfx.play("boss")
			Fx.sparkle(global_position + Vector3.UP * 2, Color(1, 0.4, 0.1))
			Fx.shake(0.4, 0.5)


func _boss_strike() -> void:
	match _boss_move:
		"slam", "leap":
			var center := global_position + _attack_dir * (2.4 if _boss_move == "slam" else 1.2)
			var radius_ := 2.8 if _boss_move == "slam" else 3.2
			Fx.big(center, 1.6)
			Fx.dust(center, 30)
			Fx.shake(0.7, 0.3)
			Sfx.play("explosion")
			if target and not target.dead and target.global_position.distance_to(center) < radius_ + 0.4:
				target.take_damage(data.dmg * damage_mult, center, 12.0, self)
			state = "recover"
			state_until = time + (0.9 if boss_phase < 2 else 0.6)
		"spin":
			state = "spin"
			state_until = time + 2.2
			play("melee/Melee_2H_Attack_Spinning", 0.1, 1.2, 2.2)
			spin_tick = 0.0
		"summon":
			if room and room.has_method("spawn_enemy"):
				for i in 3 + boss_phase:
					var off := Vector3(randf_range(-5, 5), 0, randf_range(-3, 4))
					room.spawn_enemy(["minion", "minion", "rogue", "archer"][i % 4], global_position + off)
			state = "recover"
			state_until = time + 0.6


func _boss_spin_damage(delta: float) -> void:
	spin_tick -= delta
	if spin_tick > 0:
		return
	spin_tick = 0.35
	Sfx.play("swing_heavy", -6.0)
	if target and not target.dead and target.global_position.distance_to(global_position) < 3.8:
		target.take_damage(data.dmg * damage_mult * 0.45, global_position, 9.0, self)


# ---------------- damage ----------------

func modify_incoming(amount: float, from: Vector3, source: Node) -> float:
	if data.get("shield", false) and state != "windup" and state != "recover":
		var to := from - global_position
		to.y = 0
		var is_skill: bool = source is Node and source.get("explode_radius") != null and source.get("explode_radius") > 0
		if to.length() > 0.01 and forward().angle_to(to.normalized()) < deg_to_rad(55) and not is_skill:
			Sfx.play("block", -4.0)
			Fx.text(global_position + Vector3.UP * 2.4, "BLOCK", Color(0.8, 0.85, 1.0), 40)
			return amount * 0.3
	if kind == "boss" and state == "spawning":
		return 0.0
	return amount


func on_hurt(_amount: float) -> void:
	if state == "spawning" or kind == "boss":
		return
	if state == "chase" or state == "recover":
		play("general/Hit_A", 0.05, 1.6, 0.25)
	if state == "windup" and kind == "minion":
		# minions get interrupted
		state = "recover"
		state_until = time + 0.35
		_clear_aim_line()
		if _telegraph and is_instance_valid(_telegraph):
			_telegraph.queue_free()


func die() -> void:
	if dead:
		return
	super.die()
	remove_from_group("enemies")
	collision_layer = 0
	_dots.clear()
	_clear_aim_line()
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	tint(Color.WHITE, 0.0)
	var clip := "special/Skeletons_Death" if kind != "boss" else "general/Death_A"
	play(clip, 0.08, 1.0, 99.0)
	Sfx.play("death", -6.0 if kind != "boss" else 2.0)
	Fx.dust(global_position, 12)
	if target and is_instance_valid(target):
		target.on_kill()
	corpse_time = 0.0
	if kind in ["minion", "warrior", "rogue", "archer"] and not revived:
		add_to_group("corpses")
	else:
		_fade_out(2.0)


func _fade_out(delay: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(self) or not dead:
		return
	remove_from_group("corpses")
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 1.5, 1.2)
	tw.tween_callback(queue_free)


func cleanup_corpse() -> void:
	if dead:
		_fade_out(0.1)
