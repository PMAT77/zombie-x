# 玩家输入同步器脚本
# 负责处理玩家输入、相机控制和多玩家同步

class_name PlayerInputController
extends Node

# 相机控制模式枚举
enum CameraMode {
	MOUSE_CONTROL,      # 鼠标控制模式（默认）
	KEYBOARD_CONTROL    # 键盘控制模式（Q/E按键旋转）
}

# 相机控制参数
const CAMERA_CONTROLLER_ROTATION_SPEED: float = 3.0    # 控制器相机旋转速度
const CAMERA_MOUSE_ROTATION_SPEED: float = 0.001      # 鼠标相机旋转速度
const KEYBOARD_ROTATION_ANGLE: float = deg_to_rad(90.0)  # 键盘旋转角度（每次按下旋转90度）
const KEYBOARD_ROTATION_SMOOTH_SPEED: float = 1.0     # 键盘旋转平滑过渡速度
const KEYBOARD_ROTATION_COOLDOWN_TIME: float = 0.05   # 键盘旋转冷却时间

# 相机角度限制
const CAMERA_X_ROT_MIN: float = deg_to_rad(-89.9)     # 相机X轴旋转最小角度（避免相机翻转）
const CAMERA_X_ROT_MAX: float = deg_to_rad(70.0)      # 相机X轴旋转最大角度

# 相机距离控制参数
const CAMERA_DISTANCE_MIN: float = 1.0                 # 相机最小距离
const CAMERA_DISTANCE_MAX: float = 16.0                # 相机最大距离
const CAMERA_DISTANCE_STEP: float = 0.4                # 滚轮每次调整的距离步长
const CAMERA_DISTANCE_SMOOTH_SPEED: float = 4.0        # 相机距离平滑过渡速度

# 相机高度联动参数
const CAMERA_HEIGHT_MIN: float = 1.6                   # 相机最小高度（对应最小距离）
const CAMERA_HEIGHT_MAX: float = 4.0                   # 相机最大高度（对应最大距离）
const CAMERA_HEIGHT_SMOOTH_SPEED: float = 4.0          # 相机高度平滑过渡速度

# 自动模式切换参数
const AUTO_MODE_SWITCH_THRESHOLD_CLOSE: float = 3.0    # 切换到鼠标控制模式的阈值（距离小于此值）
const AUTO_MODE_SWITCH_THRESHOLD_FAR: float = 5.0     # 切换到键盘控制模式的阈值（距离大于此值）
const AUTO_MODE_SWITCH_COOLDOWN: float = 0.5          # 自动模式切换冷却时间

# 瞄准参数
const MOUSE_AIM_ROTATION_SPEED: float = 5.0            # 键盘模式下瞄准时人物朝向鼠标方向的速度
const AIM_HOLD_THRESHOLD: float = 0.4                  # 瞄准保持阈值 - 短按切换瞄准，长按保持瞄准

# 相机控制模式
@export var camera_mode: CameraMode = CameraMode.MOUSE_CONTROL

# 输入状态变量
@export var aiming: bool = false          # 是否正在瞄准
@export var shoot_target := Vector3()     # 射击目标位置
@export var motion := Vector2()           # 移动向量
@export var shooting: bool = false        # 是否正在射击
@export var jumping: bool = false         # 是否正在跳跃

# 相机控制变量
var toggled_aim: bool = false             # 瞄准切换标志
var aiming_timer: float = 0.0            # 瞄准计时器
var keyboard_rotation_cooldown: float = 0.0  # Q/E按键旋转冷却计时器

# 键盘控制模式变量
var target_y_rotation: float = 0.0        # 目标Y轴旋转角度
var is_rotating: bool = false            # 是否正在旋转
var rotation_progress: float = 0.0       # 旋转进度（0-1）

# 相机距离控制变量
var target_camera_distance: float = 2.4   # 目标相机距离（默认2.4）
var is_distance_changing: bool = false   # 是否正在调整距离
var distance_change_progress: float = 0.0 # 距离调整进度（0-1）

# 相机高度控制变量
var target_camera_height: float = 1.6     # 目标相机高度
var is_height_changing: bool = false      # 是否正在调整高度
var height_change_progress: float = 0.0   # 高度调整进度（0-1）

# 自动模式切换变量
var auto_mode_switch_cooldown: float = 0.0  # 自动模式切换冷却计时器
var last_camera_distance: float = 2.4       # 上次检测的相机距离

# 键盘控制模式瞄准变量
var mouse_aim_target_rotation: float = 0.0  # 鼠标瞄准时的目标人物旋转角度

# 相机节点引用
@export var camera_animation: AnimationPlayer  # 相机动画播放器
@export var crosshair: TextureRect             # 准星UI
@export var camera_base: Node3D                # 相机基础节点（控制Y轴旋转）
@export var camera_rot: Node3D                 # 相机旋转节点（控制X轴旋转）
@export var camera_camera: Camera3D            # 相机组件
@export var color_rect: ColorRect              # 用于屏幕渐变的颜色矩形
@export var spring_arm: SpringArm3D             # SpringArm3D节点（控制相机距离）

# 节点准备完成时调用
func _ready() -> void:
	if camera_camera and camera_base and spring_arm:
		camera_camera.make_current()
		update_mouse_mode()
		
		target_y_rotation = camera_base.rotation.y
		target_camera_distance = spring_arm.spring_length
		target_camera_height = camera_base.position.y

# 每帧处理函数
func _process(delta: float) -> void:
	update_timers(delta)
	
	# 处理不同控制模式下的逻辑
	if camera_mode == CameraMode.KEYBOARD_CONTROL:
		handle_keyboard_mode(delta)
	
	# 处理相机距离和高度平滑调整
	if is_distance_changing:
		handle_smooth_distance_change(delta)
	if is_height_changing:
		handle_smooth_height_change(delta)
	
	# 自动模式切换检测
	handle_auto_mode_switch()
	
	update_motion_input()
	handle_camera_rotation(delta)
	handle_aiming_logic(delta)
	handle_shooting_logic()
	handle_jump_input()
	handle_fall_effect()

# 更新计时器
func update_timers(delta: float) -> void:
	if keyboard_rotation_cooldown > 0:
		keyboard_rotation_cooldown -= delta
	if auto_mode_switch_cooldown > 0:
		auto_mode_switch_cooldown -= delta

# 处理键盘控制模式
func handle_keyboard_mode(delta: float) -> void:
	if is_rotating:
		handle_smooth_rotation(delta)
	
	handle_keyboard_camera_rotation()
	
	if aiming:
		update_mouse_aim_target_rotation()

# 更新移动输入
func update_motion_input() -> void:
	motion = Vector2(
		Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left"),
		Input.get_action_strength(&"move_back") - Input.get_action_strength(&"move_forward"))

# 处理相机旋转
func handle_camera_rotation(delta: float) -> void:
	var camera_move := Vector2(
		Input.get_action_strength(&"ui_right") - Input.get_action_strength(&"ui_left"),
		Input.get_action_strength(&"ui_up") - Input.get_action_strength(&"ui_down"))
	
	var camera_speed: float = delta * CAMERA_CONTROLLER_ROTATION_SPEED
	if aiming:
		camera_speed *= 0.5
	
	rotate_camera(camera_move * camera_speed)

# 处理瞄准逻辑
func handle_aiming_logic(delta: float) -> void:
	var current_aim: bool = false
	
	# 短按切换瞄准，长按保持瞄准
	if Input.is_action_just_released(&"aim") and aiming_timer <= AIM_HOLD_THRESHOLD:
		current_aim = true
		toggled_aim = true
	else:
		current_aim = toggled_aim or Input.is_action_pressed("aim")
		if Input.is_action_just_pressed("aim"):
			toggled_aim = false
	
	# 更新瞄准计时器
	if current_aim:
		aiming_timer += delta
	else:
		aiming_timer = 0.0
	
	# 处理瞄准状态变化
	if aiming != current_aim:
		aiming = current_aim
		handle_aiming_state_change()

# 处理瞄准状态变化
func handle_aiming_state_change() -> void:
	if aiming:
		camera_animation.play("shoot")
		if camera_mode == CameraMode.KEYBOARD_CONTROL:
			update_mouse_aim_target_rotation()
	else:
		camera_animation.play("far")

# 处理射击逻辑
func handle_shooting_logic() -> void:
	shooting = Input.is_action_pressed("shoot")
	if shooting and camera_camera:
		shoot_target = calculate_shoot_target()

# 处理跳跃输入
func handle_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		jump()

# 处理坠落效果
func handle_fall_effect() -> void:
	var player_transform: Transform3D = get_parent().global_transform
	if player_transform.origin.y < -17.0 and color_rect:
		color_rect.modulate.a = minf((-17.0 - player_transform.origin.y) / 15.0, 1.0)
	elif color_rect:
		color_rect.modulate.a *= 1.0 - 4.0 * get_process_delta_time()

# 键盘控制模式下的相机旋转输入处理
func handle_keyboard_camera_rotation() -> void:
	if keyboard_rotation_cooldown <= 0 and not is_rotating:
		if Input.is_action_just_pressed("rotate_left"):
			start_smooth_rotation(-KEYBOARD_ROTATION_ANGLE)
			keyboard_rotation_cooldown = KEYBOARD_ROTATION_COOLDOWN_TIME
		elif Input.is_action_just_pressed("rotate_right"):
			start_smooth_rotation(KEYBOARD_ROTATION_ANGLE)
			keyboard_rotation_cooldown = KEYBOARD_ROTATION_COOLDOWN_TIME

# 开始平滑旋转
func start_smooth_rotation(angle: float) -> void:
	target_y_rotation = camera_base.rotation.y + angle
	rotation_progress = 0.0
	is_rotating = true
	
	print("开始平滑旋转: 从 %.1f 度到 %.1f 度" % [rad_to_deg(camera_base.rotation.y), rad_to_deg(target_y_rotation)])

# 处理平滑旋转
func handle_smooth_rotation(delta: float) -> void:
	if camera_base:
		rotation_progress += delta * KEYBOARD_ROTATION_SMOOTH_SPEED
		var t: float = ease_out_cubic(clamp(rotation_progress, 0.0, 1.0))
		var current_rotation: float = lerp_angle(camera_base.rotation.y, target_y_rotation, t)
		
		camera_base.rotation.y = current_rotation
		
		if rotation_progress >= 1.0:
			camera_base.rotation.y = target_y_rotation
			is_rotating = false
			print("旋转完成: %.1f 度" % rad_to_deg(camera_base.rotation.y))

# 缓出三次方函数（easeOutCubic）
func ease_out_cubic(t: float) -> float:
	var t2: float = t - 1.0
	return t2 * t2 * t2 + 1.0

# 输入事件处理函数
func _input(input_event: InputEvent) -> void:
	if input_event is InputEventMouseButton:
		handle_mouse_wheel_input(input_event)
	
	if camera_mode == CameraMode.MOUSE_CONTROL and input_event is InputEventMouseMotion:
		var camera_speed: float = CAMERA_MOUSE_ROTATION_SPEED
		if aiming:
			camera_speed *= 0.75
		rotate_camera(input_event.screen_relative * camera_speed)

# 相机旋转函数
func rotate_camera(move: Vector2) -> void:
	if camera_base and camera_rot:
		camera_base.rotate_y(-move.x)
		camera_base.orthonormalize()
		camera_rot.rotation.x = clampf(camera_rot.rotation.x + move.y, CAMERA_X_ROT_MIN, CAMERA_X_ROT_MAX)

# 获取瞄准旋转角度
func get_aim_rotation() -> float:
	var camera_x_rot: float = clampf(camera_rot.rotation.x, CAMERA_X_ROT_MIN, CAMERA_X_ROT_MAX)
	if camera_x_rot >= 0.0: # 向上瞄准
		return -camera_x_rot / CAMERA_X_ROT_MAX
	else: # 向下瞄准
		return camera_x_rot / CAMERA_X_ROT_MIN

# 获取相机基础四元数
func get_camera_base_quaternion() -> Quaternion:
	return camera_base.global_transform.basis.get_rotation_quaternion()

# 获取相机旋转基础
func get_camera_rotation_basis() -> Basis:
	return camera_rot.global_transform.basis

# 跳跃函数
func jump() -> void:
	jumping = true

# 切换相机控制模式
func switch_camera_mode(new_mode: CameraMode) -> void:
	if camera_mode != new_mode:
		camera_mode = new_mode
		update_mouse_mode()
		reset_rotation_state()
		print("相机模式已切换至: %s" % ("鼠标控制" if camera_mode == CameraMode.MOUSE_CONTROL else "键盘控制"))

# 更新鼠标模式
func update_mouse_mode() -> void:
	if camera_camera:
		if camera_mode == CameraMode.MOUSE_CONTROL:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# 重置旋转状态
func reset_rotation_state() -> void:
	if camera_mode == CameraMode.KEYBOARD_CONTROL and camera_base and spring_arm:
		target_y_rotation = camera_base.rotation.y
		is_distance_changing = false
		distance_change_progress = 0.0
		target_camera_distance = spring_arm.spring_length
		is_rotating = false
		rotation_progress = 0.0

# 处理鼠标滚轮输入
func handle_mouse_wheel_input(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var new_distance: float = target_camera_distance
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			new_distance = max(CAMERA_DISTANCE_MIN, target_camera_distance - CAMERA_DISTANCE_STEP)
			print("滚轮向上: 相机距离从 %.1f 调整到 %.1f" % [spring_arm.spring_length, new_distance])
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			new_distance = min(CAMERA_DISTANCE_MAX, target_camera_distance + CAMERA_DISTANCE_STEP)
			print("滚轮向下: 相机距离从 %.1f 调整到 %.1f" % [spring_arm.spring_length, new_distance])
		
		if new_distance != target_camera_distance:
			target_camera_distance = new_distance
			is_distance_changing = true
			distance_change_progress = 0.0
			
			# 联动调整相机高度
			var height_ratio: float = (new_distance - CAMERA_DISTANCE_MIN) / (CAMERA_DISTANCE_MAX - CAMERA_DISTANCE_MIN)
			target_camera_height = lerp(CAMERA_HEIGHT_MIN, CAMERA_HEIGHT_MAX, height_ratio)
			is_height_changing = true
			height_change_progress = 0.0
			
			print("同时调整相机高度到: %.1f" % target_camera_height)

# 处理相机距离平滑调整
func handle_smooth_distance_change(delta: float) -> void:
	if spring_arm:
		distance_change_progress += delta * CAMERA_DISTANCE_SMOOTH_SPEED
		var t: float = ease_out_cubic(clamp(distance_change_progress, 0.0, 1.0))
		var current_distance: float = lerp(spring_arm.spring_length, target_camera_distance, t)
		
		spring_arm.spring_length = current_distance
		
		if distance_change_progress >= 1.0:
			spring_arm.spring_length = target_camera_distance
			is_distance_changing = false
			print("相机距离调整完成: %.1f" % spring_arm.spring_length)

# 处理自动模式切换检测
func handle_auto_mode_switch() -> void:
	if spring_arm and auto_mode_switch_cooldown <= 0:
		var current_distance: float = spring_arm.spring_length
		
		if abs(current_distance - last_camera_distance) > 0.01:
			last_camera_distance = current_distance
			
			if current_distance < AUTO_MODE_SWITCH_THRESHOLD_CLOSE and camera_mode != CameraMode.MOUSE_CONTROL:
				switch_camera_mode(CameraMode.MOUSE_CONTROL)
				auto_mode_switch_cooldown = AUTO_MODE_SWITCH_COOLDOWN
			elif current_distance > AUTO_MODE_SWITCH_THRESHOLD_FAR and camera_mode != CameraMode.KEYBOARD_CONTROL:
				switch_camera_mode(CameraMode.KEYBOARD_CONTROL)
				auto_mode_switch_cooldown = AUTO_MODE_SWITCH_COOLDOWN

# 处理相机高度平滑调整
func handle_smooth_height_change(delta: float) -> void:
	if camera_base:
		height_change_progress += delta * CAMERA_HEIGHT_SMOOTH_SPEED
		var t: float = ease_out_cubic(clamp(height_change_progress, 0.0, 1.0))
		var current_height: float = lerp(camera_base.position.y, target_camera_height, t)
		
		camera_base.position.y = current_height
		
		if height_change_progress >= 1.0:
			camera_base.position.y = target_camera_height
			is_height_changing = false
			print("相机高度调整完成: %.1f" % camera_base.position.y)

# 更新鼠标瞄准时的目标人物旋转角度
func update_mouse_aim_target_rotation() -> void:
	if camera_camera and get_parent():
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var ray_from = camera_camera.project_ray_origin(mouse_pos)
		var ray_dir = camera_camera.project_ray_normal(mouse_pos)
		
		var player_pos: Vector3 = get_parent().global_transform.origin
		var plane_normal: Vector3 = Vector3.UP
		var plane_point: Vector3 = Vector3(player_pos.x, 0, player_pos.z)
		
		var denom: float = plane_normal.dot(ray_dir)
		if abs(denom) > 0.0001:
			var t: float = (plane_normal.dot(plane_point) - plane_normal.dot(ray_from)) / denom
			var hit_point: Vector3 = ray_from + ray_dir * t
			var direction: Vector3 = (hit_point - player_pos).normalized()
			
			mouse_aim_target_rotation = atan2(direction.x, direction.z)
			print("鼠标瞄准目标旋转角度: %.1f 度" % rad_to_deg(mouse_aim_target_rotation))

# 计算射击目标位置
func calculate_shoot_target() -> Vector3:
	var shoot_pos: Vector2
	
	if camera_mode == CameraMode.KEYBOARD_CONTROL:
		shoot_pos = get_viewport().get_mouse_position()
	elif crosshair:
		shoot_pos = crosshair.position + crosshair.size * 0.5
	else:
		shoot_pos = get_viewport().size * 0.5
	
	var ray_from = camera_camera.project_ray_origin(shoot_pos)
	var ray_dir = camera_camera.project_ray_normal(shoot_pos)
	
	var col = get_parent().get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_from, ray_from + ray_dir * 1000, 0b11, []))
	
	if col.is_empty():
		return ray_from + ray_dir * 1000.0
	else:
		return col.position
