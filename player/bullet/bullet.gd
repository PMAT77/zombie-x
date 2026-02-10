# 子弹脚本
# 处理子弹的移动、碰撞检测和爆炸效果

class_name Bullet
extends CharacterBody3D

# 子弹飞行速度
const BULLET_VELOCITY: float = 20.0

# 子弹存活时间 - 避免子弹无限飞行
var time_alive: float = 5.0
# 是否已经击中目标
var hit: bool = false

# 动画播放器 - 控制爆炸动画
@onready var animation_player: AnimationPlayer = $AnimationPlayer
# 碰撞形状 - 子弹的碰撞检测区域
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
# 点光源 - 子弹的光照效果
@onready var omni_light: OmniLight3D = $OmniLight3D


# 节点准备完成时调用
func _ready() -> void:
	# 如果不是服务器，禁用物理处理和碰撞检测
	if not multiplayer.is_server():
		set_physics_process(false)
		collision_shape.disabled = true


# 物理处理函数 - 每帧调用
func _physics_process(delta: float) -> void:
	# 如果已经击中目标，直接返回
	if hit:
		return
	
	# 更新子弹存活时间
	time_alive -= delta
	# 如果子弹存活时间结束，触发爆炸
	if time_alive < 0.0:
		hit = true
		explode.rpc()
	
	# 计算子弹位移（沿Z轴负方向移动）
	var displacement: Vector3 = -delta * BULLET_VELOCITY * transform.basis.z
	# 移动并检测碰撞
	var col: KinematicCollision3D = move_and_collide(displacement)
	
	# 如果发生碰撞
	if col:
		# 获取碰撞对象
		var collider: Node3D = col.get_collider() as Node3D
		# 如果碰撞对象有hit方法，调用它（例如击中敌人）
		if collider and collider.has_method(&"hit"):
			collider.hit.rpc()
		
		# 禁用碰撞检测，避免重复碰撞
		collision_shape.disabled = true
		# 远程调用爆炸函数
		explode.rpc()
		# 标记为已击中
		hit = true


# 远程调用函数 - 爆炸
# 在所有客户端同步播放爆炸效果
@rpc("call_local")
func explode() -> void:
	# 播放爆炸动画
	animation_player.play(&"explode")

	# 仅在启用阴影映射时为爆炸启用阴影
	# 移动中的子弹光源很小，不需要阴影映射
	# if Settings.config_file.get_value("rendering", "shadow_mapping"):
	# 	omni_light.shadow_enabled = true


# 销毁函数
# 服务器端销毁子弹对象
func destroy() -> void:
	if not multiplayer.is_server():
		return
	# 从场景中移除子弹
	queue_free()
