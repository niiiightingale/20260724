# walk_state.gd
# 寻路移动状态：追踪航点朝向、消费 Root Motion 水平位移，并在到达终点时流转至 StopState 进入过渡期
extends State
class_name WalkState

@export_group("移动与转向参数")
@export var waypoint_reach_threshold: float = 0.2 ## 中间航点死区保护距离，防止原地打转


## 进入移动状态：开启重力并通过 travel_to_anim 调度 Walk 动画
func enter() -> void:
	if player != null:
		player.set_gravity_enabled(true)
		if player.animation_controller != null:
			player.animation_controller.travel_to_anim(&"Walk")


## 退出移动状态：清空移动方向记录
func exit() -> void:
	if player != null:
		player.move_direction = Vector3.ZERO


## 物理帧更新：计算终点距离拦截、解算航点朝向、消费水平 Root Motion
func physics_update(delta: float) -> void:
	if player == null or player.animation_controller == null or player.nav_agent == null:
		return

	# 1. 离地状态切出检查
	if not player.is_grounded and state_machine.states.has(&"air_state"):
		state_machine.transition_to(&"air_state")
		return

	# 2. 计算与最终目标的水平投影剩余距离 (忽略 Y 轴高度差)
	var final_target: Vector3 = player.nav_agent.target_position
	var to_final_vec: Vector3 = final_target - player.global_position
	to_final_vec.y = 0.0
	var remaining_dist: float = to_final_vec.length()

	# 3. 终点到达拦截：到达容差范围或寻路标记完成时，切入 StopState 进行动作平滑过渡
	if remaining_dist <= player.nav_agent.target_desired_distance or player.nav_agent.is_navigation_finished():
		if state_machine.states.has(&"stop_state"):
			state_machine.transition_to(&"stop_state")
		else:
			state_machine.transition_to(&"idle_state")
		return

	# 4. 提取下一个中间航点并计算水平移动朝向 (死区保护防原地抖动)
	var next_path_pos: Vector3 = player.nav_agent.get_next_path_position()
	var dir_to_next: Vector3 = next_path_pos - player.global_position
	dir_to_next.y = 0.0

	if dir_to_next.length_squared() > waypoint_reach_threshold * waypoint_reach_threshold:
		player.move_direction = dir_to_next.normalized()
		player.rotate_towards_move_direction(delta)

	# 5. 提取当前帧 Root Motion 局部位移并转译为全局速度
	var root_delta_pos: Vector3 = player.animation_controller.get_root_motion_delta_position()
	var global_move_delta: Vector3 = player.global_transform.basis * -root_delta_pos
	var target_velocity: Vector3 = global_move_delta / delta

	# 6. 仅更新 X/Z 水平速度，垂直 Y 轴完全留由集中重力管控
	player.velocity.x = target_velocity.x
	player.velocity.z = target_velocity.z

	# 7. 物理引擎碰撞驱动
	player.move_and_slide()
