# 玩家输入同步器脚本
# 负责处理玩家输入、相机控制和多玩家同步

class_name PlayerInputSynchronizer
extends MultiplayerSynchronizer

# 相机控制模式枚举
enum CameraMode {
	MOUSE_CONTROL,      # 鼠标控制模式（默认）
	KEYBOARD_CONTROL    # 键盘控制模式（Q/E按键旋转）
}

# 控制器相机旋转速度
const CAMERA_CONTROLLER_ROTATION_SPEED: float = 3.0
# 鼠标相机旋转速度
const CAMERA_MOUSE_ROTATION_SPEED: float = 0.001
# 键盘旋转角度（每次按下旋转90度）
const KEYBOARD_ROTATION_ANGLE: float = deg_to_rad(90.0)
# 键盘旋转平滑过渡速度
const KEYBOARD_ROTATION_SMOOTH_SPEED: float = 1.0
# 相机X轴旋转最小角度（避免相机翻转）
const CAMERA_X_ROT_MIN: float = deg_to_rad(-89.9)
# 相机X轴旋转最大角度
const CAMERA_X_ROT_MAX: float = deg_to_rad(70.0)

# 相机距离控制相关常量
const CAMERA_DISTANCE_MIN: float = 1.0      # 相机最小距离
const CAMERA_DISTANCE_MAX: float = 16.0      # 相机最大距离
const CAMERA_DISTANCE_STEP: float = 0.2     # 滚轮每次调整的距离步长
const CAMERA_DISTANCE_SMOOTH_SPEED: float = 4.0  # 相机距离平滑过渡速度

# 相机高度与距离联动参数
const CAMERA_HEIGHT_MIN: float = 1.6                 # 相机最小高度（对应最小距离）
const CAMERA_HEIGHT_MAX: float = 4.0                 # 相机最大高度（对应最大距离）
const CAMERA_HEIGHT_SMOOTH_SPEED: float = 4.0        # 相机高度平滑过渡速度

# 自动模式切换阈值
const AUTO_MODE_SWITCH_THRESHOLD_CLOSE: float = 3.0  # 切换到鼠标控制模式的阈值（距离小于此值）
const AUTO_MODE_SWITCH_THRESHOLD_FAR: float = 5.0    # 切换到键盘控制模式的阈值（距离大于此值）
const AUTO_MODE_SWITCH_COOLDOWN: float = 0.5         # 自动模式切换冷却时间（防止频繁切换）

# 键盘控制模式瞄准参数
const MOUSE_AIM_ROTATION_SPEED: float = 5.0           # 键盘模式下瞄准时人物朝向鼠标方向的速度 

# 瞄准保持阈值 - 短按切换瞄准，长按保持瞄准
const AIM_HOLD_THRESHOLD: float = 0.4

# 相机控制模式 - 通过初始化变量切换
@export var camera_mode: CameraMode = CameraMode.MOUSE_CONTROL

# 瞄准切换标志 - 是否通过短按切换瞄准模式
var toggled_aim: bool = false
# 瞄准计时器 - 记录瞄准按钮按下的时间
var aiming_timer: float = 0.0
# Q/E按键旋转冷却计时器
var keyboard_rotation_cooldown: float = 0.0
# 键盘旋转冷却时间（避免连续快速旋转）
const KEYBOARD_ROTATION_COOLDOWN_TIME: float = 0.05

# 键盘控制模式下的平滑旋转变量
var target_y_rotation: float = 0.0  # 目标Y轴旋转角度
var is_rotating: bool = false      # 是否正在旋转
var rotation_progress: float = 0.0 # 旋转进度（0-1）

# 相机距离控制变量
var target_camera_distance: float = 2.4  # 目标相机距离（默认2.4）
var is_distance_changing: bool = false   # 是否正在调整距离
var distance_change_progress: float = 0.0 # 距离调整进度（0-1）

# 自动模式切换变量
var auto_mode_switch_cooldown: float = 0.0  # 自动模式切换冷却计时器
var last_camera_distance: float = 2.4       # 上次检测的相机距离（用于变化检测）

# 键盘控制模式瞄准变量
var mouse_aim_target_rotation: float = 0.0  # 鼠标瞄准时的目标人物旋转角度

# 相机高度控制变量
var target_camera_height: float = 1.6      # 目标相机高度
var is_height_changing: bool = false       # 是否正在调整高度
var height_change_progress: float = 0.0     # 高度调整进度（0-1）

# 同步的输入状态变量
@export var aiming: bool = false          # 是否正在瞄准
@export var shoot_target := Vector3()     # 射击目标位置
@export var motion := Vector2()           # 移动向量
@export var shooting: bool = false        # 是否正在射击
@export var jumping: bool = false         # 是否正在跳跃（通过RPC处理）

# 相机和效果相关节点
@export var camera_animation: AnimationPlayer  # 相机动画播放器
@export var crosshair: TextureRect             # 准星UI
@export var camera_base: Node3D                # 相机基础节点（控制Y轴旋转）
@export var camera_rot: Node3D                 # 相机旋转节点（控制X轴旋转）
@export var camera_camera: Camera3D            # 相机组件
@export var color_rect: ColorRect              # 用于屏幕渐变的颜色矩形
@export var spring_arm: SpringArm3D           # SpringArm3D节点（控制相机距离）


# 节点准备完成时调用
func _ready() -> void:
	# 如果是本地玩家，设置当前相机并捕获鼠标
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		camera_camera.make_current()
		# 根据相机模式设置鼠标模式
		if camera_mode == CameraMode.MOUSE_CONTROL:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# 初始化目标旋转角度为当前角度
		target_y_rotation = camera_base.rotation.y
		# 初始化目标相机距离为当前距离
		target_camera_distance = spring_arm.spring_length
		# 初始化目标相机高度为当前高度
		target_camera_height = camera_base.position.y
	else:
		# 非本地玩家禁用处理和输入，隐藏颜色矩形
		set_process(false)
		set_process_input(false)
		color_rect.hide()


# 每帧处理函数
func _process(delta: float) -> void:
	# 更新键盘旋转冷却计时器
	if keyboard_rotation_cooldown > 0:
		keyboard_rotation_cooldown -= delta

	# 更新自动模式切换冷却计时器
	if auto_mode_switch_cooldown > 0:
		auto_mode_switch_cooldown -= delta

	# 键盘控制模式下的平滑旋转处理
	if camera_mode == CameraMode.KEYBOARD_CONTROL and is_rotating:
		handle_smooth_rotation(delta)
	
	# 相机距离平滑调整处理
	if is_distance_changing:
		handle_smooth_distance_change(delta)
	
	# 相机高度平滑调整处理
	if is_height_changing:
		handle_smooth_height_change(delta)
	
	# 自动模式切换检测（仅在冷却结束后检测）
	if auto_mode_switch_cooldown <= 0:
		handle_auto_mode_switch()

	# 计算移动向量（基于输入动作强度）
	motion = Vector2(
			Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left"),
			Input.get_action_strength(&"move_back") - Input.get_action_strength(&"move_forward"))
	
	# 键盘控制模式下的相机旋转输入处理
	if camera_mode == CameraMode.KEYBOARD_CONTROL:
		handle_keyboard_camera_rotation()
	
	# 计算相机移动向量（用于控制器输入）
	var camera_move := Vector2(
			Input.get_action_strength(&"ui_right") - Input.get_action_strength(&"ui_left"),
			Input.get_action_strength(&"ui_up") - Input.get_action_strength(&"ui_down"))
	
	# 计算当前帧的相机旋转速度
	var camera_speed_this_frame: float = delta * CAMERA_CONTROLLER_ROTATION_SPEED
	# 瞄准时降低相机旋转速度
	if aiming:
		camera_speed_this_frame *= 0.5
	
	# 旋转相机（处理控制器输入）
	rotate_camera(camera_move * camera_speed_this_frame)
	
	# 瞄准逻辑处理
	var current_aim: bool = false

	# 如果瞄准按钮刚刚释放且按下时间小于阈值，则切换瞄准状态
	if Input.is_action_just_released(&"aim") and aiming_timer <= AIM_HOLD_THRESHOLD:
		current_aim = true
		toggled_aim = true
	else:
		# 否则根据切换状态或持续按压判断
		current_aim = toggled_aim or Input.is_action_pressed("aim")
		# 如果瞄准按钮刚刚按下，重置切换标志
		if Input.is_action_just_pressed("aim"):
			toggled_aim = false

	# 更新瞄准计时器
	if current_aim:
		aiming_timer += delta
	else:
		aiming_timer = 0.0

	# 如果瞄准状态发生变化
	if aiming != current_aim:
		aiming = current_aim
		# 播放相应的相机动画
		if aiming:
			camera_animation.play("shoot")
			# 键盘控制模式下瞄准时，初始化人物朝向鼠标方向
			if camera_mode == CameraMode.KEYBOARD_CONTROL:
				update_mouse_aim_target_rotation()
		else:
			camera_animation.play("far")
	
	# 键盘控制模式下瞄准时，更新鼠标瞄准目标方向和准星位置
	if camera_mode == CameraMode.KEYBOARD_CONTROL and aiming:
		update_mouse_aim_target_rotation() 

	# 跳跃输入处理（通过RPC调用）
	if Input.is_action_just_pressed("jump"):
		jump.rpc()

	# 射击输入处理
	shooting = Input.is_action_pressed("shoot")
	if shooting:
		# 计算准星在屏幕上的位置
		var ch_pos = crosshair.position + crosshair.size * 0.5
		# 从相机发射射线
		var ray_from = camera_camera.project_ray_origin(ch_pos)
		var ray_dir = camera_camera.project_ray_normal(ch_pos)

		# 检测射线碰撞
		var col = get_parent().get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_from, ray_from + ray_dir * 1000, 0b11, Array([self], TYPE_RID, "", null)))
		# 设置射击目标位置
		if col.is_empty():
			shoot_target = ray_from + ray_dir * 1000.0
		else:
			shoot_target = col.position

	# 坠落检测和屏幕渐变效果
	var player_transform: Transform3D = get_parent().global_transform
	# 如果玩家位置低于-17（地图最低有效位置）
	if player_transform.origin.y < -17.0:
		# 根据坠落距离计算屏幕渐变透明度
		color_rect.modulate.a = minf((-17.0 - player_transform.origin.y) / 15.0, 1.0)
	else:
		# 玩家回到安全位置时逐渐淡出黑色覆盖
		color_rect.modulate.a *= 1.0 - delta * 4.0


# 键盘控制模式下的相机旋转输入处理
func handle_keyboard_camera_rotation() -> void:
	# 检查旋转冷却是否结束，并且当前没有正在进行的旋转
	if keyboard_rotation_cooldown <= 0 and not is_rotating:
		# Q键 - 向左旋转90度
		if Input.is_action_just_pressed("rotate_left"):
			start_smooth_rotation(-KEYBOARD_ROTATION_ANGLE)
			keyboard_rotation_cooldown = KEYBOARD_ROTATION_COOLDOWN_TIME
		
		# E键 - 向右旋转90度
		if Input.is_action_just_pressed("rotate_right"):
			start_smooth_rotation(KEYBOARD_ROTATION_ANGLE)
			keyboard_rotation_cooldown = KEYBOARD_ROTATION_COOLDOWN_TIME


# 开始平滑旋转
func start_smooth_rotation(angle: float) -> void:
	# 设置目标旋转角度
	target_y_rotation = camera_base.rotation.y + angle
	# 重置旋转进度
	rotation_progress = 0.0
	# 标记为正在旋转
	is_rotating = true
	
	print("开始平滑旋转: 从 %.1f 度到 %.1f 度" % [rad_to_deg(camera_base.rotation.y), rad_to_deg(target_y_rotation)])


# 处理平滑旋转
func handle_smooth_rotation(delta: float) -> void:
	# 更新旋转进度
	rotation_progress += delta * KEYBOARD_ROTATION_SMOOTH_SPEED
	
	# 使用缓动函数实现平滑过渡（easeOutCubic）
	var t: float = ease_out_cubic(clamp(rotation_progress, 0.0, 1.0))
	
	# 计算当前旋转角度
	var current_rotation: float = lerp_angle(camera_base.rotation.y, target_y_rotation, t)
	
	# 应用旋转
	camera_base.rotation.y = current_rotation
	
	# 检查旋转是否完成
	if rotation_progress >= 1.0:
		# 确保最终角度精确
		camera_base.rotation.y = target_y_rotation
		# 完成旋转
		is_rotating = false
		print("旋转完成: %.1f 度" % rad_to_deg(camera_base.rotation.y))


# 缓出三次方函数（easeOutCubic）
func ease_out_cubic(t: float) -> float:
	var t2: float = t - 1.0
	return t2 * t2 * t2 + 1.0


# 输入事件处理函数
func _input(input_event: InputEvent) -> void:
	# 处理鼠标滚轮事件（两种控制模式都生效）
	if input_event is InputEventMouseButton:
		handle_mouse_wheel_input(input_event)
	
	# 只在鼠标控制模式下处理鼠标移动事件
	if camera_mode == CameraMode.MOUSE_CONTROL and input_event is InputEventMouseMotion:
		var camera_speed_this_frame = CAMERA_MOUSE_ROTATION_SPEED
		# 瞄准时降低鼠标灵敏度
		if aiming:
			camera_speed_this_frame *= 0.75
		# 根据鼠标移动旋转相机
		rotate_camera(input_event.screen_relative * camera_speed_this_frame)


# 相机旋转函数
# 根据移动向量旋转相机的基础和旋转节点
func rotate_camera(move: Vector2) -> void:
	# 旋转相机基础节点（Y轴旋转）
	camera_base.rotate_y(-move.x)
	# 正交标准化变换
	camera_base.orthonormalize()
	# 旋转相机旋转节点（X轴旋转），限制在有效范围内
	camera_rot.rotation.x = clampf(camera_rot.rotation.x + move.y, CAMERA_X_ROT_MIN, CAMERA_X_ROT_MAX)


# 获取瞄准旋转角度
# 根据相机X轴旋转计算瞄准动画的混合值
func get_aim_rotation() -> float:
	var camera_x_rot: float = clampf(camera_rot.rotation.x, CAMERA_X_ROT_MIN, CAMERA_X_ROT_MAX)
	# 根据相机角度计算瞄准混合值
	if camera_x_rot >= 0.0: # 向上瞄准
		return -camera_x_rot / CAMERA_X_ROT_MAX
	else: # 向下瞄准
		return camera_x_rot / CAMERA_X_ROT_MIN


# 获取相机基础四元数
# 用于角色旋转插值
func get_camera_base_quaternion() -> Quaternion:
	return camera_base.global_transform.basis.get_rotation_quaternion()


# 获取相机旋转基础
# 用于计算移动方向
func get_camera_rotation_basis() -> Basis:
	return camera_rot.global_transform.basis


# 远程调用函数 - 跳跃
# 设置跳跃标志，将在主玩家脚本中处理
@rpc("call_local")
func jump() -> void:
	jumping = true


# 切换相机控制模式（可用于调试或运行时切换）
func switch_camera_mode(new_mode: CameraMode) -> void:
	if camera_mode != new_mode:
		camera_mode = new_mode
		
		# 根据新模式设置鼠标模式
		if get_multiplayer_authority() == multiplayer.get_unique_id():
			if camera_mode == CameraMode.MOUSE_CONTROL:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# 重置旋转状态
		if camera_mode == CameraMode.KEYBOARD_CONTROL:
			target_y_rotation = camera_base.rotation.y
			is_distance_changing = false
			distance_change_progress = 0.0
			target_camera_distance = spring_arm.spring_length
			is_rotating = false
			rotation_progress = 0.0
		
		print("相机模式已切换至: %s" % ("鼠标控制" if camera_mode == CameraMode.MOUSE_CONTROL else "键盘控制"))


# 处理鼠标滚轮输入
func handle_mouse_wheel_input(event: InputEventMouseButton) -> void:
	# 检查是否为鼠标滚轮事件
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		# 计算新的目标距离
		var new_distance: float = target_camera_distance
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# 滚轮向上 - 拉近相机
			new_distance = max(CAMERA_DISTANCE_MIN, target_camera_distance - CAMERA_DISTANCE_STEP)
			print("滚轮向上: 相机距离从 %.1f 调整到 %.1f" % [spring_arm.spring_length, new_distance])
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# 滚轮向下 - 拉远相机
			new_distance = min(CAMERA_DISTANCE_MAX, target_camera_distance + CAMERA_DISTANCE_STEP)
			print("滚轮向下: 相机距离从 %.1f 调整到 %.1f" % [spring_arm.spring_length, new_distance])
		
		# 如果距离有变化，开始平滑调整
		if new_distance != target_camera_distance:
			target_camera_distance = new_distance
			is_distance_changing = true
			distance_change_progress = 0.0
			
			# 同时调整相机高度（根据距离比例计算高度）
			var height_ratio: float = (new_distance - CAMERA_DISTANCE_MIN) / (CAMERA_DISTANCE_MAX - CAMERA_DISTANCE_MIN)
			target_camera_height = lerp(CAMERA_HEIGHT_MIN, CAMERA_HEIGHT_MAX, height_ratio)
			is_height_changing = true
			height_change_progress = 0.0
			
			print("同时调整相机高度到: %.1f" % target_camera_height)


# 处理相机距离平滑调整
func handle_smooth_distance_change(delta: float) -> void:
	# 更新距离调整进度
	distance_change_progress += delta * CAMERA_DISTANCE_SMOOTH_SPEED
	
	# 使用缓动函数实现平滑过渡
	var t: float = ease_out_cubic(clamp(distance_change_progress, 0.0, 1.0))
	
	# 计算当前相机距离
	var current_distance: float = lerp(spring_arm.spring_length, target_camera_distance, t)
	
	# 应用距离调整
	spring_arm.spring_length = current_distance
	
	# 检查距离调整是否完成
	if distance_change_progress >= 1.0:
		# 确保最终距离精确
		spring_arm.spring_length = target_camera_distance
		# 完成距离调整
		is_distance_changing = false
		print("相机距离调整完成: %.1f" % spring_arm.spring_length)


# 处理自动模式切换检测
func handle_auto_mode_switch() -> void:
	# 获取当前相机距离
	var current_distance: float = spring_arm.spring_length
	
	# 只有当距离发生变化时才检测模式切换
	if abs(current_distance - last_camera_distance) > 0.01:
		last_camera_distance = current_distance
		
		# 检测是否需要切换到鼠标控制模式（近距离）
		if current_distance < AUTO_MODE_SWITCH_THRESHOLD_CLOSE and camera_mode != CameraMode.MOUSE_CONTROL:
			switch_camera_mode(CameraMode.MOUSE_CONTROL)
			print("自动切换到鼠标控制模式（相机距离: %.1f < %.1f）" % [current_distance, AUTO_MODE_SWITCH_THRESHOLD_CLOSE])
			auto_mode_switch_cooldown = AUTO_MODE_SWITCH_COOLDOWN
		
		# 检测是否需要切换到键盘控制模式（远距离）
		elif current_distance > AUTO_MODE_SWITCH_THRESHOLD_FAR and camera_mode != CameraMode.KEYBOARD_CONTROL:
			switch_camera_mode(CameraMode.KEYBOARD_CONTROL)
			print("自动切换到键盘控制模式（相机距离: %.1f > %.1f）" % [current_distance, AUTO_MODE_SWITCH_THRESHOLD_FAR])
			auto_mode_switch_cooldown = AUTO_MODE_SWITCH_COOLDOWN


# 处理相机高度平滑调整
func handle_smooth_height_change(delta: float) -> void:
	# 更新高度调整进度
	height_change_progress += delta * CAMERA_HEIGHT_SMOOTH_SPEED
	
	# 使用缓动函数实现平滑过渡
	var t: float = ease_out_cubic(clamp(height_change_progress, 0.0, 1.0))
	
	# 计算当前相机高度
	var current_height: float = lerp(camera_base.position.y, target_camera_height, t)
	
	# 应用高度调整（只调整Y轴位置）
	camera_base.position.y = current_height
	
	# 检查高度调整是否完成
	if height_change_progress >= 1.0:
		# 确保最终高度精确
		camera_base.position.y = target_camera_height
		# 完成高度调整
		is_height_changing = false
		print("相机高度调整完成: %.1f" % camera_base.position.y)


# 更新鼠标瞄准时的目标人物旋转角度
func update_mouse_aim_target_rotation() -> void:
	# 获取鼠标在屏幕上的位置
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	
	# 从相机发射射线到鼠标位置
	var ray_from = camera_camera.project_ray_origin(mouse_pos)
	var ray_dir = camera_camera.project_ray_normal(mouse_pos)
	
	# 计算射线与水平面的交点（Y=0的平面）
	var player_pos: Vector3 = get_parent().global_transform.origin
	var plane_normal: Vector3 = Vector3.UP
	var plane_point: Vector3 = Vector3(player_pos.x, 0, player_pos.z)
	
	# 计算射线与平面的交点
	var denom: float = plane_normal.dot(ray_dir)
	if abs(denom) > 0.0001:
		var t: float = (plane_normal.dot(plane_point) - plane_normal.dot(ray_from)) / denom
		var hit_point: Vector3 = ray_from + ray_dir * t
		
		# 计算从玩家位置到交点的方向向量
		var direction: Vector3 = (hit_point - player_pos).normalized()
		
		# 计算目标旋转角度（Y轴旋转）
		# 注意：atan2(y, x) 返回从x轴正方向逆时针旋转到向量的角度
		# 但在3D中，我们需要的是从z轴正方向的角度
		mouse_aim_target_rotation = atan2(direction.x, direction.z)
		
		print("鼠标瞄准目标旋转角度: %.1f 度" % rad_to_deg(mouse_aim_target_rotation))
