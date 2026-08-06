class_name GlideState
extends State


func enter() -> void:
	player.anim_player.play("glide")
	pass

func exit() -> void:
	# 收起滑翔伞模型
	pass

func physics_update(delta: float) -> void:
	# 1. 滑翔物理计算（低重力 + 限制最大下落速度）
	player.velocity.y -= player.glide_gravity * delta
	player.velocity.y = max(player.velocity.y, player.max_glide_fall_speed)

	# 2. 空中移动控制
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	if direction:
		player.velocity.x = direction.x * player.glide_speed
		player.velocity.z = direction.z * player.glide_speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.glide_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, player.glide_speed)

	player.move_and_slide()

	# 3. 条件转移：如果接触地面 -> 依据输入切回 Idle 或 Run
	if player.is_on_floor():
		if input_dir.length() > 0:
			state_machine.transition_to("run")
		else:
			state_machine.transition_to("idle")
