class_name RiseState
extends State


@export var anim_name: String = "rise"

func enter() -> void:
	if player.anim_player:
		# 使用 0.1 秒淡入，保证从前摇或跑动过度过来时姿态平滑
		player.anim_player.play(anim_name, 0.1)

func physics_update(delta: float) -> void:
	# 1. 模拟重力减速
	player.velocity.y -= player.rise_gravity * delta

	# 2. 空中水平移动控制
	if player.input_dir.length() > 0:
		var direction = Vector3(player.input_dir.x, 0, player.input_dir.y).normalized()
		player.velocity.x = direction.x * player.air_move_speed
		player.velocity.z = direction.z * player.air_move_speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, 2.0)
		player.velocity.z = move_toward(player.velocity.z, 0, 2.0)

	player.move_and_slide()

	# --- 转移判定 ---
	# A. 空中按滑翔 -> 滑翔
	if player.glide_just_pressed:
		state_machine.transition_to("glide")
		return

	# B. 垂直速度降至 0 或小于 0（到达最高点）-> 下落
	if player.vertical_velocity <= 0:
		state_machine.transition_to("fall")
