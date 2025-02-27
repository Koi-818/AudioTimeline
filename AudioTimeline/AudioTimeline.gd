extends Node

@export var timeline_path: String = "res://addons/AudioTimeline/Timelines/default.json"
var timeline_data = []
var current_index = 0
var is_paused = false
var voice_pos = 0.0
var music_pos = 0.0
var sfx_pos = 0.0
var choices = []
var awaiting_choice = false
var is_playing = false
var is_vibrating = false
var current_label = ""

@onready var voice_audio = $VoiceAudio
@onready var music_audio = $MusicAudio
@onready var sfx_audio = $SFXAudio
var voices = DisplayServer.tts_get_voices_for_language("zh")
var voice_id = voices[0]

const FADE_DURATION = 1.0

func _ready():
	var file = FileAccess.open(timeline_path, FileAccess.READ)
	if file:
		timeline_data = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		print("无法加载时间线文件: ", timeline_path)

func _process(_delta):
	if Input.is_action_just_pressed("pause_save"):
		if not is_paused:  # 仅在未暂停时执行
			toggle_pause()
			save_game()  # 直接存档
	if Input.is_action_just_pressed("resume_game") and is_paused:
		toggle_pause()
	
	if awaiting_choice and choices.size() > 0 and not is_paused:
		if Input.is_action_just_pressed("choice_left") and choices.size() >= 1:
			print("选择了选项 1: ", choices[0]["text"])
			stop_vibration()
			set_label(choices[0]["label"])
			choices = []
			awaiting_choice = false
			current_index += 1
			if not is_paused:
				play_timeline()
		elif Input.is_action_just_pressed("choice_right") and choices.size() >= 2:
			print("选择了选项 2: ", choices[1]["text"])
			stop_vibration()
			set_label(choices[1]["label"])
			choices = []
			awaiting_choice = false
			current_index += 1
			if not is_paused:
				play_timeline()

func play_timeline():
	if is_playing:
		print("时间线已在播放，忽略重复调用")
		return
	is_playing = true
	while current_index < timeline_data.size() and not is_paused and not awaiting_choice:
		var event = timeline_data[current_index]
		var event_tag = event.get("tag", "")
		
		if event_tag == "" or event_tag == current_label:
			print("执行事件: ", event["type"], " at index: ", current_index, " with tag: ", event_tag)
			
			if current_index > 0 and event["type"] == "choice":
				var prev_event = timeline_data[current_index - 1]
				if prev_event["type"] == "audio" and prev_event["voice"] and voice_audio.stream:
					print("等待前一个 Voice 完成...")
					await voice_audio.finished
			
			match event["type"]:
				"audio":
					play_audio_event(event)
					if event["voice"] and voice_audio.stream:
						await voice_audio.finished
				"wait":
					await get_tree().create_timer(event["duration"]).timeout
				"stop":
					if event.get("music", false):
						await fade_out(music_audio)
						music_audio.stream = null
						music_pos = 0.0
						print("停止 Music")
					if event.get("sfx", false):
						await fade_out(sfx_audio)
						sfx_audio.stream = null
						sfx_pos = 0.0
						print("停止 SFX")
				"choice":
					choices = event["options"]
					awaiting_choice = true
					show_choices()
					is_playing = false
					return
		else:
			print("跳过事件: ", event["type"], " at index: ", current_index, " with tag: ", event_tag)
		current_index += 1
	is_playing = false

func set_label(label):
	current_label = label
	print("设置当前标签: ", current_label)

func play_audio_event(event):
	if event["voice"]:
		voice_audio.stream = load(event["voice"])
		voice_audio.play()
	if event["music"]:
		music_audio.stream = load(event["music"])
		fade_in(music_audio)
	if event["sfx"]:
		sfx_audio.stream = load(event["sfx"])
		fade_in(sfx_audio)

func fade_in(audio_player, start_pos = 0.0):
	audio_player.volume_db = -80
	audio_player.play(start_pos)
	var tween = create_tween()
	tween.tween_property(audio_player, "volume_db", 0, FADE_DURATION)

func fade_out(audio_player):
	if audio_player.playing:
		var tween = create_tween()
		tween.tween_property(audio_player, "volume_db", -80, FADE_DURATION)
		await tween.finished
		audio_player.stop()

func show_choices():
	sfx_audio.stream = load("res://audio/ui-button-press.wav")
	sfx_audio.play()
	var prompt = "请选择。选项 1: " + choices[0]["text"] + "，按 LT 键。"
	if choices.size() >= 2:
		prompt += " 选项 2: " + choices[1]["text"] + "，按 RT 键。"
	DisplayServer.tts_speak(prompt, voice_id)
	print("等待玩家选择: ", prompt)
	start_vibration()

func start_vibration():
	if is_vibrating:
		return
	is_vibrating = true
	while is_vibrating and awaiting_choice and not is_paused:
		Input.start_joy_vibration(0, 0.3, 0.5, 0.5)
		await get_tree().create_timer(1.0).timeout
	Input.stop_joy_vibration(0)

func stop_vibration():
	is_vibrating = false
	Input.stop_joy_vibration(0)

func toggle_pause():
	if not is_paused:
		voice_pos = voice_audio.get_playback_position()
		music_pos = music_audio.get_playback_position()
		sfx_pos = sfx_audio.get_playback_position()
		voice_audio.stop()
		if music_audio.playing:
			await fade_out(music_audio)
		if sfx_audio.playing:
			await fade_out(sfx_audio)
		stop_vibration()
		is_paused = true
		DisplayServer.tts_speak("游戏已暂停。", voice_id)
	else:
		if voice_audio.stream:
			voice_audio.play(voice_pos)
		if music_audio.stream:
			fade_in(music_audio, music_pos)
		if sfx_audio.stream:
			fade_in(sfx_audio, sfx_pos)
		is_paused = false
		if awaiting_choice:
			start_vibration()
		DisplayServer.tts_speak("游戏已继续。", voice_id)

func save_game():
	var save_data = {
		"current_index": current_index,
		"voice_pos": voice_pos,
		"music_pos": music_pos,
		"sfx_pos": sfx_pos,
		"current_label": current_label
	}
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("user://saves"):
		dir.make_dir("saves")
	var file = FileAccess.open("user://saves/my_slot.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()
	DisplayServer.tts_speak("游戏已保存。", voice_id)

func load_game():
	var file = FileAccess.open("user://saves/my_slot.json", FileAccess.READ)
	if file:
		var save_data = JSON.parse_string(file.get_as_text())
		file.close()
		current_index = save_data["current_index"]
		voice_pos = save_data["voice_pos"]
		music_pos = save_data["music_pos"]
		sfx_pos = save_data["sfx_pos"]
		current_label = save_data["current_label"]
		play_timeline()
