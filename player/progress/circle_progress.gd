class_name CircleProgress
extends Control

@onready var progress_bar: TextureProgressBar = $TextureProgressBar

var is_bar_visible: bool = false
var fade_tween: Tween
var reload_duration: float
var progress_tween: Tween

func _ready() -> void:
	modulate.a = 0.0
	progress_bar.value = 0.0

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

func start_progress_tween() -> void:
	progress_tween = create_tween()
	progress_tween.tween_property(progress_bar, "value", 100.0, reload_duration)
	progress_tween.tween_callback(func():
		hide_progress()
	)

func hide_progress() -> void:
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, GameConstants.UI_FADE_DURATION)
	fade_tween.tween_callback(func(): 
		is_bar_visible = false 
	)

func set_progress(value: float) -> void:
	progress_bar.value = value
