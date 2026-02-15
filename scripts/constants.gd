# 游戏常量配置文件
# 集中管理所有游戏中的硬编码数值
# 注意：此脚本已配置为自动加载单例，通过 GameConstants 直接访问

extends Node

# ==================== 玩家移动参数 ====================
const MOTION_INTERPOLATE_SPEED: float = 10.0
const ROTATION_INTERPOLATE_SPEED: float = 10.0
const MIN_AIRBORNE_TIME: float = 0.1
const JUMP_SPEED: float = 5.0

# ==================== 相机控制参数 ====================
const CAMERA_CONTROLLER_ROTATION_SPEED: float = 3.0
const CAMERA_MOUSE_ROTATION_SPEED: float = 0.001
const KEYBOARD_ROTATION_ANGLE: float = 90.0
const KEYBOARD_ROTATION_SMOOTH_SPEED: float = 0.5
const KEYBOARD_ROTATION_COOLDOWN_TIME: float = 0.05

const CAMERA_X_ROT_CONSTRAINT: float = 20.0
const CAMERA_X_ROT_MIN: float = -89.9
const CAMERA_X_ROT_MAX: float = 70.0

const CAMERA_DISTANCE_MIN: float = 1.0
const CAMERA_DISTANCE_MAX: float = 16.0
const CAMERA_DISTANCE_STEP: float = 0.4
const CAMERA_DISTANCE_SMOOTH_SPEED: float = 4.0

const CAMERA_HEIGHT_MIN: float = 1.6
const CAMERA_HEIGHT_MAX: float = 4.0
const CAMERA_HEIGHT_SMOOTH_SPEED: float = 4.0

const AUTO_MODE_SWITCH_THRESHOLD_CLOSE: float = 3.0
const AUTO_MODE_SWITCH_THRESHOLD_FAR: float = 5.0
const AUTO_MODE_SWITCH_COOLDOWN: float = 0.5

const MOUSE_AIM_ROTATION_SPEED: float = 5.0
const AIM_HOLD_THRESHOLD: float = 0.4

const DEFAULT_CAMERA_DISTANCE: float = 2.4

# ==================== 子弹参数 ====================
const BULLET_VELOCITY: float = 20.0
const BULLET_MAX_LIFETIME: float = 5.0
const BULLET_RAYCAST_DISTANCE: float = 1000.0

# ==================== 玩家属性默认值 ====================
const DEFAULT_MAX_HEALTH: float = 100.0
const DEFAULT_HEALTH_REGEN: float = 0.0
const DEFAULT_ATTACK_POWER: float = 10.0
const DEFAULT_ATTACK_SPEED: float = 0.01
const DEFAULT_CRITICAL_CHANCE: float = 0.05
const DEFAULT_CRITICAL_DAMAGE: float = 1.5
const DEFAULT_DEFENSE: float = 0.0
const DEFAULT_DAMAGE_REDUCTION: float = 0.0
const DEFAULT_MOVEMENT_SPEED: float = 1.0
const DEFAULT_JUMP_HEIGHT: float = 1.0
const DEFAULT_STARTING_LEVEL: int = 1
const DEFAULT_STARTING_EXP: float = 0.0
const DEFAULT_EXP_BASE: float = 100.0
const DEFAULT_MAX_AMMO: int = 30
const DEFAULT_RELOAD_TIME: float = 1.0
const DEFAULT_AMMO_REGEN_TIME: float = 2.0

# ==================== 游戏世界参数 ====================
const FALL_RESET_HEIGHT: float = -40.0
const FALL_EFFECT_HEIGHT: float = -17.0
const FALL_FADE_SPEED: float = 4.0

# ==================== UI参数 ====================
const UI_FADE_DURATION: float = 0.3
const CROSSHAIR_SHOOT_TRAUMA: float = 0.35
const RELOAD_TRAUMA: float = 0.15
const HIT_TRAUMA: float = 0.75

# ==================== 碰撞层定义 ====================
enum CollisionLayers {
	LAYER_WORLD = 1,
	LAYER_PLAYER = 2,
	LAYER_ENEMY = 4,
	LAYER_BULLET = 8,
	LAYER_INTERACTABLE = 16,
	LAYER_PICKUP = 32
}

# ==================== 游戏状态枚举 ====================
enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER
}

func _ready() -> void:
	print("[GameConstants] 常量配置已加载")

# ==================== 工具函数 ====================
static func deg_to_rad(degrees: float) -> float:
	return degrees * PI / 180.0

static func rad_to_deg(radians: float) -> float:
	return radians * 180.0 / PI

static func ease_out_cubic(t: float) -> float:
	var t2: float = t - 1.0
	return t2 * t2 * t2 + 1.0
