# 玩家属性数据类
# 管理玩家的各种属性和状态

class_name PlayerStats
extends RefCounted

# 生命属性
var max_health: float = GameConstants.DEFAULT_MAX_HEALTH        # 最大生命值
var current_health: float = GameConstants.DEFAULT_MAX_HEALTH      # 当前生命值
var health_regen: float = GameConstants.DEFAULT_HEALTH_REGEN         # 生命值恢复速度（每秒）

# 攻击属性
var attack_power: float = GameConstants.DEFAULT_ATTACK_POWER          # 基础攻击力
var attack_speed: float = GameConstants.DEFAULT_ATTACK_SPEED           # 攻击速度（攻击间隔的倒数）
var critical_chance: float = GameConstants.DEFAULT_CRITICAL_CHANCE        # 暴击概率（0-1）
var critical_damage: float = GameConstants.DEFAULT_CRITICAL_DAMAGE          # 暴击伤害倍数

# 防御属性
var defense: float = GameConstants.DEFAULT_DEFENSE                # 基础防御力
var damage_reduction: float = GameConstants.DEFAULT_DAMAGE_REDUCTION        # 伤害减免（0-1）

# 移动属性
var movement_speed: float = GameConstants.DEFAULT_MOVEMENT_SPEED          # 移动速度倍数
var jump_height: float = GameConstants.DEFAULT_JUMP_HEIGHT             # 跳跃高度倍数

# 经验和等级
var level: int = GameConstants.DEFAULT_STARTING_LEVEL                      # 当前等级
var current_exp: float = GameConstants.DEFAULT_STARTING_EXP             # 当前经验值
var exp_to_next_level: float = GameConstants.DEFAULT_EXP_BASE     # 升到下一级所需经验

# 资源属性
var max_ammo: int = GameConstants.DEFAULT_MAX_AMMO                  # 最大弹药量
var current_ammo: int = GameConstants.DEFAULT_MAX_AMMO                # 当前弹药量
var ammo_regen_time: float = GameConstants.DEFAULT_AMMO_REGEN_TIME         # 弹药恢复时间（秒）
var reload_time: float = GameConstants.DEFAULT_RELOAD_TIME           # 换弹时间（秒）

# 状态标志
var is_dead: bool = false                    # 是否死亡
var is_invincible: bool = false               # 是否无敌
var invincible_time: float = 0.0              # 无敌时间

# 信号
signal health_changed(current_health: float, max_health: float)    # 生命值变化信号
signal death()                                                       # 死亡信号
signal level_up(new_level: int)                                      # 升级信号
signal exp_gained(exp: float)                                        # 获得经验信号
signal ammo_changed(current_ammo: int, max_ammo: int)              # 弹药变化信号

# 构造函数
func _init() -> void:
	exp_to_next_level = calculate_exp_to_next_level()

# 更新函数（需要外部调用）
func update(delta: float) -> void:
	# 生命值恢复
	if health_regen > 0 and current_health < max_health and not is_dead:
		current_health = minf(current_health + health_regen * delta, max_health)
		emit_signal("health_changed", current_health, max_health)
	
	# 无敌时间更新
	if invincible_time > 0:
		invincible_time -= delta
		if invincible_time <= 0:
			is_invincible = false

# 计算到下一级所需经验
func calculate_exp_to_next_level() -> float:
	return level * GameConstants.DEFAULT_EXP_BASE

# 获得经验
func gain_exp(amount: float) -> void:
	if is_dead:
		return
	
	current_exp += amount
	emit_signal("exp_gained", amount)
	
	# 检查是否升级
	while current_exp >= exp_to_next_level:
		current_exp -= exp_to_next_level
		perform_level_up()

# 升级
func perform_level_up() -> void:
	level += 1
	exp_to_next_level = calculate_exp_to_next_level()
	emit_signal("level_up", level)
	
	# 升级时恢复生命值
	heal(max_health * 0.2)

# 受到伤害
func take_damage(amount: float) -> void:
	if is_dead or is_invincible:
		return
	
	# 计算实际伤害（考虑防御和伤害减免）
	var actual_damage: float = calculate_damage_received(amount)
	current_health = maxf(current_health - actual_damage, 0.0)
	
	emit_signal("health_changed", current_health, max_health)
	
	# 检查是否死亡
	if current_health <= 0:
		die()

# 计算受到的伤害
func calculate_damage_received(base_damage: float) -> float:
	var reduced_damage: float = base_damage * (1.0 - damage_reduction)
	var final_damage: float = maxf(reduced_damage - defense, 0.0)
	return final_damage

# 治疗
func heal(amount: float) -> void:
	if is_dead:
		return
	
	current_health = minf(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)

# 死亡
func die() -> void:
	if is_dead:
		return
	
	is_dead = true
	current_health = 0.0
	emit_signal("health_changed", current_health, max_health)
	emit_signal("death")

# 复活
func revive() -> void:
	is_dead = false
	current_health = max_health * 0.5
	emit_signal("health_changed", current_health, max_health)

# 设置无敌状态
func set_invincible(duration: float) -> void:
	is_invincible = true
	invincible_time = duration

# 消耗弹药
func consume_ammo(amount: int = 1) -> bool:
	if current_ammo >= amount:
		current_ammo -= amount
		emit_signal("ammo_changed", current_ammo, max_ammo)
		return true
	return false

# 补充弹药
func refill_ammo() -> void:
	current_ammo = max_ammo
	emit_signal("ammo_changed", current_ammo, max_ammo)

# 获取生命值百分比
func get_health_percentage() -> float:
	if max_health <= 0:
		return 0.0
	return current_health / max_health

# 获取经验值百分比
func get_exp_percentage() -> float:
	if exp_to_next_level <= 0:
		return 0.0
	return current_exp / exp_to_next_level

# 获取弹药百分比
func get_ammo_percentage() -> float:
	if max_ammo <= 0:
		return 0.0
	return float(current_ammo) / float(max_ammo)

# 重置属性（用于游戏重置）
func reset() -> void:
	current_health = max_health
	current_exp = 0.0
	level = 1
	exp_to_next_level = calculate_exp_to_next_level()
	current_ammo = max_ammo
	is_dead = false
	is_invincible = false
	invincible_time = 0.0
	
	emit_signal("health_changed", current_health, max_health)
	emit_signal("ammo_changed", current_ammo, max_ammo)
