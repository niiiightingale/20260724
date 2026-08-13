# animation_controller.gd
# 独立动画控制器：接管 AnimationTree 状态控制、事件驱动等待、TimeScale 速率调控与 Root Motion 增量提取
extends Node
class_name AnimationController

# 宿主 Player 引用 (由 Player._ready 显式注入)
var player: CharacterBody3D = null

# 节点缓存引用
var anim_tree: AnimationTree = null
var anim_player: AnimationPlayer = null
var anim_playback: AnimationNodeStateMachinePlayback = null


## 显式依赖注入（由 Player._ready 显式调用）
func init(target_player: CharacterBody3D) -> void:
	player = target_player
	
	# 从宿主强类型属性提取节点，严禁盲目 get_parent()
	if "anim_tree" in player and player.anim_tree != null:
		anim_tree = player.anim_tree as AnimationTree
		
	if "anim_player" in player and player.anim_player != null:
		anim_player = player.anim_player as AnimationPlayer

	if anim_tree != null:
		anim_tree.active = true
		anim_playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback


## 切换 AnimationTree 内部的 State Machine 节点 (例如从 Start 切到 LocomotionTree)
func travel_to_anim(anim_node_name: StringName) -> void:
	if anim_playback != null:
		anim_playback.travel(anim_node_name)


## ✨ 基于 AnimationTree 原生信号的事件驱动等待，绝对不死锁
func play_anim_and_wait(anim_node_name: StringName) -> void:
	travel_to_anim(anim_node_name)
	if anim_tree == null:
		return

	while true:
		var finished_anim: StringName = await anim_tree.animation_finished
		if finished_anim == anim_node_name:
			break


## ✨ 提取当前帧由 Root Motion 带来的局部位移矢量 (Delta)
func get_root_motion_delta_position() -> Vector3:
	if anim_tree != null and anim_tree.active:
		return anim_tree.get_root_motion_position()
	return Vector3.ZERO


## 设置 AnimationTree 的任意混合参数 (底层通用接口)
func set_anim_tree_param(param_path: StringName, value: Variant) -> void:
	if anim_tree != null:
		anim_tree.set(param_path, value)


## ✨ 驱动 LocomotionTree 内部 1D BlendSpace (0: Idle, 1: Walk, 2: Run, 3: Fast Run)
func set_locomotion_blend(blend_value: float) -> void:
	if anim_tree != null:
		anim_tree.set("parameters/LocomotionTree/Locomotion/blend_position", blend_value)


## ✨ 动态驱动 LocomotionTree 内部 TimeScale 节点播放速率
func set_locomotion_time_scale(scale_value: float) -> void:
	if anim_tree != null:
		anim_tree.set("parameters/LocomotionTree/TimeScale/scale", scale_value)


## 获取当前 AnimationTree 正在播放的状态节点名称
func get_current_anim() -> StringName:
	if anim_playback != null:
		return anim_playback.get_current_node()
	return &""


## 读取指定动画剪辑的时长
func get_anim_length(anim_name: StringName) -> float:
	if anim_player != null and anim_player.has_animation(anim_name):
		return anim_player.get_animation(anim_name).length
	return 0.8
