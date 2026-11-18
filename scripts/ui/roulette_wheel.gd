class_name RouletteWheel
extends Control
## Animated multiplier wheel. Call spin_to(slice_index); emits `stopped` when it settles.
## The result is decided by Game.spin_wheel() before the animation, so the wheel only shows it.

signal stopped(index: int)

const GOLD := Color(1.0, 0.82, 0.35)

var slices: Array = []         # multipliers
var font: Font
var radius := 170.0
var angle := 0.0               # current rotation (radians)
var spinning := false
var _start := 0.0
var _target := 0.0
var _t := 0.0
var _dur := 4.0
var _target_index := 0
var _last_tick_slice := -1
var _highlight := -1
var _glow := 0.0
var draw_pointer := true       # the camp's 3D wheel has its own pointer
var silent := false            # no tick sounds (camp decoration)
var idle_spin := 0.0           # slow rotation while not spinning (rad/s)


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2 + 40, radius * 2 + 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func slice_color(mult: float) -> Color:
	if mult <= 0.0:
		return Color(0.35, 0.08, 0.08)
	if mult < 1.0:
		return Color(0.55, 0.3, 0.12)
	if mult == 1.0:
		return Color(0.3, 0.3, 0.35)
	if mult < 2.0:
		return Color(0.15, 0.42, 0.2)
	return Color(0.75, 0.55, 0.1)


func spin_to(index: int) -> void:
	var n := slices.size()
	var seg := TAU / n
	# pointer sits at the top (-PI/2). Slice i is centred at i*seg (wheel space) before rotation.
	var wobble := randf_range(-seg * 0.35, seg * 0.35)
	var desired := -PI * 0.5 - (index * seg + seg * 0.5) + wobble
	var base := angle - fmod(angle, TAU)
	_target = base + TAU * 6.0 + fposmod(desired, TAU)
	_start = angle
	_t = 0.0
	_dur = randf_range(3.6, 4.4)
	_target_index = index
	_highlight = -1
	spinning = true


func _process(delta: float) -> void:
	if spinning:
		_t += delta
		var k := clampf(_t / _dur, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 4.0)   # strong ease-out
		angle = lerpf(_start, _target, e)
		var cur := _slice_under_pointer()
		if cur != _last_tick_slice:
			_last_tick_slice = cur
			if not silent:
				Sfx.play("ui_click", -14.0, 0.15)
		if k >= 1.0:
			spinning = false
			_highlight = _target_index
			_glow = 1.0
			stopped.emit(_target_index)
	elif idle_spin != 0.0 and _glow <= 0.0:
		angle += idle_spin * delta
	_glow = maxf(0.0, _glow - delta * 0.5)
	queue_redraw()


func _slice_under_pointer() -> int:
	var n := slices.size()
	var seg := TAU / n
	var a := fposmod(-PI * 0.5 - angle, TAU)
	return int(a / seg) % n


func _draw() -> void:
	var c := Vector2(size.x * 0.5, radius + 30)
	var n := slices.size()
	if n == 0:
		return
	var seg := TAU / n
	# rim
	draw_circle(c, radius + 12, Color(0.22, 0.15, 0.08))
	draw_arc(c, radius + 12, 0, TAU, 96, GOLD, 3.0, true)
	for i in n:
		var a0 := angle + i * seg
		var a1 := a0 + seg
		var pts := PackedVector2Array([c])
		for k in 13:
			var a := lerpf(a0, a1, k / 12.0)
			pts.append(c + Vector2(cos(a), sin(a)) * radius)
		var col := slice_color(slices[i])
		if i == _highlight:
			col = col.lightened(0.25 + 0.25 * sin(Time.get_ticks_msec() * 0.01))
		draw_colored_polygon(pts, col)
		draw_line(c, c + Vector2(cos(a0), sin(a0)) * radius, Color(0, 0, 0, 0.6), 2.0, true)
		# label
		var mid := a0 + seg * 0.5
		var txt := "x%s" % (str(slices[i]).trim_suffix(".0"))
		var fs := 22
		var p := c + Vector2(cos(mid), sin(mid)) * radius * 0.64
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		# text runs along the spoke so narrow slices never overlap; flipped on the left half to stay readable
		var rot := mid if cos(mid) >= 0.0 else mid + PI
		draw_set_transform(p, rot)
		draw_string_outline(font, -ts * Vector2(0.5, -0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0))
		draw_string(font, -ts * Vector2(0.5, -0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))
		draw_set_transform(Vector2.ZERO)
	# hub
	draw_circle(c, 26, Color(0.25, 0.17, 0.08))
	draw_arc(c, 26, 0, TAU, 32, GOLD, 3.0, true)
	# studs on the rim
	for i in n:
		var a := angle + i * seg
		draw_circle(c + Vector2(cos(a), sin(a)) * (radius + 6), 4, GOLD)
	if not draw_pointer:
		if _glow > 0.0:
			draw_arc(c, radius + 16, 0, TAU, 96, Color(GOLD.r, GOLD.g, GOLD.b, _glow), 6.0, true)
		return
	# pointer at the top
	var tip := c + Vector2(0, -radius + 18)
	var pointer := PackedVector2Array([tip, c + Vector2(-16, -radius - 22), c + Vector2(16, -radius - 22)])
	draw_colored_polygon(pointer, Color(0.95, 0.95, 0.95))
	draw_polyline(PackedVector2Array([tip, c + Vector2(-16, -radius - 22), c + Vector2(16, -radius - 22), tip]), Color(0, 0, 0), 2.0, true)
	if _glow > 0.0:
		draw_arc(c, radius + 16, 0, TAU, 96, Color(GOLD.r, GOLD.g, GOLD.b, _glow), 6.0, true)
