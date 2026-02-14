class_name WorldUICircleProgress
extends Node3D

# 世界空间UI环形进度条控制器
# 用于在3D空间中显示换弹进度

@onready var sub_viewport_container: SubViewportContainer = $SubViewportContainer
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var circle_progress: CircleProgress = $SubViewportContainer/SubViewport/CircleProgress

# 进度条大小（世界单位）
@export var size: float = 0.5
# 相对于父节点的偏移量
@export var offset: Vector3 = Vector3(0, 0, 0)

func _ready() -> void:
	# 设置子视口大小
	sub_viewport_container.size = Vector2(50, 50)
	sub_viewport.size = Vector2i(50, 50)
	
	# 设置进度条大小
	circle_progress.set_size(Vector2(size, size))

func show_progress(duration: float) -> void:
	circle_progress.show_progress(duration)

func hide_progress() -> void:
	circle_progress.hide_progress()

func set_progress(value: float) -> void:
	circle_progress.set_progress(value)

# 设置相对于父节点的位置
func set_world_position(world_pos: Vector3) -> void:
	global_position = world_pos + offset

# 始终面向相机
func _process(_delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	if camera:
		look_at(camera.global_position, Vector3.UP)
