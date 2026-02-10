# 玩家角色主脚本
# 负责处理玩家的移动、动画、射击等核心功能

class_name Player
extends CharacterBody3D

# 玩家动画状态枚举
enum Animations {
	JUMP_UP,    # 跳跃上升动画
	JUMP_DOWN,  # 跳跃下降动画
	STRAFE,     # 侧向移动动画
	WALK,       # 行走动画
}

# 运动插值速度 - 控制移动的平滑度
const MOTION_INTERPOLATE_SPEED: float = 10.0
# 旋转插值速度 - 控制角色旋转的平滑度
const ROTATION_INTERPOLATE_SPEED: float = 10.0
# 最小空中时间 - 用于判断是否在空中
const MIN_AIRBORNE_TIME: float = 0.1
# 跳跃速度 - 控制跳跃的高度
const JUMP_SPEED: float = 5.0

# 角色状态变量
var airborne_time: float = 100.0  # 记录玩家在空中的时间
var orientation := Transform3D()  # 角色方向变换，用于控制角色朝向
var root_motion := Transform3D()  # 根运动变换，从动画中提取的运动数据
var motion := Vector2()           # 移动向量，存储玩家的移动方向
var current_animation := Animations.WALK  # 当前动画状态

# 初始位置 - 用于玩家重生
@onready var initial_position: Vector3 = transform.origin

# 节点引用
@onready var player_input: PlayerInputController = $InputSynchronizer  # 玩家输入控制器
@onready var animation_tree: AnimationTree = $AnimationTree            # 动画树控制器
@onready var player_model: Node3D = $PlayerModel                       # 玩家3D模型
@onready var shoot_from: Marker3D = player_model.get_node(^"Robot_Skeleton/Skeleton3D/GunBone/ShootFrom")  # 射击起点
@onready var fire_cooldown: Timer = $FireCooldown                      # 射击冷却计时器

# 音效节点组
@onready var sound_effects: Node = $SoundEffects
@onready var sound_effect_jump: AudioStreamPlayer = sound_effects.get_node(^"Jump")
@onready var sound_effect_land: AudioStreamPlayer = sound_effects.get_node(^"Land")
@onready var sound_effect_shoot: AudioStreamPlayer = sound_effects.get_node(^"Shoot")

# 节点准备完成时调用
func _ready() -> void:
	# 初始化方向变换为玩家模型的全局变换，只保留旋转信息
	orientation = player_model.global_transform
	orientation.origin = Vector3()

# 物理处理函数 - 每帧调用
func _physics_process(delta: float) -> void:
	apply_input(delta)      # 处理输入和动画逻辑
	animate(current_animation, delta)  # 更新动画状态

# 动画控制函数
# 根据传入的动画状态切换动画树参数
func animate(anim: int, _delta: float) -> void:
	current_animation = anim as Animations
	
	match anim:
		Animations.JUMP_UP:
			animation_tree["parameters/state/transition_request"] = "jump_up"
			
		Animations.JUMP_DOWN:
			animation_tree["parameters/state/transition_request"] = "jump_down"
			
		Animations.STRAFE:
			animation_tree["parameters/state/transition_request"] = "strafe"
			animation_tree["parameters/aim/add_amount"] = player_input.get_aim_rotation()
			animation_tree["parameters/strafe/blend_position"] = Vector2(motion.x, -motion.y)
			
		Animations.WALK:
			animation_tree["parameters/aim/add_amount"] = 0
			animation_tree["parameters/state/transition_request"] = "walk"
			animation_tree["parameters/walk/blend_position"] = Vector2(motion.length(), 0)

# 应用输入处理函数
# 处理玩家的移动、跳跃、射击等输入
func apply_input(delta: float) -> void:
	# 平滑插值移动向量
	motion = motion.lerp(player_input.motion, MOTION_INTERPOLATE_SPEED * delta)
	
	# 更新空中状态
	update_airborne_state(delta)
	
	# 处理跳跃输入
	handle_jump_input()
	
	# 根据状态选择动画和旋转逻辑
	if is_airborne():
		handle_airborne_animation()
	elif player_input.aiming:
		handle_aiming_state(delta)
	else:
		handle_walking_state(delta)
	
	# 应用物理运动和根运动
	apply_physics_motion(delta)
	
	# 坠落检测和重生
	handle_fall_reset()

# 更新空中状态
func update_airborne_state(delta: float) -> void:
	airborne_time += delta
	if is_on_floor():
		if airborne_time > 0.5:
			land()
		airborne_time = 0

# 判断是否在空中
func is_airborne() -> bool:
	return airborne_time > MIN_AIRBORNE_TIME

# 处理跳跃输入
func handle_jump_input() -> void:
	if not is_airborne() and player_input.jumping:
		velocity.y = JUMP_SPEED
		airborne_time = MIN_AIRBORNE_TIME
		jump()
	player_input.jumping = false

# 处理空中动画
func handle_airborne_animation() -> void:
	if velocity.y > 0:
		animate(Animations.JUMP_UP, 0.0)
	else:
		animate(Animations.JUMP_DOWN, 0.0)

# 处理瞄准状态
func handle_aiming_state(delta: float) -> void:
	var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
	var q_to: Quaternion
	
	# 键盘控制模式下使用鼠标方向，鼠标控制模式下使用相机方向
	if player_input.camera_mode == player_input.CameraMode.KEYBOARD_CONTROL:
		var corrected_rotation: float = player_input.mouse_aim_target_rotation + PI
		var mouse_direction: Vector3 = Vector3(sin(corrected_rotation), 0, cos(corrected_rotation))
		q_to = Basis.looking_at(mouse_direction, Vector3.UP).get_rotation_quaternion()
		orientation.basis = Basis(q_from.slerp(q_to, delta * player_input.MOUSE_AIM_ROTATION_SPEED))
	else:
		q_to = player_input.get_camera_base_quaternion()
		orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))
	
	animate(Animations.STRAFE, delta)
	update_root_motion()
	
	# 处理射击逻辑
	if player_input.shooting and fire_cooldown.time_left == 0 and shoot_from:
		handle_shooting()

# 处理行走状态
func handle_walking_state(delta: float) -> void:
	# 获取相机方向向量
	var camera_basis: Basis = player_input.get_camera_rotation_basis()
	var camera_x: Vector3 = camera_basis.x
	var camera_z: Vector3 = camera_basis.z
	
	# 标准化相机方向向量（忽略Y轴）
	camera_x.y = 0
	camera_x = camera_x.normalized()
	camera_z.y = 0
	camera_z = camera_z.normalized()
	
	# 计算移动方向
	var target: Vector3 = camera_x * motion.x + camera_z * motion.y
	if target.length() > 0.001:
		var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion = Basis.looking_at(target).get_rotation_quaternion()
		orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))
	
	animate(Animations.WALK, delta)
	update_root_motion()

# 更新根运动数据
func update_root_motion() -> void:
	root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())

# 应用物理运动
func apply_physics_motion(delta: float) -> void:
	# 应用根运动到方向变换
	orientation *= root_motion
	
	# 计算水平速度并应用重力
	var h_velocity: Vector3 = orientation.origin / delta
	velocity.x = h_velocity.x
	velocity.z = h_velocity.z
	velocity += get_gravity() * delta
	
	# 移动角色
	set_velocity(velocity)
	set_up_direction(Vector3.UP)
	move_and_slide()
	
	# 重置根运动位移并应用旋转到玩家模型
	orientation.origin = Vector3()
	orientation = orientation.orthonormalized()
	player_model.global_transform.basis = orientation.basis

# 处理射击逻辑
func handle_shooting() -> void:
	var shoot_origin: Vector3 = shoot_from.global_transform.origin
	var shoot_dir: Vector3 = (player_input.shoot_target - shoot_origin).normalized()
	
	# 创建子弹实例
	var bullet: CharacterBody3D = preload("res://player/bullet/bullet.tscn").instantiate()
	get_parent().add_child(bullet, true)
	bullet.global_transform.origin = shoot_origin
	bullet.look_at(shoot_origin + shoot_dir)
	bullet.add_collision_exception_with(self)
	
	shoot()

# 处理坠落重置
func handle_fall_reset() -> void:
	if transform.origin.y < -40.0:
		transform.origin = initial_position

# 跳跃函数 - 播放跳跃动画和音效
func jump() -> void:
	animate(Animations.JUMP_UP, 0.0)
	if sound_effect_jump:
		sound_effect_jump.play()

# 落地函数 - 播放落地动画和音效
func land() -> void:
	animate(Animations.JUMP_DOWN, 0.0)
	if sound_effect_land:
		sound_effect_land.play()

# 射击函数 - 播放射击效果和音效
func shoot() -> void:
	# 播放粒子效果
	var shoot_particle = $PlayerModel/Robot_Skeleton/Skeleton3D/GunBone/ShootFrom/ShootParticle
	var muzzle_particle = $PlayerModel/Robot_Skeleton/Skeleton3D/GunBone/ShootFrom/MuzzleFlash
	
	if shoot_particle:
		shoot_particle.restart()
		shoot_particle.emitting = true
	if muzzle_particle:
		muzzle_particle.restart()
		muzzle_particle.emitting = true
	
	# 开始冷却并播放音效
	if fire_cooldown:
		fire_cooldown.start()
	if sound_effect_shoot:
		sound_effect_shoot.play()
	
	# 添加相机震动
	add_camera_shake_trauma(0.35)

# 被击中函数 - 处理玩家被击中时的效果
func hit() -> void:
	add_camera_shake_trauma(0.75)

# 添加相机震动函数 - 控制相机震动效果
func add_camera_shake_trauma(amount: float) -> void:
	if player_input and player_input.camera_camera:
		player_input.camera_camera.add_trauma(amount)
