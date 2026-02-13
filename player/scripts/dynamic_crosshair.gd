class_name DynamicCrosshair
extends CanvasLayer

# 动态准星系统
# 基于CanvasLayer+Line2D实现的十字准星
# 支持瞄准收缩、移动晃动、射击扩散等动态效果

# 准星状态枚举
enum CrosshairState {
	IDLE,               # 空闲状态
	AIMING,             # 瞄准状态
	MOVING,             # 移动状态
	SHOOTING,           # 射击状态
	AIMING_WHILE_MOVING # 移动中瞄准状态
}

# ==================== 基础配置 ====================
@export_group("Base Settings")
@export var line_length: float = 12.0      # 单条线长度
@export var line_thickness: float = 2.0    # 线条粗细
@export var line_gap: float = 4.0          # 中心间隙大小
@export var line_color: Color = Color.WHITE # 线条颜色

# ==================== 扩散配置 ====================
@export_group("Spread Settings")
@export var base_spread: float = 8.0       # 基础扩散距离
@export var max_spread: float = 60.0       # 最大扩散距离
@export var aim_spread_multiplier: float = 0.3  # 瞄准时扩散倍率
@export var move_spread_multiplier: float = 1.5 # 移动时扩散倍率
@export var shoot_spread_add: float = 20.0      # 射击时扩散增量

# ==================== 恢复配置 ====================
@export_group("Recovery Settings")
@export var base_recovery_speed: float = 8.0    # 基础恢复速度
@export var aim_recovery_multiplier: float = 1.5 # 瞄准时恢复倍率
@export var move_recovery_multiplier: float = 0.5 # 移动时恢复倍率

# ==================== 晃动配置 ====================
@export_group("Shake Settings")
@export var move_shake_amplitude: float = 3.0   # 移动晃动幅度
@export var move_shake_speed: float = 2.0       # 移动晃动速度
@export var shoot_shake_amplitude: float = 8.0  # 射击晃动幅度
@export var shoot_shake_recovery_speed: float = 5.0 # 射击晃动恢复速度

# ==================== 武器参数 ====================
@export_group("Weapon Parameters")
@export var recoil_horizontal: float = 1.0  # 水平后坐力系数
@export var recoil_vertical: float = 1.0    # 垂直后坐力系数
@export var weapon_accuracy: float = 1.0    # 武器精度系数

# ==================== 内部变量 ====================
# 扩散相关
var current_spread: float = 8.0             # 当前扩散距离
var target_spread: float = 8.0              # 目标扩散距离

# 晃动相关
var current_shake_offset: Vector2 = Vector2.ZERO  # 当前晃动偏移
var shoot_shake_offset: Vector2 = Vector2.ZERO    # 射击晃动偏移
var time_elapsed: float = 0.0              # 时间累积（用于噪声采样）
var noise: FastNoiseLite                   # 噪声生成器
var noise_seed: int = randi()              # 噪声种子

# 状态标志
var is_aiming: bool = false                # 是否正在瞄准
var is_moving: bool = false                # 是否正在移动
var is_shooting: bool = false              # 是否正在射击
var shoot_timer: float = 0.0               # 射击计时器

# 位置相关（键盘模式下跟随鼠标）
var is_keyboard_mode: bool = false         # 是否为键盘控制模式
var target_position: Vector2 = Vector2.ZERO     # 目标位置
var current_position: Vector2 = Vector2.ZERO    # 当前位置（平滑过渡）
var position_smoothing: float = 15.0       # 位置平滑速度
var is_initialized: bool = false           # 是否已初始化

# 准星线条引用
var line_top: Line2D                       # 上方线条
var line_bottom: Line2D                    # 下方线条
var line_left: Line2D                      # 左侧线条
var line_right: Line2D                     # 右侧线条
var center_dot: Line2D                     # 中心点
var screen_center: Vector2                 # 屏幕中心位置

# 信号
signal crosshair_updated(spread: float, state: CrosshairState)

# ==================== 生命周期函数 ====================

func _ready() -> void:
	layer = 10
	
	# 初始化噪声生成器
	noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.fractal_octaves = 2
	noise.fractal_lacunarity = 2.0
	noise.frequency = 1.0
	
	# 创建准星线条
	create_crosshair_lines()
	update_screen_center()
	
	# 初始化扩散和位置
	current_spread = base_spread
	target_spread = base_spread
	current_position = screen_center
	target_position = screen_center
	is_initialized = true

# 创建四条准星线条和中心点
func create_crosshair_lines() -> void:
	line_top = create_line()
	line_bottom = create_line()
	line_left = create_line()
	line_right = create_line()
	center_dot = create_line()
	
	add_child(line_top)
	add_child(line_bottom)
	add_child(line_left)
	add_child(line_right)
	add_child(center_dot)

# 创建单条线条
func create_line() -> Line2D:
	var line := Line2D.new()
	line.width = line_thickness
	line.default_color = line_color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	return line

# 更新屏幕中心位置
func update_screen_center() -> void:
	var viewport := get_viewport()
	if viewport:
		screen_center = viewport.get_visible_rect().size * 0.5

# 每帧更新
func _process(delta: float) -> void:
	time_elapsed += delta
	
	# 更新各个子系统
	update_shoot_timer(delta)
	update_target_spread()
	update_current_spread(delta)
	update_shake(delta)
	update_position(delta)
	update_line_positions()
	
	# 发送更新信号
	var state := get_current_state()
	emit_signal("crosshair_updated", current_spread, state)

# ==================== 更新函数 ====================

# 更新射击计时器
func update_shoot_timer(delta: float) -> void:
	if shoot_timer > 0:
		shoot_timer -= delta
		if shoot_timer <= 0:
			is_shooting = false

# 计算目标扩散距离
func update_target_spread() -> void:
	target_spread = base_spread
	
	# 瞄准时收缩
	if is_aiming:
		target_spread *= aim_spread_multiplier
		# 移动中瞄准无法完全收缩
		if is_moving:
			target_spread *= move_shake_amplitude * 0.5
	else:
		# 移动时扩散
		if is_moving:
			target_spread *= move_spread_multiplier
	
	# 射击时增加扩散
	if is_shooting:
		target_spread += shoot_spread_add * weapon_accuracy
	
	target_spread = clamp(target_spread, line_gap, max_spread)

# 平滑更新当前扩散距离
func update_current_spread(delta: float) -> void:
	var recovery_speed := base_recovery_speed
	
	# 根据状态调整恢复速度
	if is_aiming:
		recovery_speed *= aim_recovery_multiplier
	if is_moving:
		recovery_speed *= move_recovery_multiplier
	
	# 根据武器后坐力调整
	recovery_speed *= (recoil_horizontal + recoil_vertical) * 0.5
	
	# 扩散时快速响应，收缩时平滑恢复
	if current_spread < target_spread:
		current_spread = move_toward(current_spread, target_spread, recovery_speed * delta * 2.0)
	else:
		current_spread = move_toward(current_spread, target_spread, recovery_speed * delta)

# 更新晃动偏移
func update_shake(delta: float) -> void:
	var shake_offset := Vector2.ZERO
	
	# 移动中瞄准时的自然晃动
	if is_moving and is_aiming:
		var noise_x := get_noise_value(noise_seed, time_elapsed * move_shake_speed)
		var noise_y := get_noise_value(noise_seed + 100, time_elapsed * move_shake_speed)
		shake_offset = Vector2(noise_x, noise_y) * move_shake_amplitude
	
	# 射击后的晃动恢复
	if shoot_timer > 0:
		var shoot_progress := shoot_timer / 0.15
		shoot_shake_offset = shoot_shake_offset.lerp(Vector2.ZERO, shoot_shake_recovery_speed * delta)
		shake_offset += shoot_shake_offset * shoot_progress
	
	# 平滑过渡晃动效果
	current_shake_offset = current_shake_offset.lerp(shake_offset, 10.0 * delta)

# 获取噪声值（范围 -1 到 1）
func get_noise_value(seed_value: int, pos: float) -> float:
	noise.seed = seed_value
	return noise.get_noise_1d(pos * 100.0)

# 更新准星位置（键盘模式下跟随鼠标）
func update_position(_delta: float) -> void:
	if is_keyboard_mode:
		# 键盘模式：直接跟随鼠标位置，无需插值
		current_position = get_viewport().get_mouse_position()
	else:
		# 鼠标模式：固定在屏幕中心
		update_screen_center()
		current_position = screen_center

# 更新准星线条位置
func update_line_positions() -> void:
	var spread_offset := current_spread + line_gap
	var center := current_position + current_shake_offset
	
	# 上方线条
	line_top.clear_points()
	line_top.add_point(Vector2(center.x, center.y - spread_offset - line_length))
	line_top.add_point(Vector2(center.x, center.y - spread_offset))
	
	# 下方线条
	line_bottom.clear_points()
	line_bottom.add_point(Vector2(center.x, center.y + spread_offset))
	line_bottom.add_point(Vector2(center.x, center.y + spread_offset + line_length))
	
	# 左侧线条
	line_left.clear_points()
	line_left.add_point(Vector2(center.x - spread_offset - line_length, center.y))
	line_left.add_point(Vector2(center.x - spread_offset, center.y))
	
	# 右侧线条
	line_right.clear_points()
	line_right.add_point(Vector2(center.x + spread_offset, center.y))
	line_right.add_point(Vector2(center.x + spread_offset + line_length, center.y))
	
	# 中心点
	center_dot.clear_points()
	center_dot.width = line_thickness * 0.5
	center_dot.add_point(Vector2(center.x - 1, center.y))
	center_dot.add_point(Vector2(center.x + 1, center.y))

# 获取当前准星状态
func get_current_state() -> CrosshairState:
	if is_shooting:
		return CrosshairState.SHOOTING
	if is_aiming and is_moving:
		return CrosshairState.AIMING_WHILE_MOVING
	if is_aiming:
		return CrosshairState.AIMING
	if is_moving:
		return CrosshairState.MOVING
	return CrosshairState.IDLE

# ==================== 外部接口 ====================

# 设置瞄准状态
func set_aiming(aiming: bool) -> void:
	is_aiming = aiming

# 设置移动状态
func set_moving(moving: bool) -> void:
	is_moving = moving

# 设置键盘控制模式
func set_keyboard_mode(keyboard_mode: bool) -> void:
	is_keyboard_mode = keyboard_mode

# 触发射击效果
func trigger_shoot() -> void:
	is_shooting = true
	shoot_timer = 0.15
	
	# 计算射击晃动偏移
	var shake_x := randf_range(-1.0, 1.0) * shoot_shake_amplitude * recoil_horizontal
	var shake_y := randf_range(-1.0, 1.0) * shoot_shake_amplitude * recoil_vertical * 0.5
	shoot_shake_offset = Vector2(shake_x, shake_y)
	
	# 瞬间增加扩散
	current_spread += shoot_spread_add * weapon_accuracy * 0.3
	current_spread = min(current_spread, max_spread)

# 设置武器参数
func set_weapon_params(h_recoil: float, v_recoil: float, accuracy: float) -> void:
	recoil_horizontal = h_recoil
	recoil_vertical = v_recoil
	weapon_accuracy = accuracy

# 设置线条颜色
func set_line_color(color: Color) -> void:
	line_color = color
	if line_top:
		line_top.default_color = color
		line_bottom.default_color = color
		line_left.default_color = color
		line_right.default_color = color
		center_dot.default_color = color

# 设置准星可见性
func set_visibility(crosshair_visible: bool) -> void:
	if line_top:
		line_top.visible = crosshair_visible
		line_bottom.visible = crosshair_visible
		line_left.visible = crosshair_visible
		line_right.visible = crosshair_visible
		center_dot.visible = crosshair_visible

# 获取当前扩散半径
func get_spread_radius() -> float:
	return current_spread
