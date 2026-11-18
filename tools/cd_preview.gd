extends Control
## Dev tool: renders the cooldown widget at several charge states, saves a screenshot, quits.
func _ready():
	var bg = ColorRect.new(); bg.color = Color(0.25, 0.22, 0.28); bg.size = Vector2(900, 200); add_child(bg)
	var font = load("res://ui/fonts/kenney_future.ttf")
	var tex = load("res://ui/icons/fastForward.png")
	var states = [[5.0, 5.0], [3.6, 5.0], [2.4, 5.0], [0.8, 5.0], [0.0, 5.0]]
	var x = 10
	for st in states:
		var w = CooldownWidget.new(); w.font = font; w.icon = tex; w.title = "FIREBALL"; w.radius = 46
		add_child(w); w.position = Vector2(x, 10); w.size = w.custom_minimum_size
		w.set_state(st[0], st[1]); x += 170
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().get_region(Rect2i(0, 0, 900, 200)).save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
