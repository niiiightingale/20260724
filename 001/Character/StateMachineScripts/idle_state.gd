# idle_state.gd
# 静止状态：瞬时锁定物理水平速度、调度 Idle 动画、维持垂直重力结算并监听寻路与离地事件
extends State
class_name IdleState


## 进入静止状态：开启重力、彻底锁定水平物理速度为零并调度 Idle 动画
func enter() -> void:
	if player != null:
		player.set_gravity_enabled(true)
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.move_direction = Vector3.ZERO
		if player.animation_controller != null:
			player.animation_controller.travel_to_anim(&"Idle")


## 物理帧更新：监听寻路触发与离地事件，执行垂直重力物理结算
func physics_update(_delta: float) -> void:
	if player == null or player.nav_agent == null:
		return

	# 2. 寻路目标检测：若存在未完成的寻路路径，切入 WalkState
	if not player.nav_agent.is_navigation_finished():
		state_machine.transition_to(&"walk_state")
		return

	# 3. 持续锁定水平速度为 0，防止静止期产生微小物理滑步
	player.velocity.x = 0.0
	player.velocity.z = 0.0

	# 4. 调用物理引擎结算垂直重力
	player.move_and_slide()
