class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets: a floating joystick on the left half of the screen
## and action buttons on the right. Each button feeds the same input actions as the keyboard,
## so the rest of the game does not know whether you play with touch, keys or a gamepad.

const JOY_RADIUS := 120.0
const DEADZONE := 0.18

## id -> action, label, offset from the bottom-right corner, radius
const BUTTONS := {
	"attack": {"action": "attack", "label": "ATTACK", "off": Vector2(-165, -165), "r": 108.0},
	"dodge": {"action": "dodge", "label": "DODGE", "off": Vector2(-355, -100), "r": 74.0},
	"skill": {"action": "skill", "label": "SKILL", "off": Vector2(-150, -370), "r": 74.0},
	"potion": {"action": "potion", "label": "POTION", "off": Vector2(-335, -285), "r": 58.0},
	"use": {"action": "interact", "label": "USE", "off": Vector2(-500, -150), "r": 60.0},
}
const PAUSE_OFF := Vector2(-64, 64)   # from the top-right corner
const PAUSE_R := 42.0

var main: Node                 # main.gd: tells us when gameplay is on screen
var _canvas: Control
var _font: Font
var _joy_index := -1
var _joy_base := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _held := {}                # touch index -> button id
var _shown := false


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	_font = ThemeDB.fallback_font
	var f := "res://ui/fonts/kenney_future.ttf"
	if ResourceLoader.exists(f):
		_font = load(f)


func _process(_delta: float) -> void:
	var want := Game.touch_mode and _gameplay_visible()
	if want != _shown:
		_shown = want
		if not want:
			_release_all()
	var portrait := Game.touch_mode and _canvas.get_viewport_rect().size.x < _canvas.get_viewport_rect().size.y
	_canvas.visible = _shown or portrait
	if _canvas.visible:
		_canvas.queue_redraw()


func _gameplay_visible() -> bool:
	if main == null or get_tree().paused:
		return false
	if not (main.state in ["hub", "run"]):
		return false
	var hud = main.hud
	if hud and (hud.modal_open() or hud.equipment_open()):
		return false
	return main.player != null and main.player.input_enabled


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not Game.touch_mode:
		Game.enable_touch_mode()
	if not _shown:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _touch_down(t.index, t.position):
				get_viewport().set_input_as_handled()
		else:
			if _touch_up(t.index):
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_index:
			_joy_knob = d.position
			_update_joystick()
			get_viewport().set_input_as_handled()
		elif _held.has(d.index):
			get_viewport().set_input_as_handled()


func _k() -> float:
	return 1.0 / maxf(get_tree().root.content_scale_factor, 0.01)


func _bpos(size: Vector2, id: String) -> Vector2:
	return size + (BUTTONS[id].off as Vector2) * _k()


func _br(id: String) -> float:
	return float(BUTTONS[id].r) * _k()


func _touch_down(index: int, pos: Vector2) -> bool:
	var size := _canvas.get_viewport_rect().size
	if pos.distance_to(_pause_center(size)) < PAUSE_R * _k() * 1.3:
		_send("pause", true)
		_send("pause", false)
		return true
	for id in BUTTONS:
		if not _button_enabled(id):
			continue
		var b: Dictionary = BUTTONS[id]
		if pos.distance_to(_bpos(size, id)) < _br(id) * 1.15:
			_held[index] = id
			_send(b.action, true)
			return true
	if pos.x < size.x * 0.5 and _joy_index == -1:
		_joy_index = index
		_joy_base = pos
		_joy_knob = pos
		_update_joystick()
		return true
	return false


func _touch_up(index: int) -> bool:
	if index == _joy_index:
		_joy_index = -1
		_set_move(Vector2.ZERO)
		return true
	if _held.has(index):
		var id: String = _held[index]
		_held.erase(index)
		_send(BUTTONS[id].action, false)
		return true
	return false


func _update_joystick() -> void:
	var jr := JOY_RADIUS * _k()
	var off := _joy_knob - _joy_base
	if off.length() > jr:
		# the base follows a finger that drifts too far, so the stick never "runs out"
		_joy_base = _joy_knob - off.normalized() * jr
		off = _joy_knob - _joy_base
	var v := off / jr
	if v.length() < DEADZONE:
		v = Vector2.ZERO
	_set_move(v)


func _set_move(v: Vector2) -> void:
	_axis("move_left", "move_right", v.x)
	_axis("move_up", "move_down", v.y)


func _axis(neg: String, pos: String, value: float) -> void:
	if value < 0.0:
		Input.action_press(neg, -value)
		Input.action_release(pos)
	elif value > 0.0:
		Input.action_press(pos, value)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _release_all() -> void:
	for index in _held:
		_send(BUTTONS[_held[index]].action, false)
	_held.clear()
	_joy_index = -1
	_set_move(Vector2.ZERO)


func _button_enabled(id: String) -> bool:
	match id:
		"use":
			return main != null and main._nearest != null
		"potion", "skill":
			return main != null and main.state == "run"
	return true


func _pause_center(size: Vector2) -> Vector2:
	return Vector2(size.x, 0) + PAUSE_OFF * _k()


# --- drawing ---------------------------------------------------------------------------------

func _draw_controls() -> void:
	var size := _canvas.get_viewport_rect().size
	var k := _k()
	if size.x < size.y:
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.05, 0.92))
		_text("ROTATE YOUR PHONE", size * 0.5 - Vector2(0, 30), int(48 * k), Color(1, 0.9, 0.75), size.x * 0.9)
		_text("BONECRAWL PLAYS IN LANDSCAPE", size * 0.5 + Vector2(0, 40), int(26 * k), Color(0.8, 0.8, 0.85), size.x * 0.9)
		return
	var jr := JOY_RADIUS * k
	# joystick
	if _joy_index != -1:
		_canvas.draw_circle(_joy_base, jr, Color(0, 0, 0, 0.28))
		_canvas.draw_arc(_joy_base, jr, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0 * k, true)
		var kn := _joy_base + (_joy_knob - _joy_base).limit_length(jr)
		_canvas.draw_circle(kn, 52 * k, Color(1, 0.92, 0.8, 0.55))
	else:
		var hint := Vector2(size.x * 0.16, size.y - 190 * k)
		_canvas.draw_arc(hint, jr * 0.8, 0, TAU, 48, Color(1, 1, 1, 0.14), 3.0 * k, true)
		_text("MOVE", hint, int(22 * k), Color(1, 1, 1, 0.25))
	var p: Player = main.player if main else null
	for id in BUTTONS:
		var b: Dictionary = BUTTONS[id]
		var c := _bpos(size, id)
		var r := _br(id)
		var on := _button_enabled(id)
		var held := _held.values().has(id)
		var col := _button_color(id)
		var alpha := 0.62 if held else (0.36 if on else 0.12)
		_canvas.draw_circle(c, r, Color(col.r, col.g, col.b, alpha))
		_canvas.draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.5 if on else 0.15), 3.0 * k, true)
		# cooldown sweep
		var frac := _cooldown_frac(id, p)
		if frac > 0.0:
			_canvas.draw_arc(c, r - 8 * k, -PI / 2, -PI / 2 + TAU * frac, 48, Color(0, 0, 0, 0.55), 14.0 * k, true)
		var label: String = b.label
		if id == "skill" and p and p.cls:
			label = str(p.cls.get("skill_name", "SKILL")).to_upper()
		elif id == "potion" and Game.run.has("potions"):
			label = "POTION %d" % int(Game.run.potions)
		_text(label, c, int((24 if b.r > 80 else 19) * k), Color(1, 1, 1, 0.95 if on else 0.3), r * 1.9)
	# pause
	var pc := _pause_center(size)
	var pr := PAUSE_R * k
	_canvas.draw_circle(pc, pr, Color(0, 0, 0, 0.35))
	_canvas.draw_arc(pc, pr, 0, TAU, 32, Color(1, 1, 1, 0.5), 3.0 * k, true)
	_canvas.draw_rect(Rect2(pc + Vector2(-12, -14) * k, Vector2(8, 28) * k), Color(1, 1, 1, 0.9))
	_canvas.draw_rect(Rect2(pc + Vector2(4, -14) * k, Vector2(8, 28) * k), Color(1, 1, 1, 0.9))


func _button_color(id: String) -> Color:
	match id:
		"attack": return Color(0.85, 0.25, 0.15)
		"dodge": return Color(0.25, 0.55, 0.9)
		"skill": return Color(0.75, 0.45, 1.0)
		"potion": return Color(0.9, 0.2, 0.35)
		"use": return Color(0.3, 0.8, 0.4)
	return Color(0.5, 0.5, 0.5)


func _cooldown_frac(id: String, p: Player) -> float:
	if p == null:
		return 0.0
	match id:
		"skill":
			var total: float = float(p.cls.get("skill_cd", 1.0)) * float(Game.run.get("cd_mult", 1.0))
			return clampf(p.skill_cd / maxf(total, 0.01), 0.0, 1.0)
		"dodge":
			return clampf(p.dodge_cd / 0.75, 0.0, 1.0)
	return 0.0


func _text(s: String, center: Vector2, size: int, col: Color, max_w := 0.0) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if max_w > 0.0 and w > max_w:   # long skill names shrink to fit their button
		size = int(size * max_w / w)
		w = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := center + Vector2(-w / 2.0, size * 0.36)
	_canvas.draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, size / 5), Color(0, 0, 0, col.a * 0.8))
	_canvas.draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
