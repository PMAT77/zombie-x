# 玩家属性UI控制器
# 显示玩家的各种属性和状态

class_name PlayerStatsUI
extends Control

# UI节点引用
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")              # 生命值进度条
@onready var health_label: Label = get_node_or_null("HealthLabel")              # 生命值文本
@onready var level_label: Label = get_node_or_null("LevelLabel")                  # 等级文本
@onready var exp_bar: ProgressBar = get_node_or_null("ExpBar")                    # 经验值进度条
@onready var exp_label: Label = get_node_or_null("ExpLabel")                        # 经验值文本
@onready var ammo_label: Label = get_node_or_null("AmmoLabel")                      # 弹药文本
@onready var ammo_bar: ProgressBar = get_node_or_null("AmmoBar")                    # 弹药进度条
@onready var status_label: Label = get_node_or_null("StatusLabel")                # 状态文本

# 玩家引用
var player: Player

# 节点准备完成时调用
func _ready() -> void:
	# 隐藏UI，直到找到玩家
	visible = false

# 设置玩家引用
func set_player(p: Player) -> void:
	player = p
	
	if player:
		# 连接玩家属性信号
		var stats: PlayerStats = player.get_stats()
		stats.health_changed.connect(_on_health_changed)
		stats.death.connect(_on_death)
		stats.level_up.connect(_on_level_up)
		stats.exp_gained.connect(_on_exp_gained)
		stats.ammo_changed.connect(_on_ammo_changed)
		
		# 更新UI显示
		update_all_stats()
		visible = true

# 更新所有属性显示
func update_all_stats() -> void:
	if not player:
		return
	
	var stats: PlayerStats = player.get_stats()
	
	# 更新生命值
	if health_bar:
		health_bar.max_value = stats.max_health
		health_bar.value = stats.current_health
	
	if health_label:
		health_label.text = "%.0f / %.0f" % [stats.current_health, stats.max_health]
	
	# 更新等级
	if level_label:
		level_label.text = "LV.%d" % stats.level
	
	# 更新经验值
	if exp_bar:
		exp_bar.max_value = stats.exp_to_next_level
		exp_bar.value = stats.current_exp
	
	if exp_label:
		exp_label.text = "%.0f / %.0f" % [stats.current_exp, stats.exp_to_next_level]
	
	# 更新弹药
	if ammo_bar:
		ammo_bar.max_value = stats.max_ammo
		ammo_bar.value = stats.current_ammo
	
	if ammo_label:
		ammo_label.text = "%d / %d" % [stats.current_ammo, stats.max_ammo]
	
	# 更新状态
	if status_label:
		if stats.is_dead:
			status_label.text = "已死亡"
			status_label.modulate = Color.RED
		elif stats.is_invincible:
			status_label.text = "无敌状态"
			status_label.modulate = Color.YELLOW
		else:
			status_label.text = "正常"
			status_label.modulate = Color.WHITE

# 生命值变化处理
func _on_health_changed(current_health: float, max_health: float) -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	if health_label:
		health_label.text = "%.0f / %.0f" % [current_health, max_health]

# 死亡处理
func _on_death() -> void:
	if status_label:
		status_label.text = "已死亡"
		status_label.modulate = Color.RED

# 升级处理
func _on_level_up(new_level: int) -> void:
	if level_label:
		level_label.text = "LV.%d" % new_level
	
	# 播放升级特效（可以在这里添加动画）
	print("UI: 升级到 %d" % new_level)

# 获得经验处理
func _on_exp_gained(_experience: float) -> void:
	if exp_bar and exp_label:
		var stats: PlayerStats = player.get_stats()
		exp_bar.max_value = stats.exp_to_next_level
		exp_bar.value = stats.current_exp
		exp_label.text = "%.0f / %.0f" % [stats.current_exp, stats.exp_to_next_level]

# 弹药变化处理
func _on_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	if ammo_bar:
		ammo_bar.max_value = max_ammo
		ammo_bar.value = current_ammo
	
	if ammo_label:
		ammo_label.text = "%d / %d" % [current_ammo, max_ammo]

# 清除玩家引用
func clear_player() -> void:
	if player:
		var stats: PlayerStats = player.get_stats()
		stats.health_changed.disconnect(_on_health_changed)
		stats.death.disconnect(_on_death)
		stats.level_up.disconnect(_on_level_up)
		stats.exp_gained.disconnect(_on_exp_gained)
		stats.ammo_changed.disconnect(_on_ammo_changed)
	
	player = null
	visible = false
