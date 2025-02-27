@tool
extends EditorPlugin

var editor_instance

func _enter_tree():
	# 仅在未实例化时加载 TimelineEditor 场景
	if not editor_instance:
		editor_instance = preload("res://addons/AudioTimeline/Editor/TimelineEditor.tscn").instantiate()
		get_editor_interface().get_editor_main_screen().add_child(editor_instance)
	# 默认隐藏
	_make_visible(false)

func _exit_tree():
	if editor_instance:
		editor_instance.queue_free()
		editor_instance = null

func _has_main_screen():
	return true

func _make_visible(visible):
	if editor_instance:
		editor_instance.visible = visible
		if visible:
			# 初始化 UI 和信号
			initialize_ui()
		else:
			# 清理临时 UI 元素（如 FileDialog）
			cleanup_dialogs()

func _get_plugin_name():
	return "TimelineEditor"

func _get_plugin_icon():
	return preload("res://addons/AudioTimeline/icon.png")

# 初始化 UI 和信号
func initialize_ui():
	# 确保实例存在且未连接信号时重新绑定
	if editor_instance and not editor_instance.new_button.is_connected("pressed", editor_instance._on_new_button_pressed):
		editor_instance.new_button.connect("pressed", editor_instance._on_new_button_pressed)
		editor_instance.open_button.connect("pressed", editor_instance._on_open_button_pressed)
		editor_instance.audio_button.connect("pressed", editor_instance._on_audio_button_pressed)
		editor_instance.await_button.connect("pressed", editor_instance._on_await_button_pressed)
		editor_instance.stop_button.connect("pressed", editor_instance._on_stop_button_pressed)
		editor_instance.choice_button.connect("pressed", editor_instance._on_choice_button_pressed)
	# 更新事件列表（防止切换时空白）
	editor_instance.update_event_list()
	editor_instance.update_properties_panel()
	print("TimelineEditor UI initialized")

# 清理临时对话框
func cleanup_dialogs():
	for child in editor_instance.get_children():
		if child is FileDialog:
			child.queue_free()
