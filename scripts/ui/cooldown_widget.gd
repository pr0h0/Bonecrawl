class_name CooldownWidget
extends Control
## Round ability button: icon, radial sweep while recharging, big countdown number,
## and a gold pulse + "READY" pop when the ability comes back.

signal became_ready

const GOLD := Color(1.0, 0.82, 0.35)

var title := "SKILL"
var key_hint := "RMB"
var icon: Texture2D
var remaining := 0.0        # seconds left
var total := 1.0            # full cooldown length
var radius := 44.0
var font: Font
var _was_ready := true
var _ready_flash := 0.0     # 1 -> 0 after becoming ready
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2 + 30, radius * 2 + 54)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(remaining_: float, total_: float) -> void:
	remaining = maxf(remaining_, 0.0)
	total = maxf(total_, 0.01)
	var is_ready := remaining <= 0.0
	if is_ready and not _was_ready:
		_ready_flash = 1.0
		became_ready.emit()
	_was_ready = is_ready


func _process(delta: float) -> void:
	_t += delta
	_ready_flash = maxf(0.0, _ready_flash - delta * 1.8)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, radius + 4)
	var is_ready := remaining <= 0.0
	var frac := clampf(remaining / total, 0.0, 1.0)

	# soft outer glow when ready (pulses gently, bursts on becoming ready)
	if is_ready:
		var pulse := 0.25 + 0.15 * sin(_t * 4.0) + _ready_flash * 0.6
		draw_circle(c, radius + 6 + _ready_flash * 10.0, Color(GOLD.r, GOLD.g, GOLD.b, pulse * 0.45))

	# base disc
	draw_circle(c, radius, Color(0.08, 0.06, 0.07, 0.92))
	# icon
	if icon:
		var s := radius * 1.45
		var col := Color(1, 1, 1, 1) if is_ready else Color(0.55, 0.55, 0.6, 1)
		draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, col)

	# radial sweep: dark wedge covering the remaining fraction, clockwise from 12 o'clock
	if not is_ready:
		var pts := PackedVector2Array([c])
		var steps := 48
		var start := -PI * 0.5
		var end := start + TAU * frac
		for i in steps + 1:
			var a := lerpf(start, end, float(i) / steps)
			pts.append(c + Vector2(cos(a), sin(a)) * radius)
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0, 0, 0, 0.62))
		# bright edge of the sweep
		var edge_a := end
		draw_line(c, c + Vector2(cos(edge_a), sin(edge_a)) * radius, Color(GOLD.r, GOLD.g, GOLD.b, 0.8), 2.0, true)
		# progress arc around the rim (fills up as it recharges)
		var done := 1.0 - frac
		if done > 0.0:
			draw_arc(c, radius + 1.5, -PI * 0.5, -PI * 0.5 + TAU * done, 64, Color(GOLD.r, GOLD.g, GOLD.b, 0.9), 4.0, true)

	# rim
	var rim_col := GOLD if is_ready else Color(0.45, 0.36, 0.25)
	draw_arc(c, radius, 0, TAU, 64, rim_col, 3.0 if is_ready else 2.0, true)

	# countdown number
	if not is_ready and font:
		var txt := ("%.1f" % remaining) if remaining < 3.0 else str(ceili(remaining))
		var fs := 34
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var pos := c + Vector2(-ts.x * 0.5, ts.y * 0.32)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, 1))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))
	elif _ready_flash > 0.0 and font:
		var fs2 := 22
		var txt2 := "READY"
		var ts2 := font.get_string_size(txt2, HORIZONTAL_ALIGNMENT_CENTER, -1, fs2)
		var p2 := c + Vector2(-ts2.x * 0.5, -radius * 0.15 - _ready_flash * 18.0)
		var a2 := clampf(_ready_flash * 1.5, 0, 1)
		draw_string_outline(font, p2, txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 8, Color(0, 0, 0, a2))
		draw_string(font, p2, txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(GOLD.r, GOLD.g, GOLD.b, a2))

	# labels under the button
	if font:
		var y := c.y + radius + 22
		var ts3 := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		draw_string_outline(font, Vector2(c.x - ts3.x * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, Color(0, 0, 0))
		draw_string(font, Vector2(c.x - ts3.x * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD if is_ready else Color(0.75, 0.7, 0.65))
		var ts4 := font.get_string_size(key_hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		draw_string_outline(font, Vector2(c.x - ts4.x * 0.5, y + 18), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 5, Color(0, 0, 0))
		draw_string(font, Vector2(c.x - ts4.x * 0.5, y + 18), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.8))
