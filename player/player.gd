# 玩家角色主脚本
# 负责处理玩家的移动、动画、射击等核心功能

class_name Player
extends CharacterBody3D

# 玩家动画状态枚举
# 定义玩家可能的各种动画状态
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

# 空中时间计数器 - 记录玩家在空中的时间
var airborne_time: float = 100.0

# 角色方向变换 - 用于控制角色朝向
var orientation := Transform3D()
# 根运动变换 - 从动画中提取的运动数据
var root_motion := Transform3D()
# 移动向量 - 存储玩家的移动方向
var motion := Vector2()

# 初始位置 - 用于玩家重生
@onready var initial_position: Vector3 = transform.origin

# 玩家输入同步器 - 处理多玩家输入同步
@onready var player_input: PlayerInputController = $InputSynchronizer  # 玩家输入控制器动画树 - 控制角色动画状态机
@onready var animation_tree: AnimationTree = $AnimationTree
# 玩家模型 - 3D角色模型节点
@onready var player_model: Node3D = $PlayerModel
# 射击起点 - 子弹发射位置标记
@onready var shoot_from: Marker3D = player_model.get_node(^"Robot_Skeleton/Skeleton3D/GunBone/ShootFrom")
# 准星 - UI准星显示
@onready var crosshair: TextureRect = $Crosshair
# 射击冷却计时器 - 控制射击间隔
@onready var fire_cooldown: Timer = $FireCooldown

# 音效节点组 - 包含所有音效播放器
@onready var sound_effects: Node = $SoundEffects
# 跳跃音效播放器
@onready var sound_effect_jump: AudioStreamPlayer = sound_effects.get_node(^"Jump")
# 落地音效播放器
@onready var sound_effect_land: AudioStreamPlayer = sound_effects.get_node(^"Land")
# 射击音效播放器
@onready var sound_effect_shoot: AudioStreamPlayer = sound_effects.get_node(^"Shoot")

# 玩家ID - 用于识别（已移除多人游戏功能）
@export var player_id: int = 1

# 当前动画状态 - 记录玩家当前的动画
@export var current_animation := Animations.WALK


# 节点准备完成时调用
func _ready() -> void:
	# 初始化方向变换为玩家模型的全局变换
	orientation = player_model.global_transform
	# 清除位置信息，只保留旋转
	orientation.origin = Vector3()


# 物理处理函数 - 每帧调用
func _physics_process(delta: float) -> void:
	# 处理输入逻辑和动画
	apply_input(delta)
	animate(current_animation, delta)


# 动画控制函数
# 根据传入的动画状态切换动画树参数
func animate(anim: int, _delta: float) -> void:
	# 更新当前动画状态
	current_animation = anim as Animations

	# 根据动画状态设置不同的动画参数
	if anim == Animations.JUMP_UP:
		# 切换到跳跃上升动画
		animation_tree["parameters/state/transition_request"] = "jump_up"

	elif anim == Animations.JUMP_DOWN:
		# 切换到跳跃下降动画
		animation_tree["parameters/state/transition_request"] = "jump_down"

	elif anim == Animations.STRAFE:
		# 切换到侧向移动动画
		animation_tree["parameters/state/transition_request"] = "strafe"
		# 设置瞄准角度（根据相机旋转）
		animation_tree["parameters/aim/add_amount"] = player_input.get_aim_rotation()
		# 设置侧向移动混合位置（前后轴反转）
		animation_tree["parameters/strafe/blend_position"] = Vector2(motion.x, -motion.y)

	elif anim == Animations.WALK:
		# 行走时不瞄准
		animation_tree["parameters/aim/add_amount"] = 0
		# 切换到行走动画
		animation_tree["parameters/state/transition_request"] = "walk"
		# 根据移动速度设置行走混合位置
		animation_tree["parameters/walk/blend_position"] = Vector2(motion.length(), 0)


# 应用输入处理函数
# 处理玩家的移动、跳跃、射击等输入
func apply_input(delta: float) -> void:
	# 平滑插值移动向量
	motion = motion.lerp(player_input.motion, MOTION_INTERPOLATE_SPEED * delta)

	# 获取相机旋转的基础向量
	var camera_basis: Basis = player_input.get_camera_rotation_basis()
	var camera_z: Vector3 = camera_basis.z
	var camera_x: Vector3 = camera_basis.x

	# 标准化相机方向向量（忽略Y轴）
	camera_z.y = 0
	camera_z = camera_z.normalized()
	camera_x.y = 0
	camera_x = camera_x.normalized()

	# 更新空中时间
	airborne_time += delta
	# 如果在地面上
	if is_on_floor():
		# 如果刚从空中落地，播放落地音效
		if airborne_time > 0.5:
			land()
		# 重置空中时间
		airborne_time = 0

	# 判断是否在空中
	var on_air: bool = airborne_time > MIN_AIRBORNE_TIME

	# 跳跃逻辑
	if not on_air and player_input.jumping:
		# 设置跳跃速度
		velocity.y = JUMP_SPEED
		on_air = true
		# 设置最小空中时间确保下一帧仍在空中状态
		airborne_time = MIN_AIRBORNE_TIME
		# 远程调用跳跃函数
		jump()

	# 重置跳跃标志
	player_input.jumping = false

	# 根据状态选择动画
	if on_air:
		# 在空中时根据速度方向选择跳跃动画
		if velocity.y > 0:
			animate(Animations.JUMP_UP, delta)
		else:
			animate(Animations.JUMP_DOWN, delta)
	elif player_input.aiming:
		# 瞄准状态下的旋转插值
		var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion
		
		# 键盘控制模式下瞄准时，使用鼠标方向旋转人物
		if player_input.camera_mode == player_input.CameraMode.KEYBOARD_CONTROL:
			# 使用鼠标瞄准方向（从人物朝向鼠标位置）
			# 如果方向相反，添加180度偏移
			var corrected_rotation: float = player_input.mouse_aim_target_rotation + PI
			var mouse_direction: Vector3 = Vector3(sin(corrected_rotation), 0, cos(corrected_rotation))
			q_to = Basis.looking_at(mouse_direction, Vector3.UP).get_rotation_quaternion()
			# 使用专门的鼠标瞄准旋转速度
			orientation.basis = Basis(q_from.slerp(q_to, delta * player_input.MOUSE_AIM_ROTATION_SPEED))
		else:
			# 鼠标控制模式下，使用相机方向
			q_to = player_input.get_camera_base_quaternion()
			# 使用默认的旋转插值速度
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

		# 播放侧向移动动画
		animate(Animations.STRAFE, delta)

		# 获取根运动数据
		root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())

		# 射击逻辑
		if player_input.shooting and fire_cooldown.time_left == 0 and shoot_from:
			# 计算射击起点
			var shoot_origin: Vector3 = shoot_from.global_transform.origin
			var shoot_dir: Vector3

			# 两种模式下子弹都朝向鼠标方向
			shoot_dir = (player_input.shoot_target - shoot_origin).normalized()

			# 创建子弹实例
			var bullet: CharacterBody3D = preload("res://player/bullet/bullet.tscn").instantiate()
			get_parent().add_child(bullet, true)
			# 设置子弹位置和方向
			bullet.global_transform.origin = shoot_origin
			bullet.look_at(shoot_origin + shoot_dir)
			# 避免子弹与玩家碰撞
			bullet.add_collision_exception_with(self)
			# 调用射击函数
			shoot()

	else:
		# 行走状态下的旋转逻辑
		var target: Vector3 = camera_x * motion.x + camera_z * motion.y
		if target.length() > 0.001:
			# 计算朝向目标的旋转
			var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
			var q_to: Quaternion = Basis.looking_at(target).get_rotation_quaternion()
			# 平滑插值旋转
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

		# 播放行走动画
		animate(Animations.WALK, delta)

		# 获取根运动数据
		root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())

	# 应用根运动到方向变换
	orientation *= root_motion

	# 计算水平速度
	var h_velocity: Vector3 = orientation.origin / delta
	velocity.x = h_velocity.x
	velocity.z = h_velocity.z
	# 应用重力
	velocity += get_gravity() * delta
	# 设置速度和移动
	set_velocity(velocity)
	set_up_direction(Vector3.UP)
	move_and_slide()

	# 重置根运动位移
	orientation.origin = Vector3()
	# 正交标准化方向变换
	orientation = orientation.orthonormalized()

	# 应用旋转到玩家模型
	player_model.global_transform.basis = orientation.basis

	# 坠落检测和重生
	if transform.origin.y < -40.0:
		transform.origin = initial_position


# 跳跃函数
# 播放跳跃动画和音效
func jump() -> void:
	animate(Animations.JUMP_UP, 0.0)
	if sound_effect_jump:
		sound_effect_jump.play()


# 落地函数
# 播放落地动画和音效
func land() -> void:
	animate(Animations.JUMP_DOWN, 0.0)
	if sound_effect_land:
		sound_effect_land.play()


# 射击函数
# 播放射击效果和音效
func shoot() -> void:
	# 播放射击粒子效果
	var shoot_particle = $PlayerModel/Robot_Skeleton/Skeleton3D/GunBone/ShootFrom/ShootParticle
	if shoot_particle:
		shoot_particle.restart()
		shoot_particle.emitting = true
	# 播放枪口闪光效果
	var muzzle_particle = $PlayerModel/Robot_Skeleton/Skeleton3D/GunBone/ShootFrom/MuzzleFlash
	if muzzle_particle:
		muzzle_particle.restart()
		muzzle_particle.emitting = true
	# 开始射击冷却
	if fire_cooldown:
		fire_cooldown.start()
	# 播放射击音效
	if sound_effect_shoot:
		sound_effect_shoot.play()
	# 添加相机震动
	add_camera_shake_trauma(0.35)


# 被击中函数
# 处理玩家被击中时的效果
func hit() -> void:
	add_camera_shake_trauma(0.75)


# 添加相机震动函数
# 控制相机震动效果
func add_camera_shake_trauma(amount: float) -> void:
	if player_input and player_input.camera_camera:
		player_input.camera_camera.add_trauma(amount)
