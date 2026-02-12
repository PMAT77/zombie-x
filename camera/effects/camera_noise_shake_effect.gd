extends Camera3D

# 相机噪声震动效果
# 使用OpenSimplex噪声生成自然的相机震动效果

# 效果常量值
const SPEED: float = 1.0                    # 震动速度系数
const DECAY_RATE: float = 1.5               # 震动衰减速率
const MAX_YAW: float = 0.05                 # 最大偏航角（左右旋转）
const MAX_PITCH: float = 0.05               # 最大俯仰角（上下旋转）
const MAX_ROLL: float = 0.1                 # 最大滚转角（倾斜旋转）
const MAX_TRAUMA: float = 1.2               # 最大创伤值（震动强度上限）

# 默认值
var start_rotation: Vector3 = rotation      # 初始旋转角度（震动基准）
var trauma: float = 0.0                     # 当前创伤值（震动强度）
var time: float = 0.0                       # 时间累积（用于噪声采样）
var noise := FastNoiseLite.new()            # 噪声生成器
var noise_seed: int = randi()               # 噪声种子（确保每次运行效果不同）


func _ready() -> void:
	# 初始化噪声生成器
	noise.seed = noise_seed
	noise.fractal_octaves = 1                 # 分形八度（控制噪声复杂度）
	noise.fractal_lacunarity = 1.0            # 分形间隙（控制频率变化）

	# 保存初始旋转角度作为震动基准
	# 注意：当其他脚本改变相机位置时（如缩放或聚焦），此变量会被重置
	# 在相机震动过程中不应重置此变量
	start_rotation = rotation


func _process(delta: float) -> void:
	# 只在有创伤值时处理震动效果
	if trauma > 0.0:
		decay_trauma(delta)     # 衰减创伤值
		apply_shake(delta)      # 应用震动效果


# 添加创伤值以开始/继续震动
func add_trauma(amount: float) -> void:
	# 增加创伤值，但不超过最大值
	trauma = minf(trauma + amount, MAX_TRAUMA)


# 随时间衰减创伤效果
func decay_trauma(delta: float) -> void:
	# 计算衰减量并确保创伤值不小于0
	var change: float = DECAY_RATE * delta
	trauma = maxf(trauma - change, 0.0)


# 根据时间增量应用随机震动
func apply_shake(delta: float) -> void:
	# 使用魔法数5000.0在SPEED为1.0时获得令人愉悦的效果
	time += delta * SPEED * 5000.0
	
	# 计算震动强度（使用创伤值的平方以获得非线性衰减）
	var shake: float = trauma * trauma
	
	# 为每个旋转轴生成不同的噪声值
	var yaw: float = MAX_YAW * shake * get_noise_value(noise_seed, time)      # 偏航轴（Y轴）
	var pitch: float = MAX_PITCH * shake * get_noise_value(noise_seed + 1, time)  # 俯仰轴（X轴）
	var roll: float = MAX_ROLL * shake * get_noise_value(noise_seed + 2, time)    # 滚转轴（Z轴）
	
	# 应用震动到相机旋转
	rotation = start_rotation + Vector3(pitch, yaw, roll)


# 使用OpenSimplex噪声返回范围在(-1, 1)内的随机浮点数
func get_noise_value(seed_value: int, pos: float) -> float:
	# 设置噪声种子并获取一维噪声值
	noise.seed = seed_value
	return noise.get_noise_1d(pos)
