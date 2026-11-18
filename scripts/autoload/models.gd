extends Node
## Loads KayKit models, builds animated characters (shared animation libraries),
## attaches weapons to hand bones and generates simple box collision for props.

const DUNGEON := "res://assets/dungeon/%s.gltf.glb"
const HALLOWEEN := "res://assets/halloween/%s.gltf"
const WEAPON := "res://assets/weapons/%s.gltf"
const SKEL_PROP := "res://assets/characters/skeletons/props/%s.gltf"
const ANIM_LIBS := {
	"general": "res://assets/animations/Rig_Medium_General.glb",
	"move": "res://assets/animations/Rig_Medium_MovementBasic.glb",
	"moveadv": "res://assets/animations/Rig_Medium_MovementAdvanced.glb",
	"melee": "res://assets/animations/Rig_Medium_CombatMelee.glb",
	"ranged": "res://assets/animations/Rig_Medium_CombatRanged.glb",
	"special": "res://assets/animations/Rig_Medium_Special.glb",
}
## Large-rig characters (Skeleton Golem, Black Knight) use their own clip set.
const ANIM_LIBS_LARGE := {
	"general": "res://assets/animations/Rig_Large_General.glb",
	"move": "res://assets/animations/Rig_Large_MovementBasic.glb",
	"moveadv": "res://assets/animations/Rig_Large_MovementAdvanced.glb",
	"melee": "res://assets/animations/Rig_Large_CombatMelee.glb",
}
const LOOPING := ["Idle_A", "Idle_B", "Running_A", "Running_B", "Walking_A", "Walking_B", "Walking_C",
	"Melee_Blocking", "Melee_2H_Attack_Spinning", "Ranged_Magic_Spellcasting", "Ranged_Bow_Aiming_Idle",
	"Skeletons_Idle", "Skeletons_Walking", "Running_Strafe_Left", "Running_Strafe_Right", "Melee_2H_Idle",
	"Death_A_Pose", "Death_B_Pose", "Skeletons_Death_Pose", "Skeletons_Inactive_Floor_Pose", "Sit_Floor_Idle",
	"Cheering", "Skeletons_Taunt_Longer", "Walking_A", "Running_A", "Melee_Unarmed_Idle", "Ranged_2H_Aiming", "Ranged_1H_Aiming"]

var _scenes := {}
var _aabbs := {}
var _libs := {}
var _libs_large := {}


func _ready() -> void:
	_load_libs(ANIM_LIBS, _libs)
	_load_libs(ANIM_LIBS_LARGE, _libs_large)


func _load_libs(paths: Dictionary, out: Dictionary) -> void:
	for key in paths:
		var inst: Node = load(paths[key]).instantiate()
		var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
		var lib: AnimationLibrary = ap.get_animation_library("")
		for anim_name in lib.get_animation_list():
			var a := lib.get_animation(anim_name)
			if String(anim_name) in LOOPING:
				a.loop_mode = Animation.LOOP_LINEAR
		out[key] = lib
		inst.free()


func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


func dungeon(model: String) -> Node3D:
	return scene(DUNGEON % model).instantiate()


func halloween(model: String) -> Node3D:
	return scene(HALLOWEEN % model).instantiate()


func aabb_of(path: String) -> AABB:
	if _aabbs.has(path):
		return _aabbs[path]
	var inst: Node3D = scene(path).instantiate()
	var acc := [null]
	_merge_aabb(inst, Transform3D.IDENTITY, acc)
	inst.free()
	var box: AABB = acc[0] if acc[0] != null else AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	_aabbs[path] = box
	return box


func _merge_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var a: AABB = t * (n as MeshInstance3D).get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_merge_aabb(c, t, acc)


## Places a static prop with a box collider sized from its mesh bounds.
func prop(parent: Node3D, path: String, pos: Vector3, rot_y := 0.0, collide := true, scale := 1.0, shrink := 0.85) -> Node3D:
	var model: Node3D = scene(path).instantiate()
	if not collide:
		parent.add_child(model)
		model.position = pos
		model.rotation.y = rot_y
		model.scale = Vector3.ONE * scale
		return model
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.position = pos
	body.rotation.y = rot_y
	body.scale = Vector3.ONE * scale
	body.add_child(model)
	var box := aabb_of(path)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(box.size.x * shrink, maxf(box.size.y, 0.4), box.size.z * shrink)
	shape.shape = bs
	shape.position = box.get_center()
	body.add_child(shape)
	return body


# ---------------- characters ----------------

## Returns a Node3D holding the character model with an AnimationPlayer that has every KayKit clip.
func character(model_path: String) -> Node3D:
	var root: Node3D = scene(model_path).instantiate()
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	ap.root_node = NodePath("..")
	var libs := _libs_large if is_large(root) else _libs
	for key in libs:
		ap.add_animation_library(key, libs[key])
	_tame_metal(root)
	return root


## Fully metallic materials (the Paladin's armour) render black without reflections; soften them.
func _tame_metal(root: Node) -> void:
	for mi in meshes_of(root):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			# the imported material is shared by every instance, so adjusting it once covers them all
			var mat := mesh.surface_get_material(i) as BaseMaterial3D
			if mat and mat.metallic > 0.5:
				mat.metallic = 0.3
				mat.roughness = 0.45


func is_large(character_root: Node) -> bool:
	return character_root.has_node("Rig_Large")


func skeleton_of(character_root: Node) -> Skeleton3D:
	var sk := character_root.get_node_or_null("Rig_Medium/Skeleton3D")
	return sk if sk else character_root.get_node_or_null("Rig_Large/Skeleton3D")


func attach(character_root: Node, item_path: String, bone := "handslot.r", offset := Transform3D.IDENTITY) -> Node3D:
	var sk := skeleton_of(character_root)
	if sk == null or item_path == "":
		return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var item: Node3D = scene(item_path).instantiate()
	item.transform = offset
	ba.add_child(item)
	_tame_metal(item)
	return item


func anim_name(full: String) -> String:
	## Accepts either "lib/Clip" or "Clip" and resolves the library automatically.
	if full.contains("/"):
		return full
	for key in _libs:
		if (_libs[key] as AnimationLibrary).has_animation(full):
			return "%s/%s" % [key, full]
	return "general/Idle_A"


func meshes_of(n: Node, out: Array = []) -> Array:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		meshes_of(c, out)
	return out
