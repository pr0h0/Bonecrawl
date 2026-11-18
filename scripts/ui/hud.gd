class_name HUD
extends CanvasLayer
## All 2D interface: in-run HUD, hub panel, title, pause, boon choice, upgrades, death/victory.

signal title_dismissed
signal boon_picked(id: String)
signal resume_pressed
signal quit_to_camp
signal end_screen_closed
signal upgrades_closed
signal inventory_pressed       # pause menu > Inventory
signal inventory_closed_run    # inventory opened with I mid-run was closed: unpause
signal equipment_changed       # equip / unequip / sell

const GOLD := Color(1.0, 0.82, 0.35)
const PANEL_BG := Color(0.07, 0.06, 0.09, 0.88)
const BORDER := Color(0.55, 0.42, 0.25)

var font: Font
var icons: IconRenderer
var theme_: Theme

# in-run widgets
var run_root: Control
var hp_bar: ProgressBar
var hp_label: Label
var gold_label: Label
var potion_label: Label
var skill_widget: CooldownWidget
var _skill_icon_class := ""
var skill_name: Label
var dodge_widget: CooldownWidget
var floor_label: Label
var weapon_label: Label
var boss_root: Control
var boss_bar: ProgressBar
var boss_label: Label
var banner: Label
var vignette: ColorRect
var fade: ColorRect
var path_row: HBoxContainer
var boon_label: Label

# hub widgets
var hub_root: Control
var hub_gold: Label
var hub_class: Label
var hub_desc: Label
var hub_stats: Label

var title_root: Control
var pause_root: Control
var modal_root: Control      # boon choice / upgrades / end screens
var _music_slider: HSlider
var _sfx_slider: HSlider


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://ui/fonts/kenney_future.ttf")
	icons = IconRenderer.new()
	add_child(icons)
	_make_theme()
	_build_run_hud()
	_build_hub_hud()
	_build_title()
	_build_pause()
	modal_root = Control.new()
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.theme = theme_
	# empty most of the time: it must not swallow clicks meant for the pause menu underneath
	# (the modals' own full-screen shade blocks clicks while one is open)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_root)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)


func _make_theme() -> void:
	theme_ = Theme.new()
	theme_.default_font = font
	theme_.default_font_size = 22
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL_BG
	panel.border_color = BORDER
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(18)
	theme_.set_stylebox("panel", "PanelContainer", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.16, 0.12, 0.1)
	btn.border_color = BORDER
	btn.set_border_width_all(2)
	btn.set_corner_radius_all(4)
	btn.set_content_margin_all(12)
	var btn_h := btn.duplicate()
	btn_h.bg_color = Color(0.32, 0.22, 0.12)
	btn_h.border_color = GOLD
	var btn_d := btn.duplicate()
	btn_d.bg_color = Color(0.1, 0.1, 0.1)
	btn_d.border_color = Color(0.3, 0.3, 0.3)
	theme_.set_stylebox("normal", "Button", btn)
	theme_.set_stylebox("hover", "Button", btn_h)
	theme_.set_stylebox("pressed", "Button", btn_h)
	theme_.set_stylebox("focus", "Button", btn_h)
	theme_.set_stylebox("disabled", "Button", btn_d)
	theme_.set_color("font_color", "Button", Color(0.95, 0.9, 0.8))
	theme_.set_color("font_hover_color", "Button", GOLD)
	theme_.set_color("font_focus_color", "Button", GOLD)
	theme_.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.45))
	theme_.set_color("font_color", "Label", Color(0.95, 0.92, 0.85))
	theme_.set_color("font_outline_color", "Label", Color(0, 0, 0))
	theme_.set_constant("outline_size", "Label", 6)


func _label(text: String, size := 22, color := Color(0.95, 0.92, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _bar(color: Color, height := 22.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.05, 0.05, 0.9)
	bg.border_color = Color(0, 0, 0)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func _icon_rect(tex: Texture2D, size := 44.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t


# ---------------- run HUD ----------------

func _build_run_hud() -> void:
	run_root = Control.new()
	run_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	run_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run_root.theme = theme_
	add_child(run_root)

	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.0;
void fragment(){
	float d = distance(UV, vec2(0.5));
	COLOR = vec4(0.6, 0.0, 0.0, smoothstep(0.35, 0.75, d) * strength);
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vignette.material = sm
	run_root.add_child(vignette)

	# top-left: health, potions, gold
	var tl := PanelContainer.new()
	tl.position = Vector2(20, 18)
	tl.custom_minimum_size = Vector2(380, 0)
	run_root.add_child(tl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	tl.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	skill_name = _label("KNIGHT", 20, GOLD)
	top.add_child(skill_name)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	weapon_label = _label("COMMON", 16, Color(0.8, 0.8, 0.8))
	top.add_child(weapon_label)
	var hp_stack := Control.new()
	hp_stack.custom_minimum_size = Vector2(340, 26)
	v.add_child(hp_stack)
	hp_bar = _bar(Color(0.78, 0.15, 0.15), 26)
	hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_stack.add_child(hp_bar)
	hp_label = _label("100 / 100", 16)
	hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_stack.add_child(hp_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(_icon_rect(icons.icon(Models.DUNGEON % "potionLarge_red", 96, Vector3(0, 0.5, 0)), 40))
	potion_label = _label("1   (Q)", 20)
	row.add_child(potion_label)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(30, 0)
	row.add_child(sp2)
	row.add_child(_icon_rect(icons.icon(Models.DUNGEON % "coin", 96, Vector3(0.3, 0.4, 0)), 36))
	gold_label = _label("0", 22, GOLD)
	row.add_child(gold_label)
	boon_label = _label("", 14, Color(0.6, 1, 0.85))
	boon_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	boon_label.custom_minimum_size = Vector2(340, 0)
	v.add_child(boon_label)

	# top-center: floor + path
	var tc := VBoxContainer.new()
	tc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tc.position = Vector2(-200, 18)
	tc.custom_minimum_size = Vector2(400, 0)
	tc.alignment = BoxContainer.ALIGNMENT_CENTER
	run_root.add_child(tc)
	floor_label = _label("FLOOR 1", 26, GOLD)
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc.add_child(floor_label)
	path_row = HBoxContainer.new()
	path_row.alignment = BoxContainer.ALIGNMENT_CENTER
	path_row.add_theme_constant_override("separation", 8)
	tc.add_child(path_row)

	# bottom-center: skill + dodge
	var bc := HBoxContainer.new()
	bc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bc.position = Vector2(-150, -170)
	bc.custom_minimum_size = Vector2(300, 150)
	bc.alignment = BoxContainer.ALIGNMENT_CENTER
	bc.add_theme_constant_override("separation", 24)
	run_root.add_child(bc)
	skill_widget = CooldownWidget.new()
	skill_widget.font = font
	skill_widget.key_hint = "RMB / K"
	skill_widget.radius = 46.0
	bc.add_child(skill_widget)
	skill_widget.became_ready.connect(func(): Sfx.play("ui_select", -10.0))
	dodge_widget = CooldownWidget.new()
	dodge_widget.font = font
	dodge_widget.title = "DODGE"
	dodge_widget.key_hint = "SPACE"
	dodge_widget.radius = 34.0
	dodge_widget.icon = load("res://ui/icons/fastForward.png")
	bc.add_child(dodge_widget)

	# boss bar
	boss_root = VBoxContainer.new()
	boss_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	boss_root.position = Vector2(-400, -200)
	boss_root.custom_minimum_size = Vector2(800, 0)
	run_root.add_child(boss_root)
	boss_label = _label("THE BONE KING", 26, Color(1, 0.45, 0.3))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_root.add_child(boss_label)
	boss_bar = _bar(Color(0.85, 0.3, 0.1), 22)
	boss_root.add_child(boss_bar)
	boss_root.visible = false

	banner = _label("", 54, GOLD)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-500, -200)
	banner.custom_minimum_size = Vector2(1000, 80)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 12)
	banner.modulate.a = 0.0
	run_root.add_child(banner)

	var help := _label("WASD move + aim   LMB attack   RMB skill   SPACE dodge   Q potion   E use   ESC pause   F11 fullscreen", 14, Color(0.7, 0.7, 0.7, 0.8))
	help.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	help.position = Vector2(-900, -28)
	help.custom_minimum_size = Vector2(880, 0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	run_root.add_child(help)
	help.visible = not Game.touch_mode
	Game.touch_mode_changed.connect(func(): help.visible = false)
	run_root.visible = false


func _cooldown_box(title: String, key: String) -> Array:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(170, 86)
	var c := Control.new()
	c.custom_minimum_size = Vector2(150, 70)
	box.add_child(c)
	var fill := ColorRect.new()
	fill.color = Color(0, 0, 0, 0.6)
	fill.position = Vector2(0, 0)
	fill.size = Vector2(150, 0)
	c.add_child(fill)
	var name_l := _label(title, 18, GOLD)
	name_l.position = Vector2(0, 8)
	name_l.size = Vector2(150, 24)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(name_l)
	var key_l := _label(key, 13, Color(0.8, 0.8, 0.8))
	key_l.position = Vector2(0, 42)
	key_l.size = Vector2(150, 20)
	key_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(key_l)
	return [box, fill, name_l]


func show_run(v: bool) -> void:
	run_root.visible = v


func update_run(player: Player, boss: Enemy) -> void:
	if player == null:
		return
	var r := Game.run
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_label.text = "%d / %d" % [ceili(player.hp), int(player.max_hp)]
	potion_label.text = "%d   (Q)" % r.potions
	gold_label.text = str(r.gold)
	skill_name.text = "%s" % player.cls.name.to_upper()
	if _skill_icon_class != player.class_id:
		_skill_icon_class = player.class_id
		skill_widget.title = player.cls.skill_name.to_upper()
		var icon_model: String = {"knight": "shield_badge_color", "barbarian": "axe_2handed", "ranger": "arrow_bow_bundle",
			"mage": "spellbook_open", "rogue": "smokebomb", "paladin": "paladin_shield", "druid": "druid_staff",
			"engineer": "turret_base"}.get(player.class_id, "sword_1handed")
		skill_widget.icon = icons.icon(Models.WEAPON % icon_model, 128, Vector3(-0.3, 0.7, 0.2))
	weapon_label.text = "%s WEAPON" % Game.WEAPON_TIERS[r.weapon_tier].to_upper()
	weapon_label.add_theme_color_override("font_color", [Color(0.8, 0.8, 0.8), Color(0.4, 1, 0.5), Color(0.5, 0.65, 1)][r.weapon_tier])
	var scd: float = float(player.cls.skill_cd) * float(r.cd_mult)
	skill_widget.set_state(player.skill_cd, scd)
	dodge_widget.set_state(player.dodge_cd, 0.75)
	var low := 1.0 - clampf(player.hp / player.max_hp / 0.35, 0, 1)
	(vignette.material as ShaderMaterial).set_shader_parameter("strength", low * (0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)))
	if boss and is_instance_valid(boss) and not boss.dead:
		boss_root.visible = true
		var info: Dictionary = Game.BOSSES.get(boss.boss_id, Game.BOSSES.bone_king)
		boss_label.text = String(info.name).to_upper()
		boss_label.add_theme_color_override("font_color", info.color)
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp
	else:
		boss_root.visible = false
	var names := []
	for b in r.boons:
		names.append(Game.BOONS[b].name)
	var txt := ("BOONS: " + ", ".join(names)) if names.size() > 0 else ""
	var lg: Array = []
	for l in r.get("legends", []):
		lg.append(Game.legend_info(l).name)
	if lg.size() > 0:
		txt += ("\n" if txt != "" else "") + "GEAR: " + ", ".join(lg)
	var bw: Array = []
	for b in r.get("brews", []):
		bw.append(Game.BREWS[b].name)
	if bw.size() > 0:
		txt += ("\n" if txt != "" else "") + "BREWS: " + ", ".join(bw)
	var mt: Array = []
	for id in Game.MATERIAL_ORDER:
		var n := int(r.get("mats", {}).get(id, 0))
		if n > 0:
			mt.append("%d %s" % [n, Game.MATERIALS[id].name])
	if mt.size() > 0:
		txt += ("\n" if txt != "" else "") + "LOOT: " + ", ".join(mt)
	boon_label.text = txt


func set_floor_info(floor_num: int, room_idx: int, room_type: String) -> void:
	floor_label.text = "FLOOR %d%s  -  %s" % [floor_num, "  (ENDLESS)" if floor_num > Game.FLOORS else "", room_type.to_upper()]
	var t := Game.torment_level()
	if t > 0:
		floor_label.text += "   |   %s" % Game.TORMENT_NAMES[t].to_upper()
	for c in path_row.get_children():
		c.queue_free()
	for i in Game.ROOMS_PER_FLOOR:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(36, 12)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		if i < room_idx:
			sb.bg_color = Color(0.6, 0.5, 0.3)
		elif i == room_idx:
			sb.bg_color = GOLD
		else:
			sb.bg_color = Color(0.25, 0.22, 0.2)
		if i == Game.ROOMS_PER_FLOOR - 1:
			sb.border_color = Color(1, 0.3, 0.2) if Game.is_boss_floor(floor_num) else Color(0.4, 0.6, 1)
			sb.set_border_width_all(2)
		p.add_theme_stylebox_override("panel", sb)
		path_row.add_child(p)


func show_banner(text: String, color := GOLD, duration := 1.8) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	var tw := banner.create_tween()
	banner.modulate.a = 0.0
	banner.scale = Vector2(1, 1)
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(duration)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)


func fade_to(alpha: float, duration := 0.35) -> void:
	var tw := fade.create_tween()
	tw.tween_property(fade, "color:a", alpha, duration)
	await tw.finished


# ---------------- hub ----------------

func _build_hub_hud() -> void:
	hub_root = Control.new()
	hub_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hub_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hub_root.theme = theme_
	add_child(hub_root)
	var p := PanelContainer.new()
	p.position = Vector2(20, 18)
	p.custom_minimum_size = Vector2(430, 0)
	hub_root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	row.add_child(_icon_rect(icons.icon(Models.DUNGEON % "coin", 96, Vector3(0.3, 0.4, 0)), 34))
	hub_gold = _label("0", 26, GOLD)
	row.add_child(hub_gold)
	hub_class = _label("KNIGHT", 30, GOLD)
	v.add_child(hub_class)
	hub_desc = _label("", 16)
	hub_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	hub_desc.custom_minimum_size = Vector2(400, 0)
	v.add_child(hub_desc)
	hub_stats = _label("", 15, Color(0.75, 0.75, 0.8))
	v.add_child(hub_stats)
	var hint := _label("Walk to a hero and press E to choose (E again for Mastery). Upgrades at the green shrine, Torment at the skull altar, buildings around camp. Gear: ESC > Inventory (or I). Enter the crypt to begin.\nCOMBAT: every 3rd hit in a row is a finisher. Attack right out of a roll for a dash strike. Roll just before a blow lands for a PERFECT dodge (slow-mo, next hit crits).", 15, Color(0.75, 0.85, 0.75))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.custom_minimum_size = Vector2(400, 0)
	v.add_child(hint)
	var touch_hint := func():
		hint.text = "Walk to a hero and tap USE to choose (USE again for Mastery). Upgrades at the green shrine, Torment at the skull altar, buildings around camp. Gear: pause (top right) > Inventory. Enter the crypt to begin.\nCOMBAT: every 3rd hit in a row is a finisher. Attack right out of a roll for a dash strike. Roll just before a blow lands for a PERFECT dodge (slow-mo, next hit crits)."
	Game.touch_mode_changed.connect(touch_hint)
	if Game.touch_mode:
		touch_hint.call()
	hub_root.visible = false


func update_hub() -> void:
	hub_gold.text = str(Game.bank_gold)
	var c: Dictionary = Game.CLASSES[Game.selected_class]
	hub_class.text = c.name.to_upper()
	hub_desc.text = c.desc
	var built := 0
	for k in Game.BUILDINGS:
		if Game.has_building(k): built += 1
	hub_stats.text = "HP %d   DMG %d   SPEED %.1f\nRuns %d   Wins %d   Deepest floor %d\n%s   Buildings %d/%d" % [c.hp + Game.upgrades.vitality * 12 + Game.mastery_level(Game.selected_class, "toughness") * 15, int(c.dmg), c.speed, Game.runs, Game.wins, Game.best_floor, Game.TORMENT_NAMES[Game.torment], built, Game.BUILDINGS.size()]


func show_hub(v: bool) -> void:
	hub_root.visible = v
	if v:
		update_hub()


# ---------------- title ----------------

func _build_title() -> void:
	title_root = Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_root.theme = theme_
	add_child(title_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-450, -180)
	v.custom_minimum_size = Vector2(900, 300)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	title_root.add_child(v)
	var t := _label("BONECRAWL", 120, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 22)
	v.add_child(t)
	var s := _label("Descend the crypt.  Break the Bone King.", 26, Color(0.85, 0.8, 0.75))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 50)
	v.add_child(gap)
	var press := _label("TAP TO START" if Game.touch_mode else "PRESS ANY KEY", 28, Color(1, 1, 1))
	Game.touch_mode_changed.connect(func(): press.text = "TAP TO START")
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(press)
	var tw := press.create_tween().set_loops()
	tw.tween_property(press, "modulate:a", 0.3, 0.8)
	tw.tween_property(press, "modulate:a", 1.0, 0.8)
	var credit := _label("Art: KayKit by Kay Lousberg (CC0)   Audio: Kenney, OpenGameArt (CC0)   VFX: Binbun3D (CC0)", 14, Color(0.7, 0.7, 0.7))
	credit.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	credit.position = Vector2(-600, -40)
	credit.custom_minimum_size = Vector2(1200, 0)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_root.add_child(credit)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if title_root.visible and ((event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)):
		title_root.visible = false
		get_viewport().set_input_as_handled()
		Sfx.play("ui_confirm")
		title_dismissed.emit()


# ---------------- pause ----------------

func _build_pause() -> void:
	pause_root = Control.new()
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.theme = theme_
	add_child(pause_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(shade)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = Vector2(-220, -210)
	p.custom_minimum_size = Vector2(440, 0)
	pause_root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var t := _label("PAUSED", 44, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(func(): Sfx.play("ui_click"); resume_pressed.emit())
	v.add_child(resume)
	var inv := Button.new()
	inv.name = "InventoryButton"
	inv.text = "Inventory  (I)"
	inv.pressed.connect(func(): Sfx.play("ui_open"); inventory_pressed.emit())
	v.add_child(inv)
	v.add_child(_label("Music", 18))
	_music_slider = HSlider.new()
	_music_slider.min_value = 0
	_music_slider.max_value = 1
	_music_slider.step = 0.05
	_music_slider.value = Game.music_volume
	_music_slider.value_changed.connect(func(x): Game.set_volumes(x, Game.sfx_volume))
	v.add_child(_music_slider)
	v.add_child(_label("Sound effects", 18))
	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0
	_sfx_slider.max_value = 1
	_sfx_slider.step = 0.05
	_sfx_slider.value = Game.sfx_volume
	_sfx_slider.value_changed.connect(func(x): Game.set_volumes(Game.music_volume, x); Sfx.play("ui_click"))
	v.add_child(_sfx_slider)
	var quit := Button.new()
	quit.name = "QuitButton"
	quit.text = "Abandon run (keep 50% gold)"
	quit.pressed.connect(func(): Sfx.play("ui_click"); quit_to_camp.emit())
	v.add_child(quit)
	var gfx := Button.new()
	gfx.name = "GraphicsButton"
	gfx.text = "Graphics: " + Game.graphics_label()
	gfx.pressed.connect(func(): Sfx.play("ui_click"); Game.cycle_graphics())
	Game.quality_changed.connect(func(): gfx.text = "Graphics: " + Game.graphics_label())
	v.add_child(gfx)
	var fs := Button.new()
	fs.name = "FullscreenButton"
	fs.pressed.connect(func(): Sfx.play("ui_click"); toggle_fullscreen())
	v.add_child(fs)
	_update_fullscreen_label()
	# a browser tab can't be closed by the game, so there is no Quit on web
	if not OS.has_feature("web"):
		var exit := Button.new()
		exit.text = "Quit game"
		exit.pressed.connect(func(): get_tree().quit())
		v.add_child(exit)
	pause_root.visible = false
	resume.name = "Resume"


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# the browser applies fullscreen asynchronously; refresh the label shortly after
	get_tree().create_timer(0.3, true, false, true).timeout.connect(_update_fullscreen_label)


func _update_fullscreen_label() -> void:
	var b := pause_root.find_child("FullscreenButton", true, false) as Button
	if b == null:
		return
	var mode := DisplayServer.window_get_mode()
	var full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	b.text = "Exit fullscreen  (F11)" if full else "Fullscreen  (F11)"


var _pause_in_run := false

func show_pause(v: bool, in_run: bool) -> void:
	_pause_in_run = in_run
	pause_root.visible = v
	_update_fullscreen_label()
	(pause_root.find_child("QuitButton", true, false) as Button).visible = in_run
	if v:
		(pause_root.find_child("Resume", true, false) as Button).grab_focus()


# ---------------- modals ----------------

func _clear_modal() -> void:
	_equip_open = false
	for c in modal_root.get_children():
		c.queue_free()


func _modal_panel(title: String, width := 900.0) -> VBoxContainer:
	_clear_modal()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	# panels taller than the screen (phones, small windows) scroll instead of running off the edge
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var fit := func():
		if not is_instance_valid(scroll):
			return
		var max_h := modal_root.get_viewport_rect().size.y - 70.0
		scroll.custom_minimum_size.y = minf(v.get_combined_minimum_size().y, max_h)
	v.minimum_size_changed.connect(fit)
	fit.call_deferred()
	var t := _label(title, 40, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return v


func close_modal() -> void:
	_clear_modal()


func modal_open() -> bool:
	return modal_root.get_child_count() > 0


func show_boons(options: Array) -> void:
	var v := _modal_panel("THE SHRINE OFFERS A BOON", 1000)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var first: Button = null
	for id in options:
		var b: Dictionary = Game.BOONS[id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(300, 170)
		btn.text = "%s\n\n%s" % [b.name.to_upper(), b.desc]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.pressed.connect(func():
			Sfx.play("boon")
			close_modal()
			boon_picked.emit(id))
		row.add_child(btn)
		if first == null:
			first = btn
	if first:
		first.grab_focus()


func show_upgrades() -> void:
	var v := _modal_panel("UPGRADES", 760)
	var gold := _label("Gold: %d" % Game.bank_gold, 26, GOLD)
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(gold)
	var first: Button = null
	for id in Game.UPGRADES:
		var u: Dictionary = Game.UPGRADES[id]
		var lvl: int = Game.upgrades[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		v.add_child(row)
		var info := _label("%s  (%d/%d)\n%s" % [u.name.to_upper(), lvl, u.max, u.desc], 18)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 56)
		if lvl >= u.max:
			btn.text = "MAXED"
			btn.disabled = true
		else:
			var cost := Game.upgrade_cost(id)
			btn.text = "%d GOLD" % cost
			btn.disabled = Game.bank_gold < cost
			btn.pressed.connect(func():
				if Game.buy_upgrade(id):
					Sfx.play("upgrade")
				show_upgrades())
		row.add_child(btn)
		if first == null and not btn.disabled:
			first = btn
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func():
		Sfx.play("ui_click")
		close_modal()
		upgrades_closed.emit())
	v.add_child(close)
	(first if first else close).grab_focus()


func _close_button(v: VBoxContainer) -> Button:
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func():
		Sfx.play("ui_click")
		close_modal()
		upgrades_closed.emit())
	v.add_child(close)
	return close


func show_mastery(class_id: String) -> void:
	var cls: Dictionary = Game.CLASSES[class_id]
	var v := _modal_panel("%s MASTERY" % cls.name.to_upper(), 820)
	var gold := _label("Gold: %d" % Game.bank_gold, 26, GOLD)
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(gold)
	var first: Button = null
	for d in Game.MASTERY[class_id]:
		var lvl := Game.mastery_level(class_id, d.id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		v.add_child(row)
		var pips := ""
		for i in int(d.max):
			pips += "#" if i < lvl else "-"
		var info := _label("%s  [%s]\n%s" % [str(d.name).to_upper(), pips, d.desc], 18)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 56)
		if lvl >= int(d.max):
			btn.text = "MASTERED"
			btn.disabled = true
		else:
			var cost := Game.mastery_cost(class_id, d.id)
			btn.text = "%d GOLD" % cost
			btn.disabled = Game.bank_gold < cost
			var id: String = d.id
			btn.pressed.connect(func():
				if Game.buy_mastery(class_id, id):
					Sfx.play("upgrade")
				show_mastery(class_id))
		row.add_child(btn)
		if first == null and not btn.disabled:
			first = btn
	var close := _close_button(v)
	(first if first else close).grab_focus()


func show_build(id: String) -> void:
	var info: Dictionary = Game.BUILDINGS[id]
	var built := Game.has_building(id)
	var v := _modal_panel(str(info.name).to_upper(), 640)
	var desc := _label(info.desc, 22)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	if built:
		var done := _label("BUILT", 26, Color(0.5, 1, 0.6))
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(done)
		_close_button(v).grab_focus()
		return
	var gold := _label("Cost: %d gold   (you have %d)" % [info.cost, Game.bank_gold], 20, GOLD)
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(gold)
	var btn := Button.new()
	btn.text = "BUILD"
	btn.disabled = Game.bank_gold < int(info.cost)
	btn.pressed.connect(func():
		if Game.build(id):
			Sfx.play("upgrade")
			close_modal()
			upgrades_closed.emit()
		else:
			Sfx.play("ui_error"))
	v.add_child(btn)
	var close := _close_button(v)
	(btn if not btn.disabled else close).grab_focus()


func show_torment() -> void:
	var v := _modal_panel("TORMENT", 900)
	var sub := _label("Each level: +30% enemy health, +20% damage, faster foes, more elites and +35% gold.\nBeat the Bone King to unlock the next level. Torment I to V must each be conquered by a DIFFERENT hero.", 16, Color(0.85, 0.8, 0.75))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var gold := _label("Gold: %d" % Game.bank_gold, 22, GOLD)
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(gold)
	var hero: String = Game.selected_class
	var used := Game.torment_conqueror_level(hero)
	var free: Array = Game.torment_free_heroes().map(func(c): return Game.CLASSES[c].name)
	var note := ""
	if used > 0:
		note = "Your %s already conquered %s, so a Torment win with them won't count toward a new level. Heroes still free: %s." % [
			Game.CLASSES[hero].name, Game.TORMENT_NAMES[used], ", ".join(free) if free.size() > 0 else "none"]
	else:
		note = "Your %s hasn't conquered a Torment level yet: their next Torment win will count." % Game.CLASSES[hero].name
	var nl := _label(note, 16, Color(1, 0.6, 0.4) if used > 0 else Color(0.6, 1, 0.65))
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nl)
	var first: Button = null
	for lvl in Game.TORMENT_MAX + 1:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		v.add_child(row)
		var name_col := Color(1, 0.45, 0.35) if lvl > 0 else Color(0.9, 0.9, 0.9)
		var desc := "Gold x%.2f" % (1.0 + 0.35 * lvl) if lvl > 0 else "The standard crypt"
		if lvl > 0:
			var who: String = Game.torment_clears.get(str(lvl), "")
			if who == "legacy":
				desc += "   ·   CONQUERED"
			elif who != "":
				desc += "   ·   CONQUERED BY %s" % Game.CLASSES[who].name.to_upper()
		var info := _label("%s\n%s" % [Game.TORMENT_NAMES[lvl].to_upper(), desc], 18, name_col)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(300, 56)
		if lvl <= Game.torment_unlocked:
			btn.text = "SELECTED" if lvl == Game.torment else "SELECT"
			btn.disabled = lvl == Game.torment
			btn.pressed.connect(func():
				Game.torment = lvl
				Game.save_game()
				Sfx.play("ui_confirm")
				show_torment())
		elif Game.can_unlock_torment(lvl):
			btn.text = "UNLOCK  %d GOLD" % Game.TORMENT_COSTS[lvl]
			btn.disabled = Game.bank_gold < Game.TORMENT_COSTS[lvl]
			btn.pressed.connect(func():
				if Game.unlock_torment(lvl):
					Sfx.play("boss")
				show_torment())
		else:
			btn.text = "CONQUER %s FIRST" % Game.TORMENT_NAMES[lvl - 1].to_upper()
			btn.disabled = true
		row.add_child(btn)
		if first == null and not btn.disabled:
			first = btn
	var close := _close_button(v)
	(first if first else close).grab_focus()


# ---------------- gear UI ----------------

func item_icon(it: Dictionary) -> Texture2D:
	if it.slot == "weapon":
		var wp: String = Game.weapon_path(Game.CLASS_WEAPONS[it["class"]].models[int(it.rarity)])
		return icons.icon(wp, 128, Vector3(-0.35, 0.6, 0.6))
	var path: String = Game.SLOT_MODELS[it.slot][int(it.rarity)]
	return icons.icon(path, 128, Vector3(-0.35, 0.6, 0.0))


func item_kind_name(it: Dictionary) -> String:
	if it.slot == "weapon":
		return "%s %s" % [Game.CLASSES[it["class"]].name, Game.CLASS_WEAPONS[it["class"]].noun]
	return Game.SLOT_NAMES[it.slot]


func item_card(it: Dictionary, width := 250.0) -> PanelContainer:
	var r := int(it.rarity)
	var col: Color = Game.RARITY_COLORS[r]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.1, 0.95)
	sb.border_color = col
	sb.set_border_width_all(3 if r < 4 else 4)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	if r == 4:
		sb.shadow_color = Color(col.r, col.g, col.b, 0.45)
		sb.shadow_size = 10
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(_icon_rect(item_icon(it), 52))
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	var n := _label(str(it.name).to_upper(), 15, col)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD
	names.add_child(n)
	names.add_child(_label("%s %s" % [Game.RARITIES[r].to_upper(), item_kind_name(it).to_upper()], 12, Color(0.7, 0.7, 0.72)))
	for k in it.stats:
		var val := int(it.stats[k])
		var label: String = Game.STATS[k][0]
		var line := ("+%d %s" % [val, label]) if k == "hp" else ("%s%d%s" % ["-" if k == "cdr" else "+", val, label])
		v.add_child(_label(line, 14, Color(0.85, 0.95, 0.85)))
	if str(it.get("legend", "")) != "":
		var lg: Dictionary = Game.legend_info(it.legend)
		var l := _label("%s: %s" % [str(lg.name).to_upper(), lg.desc], 14, Game.RARITY_COLORS[4])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(l)
	return card


func _gold_header(v: VBoxContainer) -> void:
	var gold := _label("Gold: %d" % Game.bank_gold, 24, GOLD)
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(gold)


func _gear_hint() -> Label:
	var l := _label("Equip your gear from  ESC > Inventory  (or press I)", 15, Color(0.7, 0.7, 0.72))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func show_armory(tab := "shop") -> void:
	var v := _modal_panel("ARMORY", 1180)
	_gold_header(v)
	_tabs(v, tab, ["shop", "forge"], ["BUY GEAR", "FORGE GEAR"], show_armory)
	if tab == "forge":
		_forge_panel(v, "armour", "", show_armory.bind("forge"))
		v.add_child(_gear_hint())
		_close_button(v)
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var first: Button = null
	if Game.shop_stock.is_empty():
		row.add_child(_label("Sold out. Stock refreshes after your next run (or reroll).", 18))
	for i in Game.shop_stock.size():
		var it: Dictionary = Game.shop_stock[i]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		row.add_child(col)
		col.add_child(item_card(it, 260))
		var b := Button.new()
		var price := Game.item_price(it)
		b.text = "BUY  %d GOLD" % price
		b.disabled = Game.bank_gold < price or Game.stash.size() >= Game.STASH_MAX
		var idx := i
		b.pressed.connect(func():
			if Game.buy_shop_item(idx):
				Sfx.play("coin")
			show_armory())
		col.add_child(b)
		if first == null and not b.disabled:
			first = b
	var rr := Button.new()
	rr.text = "REROLL STOCK  %d GOLD" % Game.REROLL_COST
	rr.disabled = Game.bank_gold < Game.REROLL_COST
	rr.pressed.connect(func():
		if Game.reroll_shop():
			Sfx.play("ui_confirm")
		show_armory())
	v.add_child(rr)
	v.add_child(_gear_hint())
	var close := _close_button(v)
	(first if first else close).grab_focus()


# ---------------- shared shop widgets ----------------

func _tabs(v: VBoxContainer, current: String, ids: Array, labels: Array, open_fn: Callable) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for i in ids.size():
		var b := Button.new()
		b.text = labels[i]
		b.custom_minimum_size = Vector2(240, 46)
		var id: String = ids[i]
		if id == current:
			_mark_selected(b, GOLD)
		b.pressed.connect(func(): Sfx.play("ui_click"); open_fn.call(id))
		row.add_child(b)


func _mark_selected(b: Button, col: Color) -> void:
	## The chosen tab/option: lit up with a coloured frame (and not clickable again).
	b.disabled = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.95)
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	b.add_theme_stylebox_override("disabled", sb)
	b.add_theme_color_override("font_disabled_color", col.lightened(0.3))


func _mats_row(v: VBoxContainer) -> void:
	## Banked materials with their icons.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	for id in Game.MATERIAL_ORDER:
		var md: Dictionary = Game.MATERIALS[id]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		row.add_child(hb)
		var mi := _icon_rect(icons.icon(md.model, 96, Vector3(-0.4, 0.6, 0.2)), 34)
		if id == "essence": mi.modulate = md.color
		hb.add_child(mi)
		hb.add_child(_label("%d %s" % [Game.mat_count(id), md.name], 15, md.color))


var _forge_slot := "helm"
var _forge_rarity := 2
var _forge_legend := "vampiric"
var _forged: Dictionary = {}

func _forge_panel(v: VBoxContainer, kind: String, class_id: String, reopen: Callable) -> void:
	## kind "armour" (pick a slot, and the power of a Legendary) or "weapon" (for class_id).
	_mats_row(v)
	if not _forged.is_empty():
		var fc := CenterContainer.new()
		v.add_child(fc)
		var fv := VBoxContainer.new()
		fv.add_theme_constant_override("separation", 6)
		fc.add_child(fv)
		var t := _label("FORGED!", 24, Game.RARITY_COLORS[int(_forged.rarity)])
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fv.add_child(t)
		fv.add_child(item_card(_forged, 360))
		var hb0 := HBoxContainer.new()
		hb0.alignment = BoxContainer.ALIGNMENT_CENTER
		hb0.add_theme_constant_override("separation", 10)
		fv.add_child(hb0)
		var eq := Button.new()
		eq.text = "EQUIP NOW"
		var fid: String = _forged.id
		eq.pressed.connect(func():
			Game.equip(fid)
			Sfx.play("upgrade")
			equipment_changed.emit()
			_forged = {}
			reopen.call())
		hb0.add_child(eq)
		var again := Button.new()
		again.text = "FORGE ANOTHER"
		again.pressed.connect(func(): _forged = {}; Sfx.play("ui_click"); reopen.call())
		hb0.add_child(again)
		eq.grab_focus()
		return
	if kind == "armour":
		var srow := HBoxContainer.new()
		srow.alignment = BoxContainer.ALIGNMENT_CENTER
		srow.add_theme_constant_override("separation", 8)
		v.add_child(srow)
		for slot in Game.SLOTS:
			var sb := Button.new()
			sb.text = Game.SLOT_NAMES[slot].to_upper()
			sb.custom_minimum_size = Vector2(150, 42)
			if slot == _forge_slot:
				_mark_selected(sb, GOLD)
			sb.pressed.connect(func(): _forge_slot = slot; Sfx.play("ui_click"); reopen.call())
			srow.add_child(sb)
	var rrow := HBoxContainer.new()
	rrow.alignment = BoxContainer.ALIGNMENT_CENTER
	rrow.add_theme_constant_override("separation", 8)
	v.add_child(rrow)
	for r in [2, 3, 4]:
		var rb := Button.new()
		rb.text = Game.RARITIES[r].to_upper()
		rb.custom_minimum_size = Vector2(190, 42)
		rb.add_theme_color_override("font_color", Game.RARITY_COLORS[r])
		if r == _forge_rarity:
			_mark_selected(rb, Game.RARITY_COLORS[r])
		rb.pressed.connect(func(): _forge_rarity = r; Sfx.play("ui_click"); reopen.call())
		rrow.add_child(rb)
	# what comes out
	var what := ""
	if kind == "weapon":
		var cw: Dictionary = Game.CLASS_WEAPONS[class_id]
		what = "%s %s %s: +%d%% damage and %d more random bonus%s." % [Game.RARITIES[_forge_rarity], Game.CLASSES[class_id].name, cw.noun,
			Game.WEAPON_DMG[_forge_rarity], Game.RARITY_LINES[_forge_rarity] - 1, "" if Game.RARITY_LINES[_forge_rarity] == 2 else "es"]
		if _forge_rarity == 4:
			what = "%s, the legendary %s %s: +%d%% damage, 3 more bonuses, and\n%s." % [cw.legend_name.to_upper(), Game.CLASSES[class_id].name, cw.noun, Game.WEAPON_DMG[4], cw.legend_desc]
	else:
		what = "%s %s with %d random bonuses." % [Game.RARITIES[_forge_rarity], Game.SLOT_NAMES[_forge_slot], Game.RARITY_LINES[_forge_rarity]]
		if _forge_rarity == 4:
			what = "Legendary %s with 4 strong bonuses and the power you choose:" % Game.SLOT_NAMES[_forge_slot]
	var wl := _label(what, 16, Color(0.85, 0.85, 0.8))
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(wl)
	if kind == "armour" and _forge_rarity == 4:
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		var gc := CenterContainer.new()
		gc.add_child(grid)
		v.add_child(gc)
		for lid in Game.LEGENDS:
			var lb := Button.new()
			lb.text = str(Game.LEGENDS[lid].name).to_upper()
			lb.custom_minimum_size = Vector2(220, 38)
			lb.tooltip_text = Game.LEGENDS[lid].desc
			if lid == _forge_legend:
				_mark_selected(lb, Game.RARITY_COLORS[4])
			lb.pressed.connect(func(): _forge_legend = lid; Sfx.play("ui_click"); reopen.call())
			grid.add_child(lb)
		var ld := _label(Game.LEGENDS[_forge_legend].desc, 15, Game.RARITY_COLORS[4])
		ld.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ld)
	# recipe
	var cost: Dictionary = Game.CRAFT_COSTS[_forge_rarity]
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 16)
	v.add_child(crow)
	crow.add_child(_label("COST:", 16, Color(0.8, 0.8, 0.8)))
	crow.add_child(_label("%d gold" % cost.gold, 16, GOLD if Game.bank_gold >= int(cost.gold) else Color(1, 0.4, 0.35)))
	for m in cost.mats:
		var have := Game.mat_count(m)
		var need := int(cost.mats[m])
		crow.add_child(_label("%d/%d %s" % [have, need, Game.MATERIALS[m].name], 16, Color(0.6, 1, 0.6) if have >= need else Color(1, 0.4, 0.35)))
	var fb := Button.new()
	fb.text = "FORGE"
	fb.custom_minimum_size = Vector2(320, 52)
	fb.disabled = not Game.can_craft(_forge_rarity)
	fb.pressed.connect(func():
		var it := Game.craft(_forge_rarity, "weapon" if kind == "weapon" else _forge_slot, class_id, _forge_legend)
		if it.is_empty():
			Sfx.play("ui_error")
			return
		Sfx.play("victory" if _forge_rarity == 4 else "upgrade")
		Fx.shake(0.2, 0.15)
		_forged = it
		reopen.call())
	var fcc := CenterContainer.new()
	fcc.add_child(fb)
	v.add_child(fcc)
	if Game.stash.size() >= Game.STASH_MAX:
		v.add_child(_label("Your stash is full (%d). Sell something first." % Game.STASH_MAX, 15, Color(1, 0.5, 0.4)))
	elif not fb.disabled:
		fb.grab_focus()


# ---------------- blacksmith ----------------

func show_blacksmith(tab := "shop") -> void:
	var hero := Game.selected_class
	var v := _modal_panel("BLACKSMITH", 1180)
	_gold_header(v)
	_tabs(v, tab, ["shop", "forge"], ["BUY WEAPONS", "FORGE WEAPONS"], show_blacksmith)
	var who := _label("Weapons for your %s (each hero has their own weapon slot; pick another hero in camp to shop for them)." % Game.CLASSES[hero].name, 15, Color(0.75, 0.75, 0.72))
	who.autowrap_mode = TextServer.AUTOWRAP_WORD
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(who)
	if tab == "forge":
		_forge_panel(v, "weapon", hero, show_blacksmith.bind("forge"))
		v.add_child(_gear_hint())
		_close_button(v)
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var stock := Game.weapon_shop(hero)
	var first: Button = null
	if stock.is_empty():
		row.add_child(_label("Sold out. New weapons after your next run.", 18))
	for i in stock.size():
		var it: Dictionary = stock[i]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		row.add_child(col)
		col.add_child(item_card(it, 300))
		var b := Button.new()
		b.text = "BUY  %d GOLD" % Game.item_price(it)
		b.disabled = Game.bank_gold < Game.item_price(it) or Game.stash.size() >= Game.STASH_MAX
		var idx := i
		b.pressed.connect(func():
			if Game.buy_weapon(hero, idx):
				Sfx.play("coin")
			show_blacksmith())
		col.add_child(b)
		if first == null and not b.disabled:
			first = b
	var lg := _label("Legendary weapons can't be bought: forge them from materials (Forge tab).", 15, Game.RARITY_COLORS[4])
	lg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lg)
	v.add_child(_gear_hint())
	var close := _close_button(v)
	(first if first else close).grab_focus()


# ---------------- merchant (materials) ----------------

func show_merchant() -> void:
	var v := _modal_panel("MERCHANT'S TENT", 980)
	_gold_header(v)
	var sub := _label("Crafting materials for the Blacksmith and Armory forges. Skeletons drop them too (elites always do, the Bone King drops King's Shards).", 15, Color(0.8, 0.78, 0.74))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var first: Button = null
	for id in Game.MATERIAL_ORDER:
		var md: Dictionary = Game.MATERIALS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var mi := _icon_rect(icons.icon(md.model, 96, Vector3(-0.4, 0.6, 0.2)), 48)
		if id == "essence": mi.modulate = md.color
		row.add_child(mi)
		var info := _label("%s\nYou have %d   ·   %d gold each" % [str(md.name).to_upper(), Game.mat_count(id), md.price], 16, md.color)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		for n in [1, 5]:
			var b := Button.new()
			b.text = "BUY %d\n%d" % [n, int(md.price) * n]
			b.custom_minimum_size = Vector2(110, 54)
			b.disabled = Game.bank_gold < int(md.price) * n
			b.pressed.connect(func():
				if Game.buy_material(id, n):
					Sfx.play("coin")
				show_merchant())
			row.add_child(b)
			if first == null and not b.disabled:
				first = b
		var sb := Button.new()
		sb.text = "SELL 1\n+%d" % Game.material_sell_price(id)
		sb.custom_minimum_size = Vector2(110, 54)
		sb.disabled = Game.mat_count(id) < 1
		sb.pressed.connect(func():
			if Game.sell_material(id, 1):
				Sfx.play("coin")
			show_merchant())
		row.add_child(sb)
	var close := _close_button(v)
	(first if first else close).grab_focus()


# ---------------- alchemist (brews) ----------------

func show_alchemist() -> void:
	var v := _modal_panel("ALCHEMIST", 1100)
	_gold_header(v)
	var sub := _label("Brews are drunk at the start of your next run and last the whole run. Up to %d per run." % Game.BREW_MAX, 16, Color(0.8, 0.9, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	v.add_child(gc)
	var first: Button = null
	for id in Game.BREWS:
		var bd: Dictionary = Game.BREWS[id]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(330, 0)
		grid.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		cv.add_child(top)
		var bi := _icon_rect(icons.icon(Models.DUNGEON % bd.model, 96, Vector3(-0.3, 0.5, 0)), 52)
		bi.modulate = bd.color   # the potion glass renders white: tint it with the brew's colour
		top.add_child(bi)
		var nl := _label("%s\n%s" % [str(bd.name).to_upper(), bd.desc], 15)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nl)
		var b := Button.new()
		var owned := Game.brew_count(id)
		b.text = "BREW  %d GOLD" % bd.price + ("   (ready x%d)" % owned if owned > 0 else "")
		b.disabled = not Game.can_buy_brew(id)
		b.pressed.connect(func():
			if Game.buy_brew(id):
				Sfx.play("potion")
			show_alchemist())
		cv.add_child(b)
		if first == null and not b.disabled:
			first = b
	var names: Array = []
	for b2 in Game.brews:
		names.append(Game.BREWS[b2].name)
	var q := _label("READY FOR NEXT RUN (%d/%d):  %s" % [Game.brews.size(), Game.BREW_MAX, ", ".join(names) if names.size() > 0 else "nothing yet"], 17, Color(0.5, 1, 0.65))
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(q)
	var close := _close_button(v)
	(first if first else close).grab_focus()


# ---------------- treasury ----------------

func show_treasury() -> void:
	var v := _modal_panel("TREASURY", 820)
	_gold_header(v)
	var pct := int(round(Game.death_keep_fraction() * 100))
	var big := _label("You keep %d%% of your gold when you fall" % pct, 26, Color(0.6, 1, 0.65))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 6)
	v.add_child(pips)
	for i in Game.TREASURY_MAX:
		var pnl := Panel.new()
		pnl.custom_minimum_size = Vector2(56, 22)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		sb.bg_color = GOLD if i < Game.treasury_level else Color(0.22, 0.2, 0.18)
		pnl.add_theme_stylebox_override("panel", sb)
		pnl.tooltip_text = "%d%%" % (55 + i * 5)
		pips.add_child(pnl)
	var range_l := _label("50%   ->   95%", 15, Color(0.7, 0.7, 0.7))
	range_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(range_l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 56)
	if Game.treasury_level >= Game.TREASURY_MAX:
		b.text = "FULLY UPGRADED"
		b.disabled = true
	else:
		b.text = "REINFORCE THE VAULT: %d%% -> %d%%   (%d GOLD)" % [pct, pct + 5, Game.treasury_cost()]
		b.disabled = Game.bank_gold < Game.treasury_cost()
		b.pressed.connect(func():
			if Game.upgrade_treasury():
				Sfx.play("upgrade")
			show_treasury())
	v.add_child(b)
	var close := _close_button(v)
	(b if not b.disabled else close).grab_focus()


var _equip_open := false
var _equip_mode := "hub"   # hub | pause | run: where closing the inventory returns to

func open_inventory_from_pause() -> void:
	pause_root.visible = false
	show_equipment("pause")


func equipment_open() -> bool:
	return _equip_open and modal_open()


func close_equipment() -> void:
	Sfx.play("ui_click")
	close_modal()
	match _equip_mode:
		"pause":
			show_pause(true, _pause_in_run)
		"run":
			inventory_closed_run.emit()
		_:
			upgrades_closed.emit()


func show_equipment(mode := "") -> void:
	if mode != "":
		_equip_mode = mode
	var in_run := _equip_mode == "run" or (_equip_mode == "pause" and _pause_in_run)
	var v := _modal_panel("INVENTORY", 1320)
	_equip_open = true
	var hero: String = Game.active_class()
	if in_run:
		var note := _label("Changes apply to this run right away.", 15, Color(0.7, 0.9, 0.75))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(note)
	_gold_header(v)
	# equipped slots
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 12)
	v.add_child(slots)
	for slot in [Game.weapon_key(hero)] + Game.SLOTS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		slots.add_child(col)
		if Game.equipped.has(slot):
			col.add_child(item_card(Game.equipped[slot], 245))
			var ub := Button.new()
			ub.text = "UNEQUIP"
			ub.pressed.connect(func(): Game.unequip(slot); Sfx.play("ui_click"); equipment_changed.emit(); show_equipment())
			col.add_child(ub)
		else:
			var empty := PanelContainer.new()
			empty.custom_minimum_size = Vector2(245, 120)
			col.add_child(empty)
			var slot_name: String = ("%s WEAPON" % Game.CLASSES[hero].name) if str(slot).begins_with("weapon_") else Game.SLOT_NAMES[slot]
			var el := _label("EMPTY %s SLOT" % slot_name.to_upper(), 14, Color(0.55, 0.55, 0.58))
			el.autowrap_mode = TextServer.AUTOWRAP_WORD
			el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.add_child(el)
	# totals
	var g := Game.gear_totals()
	var parts: Array = []
	for k in Game.STATS:
		if int(g[k]) != 0:
			parts.append(("+%d %s" % [g[k], Game.STATS[k][0]]) if k != "cdr" else ("-%d%s" % [g[k], Game.STATS[k][0]]))
	for l in g.legends:
		parts.append(str(Game.legend_info(l).name).to_upper())
	var tot := _label("TOTAL:  " + ("   ".join(parts) if parts.size() > 0 else "nothing equipped"), 15, Color(0.75, 0.95, 0.8))
	tot.autowrap_mode = TextServer.AUTOWRAP_WORD
	tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tot)
	v.add_child(_label("STASH  (%d/%d)" % [Game.stash.size(), Game.STASH_MAX], 18, GOLD))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var sorted := Game.stash.duplicate()
	sorted.sort_custom(func(a, b): return int(a.rarity) > int(b.rarity))
	var mine := sorted.filter(func(x): return x.slot != "weapon" or x["class"] == hero)
	var others := sorted.filter(func(x): return x.slot == "weapon" and x["class"] != hero)
	sorted = mine + others
	var first: Button = null
	for it in sorted:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		grid.add_child(col)
		col.add_child(item_card(it, 280))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		col.add_child(hb)
		var eb := Button.new()
		eb.text = "EQUIP"
		if it.slot == "weapon" and it["class"] != hero:
			eb.text = "EQUIP (%s)" % Game.CLASSES[it["class"]].name.to_upper()
		eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var item_id: String = it.id
		eb.pressed.connect(func(): Game.equip(item_id); Sfx.play("upgrade"); equipment_changed.emit(); show_equipment())
		hb.add_child(eb)
		var sbtn := Button.new()
		sbtn.text = "SELL %d" % Game.sell_value(it)
		sbtn.pressed.connect(func(): Game.sell(item_id); Sfx.play("coin"); equipment_changed.emit(); show_equipment())
		hb.add_child(sbtn)
		if first == null:
			first = eb
	if sorted.is_empty():
		grid.add_child(_label("No gear yet. Buy or forge it at the Armory and Blacksmith, win it at the Gambler's Den, or find weapons in the crypt.", 16, Color(0.7, 0.7, 0.7)))
	var close := Button.new()
	close.text = "Back" if _equip_mode == "pause" else "Close"
	close.pressed.connect(close_equipment)
	v.add_child(close)
	(first if first else close).grab_focus()


var _wheel: RouletteWheel
var _wheel_result: Label
var _wager_buttons: Array = []

func show_gambler() -> void:
	var v := _modal_panel("GAMBLER'S DEN", 1180)
	_gold_header(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	v.add_child(row)
	# --- roulette ---
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left)
	left.add_child(_label("WHEEL OF BONES", 22, GOLD))
	_wheel = RouletteWheel.new()
	_wheel.font = font
	_wheel.slices = Game.WHEEL
	left.add_child(_wheel)
	_wheel_result = _label("Bet a share of your gold. The wheel pays x0 to x2.", 16, Color(0.85, 0.82, 0.78))
	_wheel_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wheel_result.custom_minimum_size = Vector2(420, 50)
	_wheel_result.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(_wheel_result)
	var bets := HBoxContainer.new()
	bets.alignment = BoxContainer.ALIGNMENT_CENTER
	bets.add_theme_constant_override("separation", 8)
	left.add_child(bets)
	_wager_buttons.clear()
	for frac in [0.1, 0.25, 0.5, 1.0]:
		var b := Button.new()
		var amount := int(Game.bank_gold * frac)
		b.text = ("ALL IN\n%d" % amount) if frac == 1.0 else ("BET %d%%\n%d" % [int(frac * 100), amount])
		b.custom_minimum_size = Vector2(110, 64)
		b.disabled = amount < 10
		b.pressed.connect(_spin.bind(frac))
		bets.add_child(b)
		_wager_buttons.append(b)
	# --- chests ---
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_label("LOOT CHESTS", 22, GOLD))
	for id in Game.LOOT_CHESTS:
		var c: Dictionary = Game.LOOT_CHESTS[id]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		right.add_child(hb)
		hb.add_child(_icon_rect(icons.chest_icon(c.tier, 128), 80))
		var odds: Array = []
		for r in 5:
			if int(c.weights[r]) > 0:
				odds.append("%s %d%%" % [Game.RARITIES[r], c.weights[r]])
		var info := _label("%s\n%d-%d gold + 1 gear\n%s" % [str(c.name).to_upper(), c.gold[0], c.gold[1], ", ".join(odds)], 14)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD
		hb.add_child(info)
		var b := Button.new()
		b.text = "%d GOLD" % c.price
		b.custom_minimum_size = Vector2(150, 56)
		b.disabled = Game.bank_gold < int(c.price)
		b.pressed.connect(_open_chest.bind(id))
		hb.add_child(b)
	right.add_child(_gear_hint())
	var close := _close_button(v)
	if not (_wager_buttons[0] as Button).disabled:
		(_wager_buttons[0] as Button).grab_focus()
	else:
		close.grab_focus()


func _spin(frac: float) -> void:
	if _wheel == null or _wheel.spinning:
		return
	var wager := int(Game.bank_gold * frac)
	var res := Game.spin_wheel(wager)
	if res.is_empty():
		return
	for b in _wager_buttons:
		(b as Button).disabled = true
	_wheel_result.text = "Spinning for %d gold..." % wager
	_wheel_result.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	Sfx.play("ui_open")
	_wheel.spin_to(res.index)
	await _wheel.stopped
	var mult: float = res.mult
	var net: int = res.payout - res.wager
	var col := Color(0.4, 1, 0.5) if net > 0 else (Color(1, 0.4, 0.3) if net < 0 else Color(0.9, 0.9, 0.9))
	_wheel_result.text = "x%s!  %s%d gold" % [str(mult).trim_suffix(".0"), "+" if net >= 0 else "", net]
	_wheel_result.add_theme_color_override("font_color", col)
	Sfx.play("victory" if mult >= 1.75 else ("upgrade" if net > 0 else ("ui_error" if mult == 0.0 else "coin")))
	Game.gold_changed.emit()
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(_wheel) and modal_open():
		var keep := _wheel_result.text
		show_gambler()
		_wheel_result.text = keep
		_wheel_result.add_theme_color_override("font_color", col)


func _open_chest(id: String) -> void:
	var res := Game.open_loot_chest(id)
	if res.is_empty():
		Sfx.play("ui_error")
		return
	var c: Dictionary = Game.LOOT_CHESTS[id]
	var v := _modal_panel(str(c.name).to_upper(), 620)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 150)
	v.add_child(holder)
	var chest := _icon_rect(icons.chest_icon(c.tier, 256), 150)
	chest.pivot_offset = Vector2(75, 75)
	holder.add_child(chest)
	var tw := chest.create_tween()
	for i in 8:
		tw.tween_property(chest, "rotation", 0.1 if i % 2 == 0 else -0.1, 0.07)
	tw.tween_property(chest, "rotation", 0.0, 0.05)
	await tw.finished
	if not is_instance_valid(v):
		return
	Sfx.play("chest")
	var tw3 := chest.create_tween()
	tw3.tween_property(chest, "scale", Vector2(1.35, 1.35), 0.12)
	tw3.parallel().tween_property(chest, "modulate", Color(2.2, 1.9, 1.2, 1.0), 0.12)
	tw3.tween_property(chest, "scale", Vector2(0.9, 0.9), 0.25)
	tw3.parallel().tween_property(chest, "modulate", Color(1, 1, 1, 0.35), 0.25)
	var it: Dictionary = res.item
	var r := int(it.rarity)
	Sfx.play("victory" if r >= 3 else "upgrade")
	var g := _label("+%d GOLD" % res.gold, 34, GOLD)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(g)
	var card := item_card(it, 380)
	card.scale = Vector2(0.6, 0.6)
	var center := CenterContainer.new()
	center.add_child(card)
	v.add_child(center)
	card.pivot_offset = Vector2(190, 60)
	var tw2 := card.create_tween()
	tw2.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not res.kept:
		v.add_child(_label("Stash full: sold for %d gold" % Game.sell_value(it), 16, Color(1, 0.6, 0.4)))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	if res.kept:
		var eb := Button.new()
		eb.text = "EQUIP NOW"
		var item_id: String = it.id
		eb.pressed.connect(func(): Game.equip(item_id); Sfx.play("upgrade"); show_gambler())
		hb.add_child(eb)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(func(): Sfx.play("ui_click"); show_gambler())
	hb.add_child(back)
	back.grab_focus()
	Game.gold_changed.emit()


func show_end(victory: bool, kept: int) -> void:
	var r := Game.run
	var v := _modal_panel("VICTORY!" if victory else "YOU HAVE FALLEN", 700)
	var lines := [
		"Class: %s   %s" % [Game.CLASSES[r["class"]].name, Game.TORMENT_NAMES[int(r.get("torment", 0))]],
		"Reached floor %d" % r.floor,
		"Skeletons destroyed: %d" % r.kills,
		"Gold found: %d" % r.gold,
		"Gold kept: %d%s" % [kept, "" if victory else "  (%d%%, for dying)" % int(Game.death_keep_fraction() * 100)],
		"Time: %d:%02d" % [int(r.time) / 60, int(r.time) % 60],
	]
	var kings := int(r.get("boss_kills", 0))
	if victory:
		lines.insert(0, "You escaped the crypt with your loot.")
	elif kings > 0:
		lines.insert(0, "You slew the Bone King, but went deeper and never came back.")
	if kings > 1:
		lines.insert(1, "Bone Kings slain: %d" % kings)
	if kings > 0:
		var tl := int(r.get("torment", 0))
		match str(r.get("torment_result", "counted")):
			"hero_used":
				lines.append("Your %s already conquered %s: beat %s with a different hero to conquer it." % [
					Game.CLASSES[r["class"]].name, Game.TORMENT_NAMES[Game.torment_conqueror_level(r["class"])], Game.TORMENT_NAMES[tl]])
			"counted":
				if tl > 0:
					lines.append("%s conquered by your %s!" % [Game.TORMENT_NAMES[tl], Game.CLASSES[r["class"]].name])
				if tl < Game.TORMENT_MAX and Game.torment_unlocked == tl:
					lines.append("%s can now be unlocked at the skull altar in camp." % Game.TORMENT_NAMES[tl + 1])
	for l in lines:
		var lab := _label(l, 22)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lab)
	var btn := Button.new()
	btn.text = "Return to camp"
	btn.pressed.connect(func():
		Sfx.play("ui_confirm")
		close_modal()
		end_screen_closed.emit())
	v.add_child(btn)
	btn.grab_focus()
