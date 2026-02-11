# 换弹功能测试脚本
# 测试换弹功能是否正常工作

class_name ReloadTest
extends Node

# 测试函数
func test_reload_functionality() -> void:
	print("=== 换弹功能测试 ===")
	
	# 创建玩家属性实例
	var stats: PlayerStats = PlayerStats.new()
	
	# 测试1：初始状态
	print("\n测试1：初始状态")
	print("当前弹药: %d / %d" % [stats.current_ammo, stats.max_ammo])
	
	# 测试2：消耗弹药
	print("\n测试2：消耗弹药")
	for i in range(5):
		if stats.consume_ammo():
			print("消耗弹药 %d，剩余: %d" % [i + 1, stats.current_ammo])
	
	# 测试3：换弹
	print("\n测试3：换弹")
	print("换弹前弹药: %d / %d" % [stats.current_ammo, stats.max_ammo])
	stats.refill_ammo()
	print("换弹后弹药: %d / %d" % [stats.current_ammo, stats.max_ammo])
	
	# 测试4：满弹药时换弹
	print("\n测试4：满弹药时换弹")
	print("当前弹药: %d / %d" % [stats.current_ammo, stats.max_ammo])
	stats.refill_ammo()
	print("换弹后弹药: %d / %d" % [stats.current_ammo, stats.max_ammo])
	
	# 测试5：射击时自动检查弹药
	print("\n测试5：射击时自动检查弹药")
	print("消耗弹药前: %d / %d" % [stats.current_ammo, stats.max_ammo])
	var can_shoot = stats.consume_ammo()
	print("能否射击: %s" % can_shoot)
	print("消耗弹药后: %d / %d" % [stats.current_ammo, stats.max_ammo])
	
	# 测试6：弹药耗尽时射击
	print("\n测试6：弹药耗尽时射击")
	# 消耗所有弹药
	while stats.consume_ammo():
		pass
	print("弹药耗尽后: %d / %d" % [stats.current_ammo, stats.max_ammo])
	can_shoot = stats.consume_ammo()
	print("能否射击: %s" % can_shoot)
	
	print("\n=== 测试完成 ===")

# 节点准备完成时调用
func _ready() -> void:
	test_reload_functionality()