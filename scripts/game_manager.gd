# 游戏管理器
# 统一管理游戏状态、玩家实例、世界等
# 注意：此脚本已配置为自动加载单例，通过 GameManager 直接访问
extends Node

signal game_state_changed(new_state: int, old_state: int)
signal player_spawned(player: Node3D)
signal player_died(player: Node3D)
signal game_paused()
signal game_resumed()

# 当前游戏状态
var current_state: int = GameConstants.GameState.PLAYING
var previous_state: int = GameConstants.GameState.PLAYING

# 玩家引用
var player: Player = null

func _ready() -> void:
	print("[GameManager] 初始化完成")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_pause()

func set_game_state(new_state: int) -> void:
	if new_state == current_state:
		return
	
	previous_state = current_state
	current_state = new_state
	
	match current_state:
		GameConstants.GameState.MENU:
			_on_enter_menu()
		GameConstants.GameState.PLAYING:
			_on_enter_playing()
		GameConstants.GameState.PAUSED:
			_on_enter_paused()
		GameConstants.GameState.GAME_OVER:
			_on_enter_game_over()
	
	emit_signal("game_state_changed", current_state, previous_state)
	print("[GameManager] 游戏状态变更: %d -> %d" % [previous_state, current_state])

func toggle_pause() -> void:
	if current_state == GameConstants.GameState.PLAYING:
		set_game_state(GameConstants.GameState.PAUSED)
	elif current_state == GameConstants.GameState.PAUSED:
		set_game_state(GameConstants.GameState.PLAYING)

func _on_enter_menu() -> void:
	get_tree().paused = false

func _on_enter_playing() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("game_resumed")

func _on_enter_paused() -> void:
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	emit_signal("game_paused")

func _on_enter_game_over() -> void:
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func register_player(new_player: Player) -> void:
	player = new_player
	print("[GameManager] 玩家已注册")
	emit_signal("player_spawned", player)
	
	if player.player_stats:
		player.player_stats.death.connect(_on_player_death)

func _on_player_death() -> void:
	print("[GameManager] 玩家死亡")
	emit_signal("player_died", player)
	set_game_state(GameConstants.GameState.GAME_OVER)

func get_player() -> Player:
	return player

func is_paused() -> bool:
	return current_state == GameConstants.GameState.PAUSED

func is_playing() -> bool:
	return current_state == GameConstants.GameState.PLAYING

func restart_game() -> void:
	if player:
		player.revive()
	set_game_state(GameConstants.GameState.PLAYING)

func quit_game() -> void:
	get_tree().quit()
