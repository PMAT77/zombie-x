# 主菜单UI控制器
# 处理主菜单的交互和导航
class_name MainMenu
extends Control

# UI节点引用
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var title_label: Label = $TitleLabel

func _ready() -> void:
	# 连接按钮信号
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# 设置初始鼠标模式
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# 开始游戏按钮点击事件
func _on_start_pressed() -> void:
	print("[MainMenu] 开始游戏")
	# 切换到游戏场景
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

# 设置按钮点击事件
func _on_settings_pressed() -> void:
	print("[MainMenu] 打开设置")
	# 这里可以添加设置菜单逻辑

# 退出游戏按钮点击事件
func _on_quit_pressed() -> void:
	print("[MainMenu] 退出游戏")
	get_tree().quit()
