class_name IconRenderer
extends Node
## Renders 3D models into small textures once (for HUD icons), so items look exactly like in-game.

var _cache := {}


func icon(model_path: String, size := 128, rot := Vector3(-0.35, 0.6, 0.0), zoom := 1.0) -> Texture2D:
	return icon_parts([[model_path, Transform3D.IDENTITY]], size, rot, zoom)


func chest_icon(tier: String, size := 128, open := false) -> Texture2D:
	## Chest body + lid, assembled exactly like the in-dungeon Chest (closed, or lid flung open).
	var lid_pos := Vector3(0, 0.55, -0.4) if tier == "common" else Vector3(0, 0.5, -0.4)
	var lid := Transform3D(Basis.from_euler(Vector3(-1.05 if open else 0.0, 0, 0)), lid_pos)
	var parts := [[Models.DUNGEON % ("chest_%s" % tier), Transform3D.IDENTITY], [Models.DUNGEON % ("chestTop_%s" % tier), lid]]
	return icon_parts(parts, size, Vector3(0.75, 0.3, 0), 1.05)   # tilted toward the camera: the ¾ top-down look of the dungeon


func icon_parts(parts: Array, size := 128, rot := Vector3(-0.35, 0.6, 0.0), zoom := 1.0) -> Texture2D:
	## parts: [[model_path, local Transform3D], ...] rendered together as one object.
	var key := "%s|%d|%s|%s" % [str(parts), size, rot, zoom]
	if _cache.has(key):
		return _cache[key]
	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.85)
	e.ambient_light_energy = 0.7
	env.environment = e
	vp.add_child(env)
	var root := Node3D.new()
	vp.add_child(root)
	var box := AABB()
	for i in parts.size():
		var path: String = parts[i][0]
		var xf: Transform3D = parts[i][1]
		var m: Node3D = Models.scene(path).instantiate()
		m.transform = xf
		root.add_child(m)
		var b := xf * Models.aabb_of(path)
		box = b if i == 0 else box.merge(b)
	root.rotation = rot
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.5, 0)
	light.light_energy = 1.3
	vp.add_child(light)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var extent := maxf(box.size.x, maxf(box.size.y, box.size.z))
	cam.size = extent * 1.25 / zoom
	vp.add_child(cam)
	var center := root.transform * box.get_center()
	cam.position = center + Vector3(0, 0, 10)
	cam.look_at(center, Vector3.UP)
	var tex := vp.get_texture()
	_cache[key] = tex
	return tex
