class_name RunState
extends State

@export var glide_action_name: String = "glide"

func enter() -> void:
	if player.anim_player:
		player.anim_player.play("run", 0.1)

func physics_update(delta: float) -> void:
	# 1. 应用重力（防止浮空）
	player.velocity.y -= player.fall_gravity * delta

	# --- 条件转移判断 ---

	# 条件 1：走出了平台边缘（不再接地） -> 自动切入下落状态 Fall
	if not player.is_grounded:
		state_machine.transition_to("fall")
		return

	# 条件 2：没有方向输入 -> 切回 Idle
	if player.input_dir.length() == 0:
		state_machine.transition_to("idle")
		return

	# 条件 3：跑动中按下跳跃键 -> 直接给予向上初速度，跳过前摇进入 Rise
	if player.jump_just_pressed:
		player.velocity.y = player.jump_velocity
		state_machine.transition_to("rise")
		return

	# --- 物理移动计算 ---
	# 直接使用 Player 脚本中基于摄像机投影算出的 3D 向量 move_direction
	player.velocity.x = player.move_direction.x * player.run_speed
	player.velocity.z = player.move_direction.z * player.run_speed

	player.move_and_slide()
