extends Node
## Sound effect + music manager. Sounds are grouped into named banks; a random variant
## from the bank is played with slight pitch variation so repeated hits don't sound robotic.

const BANKS := {
	"swing": ["rpg-audio/drawKnife1", "rpg-audio/drawKnife2", "rpg-audio/drawKnife3"],
	"swing_heavy": ["rpg-audio/chop", "rpg-audio/knifeSlice", "rpg-audio/knifeSlice2"],
	"hit": ["impact-sounds/impactPunch_medium_000", "impactPunch_medium_001", "impactPunch_medium_002", "impactPunch_medium_003"],
	"hit_bone": ["impact-sounds/impactWood_light_000", "impactWood_light_001", "impactWood_light_002", "impactPlank_medium_000", "impactPlank_medium_001"],
	"block": ["impact-sounds/impactMetal_medium_000", "impactMetal_medium_001", "impactMetal_medium_002"],
	"hurt": ["impact-sounds/impactPunch_heavy_000", "impactPunch_heavy_001", "impactPunch_heavy_002"],
	"break": ["impact-sounds/impactWood_heavy_000", "impactWood_heavy_001", "impactWood_heavy_002"],
	"bow": ["rpg-audio/cloth1", "rpg-audio/cloth2"],
	"magic": ["interface-sounds/glass_001", "glass_002", "glass_003"],
	"explosion": ["impact-sounds/impactBell_heavy_000", "impactBell_heavy_001"],
	"coin": ["rpg-audio/handleCoins", "rpg-audio/handleCoins2"],
	"potion": ["impact-sounds/impactGlass_light_000", "impactGlass_light_001"],
	"drink": ["rpg-audio/bookFlip1", "rpg-audio/bookFlip2"],
	"chest": ["rpg-audio/creak1", "rpg-audio/creak2", "rpg-audio/creak3"],
	"door": ["rpg-audio/doorOpen_1", "rpg-audio/doorOpen_2"],
	"gate": ["rpg-audio/metalLatch", "rpg-audio/metalClick"],
	"step": ["impact-sounds/footstep_concrete_000", "footstep_concrete_001", "footstep_concrete_002", "footstep_concrete_003", "footstep_concrete_004"],
	"dodge": ["rpg-audio/cloth3", "rpg-audio/cloth4"],
	"spawn": ["impact-sounds/impactMining_000", "impactMining_001", "impactMining_002"],
	"death": ["impact-sounds/impactPlate_heavy_000", "impactPlate_heavy_001"],
	"ui_click": ["interface-sounds/click_001", "click_002", "click_003"],
	"ui_select": ["interface-sounds/select_001", "select_002", "select_003"],
	"ui_confirm": ["interface-sounds/confirmation_001", "confirmation_002"],
	"ui_error": ["interface-sounds/error_001", "error_002"],
	"ui_open": ["interface-sounds/open_001", "open_002"],
	"upgrade": ["interface-sounds/maximize_001", "maximize_002", "maximize_003"],
	"room_clear": ["music-jingles/jingles_PIZZI00"],
	"boon": ["music-jingles/jingles_PIZZI04"],
	"floor": ["music-jingles/jingles_NES03"],
	"victory": ["music-jingles/jingles_NES05"],
	"defeat": ["music-jingles/jingles_NES08"],
	"boss": ["music-jingles/jingles_HIT03"],
}
const MUSIC := {
	"camp": "res://audio/music/dungeon_ambience.ogg",
	"dungeon": "res://audio/music/dungeon_theme.ogg",
	"boss": "res://audio/music/boss_battle.ogg",
}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music := ""
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bank in BANKS:
		var dir := ""
		var list: Array = []
		for entry in BANKS[bank]:
			var e: String = entry
			if e.contains("/"):
				dir = e.get_slice("/", 0)
				e = e.get_slice("/", 1)
			var path := "res://audio/sfx/%s/%s.ogg" % [dir, e]
			if ResourceLoader.exists(path):
				list.append(load(path))
		_streams[bank] = list
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		add_child(m)


func play(bank: String, volume_db := 0.0, pitch_var := 0.08) -> void:
	var list: Array = _streams.get(bank, [])
	if list.is_empty():
		return
	# throttle identical sounds within a single frame-ish window
	var now := Time.get_ticks_msec()
	if _last_play.get(bank, 0) > now - 35:
		return
	_last_play[bank] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func music(id: String, fade := 1.2) -> void:
	if id == _current_music:
		return
	_current_music = id
	var from := _music_a if _music_a.playing else _music_b
	var to := _music_b if from == _music_a else _music_a
	if id != "" and MUSIC.has(id):
		var s = load(MUSIC[id])
		if s is AudioStreamOggVorbis:
			s.loop = true
		to.stream = s
		to.volume_db = -40.0
		to.play()
		var tw := create_tween()
		tw.tween_property(to, "volume_db", -6.0 if id != "camp" else -2.0, fade)
	if from.playing:
		var tw2 := create_tween()
		tw2.tween_property(from, "volume_db", -40.0, fade)
		tw2.tween_callback(from.stop)
