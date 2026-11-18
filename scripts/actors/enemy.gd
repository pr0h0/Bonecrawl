class_name Enemy
extends Actor
## Skeleton enemies. One script, behaviour picked by `kind`:
## minion (swarm melee), warrior (shielded front), rogue (lunging dasher),
## archer (crossbow), mage (caster that revives fallen skeletons), golem (slow giant: slam + charge),
## necromancer (summoner that blinks away), mimic, and the bosses (see BOSSES).

const PROJECTILE := preload("res://scripts/objects/projectile.gd")

const TYPES := {
	"minion": {"model": "Skeleton_Minion", "hp": 32, "speed": 3.6, "dmg": 9, "range": 1.7, "cd": 1.3, "windup": 0.45,
		"weapon_r": "Skeleton_Blade", "weapon_l": "", "gold": [1, 3], "anim": "Melee_1H_Attack_Chop"},
	"warrior": {"model": "Skeleton_Warrior", "hp": 75, "speed": 2.9, "dmg": 15, "range": 2.1, "cd": 1.6, "windup": 0.6,
		"weapon_r": "Skeleton_Axe", "weapon_l": "Skeleton_Shield_Large_A", "gold": [3, 6], "anim": "Melee_1H_Attack_Chop", "shield": true},
	"rogue": {"model": "Skeleton_Rogue", "hp": 42, "speed": 7.6, "dmg": 13, "range": 2.0, "cd": 2.2, "windup": 0.5,
		"weapon_r": "Skeleton_Blade", "weapon_l": "Skeleton_Blade", "gold": [2, 4], "anim": "Melee_Dualwield_Attack_Stab", "lunge": true},
	"archer": {"model": "Skeleton_Rogue", "hp": 36, "speed": 4.6, "dmg": 10, "range": 13.0, "cd": 2.3, "windup": 0.7,
		"weapon_r": "Skeleton_Crossbow", "weapon_l": "", "gold": [2, 4], "anim": "Ranged_1H_Shoot", "ranged": "enemy_arrow", "keep": 8.0},
	"mage": {"model": "Skeleton_Mage", "hp": 48, "speed": 3.8, "dmg": 11, "range": 12.0, "cd": 2.6, "windup": 0.8,
		"weapon_r": "Skeleton_Staff", "weapon_l": "", "gold": [3, 6], "anim": "Ranged_Magic_Shoot", "ranged": "enemy_bolt", "keep": 9.0, "reviver": true},
	"golem": {"model": "Skeleton_Golem", "hp": 300, "speed": 2.7, "dmg": 26, "range": 3.2, "cd": 2.4, "windup": 1.0,
		"weapon_r": "Skeleton_Golem_Axe", "weapon_l": "", "gold": [8, 14], "anim": "Melee_2H_Attack", "scale": 0.72, "heavy": true},
	"necromancer": {"model": "Necromancer", "hp": 80, "speed": 3.6, "dmg": 12, "range": 13.0, "cd": 2.6, "windup": 0.7,
		"weapon_r": "Skeleton_Staff", "weapon_l": "", "gold": [6, 10], "anim": "Ranged_Magic_Shoot", "ranged": "enemy_skull", "keep": 10.0, "reviver": true},
	"boss": {"model": "Skeleton_Warrior", "hp": 1700, "speed": 3.3, "dmg": 20, "range": 3.2, "cd": 1.4, "windup": 0.75,
		"weapon_r": "Skeleton_Axe", "weapon_l": "Skeleton_Shield_Large_B", "gold": [80, 120], "anim": "Melee_2H_Attack_Chop", "scale": 2.1},
}

## Deeper bosses: overrides on top of TYPES.boss (the Bone King).
const BOSS_DATA := {
	"vampire": {"model": "Vampire", "path": "res://assets/characters/bosses/Vampire.glb", "hp": 1500, "speed": 4.2, "dmg": 18,
		"range": 2.6, "weapon_r": "Vampire_Sword", "weapon_l": "", "prop_dir": "res://assets/characters/bosses/%s.gltf", "scale": 1.9,
		"summon": ["rogue", "rogue", "archer"], "glow": Color(1, 0.15, 0.25)},
	"black_knight": {"model": "BlackKnight", "path": "res://assets/characters/bosses/BlackKnight.glb", "hp": 1600, "speed": 3.4, "dmg": 24,
		"range": 3.6, "weapon_r": "BlackKnight_Sword_Large", "weapon_l": "BlackKnight_Shield_Large", "prop_dir": "res://assets/characters/bosses/%s.gltf",
		"scale": 0.95, "shield": true, "shield_mult": 0.5, "summon": ["warrior", "warrior", "archer"], "glow": Color(0.5, 0.6, 1.0)},
	"lich": {"model": "Necromancer", "path": "res://assets/characters/skeletons/Necromancer.glb", "hp": 1400, "speed": 3.6, "dmg": 18,
		"range": 13.0, "weapon_r": "Skeleton_Staff", "weapon_l": "", "scale": 1.9, "summon": ["minion", "minion", "mage", "golem"],
		"glow": Color(0.7, 0.3, 1.0)},
}

var kind := "minion"
var boss_id := ""
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
var guard := false              # melee that body-blocks for a ranged ally
var winded_until := 0.0         # dashers are exposed after a lunge
var rooted_until := 0.0         # Druid's Entangle
var _reposition_until := 0.0
var _lunge_hit := false
var _summon_timer := 4.0
var _blink_cd := 0.0
var summons: Array = []
var _blink_to := Vector3.ZERO


func setup(kind_: String, floor_num: int, is_elite := false) -> void:
	kind = kind_
	data = TYPES[kind]
	if kind == "boss":
		boss_id = Game.boss_for_floor(floor_num)
		if BOSS_DATA.has(boss_id):
			data = data.merged(BOSS_DATA[boss_id], true)
	elite = is_elite
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var sc: float = data.get("scale", 1.0) * (1.25 if elite else 1.0)
	radius = 0.5 * sc
	add_capsule(0.45 * sc, 1.8 * sc)
	setup_model(data.get("path", "res://assets/characters/skeletons/%s.glb" % data.model), sc)
	var wr: String = data.weapon_r
	var wl: String = data.weapon_l
	# a little variety in what the rank and file carry
	if kind == "minion":
		wr = ["Skeleton_Blade", "Skeleton_Blade", "Skeleton_Axe", "Skeleton_Dagger", "Skeleton_Mace"][randi() % 5]
		if randf() < 0.25:
			wl = "Skeleton_Shield_Small_A" if randf() < 0.5 else "Skeleton_Shield_Small_B"
	elif kind == "warrior":
		wr = ["Skeleton_Axe", "Skeleton_Mace", "Skeleton_Mace_Large"][randi() % 3]
		wl = ["Skeleton_Shield_Large_A", "Skeleton_Shield_Large_A", "Skeleton_Shield_Small_A"][randi() % 3]
	elif kind == "rogue" and randf() < 0.5:
		wr = "Skeleton_Dagger"
		wl = "Skeleton_Dagger"
	var wpref: String = data.get("prop_dir", Models.SKEL_PROP)
	if wr != "":
		Models.attach(model, wpref % wr, "handslot.r")
	if wl != "":
		Models.attach(model, wpref % wl, "handslot.l")
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
	guard = (kind == "warrior" and randf() < 0.6) or (kind == "minion" and randf() < 0.3)
	if elite:
		_make_elite_glow(Color(0.7, 0.3, 1.0))
	if kind == "boss":
		_make_elite_glow(data.get("glow", Color(1.0, 0.3, 0.1)))


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
	if Models.is_large(model) or not anim.has_animation("special/Skeletons_Awaken_Floor"):
		# big ones (no awaken clip) heave up out of the floor
		visual.position.y = -3.0
		var tw := create_tween()
		tw.tween_property(visual, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		play("general/Idle_A")
		state_until = time + 1.3
		Fx.dust(global_position, 30)
		Fx.shake(0.3, 0.3)
		Sfx.play("spawn", -2.0)
		invulnerable_until = time + 0.8
		return
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
		if time >= rooted_until:
			play_loop("general/Hit_B")
		apply_motion(Vector3.ZERO, delta)
		if rooted_until > 0.0 and time + delta >= rooted_until:
			tint(Color.WHITE, 0.0)
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
			desired = _attack_dir * 15.0
			if not _lunge_hit and _melee_check(1.7, 100.0, data.dmg * damage_mult):
				_lunge_hit = true
			if time >= state_until:
				# out of breath: stands still and takes extra damage
				state = "winded"
				state_until = time + 1.3
				winded_until = state_until
				play("general/Hit_B", 0.1, 0.5, 1.3)
				tint(Color(0.4, 0.55, 1.0), 0.35)
				Fx.text(global_position + Vector3.UP * 2.4, "WINDED", Color(0.6, 0.75, 1.0), 34)
		"charge":
			desired = _attack_dir * 15.0
			if not _lunge_hit and target and not target.dead and target.global_position.distance_to(global_position) < 2.2 * model.scale.x:
				_lunge_hit = true
				target.take_damage(data.dmg * damage_mult * 1.2, global_position, 16.0, self)
				Fx.shake(0.5, 0.2)
			for b in get_tree().get_nodes_in_group("breakables"):
				if b.global_position.distance_to(global_position) < 2.0:
					b.call("smash")
			if time >= state_until or (get_slide_collision_count() > 0 and time > state_until - 0.5):
				state = "winded"
				state_until = time + 1.6
				winded_until = state_until
				play("general/Hit_A", 0.1, 0.4, 1.6)
				tint(Color(0.4, 0.55, 1.0), 0.35)
				Fx.dust(global_position, 20)
				Fx.text(global_position + Vector3.UP * 3.2, "WINDED", Color(0.6, 0.75, 1.0), 40)
		"winded":
			if time >= state_until:
				tint(Color.WHITE, 0.0)
				state = "chase"
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


func _flee_dir(to_player: Vector3) -> Vector3:
	## Away from the hero, bent along the walls so they don't back into a corner.
	var away := -to_player
	if room and room.get("spawn_area") != null:
		var area: Rect2 = room.spawn_area
		var p := Vector2(position.x, position.z)
		var center := area.get_center()
		var margin := 2.5
		if p.x < area.position.x + margin or p.x > area.end.x - margin or p.y < area.position.y + margin or p.y > area.end.y - margin:
			var side := to_player.cross(Vector3.UP) * _strafe
			var to_c := Vector3(center.x - p.x, 0, center.y - p.y).normalized()
			away = (side * 1.2 + to_c * 0.6 + away * 0.2)
	return away.normalized()


func _guard_post() -> Vector3:
	if not guard or target == null:
		return Vector3.INF
	var best: Node3D = null
	var best_d := 14.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or e.dead or not e.data.has("ranged") and e.kind != "necromancer":
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return Vector3.INF
	var to_p := target.global_position - best.global_position
	to_p.y = 0
	if to_p.length() < 3.5:
		return Vector3.INF
	return best.global_position + to_p.normalized() * 2.6


func stagger(duration: float) -> void:
	## Combo finishers knock regular skeletons out of their swing.
	if dead or kind in ["boss", "golem"] or data.get("boss", false):
		return
	stunned_until = maxf(stunned_until, time + duration)
	if state == "windup":
		state = "recover"
		state_until = time + 0.2
		_clear_aim_line()
		if _telegraph and is_instance_valid(_telegraph):
			_telegraph.queue_free()


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
	if kind == "necromancer":
		_blink_cd -= delta
		_summon_timer -= delta
		if dist < 4.0 and _blink_cd <= 0.0:
			_blink_away()
			return Vector3.ZERO
		if _summon_timer <= 0.0:
			_summon_timer = randf_range(7.0, 9.0)
			summons = summons.filter(func(x): return is_instance_valid(x) and not x.dead)
			if summons.size() < 4:
				_summon_minions(2)
				return Vector3.ZERO
	if data.has("ranged"):
		var keep: float = data.keep
		if kind in ["mage", "necromancer"] and data.get("reviver", false) and revives_left > 0 and attack_timer < 1.5:
			var corpse := _find_corpse()
			if corpse:
				_revive(corpse)
				return Vector3.ZERO
		if dist < keep - 3.0:
			# too close: run (they are nearly as fast as you, so chasing them is a choice)
			desired = _flee_dir(dir) * move_speed * 1.15
		elif dist > keep + 1.5:
			desired = dir * move_speed
		elif time < _reposition_until:
			desired = dir.cross(Vector3.UP) * _strafe * move_speed * 0.9
		else:
			desired = dir.cross(Vector3.UP) * _strafe * move_speed * 0.4
			if randf() < delta * 0.4:
				_strafe = -_strafe
		face(dir, false, delta)
		if attack_timer <= 0.0 and dist < float(data.range) + 2.0 and dist > 3.0:
			_begin_windup(dir)
			return Vector3.ZERO
	elif kind == "rogue":
		# dashers circle at a distance and outrun you; they only commit when their dash is ready
		if attack_timer <= 0.0:
			if dist < 6.5:
				face(dir, true)
				_begin_windup(dir)
				return Vector3.ZERO
			desired = dir * move_speed
		elif dist < 4.5:
			desired = _flee_dir(dir) * move_speed * 0.9
		else:
			desired = (dir.cross(Vector3.UP) * _strafe * 0.8 + dir * (0.4 if dist > 7.0 else -0.1)) * move_speed * 0.7
			if randf() < delta * 0.5:
				_strafe = -_strafe
		face(dir, false, delta)
	else:
		var reach: float = data.range
		var post := _guard_post()
		if post != Vector3.INF and dist > 4.5:
			# bodyguard: stand between the hero and the archer/mage it protects
			var to_post := post - global_position
			to_post.y = 0
			desired = to_post.normalized() * move_speed if to_post.length() > 0.6 else Vector3.ZERO
			face(dir, false, delta)
		else:
			if dist > reach * 0.85:
				desired = dir * move_speed
			elif kind == "boss" and dist < 1.6:
				desired = -dir * 1.0
			if boss_id == "lich":
				# the Lich hovers at range instead of closing in
				desired = (-dir if dist < 7.0 else (dir if dist > 11.0 else dir.cross(Vector3.UP) * _strafe * 0.5)) * move_speed
				if attack_timer <= 0.0:
					_begin_windup(dir)
					return Vector3.ZERO
			face(dir, false, delta)
			if attack_timer <= 0.0 and dist < reach + 0.4:
				_begin_windup(dir)
				return Vector3.ZERO
			if kind == "golem" and attack_timer <= 0.0 and dist > 6.0 and dist < 13.0:
				_begin_windup(dir)
				return Vector3.ZERO
	desired += _separation() * 4.0
	if desired.length() > 0.3:
		var walk := "special/Skeletons_Walking" if kind in ["minion", "warrior", "boss"] else "move/Running_B"
		if data.get("heavy", false):
			walk = "move/Walking_A"
		play_loop(walk, 0.2, clampf(desired.length() / 3.0, 0.7, 1.6))
	else:
		play_loop("general/Idle_B" if kind != "boss" or boss_id == "lich" else "melee/Melee_2H_Idle")
	return desired


func _begin_windup(dir: Vector3) -> void:
	_attack_dir = dir
	if kind == "boss":
		_boss_choose()
		return
	if kind == "golem":
		_golem_choose()
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
		tint(Color(0.5, 1, 0.4) if kind == "mage" else (Color(0.75, 0.4, 1.0) if kind == "necromancer" else Color(1, 0.8, 0.3)), 0.25)
		_show_aim_line(w)


func _strike() -> void:
	attack_timer = float(data.cd) * randf_range(0.85, 1.2)
	tint(Color.WHITE, 0.0)
	_clear_aim_line()
	if kind == "boss":
		_boss_strike()
		return
	if kind == "golem":
		_golem_strike()
		return
	if kind == "rogue":
		state = "lunge"
		state_until = time + 0.3
		_lunge_hit = false
		Sfx.play("swing", -6.0)
		return
	state = "recover"
	state_until = time + 0.45
	if data.has("ranged"):
		if target == null:
			return
		var p := PROJECTILE.new()
		p.kind = data.ranged
		p.speed = 12.0 if kind == "mage" else 17.0
		if kind == "necromancer":
			p.speed = 7.5
			p.homing = 1.5
			p.life = 4.0
		p.damage = data.dmg * damage_mult
		p.from_player = false
		# fire along the direction locked in when the windup began, so the shot can be dodged
		p.direction = _attack_dir
		p.source = self
		get_parent().add_child(p)
		p.global_position = global_position + Vector3.UP * 1.3 * model.scale.x + p.direction * 0.7
		Sfx.play("magic" if kind in ["mage", "necromancer"] else "bow", -8.0)
		_reposition_until = time + 1.0
		_strafe = -_strafe
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
	var col := Color(0.4, 1.0, 0.3) if kind == "mage" else (Color(0.7, 0.3, 1.0) if kind == "necromancer" else Color(1.0, 0.35, 0.2))
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
	if dead or kind in ["boss", "golem"] or data.get("boss", false):
		duration *= 0.35
	stunned_until = maxf(stunned_until, time + duration)
	if state == "windup" or state == "lunge":
		state = "recover"
		state_until = time + 0.2
		_clear_aim_line()
		if _telegraph and is_instance_valid(_telegraph):
			_telegraph.queue_free()
	Fx.text(global_position + Vector3.UP * 2.6, "STUNNED", Color(1, 0.95, 0.4), 40)


func root(duration: float) -> void:
	## Held in place by vines: can't move or attack.
	if dead:
		return
	if kind in ["boss", "golem"] or data.get("boss", false):
		duration *= 0.35
	rooted_until = maxf(rooted_until, time + duration)
	stunned_until = maxf(stunned_until, time + duration)
	if state in ["windup", "lunge", "charge"]:
		state = "recover"
		state_until = time + 0.2
		_clear_aim_line()
		if _telegraph and is_instance_valid(_telegraph):
			_telegraph.queue_free()
	tint(Color(0.35, 0.85, 0.3), 0.3)


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


# ---------------- golem ----------------

func _golem_choose() -> void:
	var to_t := target.global_position.distance_to(global_position) if target else 99.0
	state = "windup"
	if to_t > 6.0 and randf() < 0.65:
		_boss_move = "charge"
		var w := 0.9
		state_until = time + w
		play("general/Idle_A", 0.1)
		tint(Color(1, 0.4, 0.2), 0.3)
		_show_aim_line(w)
		Sfx.play("boss", -8.0)
	else:
		_boss_move = "slam"
		var w: float = data.windup
		state_until = time + w
		play("melee/Melee_2H_Slam", 0.08, clampf(clip_length("melee/Melee_2H_Slam") * 0.55 / w, 0.5, 2.0), w + 0.6)
		_telegraph = Fx.ring(global_position + _attack_dir * 1.6, 3.2, w)


func _golem_strike() -> void:
	if _boss_move == "charge":
		state = "charge"
		state_until = time + 0.75
		_lunge_hit = false
		play("move/Running_A", 0.05, 1.6)
		Sfx.play("swing_heavy")
		return
	var center := global_position + _attack_dir * 1.6
	Fx.big(center, 1.5)
	Fx.dust(center, 26)
	Fx.shake(0.55, 0.25)
	Sfx.play("explosion", -4.0)
	if target and not target.dead and target.global_position.distance_to(center) < 3.6:
		target.take_damage(data.dmg * damage_mult, center, 12.0, self)
	for b in get_tree().get_nodes_in_group("breakables"):
		if b.global_position.distance_to(center) < 3.4:
			b.call("smash")
	state = "recover"
	state_until = time + 0.9


# ---------------- necromancer ----------------

func _summon_minions(n: int) -> void:
	state = "casting"
	state_until = time + 1.3
	play("ranged/Ranged_Magic_Summon", 0.1, 1.0, 1.3)
	Fx.sparkle(global_position + Vector3.UP * 1.5, Color(0.7, 0.3, 1.0))
	Sfx.play("magic", -4.0)
	await get_tree().create_timer(0.9, false).timeout
	if dead or room == null or not room.has_method("spawn_enemy"):
		return
	for i in n:
		var off := Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
		var e: Enemy = room.spawn_enemy("minion", position + off)
		if e:
			summons.append(e)


func _blink_away() -> void:
	_blink_cd = 4.5
	if room == null or not room.has_method("_random_spawn_point"):
		return
	Fx.smoke(global_position)
	Sfx.play("dodge", -2.0)
	var p: Vector3 = room._random_spawn_point()
	position = Vector3(p.x, position.y, p.z)
	Fx.sparkle(global_position + Vector3.UP, Color(0.7, 0.3, 1.0))
	attack_timer = maxf(attack_timer, 0.8)


# ---------------- boss ----------------

func _boss_choose() -> void:
	var to_t := target.global_position.distance_to(global_position) if target else 99.0
	var r := randf()
	if boss_phase < 2 and hp < max_hp * (0.66 if boss_phase == 0 else 0.33):
		boss_phase += 1
		_boss_move = "summon"
	elif boss_id == "vampire":
		_boss_move = "blink" if r < 0.4 else ("blood_fan" if r < 0.7 or to_t > 5.0 else "slam")
	elif boss_id == "black_knight":
		_boss_move = "charge" if to_t > 6.0 and r < 0.6 else ("shockwave" if r < 0.35 else "cleave")
	elif boss_id == "lich":
		_boss_move = "nova" if to_t < 5.0 and r < 0.6 else ("blink" if r < 0.2 else "skull_volley")
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
		"blink":
			# vanish, then strike from behind the hero
			state_until = time + 0.75
			Fx.smoke(global_position)
			Sfx.play("dodge")
			visual.visible = false
			invulnerable_until = time + 0.8
			var behind: Vector3 = target.global_position - target.forward() * 1.8
			_telegraph = Fx.ring(behind, 2.4, 0.75, Color(data.glow.r, data.glow.g, data.glow.b, 0.55))
			_attack_dir = (target.global_position - behind).normalized()
			_blink_to = behind
		"blood_fan", "skull_volley", "shockwave":
			var w := 0.75 if boss_phase < 2 else 0.55
			state_until = time + w
			play("ranged/Ranged_Magic_Spellcasting" if _boss_move != "shockwave" else "melee/Melee_2H_Slam", 0.08, 1.2, w + 0.3)
			tint(data.get("glow", Color.RED), 0.3)
			Fx.sparkle(global_position + Vector3.UP * 2.5, data.get("glow", Color.RED))
		"cleave":
			var w := 0.8 if boss_phase < 2 else 0.6
			state_until = time + w
			play("melee/Melee_2H_Attack", 0.08, clampf(clip_length("melee/Melee_2H_Attack") * 0.5 / w, 0.5, 2.0), w + 0.5)
			_telegraph = Fx.ring(global_position + _attack_dir * 2.4, 3.6, w)
		"charge":
			state_until = time + 0.85
			tint(Color(0.5, 0.6, 1.0), 0.3)
			_show_aim_line(0.85)
			Sfx.play("boss", -6.0)
		"nova":
			var w := 1.1
			state_until = time + w
			play("ranged/Ranged_Magic_Summon", 0.1, 1.0, w + 0.3)
			_telegraph = Fx.ring(global_position, 5.5, w, Color(0.7, 0.3, 1.0, 0.5))
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
				var pool: Array = data.get("summon", ["minion", "minion", "rogue", "archer"])
				for i in 3 + boss_phase:
					var off := Vector3(randf_range(-5, 5), 0, randf_range(-3, 4))
					room.spawn_enemy(pool[i % pool.size()], position + off)
			state = "recover"
			state_until = time + 0.6
		"blink":
			position = Vector3(_blink_to.x - get_parent().global_position.x, position.y, _blink_to.z - get_parent().global_position.z)
			visual.visible = true
			face(_attack_dir, true)
			play("melee/Melee_1H_Attack_Slice_Horizontal", 0.02, 1.6, 0.5)
			Fx.sparkle(global_position + Vector3.UP, data.glow)
			Sfx.play("swing_heavy")
			if target and not target.dead and target.global_position.distance_to(_blink_to) < 2.6:
				var a := target.take_damage(data.dmg * damage_mult, _blink_to, 10.0, self)
				if a > 0 and boss_id == "vampire":
					heal_self(a * 2.0)
			state = "recover"
			state_until = time + 0.8
		"blood_fan", "skull_volley":
			var n := 9 if _boss_move == "blood_fan" else 3
			var spread := 110.0 if _boss_move == "blood_fan" else 50.0
			for wave in (2 if boss_phase >= 2 else 1):
				for i in n:
					var ang := deg_to_rad(-spread * 0.5 + i * spread / maxf(n - 1, 1) + wave * 7.0)
					_shoot("blood_bolt" if _boss_move == "blood_fan" else "enemy_skull", _attack_dir.rotated(Vector3.UP, ang), 0.55)
			state = "recover"
			state_until = time + 0.7
		"shockwave":
			Fx.big(global_position + _attack_dir * 2.0, 1.4)
			Fx.shake(0.6, 0.3)
			Sfx.play("explosion", -2.0)
			for i in 5:
				var p := _shoot("enemy_bolt", _attack_dir.rotated(Vector3.UP, deg_to_rad(-40 + i * 20)), 0.6)
				p.speed = 10.0
			state = "recover"
			state_until = time + 0.8
		"cleave":
			var center := global_position + _attack_dir * 2.4
			Fx.big(center, 1.3)
			Fx.shake(0.5, 0.25)
			Sfx.play("swing_heavy")
			if target and not target.dead and target.global_position.distance_to(center) < 4.0:
				target.take_damage(data.dmg * damage_mult, center, 12.0, self)
			state = "recover"
			state_until = time + (0.7 if boss_phase < 2 else 0.5)
		"charge":
			state = "charge"
			state_until = time + 0.8
			_lunge_hit = false
			play("move/Running_A", 0.05, 1.6)
			Sfx.play("swing_heavy")
		"nova":
			Fx.explosion(global_position, 5.0)
			Fx.burst(global_position + Vector3.UP, Color(0.7, 0.3, 1.0), 40, 9.0, 0.2, 0.6, -2.0, 3.0)
			Fx.shake(0.7, 0.3)
			Sfx.play("explosion")
			if target and not target.dead and target.global_position.distance_to(global_position) < 5.8:
				target.take_damage(data.dmg * damage_mult * 1.2, global_position, 14.0, self)
			state = "recover"
			state_until = time + 0.8


func _shoot(proj_kind: String, dir: Vector3, dmg_scale: float) -> Node3D:
	var p := PROJECTILE.new()
	p.kind = proj_kind
	p.speed = 9.0
	p.damage = data.dmg * damage_mult * dmg_scale
	p.from_player = false
	p.direction = dir
	p.source = self
	if proj_kind == "enemy_skull":
		p.homing = 1.2
		p.life = 4.0
		p.speed = 7.5
	get_parent().add_child(p)
	p.global_position = global_position + Vector3.UP * 1.4 + dir * 1.2
	return p


func heal_self(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	Fx.number(global_position + Vector3.UP * 3.5, amount, Color(1, 0.3, 0.4))


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
	if data.get("shield", false) and not state in ["windup", "recover", "winded", "charge", "stunned"] and time >= stunned_until:
		var to := from - global_position
		to.y = 0
		var is_skill: bool = source is Node and source.get("explode_radius") != null and source.get("explode_radius") > 0
		if to.length() > 0.01 and forward().angle_to(to.normalized()) < deg_to_rad(55) and not is_skill:
			Sfx.play("block", -4.0)
			Fx.text(global_position + Vector3.UP * 2.4, "BLOCK", Color(0.8, 0.85, 1.0), 40)
			return amount * 0.3
	if kind == "boss" and state == "spawning":
		return 0.0
	if state == "winded":
		amount *= 1.5
	if time < rooted_until and Game.has_legend("heartwood"):
		amount *= 2.0
	return amount


func on_hurt(_amount: float) -> void:
	if data.get("heavy", false) or data.get("boss", false):
		knockback *= 0.15
	if state == "spawning" or kind == "boss" or data.get("heavy", false) or data.get("boss", false):
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
