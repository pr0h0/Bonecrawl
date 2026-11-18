class_name Actor
extends CharacterBody3D
## Shared body for the player and every enemy: health, hit flash, knockback, animation helpers.

signal died(actor: Actor)
signal damaged(actor: Actor, amount: float)

var max_hp := 100.0
var hp := 100.0
var move_speed := 5.0
var dead := false
var visual: Node3D          # rotates to face; holds the character model
var model: Node3D           # KayKit character root
var anim: AnimationPlayer
var knockback := Vector3.ZERO
var facing := Vector3.FORWARD
var gravity := 30.0
var invulnerable_until := 0.0
var _flash_mat: StandardMaterial3D
var _current_anim := ""
var _anim_lock_until := 0.0
var time := 0.0


func setup_model(model_path: String, scale := 1.0) -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	model = Models.character(model_path)
	model.scale = Vector3.ONE * scale
	visual.add_child(model)
	anim = model.get_node("AnimationPlayer")
	var ico := model.find_child("Icosphere", true, false)
	if ico:
		ico.visible = false
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1, 1, 1, 0)
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for m in Models.meshes_of(model):
		(m as MeshInstance3D).material_overlay = _flash_mat
	_add_blob_shadow(scale)


static var _blob_mat: StandardMaterial3D

## Low graphics turns real shadows off; a soft dark disc keeps characters grounded.
func _add_blob_shadow(sc: float) -> void:
	if _blob_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.75))
		g.set_color(1, Color(0, 0, 0, 0))
		g.add_point(0.45, Color(0, 0, 0, 0.6))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.albedo_texture = tex
	var blob := MeshInstance3D.new()
	blob.name = "BlobShadow"
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * 1.9 * sc
	blob.mesh = pm
	blob.material_override = _blob_mat
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.position.y = 0.06
	add_child(blob)
	blob.visible = Game.low_quality()
	Game.quality_changed.connect(func(): if is_instance_valid(blob): blob.visible = Game.low_quality())


func add_capsule(radius := 0.45, height := 1.8) -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	cs.shape = cap
	cs.position.y = height * 0.5
	add_child(cs)


func play(clip: String, blend := 0.12, speed := 1.0, lock := 0.0) -> void:
	if anim == null:
		return
	var full := _resolve_clip(clip)
	if full == "":
		return
	if lock > 0.0:
		_anim_lock_until = time + lock
	if full == _current_anim and anim.is_playing() and lock <= 0.0:
		return
	_current_anim = full
	anim.play(full, blend, speed)


func play_loop(clip: String, blend := 0.15, speed := 1.0) -> void:
	## Only switches when not locked by a one-shot (attack, hit, etc).
	if time < _anim_lock_until:
		return
	play(clip, blend, speed)


func anim_locked() -> bool:
	return time < _anim_lock_until


## Large-rig characters (Golem, Black Knight) have fewer clips; map medium-rig names onto theirs.
const LARGE_CLIPS := {
	"Idle_B": "general/Idle_A", "Hit_B": "general/Hit_A", "Death_B": "general/Death_A",
	"Skeletons_Death": "general/Death_A", "Skeletons_Awaken_Floor": "general/Idle_A",
	"Skeletons_Death_Resurrect": "general/Idle_A", "Skeletons_Walking": "move/Walking_A",
	"Walking_B": "move/Walking_A", "Walking_C": "move/Walking_A", "Running_B": "move/Running_A",
	"Melee_1H_Attack_Chop": "melee/Melee_2H_Attack", "Melee_2H_Attack_Chop": "melee/Melee_2H_Attack",
	"Melee_2H_Attack_Slice": "melee/Melee_2H_Attack", "Melee_1H_Attack_Jump_Chop": "melee/Melee_2H_Slam",
	"Melee_2H_Attack_Spin": "melee/Melee_Dualwield_SlashCombo", "Melee_2H_Attack_Spinning": "melee/Melee_Dualwield_SlashCombo",
	"Ranged_Magic_Summon": "melee/Melee_Unarmed_Smash", "Ranged_Magic_Spellcasting": "melee/Melee_Unarmed_Smash",
	"Melee_Dualwield_Attack_Stab": "melee/Melee_Dualwield_Slash", "Use_Item": "general/Idle_A", "Throw": "general/Idle_A",
}


func _resolve_clip(clip: String) -> String:
	var full := Models.anim_name(clip)
	if anim == null or anim.has_animation(full):
		return full
	var alt: String = LARGE_CLIPS.get(clip.get_file(), "")
	if alt != "":
		var f2 := Models.anim_name(alt)
		if anim.has_animation(f2):
			return f2
	return ""


func clip_length(clip: String) -> float:
	var full := _resolve_clip(clip)
	if anim and anim.has_animation(full):
		return anim.get_animation(full).length
	return 0.5


func face(dir: Vector3, instant := false, delta := 0.016, turn_speed := 14.0) -> void:
	dir.y = 0
	if dir.length_squared() < 0.0001:
		return
	facing = dir.normalized()
	var target := atan2(facing.x, facing.z)
	if instant:
		visual.rotation.y = target
	else:
		visual.rotation.y = lerp_angle(visual.rotation.y, target, clampf(turn_speed * delta, 0, 1))


func forward() -> Vector3:
	return Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))


func flash(color := Color(1, 1, 1), strength := 0.75) -> void:
	if _flash_mat == null:
		return
	_flash_mat.albedo_color = Color(color.r, color.g, color.b, strength)
	var tw := create_tween()
	tw.tween_property(_flash_mat, "albedo_color:a", 0.0, 0.18)


func tint(color: Color, strength: float) -> void:
	if _flash_mat:
		_flash_mat.albedo_color = Color(color.r, color.g, color.b, strength)


## Returns the damage actually applied.
func take_damage(amount: float, from: Vector3, knock := 6.0, source: Node = null) -> float:
	if dead or time < invulnerable_until:
		return 0.0
	amount = modify_incoming(amount, from, source)
	if amount <= 0.0:
		return 0.0
	hp -= amount
	var away := global_position - from
	away.y = 0
	if away.length_squared() > 0.0001:
		knockback += away.normalized() * knock
	flash()
	damaged.emit(self, amount)
	on_hurt(amount)
	if hp <= 0.0:
		hp = 0.0
		die()
	return amount


func modify_incoming(amount: float, _from: Vector3, _source: Node) -> float:
	return amount


func on_hurt(_amount: float) -> void:
	pass


func die() -> void:
	if dead:
		return
	dead = true
	died.emit(self)


func apply_motion(desired: Vector3, delta: float) -> void:
	var v := desired + knockback
	knockback = knockback.move_toward(Vector3.ZERO, 28.0 * delta)
	velocity.x = v.x
	velocity.z = v.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	if global_position.y < -6.0:
		global_position.y = 0.5
