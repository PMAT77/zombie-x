# 圆形进度条组件
# 用于显示换弹、技能冷却等进度
class_name CircleProgress
extends Control

@onready var progress_bar: TextureProgressBar = $TextureProgressBar

var is_bar_visible: bool = false  # 进度条是否可见
var fade_tween: Tween  # 淡入淡出动画
var reload_duration: float  # 进度持续时间
var progress_tween: Tween  # 进度动画

func _ready() -> void:
	modulate.a = 0.0
	progress_bar.value = 0.0

# 显示进度条并开始动画
func show_progress(duration: float) -> void:
	reload_duration = duration 
	set_progress(0.0)
	
	if fade_tween:
		fade_tween.kill()
	if progress_tween:
		progress_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, GameConstants.UI_FADE_DURATION)
	fade_tween.tween_callback(func():  
		is_bar_visible = true 
		start_progress_tween()
	)

# 开始进度条动画
func start_progress_tween() -> void:
	progress_tween = create_tween()
	progress_tween.tween_property(progress_bar, "value", 100.0, reload_duration)
	progress_tween.tween_callback(func():
		hide_progress()
	)

# 隐藏进度条
func hide_progress() -> void:
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, GameConstants.UI_FADE_DURATION)
	fade_tween.tween_callback(func(): 
		is_bar_visible = false 
	)

# 设置进度值（0-100）
func set_progress(value: float) -> void:
	progress_bar.value = value
