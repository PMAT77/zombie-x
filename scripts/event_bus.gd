# 事件总线
# 用于解耦系统间的通信，所有系统间的信号都通过这里传递
# 注意：此脚本已配置为自动加载单例，通过 EventBus 直接访问
extends Node

# ==================== 玩家相关事件 ====================
signal player_jumped()
signal player_landed()
signal player_shoot()
signal player_reload_start()
signal player_reload_complete()
signal player_hit(damage: float)
signal player_heal(amount: float)

# ==================== 武器相关事件 ====================
signal weapon_fired(weapon: Node)
signal weapon_empty()
signal bullet_hit(target: Node, position: Vector3)

# ==================== UI相关事件 ====================
signal show_notification(message: String, duration: float)
signal update_health_ui(current: float, max_value: float)
signal update_ammo_ui(current: int, max_value: int)
signal update_exp_ui(current: float, max_value: float)
signal update_level_ui(level: int)

# ==================== 世界相关事件 ====================
signal time_of_day_changed(time: float)
signal weather_changed(weather_type: int)

# ==================== 游戏状态事件 ====================
signal game_saved()
signal game_loaded()

func _ready() -> void:
	print("[EventBus] 事件总线初始化完成")

# ==================== 玩家事件快捷方法 ====================
func emit_player_jumped() -> void:
	emit_signal("player_jumped")

func emit_player_landed() -> void:
	emit_signal("player_landed")

func emit_player_shoot() -> void:
	emit_signal("player_shoot")

func emit_player_reload_start() -> void:
	emit_signal("player_reload_start")

func emit_player_reload_complete() -> void:
	emit_signal("player_reload_complete")

func emit_player_hit(damage: float) -> void:
	emit_signal("player_hit", damage)

func emit_player_heal(amount: float) -> void:
	emit_signal("player_heal", amount)

# ==================== 武器事件快捷方法 ====================
func emit_weapon_fired(weapon: Node) -> void:
	emit_signal("weapon_fired", weapon)

func emit_weapon_empty() -> void:
	emit_signal("weapon_empty")

func emit_bullet_hit(target: Node, position: Vector3) -> void:
	emit_signal("bullet_hit", target, position)

# ==================== UI事件快捷方法 ====================
func emit_show_notification(message: String, duration: float = 2.0) -> void:
	emit_signal("show_notification", message, duration)

func emit_update_health_ui(current: float, max_value: float) -> void:
	emit_signal("update_health_ui", current, max_value)

func emit_update_ammo_ui(current: int, max_value: int) -> void:
	emit_signal("update_ammo_ui", current, max_value)

func emit_update_exp_ui(current: float, max_value: float) -> void:
	emit_signal("update_exp_ui", current, max_value)

func emit_update_level_ui(level: int) -> void:
	emit_signal("update_level_ui", level)

# ==================== 世界事件快捷方法 ====================
func emit_time_of_day_changed(time: float) -> void:
	emit_signal("time_of_day_changed", time)

func emit_weather_changed(weather_type: int) -> void:
	emit_signal("weather_changed", weather_type)

# ==================== 游戏状态事件快捷方法 ====================
func emit_game_saved() -> void:
	emit_signal("game_saved")

func emit_game_loaded() -> void:
	emit_signal("game_loaded")
