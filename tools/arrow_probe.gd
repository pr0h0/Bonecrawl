extends SceneTree
func _aabb(n, xf, acc):
	var t = xf
	if n is Node3D: t = xf * n.transform
	if n is MeshInstance3D:
		var a = t * n.get_aabb()
		acc[0] = a if acc[0] == null else acc[0].merge(a)
		# report where the vertices are concentrated: tip = narrow end
		var arr = n.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		acc[1] += arr.size()
	for c in n.get_children(): _aabb(c, t, acc)
func _init():
	for p in ["res://assets/weapons/arrow_bow.gltf", "res://assets/characters/skeletons/props/Skeleton_Arrow.gltf"]:
		var n = load(p).instantiate()
		var acc = [null, 0]
		_aabb(n, Transform3D(), acc)
		print("A ", p.get_file(), " pos=", acc[0].position, " size=", acc[0].size)
		# find extreme vertices along the long axis and their spread (wide end = fletching)
		var mi = n.find_children("*", "MeshInstance3D", true, false)
		for m in mi:
			var verts = m.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var xf = m.transform
			var lo = []; var hi = []
			var box = acc[0]
			var axis = 0
			for i in 3:
				if box.size[i] > box.size[axis]: axis = i
			for v in verts:
				var w = xf * v
				if w[axis] < box.position[axis] + box.size[axis] * 0.15: lo.append(w)
				elif w[axis] > box.end[axis] - box.size[axis] * 0.15: hi.append(w)
			var spread = func(list):
				var mn = Vector3.INF; var mx = -Vector3.INF
				for w in list: mn = mn.min(w); mx = mx.max(w)
				return (mx - mn) if list.size() > 0 else Vector3.ZERO
			print("  axis=", axis, " low-end spread=", spread.call(lo), " high-end spread=", spread.call(hi))
		n.free()
	quit()
