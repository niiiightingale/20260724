class_name State
extends Node

# 存储对角色和状态机的引用，方便子类直接调用
var player: CharacterBody3D
var state_machine: StateMachine

# 进入状态时触发（用于播放动画、重置物理参数等）
func enter() -> void:
	pass

# 退出状态时触发（用于清理临时标记、恢复参数等）
func exit() -> void:
	pass

# 处理输入事件
func handle_input(_event: InputEvent) -> void:
	pass

# 帧更新（非物理逻辑）
func update(_delta: float) -> void:
	pass

# 物理帧更新（移动、重力、碰撞检测等）
func physics_update(_delta: float) -> void:
	pass
