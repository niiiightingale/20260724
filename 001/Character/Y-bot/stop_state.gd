# stop_state.gd
# 停步过渡状态：在 AnimationTree 触发向 Idle 交叉淡入期间持续提取衰减的 Root Motion，过渡完成后平稳流转至 IdleState
extends State
class_name StopState

@export_group("过渡参数")
@export var stop_duration: float = 0.25 ## 停步过渡窗口时长 (秒)，需对齐 AnimationTree 中 Walk->Idle 的 Xfade Time

# 记录当前已过渡的时长
var elapsed_time: float = 0.0


## 进入停步状态：开启重力、触发向待机动作的 Xfade 淡入并重置过渡计时器
func enter() -> void:
	elapsed_time = 0.0
	if player != null:
		player.set_gravity_enabled(true)
		player.move_direction = Vector3.ZERO
		if player.animation_controller != null:
			player.animation_controller.travel_to_anim(&"Idle")


## 物理帧更新：消费淡出期的 Root Motion 位移、处理移动打断，并在时间到达后切入 IdleState
func physics_update(delta: float) -> void:
	if player == null or player.animation_controller == null or player.nav_agent == null:
		return


	# 2. 玩家重新点击地面时立即打断停步，切回 WalkState
	if not player.nav_agent.is_navigation_finished():
		state_machine.transition_to(&"walk_state")
		return

	# 3. 累计过渡时间，时间耗尽代表动作已完全淡入 Idle，流转至纯静止待机
	elapsed_time += delta
	if elapsed_time >= stop_duration:
		state_machine.transition_to(&"idle_state")
		return

	# 4. 提取交叉淡入期间正在衰减的 Root Motion 局部位移增量
	var root_delta_pos: Vector3 = player.animation_controller.get_root_motion_delta_position()
	var global_move_delta: Vector3 = player.global_transform.basis * -root_delta_pos
	var target_velocity: Vector3 = global_move_delta / delta

	# 5. 更新水平速度 (保持原有惯性与步幅平滑收拢，不改变朝向)
	player.velocity.x = target_velocity.x
	player.velocity.z = target_velocity.z

	# 6. 物理引擎碰撞驱动
	player.move_and_slide()
