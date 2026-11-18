extends Node
## Dev tool: drives the real game with synthetic touch events (title tap, joystick, buttons).
var main: Node

func _win(pos: Vector2) -> Vector2:
	# events arrive in window pixels; the game sees them in (stretched) viewport units
	return pos * Vector2(get_window().size) / get_viewport().get_visible_rect().size

func _touch(i: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new(); e.index = i; e.position = _win(pos); e.pressed = pressed
	Input.parse_input_event(e)

func _drag(i: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new(); e.index = i; e.position = _win(pos)
	Input.parse_input_event(e)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	var size := get_viewport().get_visible_rect().size
	_touch(0, size * 0.5, true); _touch(0, size * 0.5, false)     # tap to start
	await _wait(1.5)
	print("touch_mode=", Game.touch_mode, " state=", main.state)
	var p: Player = main.player
	var start := p.global_position
	# joystick: press on the left, drag right
	var base := Vector2(size.x * 0.2, size.y * 0.7)
	_touch(0, base, true)
	await _wait(0.05)
	_drag(0, base + Vector2(100, 0))
	await _wait(0.8)
	var moved := p.global_position - start
	print("moved x=", snapped(moved.x, 0.01), " z=", snapped(moved.z, 0.01))
	_touch(0, base + Vector2(100, 0), false)
	await _wait(0.3)
	var still := p.global_position
	await _wait(0.4)
	print("stopped=", p.global_position.distance_to(still) < 0.05)
	# attack button while the joystick is held by another finger (multi-touch)
	var k := 1.0 / get_tree().root.content_scale_factor
	var atk := size + Vector2(-165, -165) * k
	_touch(0, base, true)
	_touch(1, atk, true)
	await _wait(0.1)
	print("attack_cd_after_tap=", snapped(p.attack_cd, 0.01), " attack_pressed=", Input.is_action_pressed("attack"))
	_touch(1, atk, false); _touch(0, base, false)
	await _wait(0.1)
	print("attack_released=", not Input.is_action_pressed("attack"))
	# a plain tap elsewhere must NOT attack (mouse-click binding removed in touch mode)
	await _wait(1.0)
	_touch(0, Vector2(size.x * 0.75, size.y * 0.3), true)
	await _wait(0.05)
	print("tap_attacks=", Input.is_action_pressed("attack"))
	_touch(0, Vector2(size.x * 0.75, size.y * 0.3), false)
	# pause button
	_touch(0, Vector2(size.x, 0) + Vector2(-64, 64) * k, true); _touch(0, Vector2(size.x, 0) + Vector2(-64, 64) * k, false)
	await _wait(0.3)
	print("paused=", get_tree().paused)
	get_tree().quit()
