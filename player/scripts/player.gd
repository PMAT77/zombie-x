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

# 角色状态变量
var airborne_time: float = 50.0  # 记录玩家在空中的时间
var orientation := Transform3D()  # 角色方向变换，用于控制角色朝向
var root_motion := Transform3D()  # 根运动变换，从动画中提取的运动数据
var motion := Vector2()           # 移动向量，存储玩家的移动方向
var current_animation := Animations.WALK  # 当前动画状态

# 玩家属性系统
var player_stats: PlayerStats = PlayerStats.new()

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
@onready var sound_effect_jump: AudioStreamPlayer = sound_effects.get_node_or_null(^"Jump")
@onready var sound_effect_land: AudioStreamPlayer = sound_effects.get_node_or_null(^"Land")
@onready var sound_effect_shoot: AudioStreamPlayer = sound_effects.get_node_or_null(^"Shoot")
@onready var sound_effect_reload: AudioStreamPlayer = sound_effects.get_node_or_null(^"Reload")
@onready var world_ui_circle_progress: WorldUICircleProgress = $PlayerModel/WorldUICircleProgress

# 节点准备完成时调用
func _ready() -> void:
	# 初始化方向变换为玩家模型的全局变换，只保留旋转信息
	orientation = player_model.global_transform
	orientation.origin = Vector3()
	
	# 连接属性系统信号
	player_stats.health_changed.connect(_on_health_changed)
	player_stats.death.connect(_on_death)
	player_stats.level_up.connect(_on_level_up)
	player_stats.exp_gained.connect(_on_exp_gained)
	player_stats.ammo_changed.connect(_on_ammo_changed)
	
	# 注册到游戏管理器
	if GameManager:
		GameManager.register_player(self)

# 物理处理函数 - 每帧调用
func _physics_process(delta: float) -> void:
	# 更新玩家属性系统
	player_stats.update(delta)
	
	# 检查玩家是否死亡
	if player_stats.is_dead:
		return
	
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
			# 在键盘控制模式下，移动方向相对于相机方向
			if player_input.camera_mode == player_input.CameraMode.KEYBOARD_CONTROL:
				animation_tree["parameters/strafe/blend_position"] = calculate_strafe_blend_position()
			else:
				animation_tree["parameters/strafe/blend_position"] = Vector2(motion.x, -motion.y)
			
		Animations.WALK:
			animation_tree["parameters/aim/add_amount"] = 0
			animation_tree["parameters/state/transition_request"] = "walk"
			animation_tree["parameters/walk/blend_position"] = Vector2(motion.length(), 0)

# 应用输入处理函数
# 处理玩家的移动、跳跃、射击等输入
func apply_input(delta: float) -> void:
	# 平滑插值移动向量
	motion = motion.lerp(player_input.motion, GameConstants.MOTION_INTERPOLATE_SPEED * delta) 
	
	# 更新空中状态
	update_airborne_state(delta)
	
	# 处理跳跃输入
	handle_jump_input()
	
	# 处理换弹输入
	handle_reload_input()
	
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
	return airborne_time > GameConstants.MIN_AIRBORNE_TIME

# 处理跳跃输入
func handle_jump_input() -> void:
	if not is_airborne() and player_input.jumping:
		velocity.y = GameConstants.JUMP_SPEED
		airborne_time = GameConstants.MIN_AIRBORNE_TIME
		jump()
	player_input.jumping = false

# 处理换弹输入
func handle_reload_input() -> void:
	if Input.is_action_just_pressed("reload"):
		reload()

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
		# 需要额外的PI修正来正确对齐人物朝向
		var corrected_rotation: float = player_input.mouse_aim_target_rotation + PI
		var mouse_direction: Vector3 = Vector3(sin(corrected_rotation), 0, cos(corrected_rotation))
		q_to = Basis.looking_at(mouse_direction, Vector3.UP).get_rotation_quaternion()
		orientation.basis = Basis(q_from.slerp(q_to, delta * GameConstants.MOUSE_AIM_ROTATION_SPEED))
	else:
		q_to = player_input.get_camera_base_quaternion()
		orientation.basis = Basis(q_from.slerp(q_to, delta * GameConstants.ROTATION_INTERPOLATE_SPEED))
	
	animate(Animations.STRAFE, delta)
	update_root_motion()
	
	# 处理射击逻辑
	if player_input.shooting and fire_cooldown.time_left == 0 and shoot_from:
		# 如果正在换弹，不允许射击
		if(is_reloading()):
			return

		if not player_stats.consume_ammo():  # 检查是否有弹药
			return
		handle_shooting()

# 计算移动方向
func calculate_move_direction() -> Vector3:
	# 获取相机方向向量
	var camera_vectors: Dictionary = player_input.get_normalized_camera_vectors()
	
	# 计算移动方向（始终相对于相机方向）
	return camera_vectors["x"] * motion.x + camera_vectors["z"] * motion.y

# 计算侧向移动混合位置（相对于相机方向）
func calculate_strafe_blend_position() -> Vector2:
	# 获取相机方向向量
	var camera_vectors: Dictionary = player_input.get_normalized_camera_vectors()
	
	# 获取角色当前朝向
	var character_forward: Vector3 = orientation.basis.z
	var character_right: Vector3 = orientation.basis.x
	
	# 计算移动方向（相对于相机方向）
	var move_direction: Vector3 = camera_vectors["x"] * motion.x + camera_vectors["z"] * motion.y
	
	# 将移动方向投影到角色的前后和左右方向
	var forward_component: float = move_direction.dot(character_forward)
	var right_component: float = move_direction.dot(character_right)
	
	# 返回混合位置（前后和左右分量）
	return Vector2(right_component, -forward_component)

# 处理行走状态
func handle_walking_state(delta: float) -> void:
	# 获取移动方向向量
	var move_direction: Vector3 = calculate_move_direction() 
	
	# 如果移动方向有效，旋转角色朝向移动方向
	if move_direction.length() > 0.001:
			var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
			var q_to: Quaternion = Basis.looking_at(move_direction).get_rotation_quaternion()
			orientation.basis = Basis(q_from.slerp(q_to, delta * GameConstants.ROTATION_INTERPOLATE_SPEED))
	
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
	if transform.origin.y < GameConstants.FALL_RESET_HEIGHT:
		transform.origin = initial_position

# 跳跃函数 - 播放跳跃动画和音效
func jump() -> void:
	animate(Animations.JUMP_UP, 0.0)
	if sound_effect_jump and sound_effect_jump.stream:
		sound_effect_jump.play()

# 落地函数 - 播放落地动画和音效
func land() -> void:
	animate(Animations.JUMP_DOWN, 0.0)
	if sound_effect_land and sound_effect_land.stream:
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
	
	# 触发动态准星射击效果
	player_input.trigger_crosshair_shoot()
	
	# 开始冷却并播放音效
	if fire_cooldown:
		fire_cooldown.start()
	if sound_effect_shoot and sound_effect_shoot.stream:
		sound_effect_shoot.play()
	
	# 发送射击事件
	if EventBus:
		EventBus.emit_player_shoot()
	
	# 添加相机震动
	add_camera_shake_trauma(GameConstants.CROSSHAIR_SHOOT_TRAUMA)

# 换弹函数 - 播放换弹效果和音效
func reload() -> void:
	if player_stats.current_ammo >= player_stats.max_ammo:
		return 
	 
	if is_reloading():
		return
	
	start_reload()
	if EventBus:
		EventBus.emit_player_reload_start()
	
	if world_ui_circle_progress:
		world_ui_circle_progress.show_progress(player_stats.reload_time)
	
	if sound_effect_reload and sound_effect_reload.stream:
		sound_effect_reload.play()
	
	add_camera_shake_trauma(GameConstants.RELOAD_TRAUMA)
	
	await get_tree().create_timer(player_stats.reload_time).timeout
	
	player_stats.refill_ammo()
	end_reload() 
	if EventBus:
		EventBus.emit_player_reload_complete()
	
	print("换弹完成，当前弹药: %d/%d" % [player_stats.current_ammo, player_stats.max_ammo])

# 开始换弹
func start_reload() -> void:
	player_input.reloading = true
	print("开始换弹")

# 结束换弹
func end_reload() -> void:
	player_input.reloading = false
	print("结束换弹")

# 检查是否正在换弹
func is_reloading() -> bool:
	return player_input.reloading

# 被击中函数 - 处理玩家被击中时的效果
func hit() -> void:
	add_camera_shake_trauma(GameConstants.HIT_TRAUMA)

# 添加相机震动函数 - 控制相机震动效果
func add_camera_shake_trauma(amount: float) -> void:
	if player_input and player_input.camera_camera:
		player_input.camera_camera.add_trauma(amount)

# 属性系统信号处理函数
# 生命值变化处理
func _on_health_changed(current_health: float, max_health: float) -> void:
	print("生命值变化: %.1f / %.1f" % [current_health, max_health])

# 死亡处理
func _on_death() -> void:
	print("玩家死亡")
	# 禁用输入
	set_physics_process(false)
	# 播放死亡动画（如果有的话）
	# 可以在这里添加死亡特效

# 升级处理
func _on_level_up(new_level: int) -> void:
	print("升级到等级: %d" % new_level)
	# 播放升级特效
	# 可以在这里添加升级奖励

# 获得经验处理
func _on_exp_gained(experience: float) -> void:
	print("获得经验: %.1f" % experience)
	# 可以在这里添加经验获得特效

# 弹药变化处理
func _on_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	print("弹药变化: %d / %d" % [current_ammo, max_ammo])

# 玩家属性系统接口函数
# 获得经验（从外部调用）
func gain_experience(amount: float) -> void:
	player_stats.gain_exp(amount)

# 受到伤害（从外部调用）
func take_damage(amount: float) -> void:
	player_stats.take_damage(amount)
	# 添加受伤特效
	hit()

# 治疗（从外部调用）
func heal(amount: float) -> void:
	player_stats.heal(amount)

# 复活（从外部调用）
func revive() -> void:
	player_stats.revive()
	set_physics_process(true)
	transform.origin = initial_position

# 设置无敌状态（从外部调用）
func set_invincible(duration: float) -> void:
	player_stats.set_invincible(duration)

# 补充弹药（从外部调用）
func refill_ammo() -> void:
	player_stats.refill_ammo()

# 获取属性系统（用于外部访问）
func get_stats() -> PlayerStats:
	return player_stats
