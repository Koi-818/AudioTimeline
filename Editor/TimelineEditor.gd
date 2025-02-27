extends Control

var events = []
var current_file_path = ""
var selected_event_index = -1

@onready var new_button = $FileMenu/NewButton
@onready var open_button = $FileMenu/OpenButton
@onready var file_dialog = $FileDialog
@onready var event_list = $EventScroll/EventListPanel/EventList
@onready var audio_button = $EventScroll/EventListPanel/EventButtons/AudioButton
@onready var await_button = $EventScroll/EventListPanel/EventButtons/AwaitButton
@onready var stop_button = $EventScroll/EventListPanel/EventButtons/StopButton
@onready var choice_button = $EventScroll/EventListPanel/EventButtons/ChoiceButton
@onready var properties_container = $PropertiesPanel/PropertiesContainer
@onready var status_label = $StatusLabel

var preview_player = AudioStreamPlayer.new()

func _ready():
	new_button.connect("pressed", _on_new_button_pressed)
	open_button.connect("pressed", _on_open_button_pressed)
	audio_button.connect("pressed", _on_audio_button_pressed)
	await_button.connect("pressed", _on_await_button_pressed)
	stop_button.connect("pressed", _on_stop_button_pressed)
	choice_button.connect("pressed", _on_choice_button_pressed)
	add_child(preview_player)
	apply_button_style(new_button)
	apply_button_style(open_button)
	apply_button_style(audio_button)
	apply_button_style(await_button)
	apply_button_style(stop_button)
	apply_button_style(choice_button)

func apply_button_style(button):
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.add_theme_constant_override("hseparation", 5)
	button.add_theme_font_size_override("font_size", 14)

# 显示状态提示
func show_status(message, color = Color.WHITE, duration = 2.0):
	status_label.text = message
	status_label.modulate = color
	await get_tree().create_timer(duration).timeout
	status_label.text = ""
	status_label.modulate = Color.WHITE

# 新建时间线
func _on_new_button_pressed():
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.current_dir = "res://addons/AudioTimeline/Timelines/"
	file_dialog.filters = ["*.json"]
	file_dialog.connect("file_selected", _on_new_file_selected)
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(600, 400))

func _on_new_file_selected(path):
	var dir = DirAccess.open("res://addons/AudioTimeline/Timelines/")
	if not dir:
		DirAccess.make_dir_absolute("res://addons/AudioTimeline/Timelines/")
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify([]))
		file.close()
		current_file_path = path
		events = []
		print("新建时间线: ", path)
		load_timeline(path)
		show_status("TimeLine created: " + path.get_file(), Color.GREEN)
	else:
		print("创建文件失败: ", path)
		show_status("Failed to create TimeLine: " + path.get_file(), Color.RED)

# 打开时间线
func _on_open_button_pressed():
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.current_dir = "res://addons/AudioTimeline/Timelines/"
	file_dialog.filters = ["*.json"]
	file_dialog.connect("file_selected", _on_open_file_selected)
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(600, 400))

func _on_open_file_selected(path):
	load_timeline(path)

func load_timeline(path):
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var result = JSON.parse_string(json_text)
		if result is Array:
			events = result
			current_file_path = path
			print("加载时间线: ", path, " 事件数: ", events.size())
			update_event_list()
			show_status("TimeLine loaded: " + path.get_file(), Color.GREEN)
		else:
			print("解析 JSON 失败: ", path)
			show_status("Failed to parse JSON: " + path.get_file(), Color.RED)
	else:
		print("打开文件失败: ", path)
		show_status("Failed to open TimeLine: " + path.get_file(), Color.RED)

func save_timeline():
	if current_file_path == "":
		print("未指定时间线文件路径，无法保存")
		show_status("No TimeLine file path specified", Color.YELLOW)
		return
	var file = FileAccess.open(current_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(events))
		file.close()
		print("保存时间线: ", current_file_path)
		show_status("TimeLine saved: " + current_file_path.get_file(), Color.GREEN)
	else:
		print("保存文件失败: ", current_file_path)
		show_status("Failed to save TimeLine: " + current_file_path.get_file(), Color.RED)

func update_event_list():
	for child in event_list.get_children():
		child.queue_free()
	
	for i in range(events.size()):
		var event = events[i]
		var event_node = HBoxContainer.new()
		event_node.size_flags_horizontal = SIZE_EXPAND_FILL
		event_node.add_theme_constant_override("hseparation", 5)
		
		var label = Label.new()
		var event_type = event["type"]
		var display_text = event_type
		
		match event_type:
			"audio":
				var tag = event.get("tag", "")
				if tag != "":
					display_text += " (tag: " + tag + ")"
			"wait":
				display_text += " (" + str(event.get("duration", 1.0)) + "s)"
			"stop":
				if event.get("music", false):
					display_text += " (Music)"
				if event.get("sfx", false):
					display_text += " (SFX)"
			"choice":
				display_text += " (2 options)"
		
		label.text = display_text
		label.clip_text = true
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		event_node.add_child(label)
		
		var delete_button = Button.new()
		delete_button.text = "Delete"
		apply_button_style(delete_button)
		delete_button.connect("pressed", _on_delete_button_pressed.bind(i))
		event_node.add_child(delete_button)
		
		event_list.add_child(event_node)
		event_node.connect("gui_input", _on_event_node_gui_input.bind(i))

func _on_audio_button_pressed():
	add_event("audio")

func _on_await_button_pressed():
	add_event("wait")

func _on_stop_button_pressed():
	add_event("stop")

func _on_choice_button_pressed():
	add_event("choice")

func add_event(event_type):
	var new_event = {}
	match event_type:
		"audio":
			new_event = {
				"type": "audio",
				"tag": "",
				"voice": "",
				"music": "",
				"sfx": ""
			}
		"wait":
			new_event = {
				"type": "wait",
				"duration": 1.0
			}
		"stop":
			new_event = {
				"type": "stop",
				"music": false,
				"sfx": false
			}
		"choice":
			new_event = {
				"type": "choice",
				"options": [
					{"text": "Option 1", "label": ""},
					{"text": "Option 2", "label": ""}
				]
			}
	events.append(new_event)
	update_event_list()
	save_timeline()
	print("添加事件: ", event_type)
	show_status("Added " + event_type + " event", Color.GREEN)

func _on_event_node_gui_input(event, index):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected_event_index = index
		update_properties_panel()
		print("选中事件: ", index)

func _on_delete_button_pressed(index):
	if index >= 0 and index < events.size():
		var event_type = events[index]["type"]
		events.remove_at(index)
		if selected_event_index == index:
			selected_event_index = -1
		elif selected_event_index > index:
			selected_event_index -= 1
		update_event_list()
		update_properties_panel()
		save_timeline()
		print("删除事件: ", index)
		show_status("Deleted " + event_type + " event", Color.GREEN)

func update_properties_panel():
	for child in properties_container.get_children():
		child.queue_free()
	
	if selected_event_index < 0 or selected_event_index >= events.size():
		return
	
	var event = events[selected_event_index]
	match event["type"]:
		"audio":
			add_property_field("Tag", "tag", LineEdit.new())
			add_audio_path_field("Voice", "voice")
			add_audio_path_field("Music", "music")
			add_audio_path_field("SFX", "sfx")
		"wait":
			var spin_box = SpinBox.new()
			spin_box.value = event["duration"]
			spin_box.step = 0.1
			spin_box.min_value = 0.0
			spin_box.connect("value_changed", _on_duration_changed)
			add_property_field("Duration (s)", "duration", spin_box)
		"stop":
			var music_check = CheckBox.new()
			music_check.button_pressed = event["music"]
			music_check.connect("toggled", _on_stop_music_toggled)
			add_property_field("Stop Music", "music", music_check)
			
			var sfx_check = CheckBox.new()
			sfx_check.button_pressed = event["sfx"]
			sfx_check.connect("toggled", _on_stop_sfx_toggled)
			add_property_field("Stop SFX", "sfx", sfx_check)
		"choice":
			for i in range(2):
				var option = event["options"][i]
				var text_edit = LineEdit.new()
				text_edit.text = option["text"]
				text_edit.size_flags_horizontal = SIZE_EXPAND_FILL
				text_edit.connect("text_changed", _on_option_text_changed.bind(i))
				add_property_field("Option " + str(i+1) + " Text", "", text_edit)
				
				var label_edit = LineEdit.new()
				label_edit.text = option["label"]
				label_edit.size_flags_horizontal = SIZE_EXPAND_FILL
				label_edit.connect("text_changed", _on_option_label_changed.bind(i))
				add_property_field("Option " + str(i+1) + " Label", "", label_edit)

func add_property_field(label_text, property_key, control):
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("hseparation", 5)
	
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_SHRINK_BEGIN
	hbox.add_child(label)
	
	control.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(control)
	properties_container.add_child(hbox)
	
	if property_key != "" and control is LineEdit:
		control.text = events[selected_event_index][property_key]
		control.connect("text_changed", _on_property_text_changed.bind(property_key))

func add_audio_path_field(label_text, property_key):
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("hseparation", 5)
	
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_SHRINK_BEGIN
	hbox.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.text = events[selected_event_index][property_key]
	line_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	update_path_validation(line_edit, property_key)  # 初始验证
	line_edit.connect("text_changed", _on_audio_path_changed.bind(property_key, line_edit))
	hbox.add_child(line_edit)
	
	var browse_button = Button.new()
	browse_button.text = "Browse"
	apply_button_style(browse_button)
	browse_button.connect("pressed", _on_browse_audio_pressed.bind(property_key, line_edit))
	hbox.add_child(browse_button)
	
	var play_button = Button.new()
	play_button.text = "Play"
	apply_button_style(play_button)
	play_button.connect("pressed", _on_play_audio_pressed.bind(property_key))
	hbox.add_child(play_button)
	
	properties_container.add_child(hbox)

# 更新路径有效性显示
func update_path_validation(line_edit, property_key):
	var path = events[selected_event_index][property_key]
	if path != "" and ResourceLoader.exists(path):
		line_edit.modulate = Color.GREEN
	else:
		line_edit.modulate = Color.RED

func _on_property_text_changed(new_text, property_key):
	events[selected_event_index][property_key] = new_text
	update_event_list()
	save_timeline()

func _on_audio_path_changed(new_text, property_key, line_edit):
	events[selected_event_index][property_key] = new_text
	update_path_validation(line_edit, property_key)
	save_timeline()
	if new_text != "" and not ResourceLoader.exists(new_text):
		show_status("Invalid audio path: " + new_text.get_file(), Color.RED)

func _on_browse_audio_pressed(property_key, line_edit):
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.current_dir = "res://audio/"
	file_dialog.filters = ["*.wav", "*.mp3"]
	file_dialog.connect("file_selected", _on_audio_file_selected.bind(property_key, line_edit))
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(600, 400))

func _on_audio_file_selected(path, property_key, line_edit):
	events[selected_event_index][property_key] = path
	line_edit.text = path
	update_path_validation(line_edit, property_key)
	save_timeline()
	show_status("Audio path set: " + path.get_file(), Color.GREEN)

func _on_play_audio_pressed(property_key):
	var path = events[selected_event_index][property_key]
	if path != "" and ResourceLoader.exists(path):
		preview_player.stream = load(path)
		preview_player.play()
		print("预览音频: ", path)
		show_status("Playing: " + path.get_file(), Color.GREEN)
	else:
		print("无效音频路径: ", path)
		show_status("Cannot play, invalid path: " + path.get_file(), Color.RED)

func _on_duration_changed(value):
	events[selected_event_index]["duration"] = value
	update_event_list()
	save_timeline()

func _on_stop_music_toggled(button_pressed):
	events[selected_event_index]["music"] = button_pressed
	update_event_list()
	save_timeline()

func _on_stop_sfx_toggled(button_pressed):
	events[selected_event_index]["sfx"] = button_pressed
	update_event_list()
	save_timeline()

func _on_option_text_changed(new_text, option_index):
	events[selected_event_index]["options"][option_index]["text"] = new_text
	update_event_list()
	save_timeline()

func _on_option_label_changed(new_text, option_index):
	events[selected_event_index]["options"][option_index]["label"] = new_text
	update_event_list()
	save_timeline()
