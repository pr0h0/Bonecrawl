extends Node
func _ready():
	for p in ["res://assets/halloween/crypt.gltf", "res://assets/halloween/arch_gate.gltf", "res://assets/halloween/arch.gltf", "res://assets/dungeon/door.gltf.glb", "res://assets/dungeon/door_gate.gltf.glb", "res://assets/dungeon/wall_gateDoor.gltf.glb", "res://assets/dungeon/stairs.gltf.glb", "res://assets/halloween/tree_pine_orange_large.gltf", "res://assets/halloween/tree_dead_large.gltf", "res://assets/halloween/bone_A.gltf", "res://assets/dungeon/artifact.gltf.glb"]:
		print(p.get_file(), "  ", Models.aabb_of(p))
	get_tree().quit()
