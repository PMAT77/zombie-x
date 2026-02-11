# 玩家属性系统测试脚本
# 演示如何使用玩家属性系统

class_name PlayerStatsTest
extends Node

# 测试函数
func test_player_stats() -> void:
	print("=== 玩家属性系统测试 ===")
	
	# 创建玩家属性实例
	var stats: PlayerStats = PlayerStats.new()
	
	# 测试1：初始状态
	print("\n测试1：初始状态")
	print("最大生命值: %.1f" % stats.max_health)
	print("当前生命值: %.1f" % stats.current_health)
	print("等级: %d" % stats.level)
	print("当前经验: %.1f" % stats.current_exp)
	print("弹药: %d / %d" % [stats.current_ammo, stats.max_ammo])
	
	# 测试2：受到伤害
	print("\n测试2：受到伤害")
	stats.take_damage(20.0)
	print("受到20点伤害后生命值: %.1f" % stats.current_health)
	print("生命值百分比: %.1f%%" % (stats.get_health_percentage() * 100))
	
	# 测试3：治疗
	print("\n测试3：治疗")
	stats.heal(15.0)
	print("治疗15点后生命值: %.1f" % stats.current_health)
	
	# 测试4：获得经验
	print("\n测试4：获得经验")
	stats.gain_exp(50.0)
	print("获得50点经验后当前经验: %.1f" % stats.current_exp)
	print("经验百分比: %.1f%%" % (stats.get_exp_percentage() * 100))
	
	# 测试5：升级
	print("\n测试5：升级")
	stats.gain_exp(60.0)
	print("获得60点经验后等级: %d" % stats.level)
	print("升级后生命值: %.1f" % stats.current_health)
	
	# 测试6：消耗弹药
	print("\n测试6：消耗弹药")
	for i in range(5):
		if stats.consume_ammo():
			print("消耗弹药 %d，剩余: %d" % [i + 1, stats.current_ammo])
	
	# 测试7：补充弹药
	print("\n测试7：补充弹药")
	stats.refill_ammo()
	print("补充弹药后: %d / %d" % [stats.current_ammo, stats.max_ammo])
	
	# 测试8：无敌状态
	print("\n测试8：无敌状态")
	stats.set_invincible(2.0)
	print("设置无敌状态: %s" % stats.is_invincible)
	stats.take_damage(50.0)
	print("无敌状态下受到50点伤害后生命值: %.1f" % stats.current_health)
	
	# 测试9：死亡
	print("\n测试9：死亡")
	stats.take_damage(200.0)
	print("受到200点伤害后生命值: %.1f" % stats.current_health)
	print("是否死亡: %s" % stats.is_dead)
	
	# 测试10：复活
	print("\n测试10：复活")
	stats.revive()
	print("复活后生命值: %.1f" % stats.current_health)
	print("复活后是否死亡: %s" % stats.is_dead)
	
	# 测试11：重置
	print("\n测试11：重置")
	stats.level = 5
	stats.current_exp = 50.0
	stats.current_health = 50.0
	stats.current_ammo = 10
	print("重置前 - 等级: %d, 经验: %.1f, 生命: %.1f, 弹药: %d" % [stats.level, stats.current_exp, stats.current_health, stats.current_ammo])
	stats.reset()
	print("重置后 - 等级: %d, 经验: %.1f, 生命: %.1f, 弹药: %d" % [stats.level, stats.current_exp, stats.current_health, stats.current_ammo])
	
	print("\n=== 测试完成 ===")

# 节点准备完成时调用
func _ready() -> void:
	test_player_stats()
