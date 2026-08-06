class_name IdleState
extends State

func enter() -> void:
	if player.anim_player:
		player.anim_player.play("idle")

func physics_update(_delta: float) -> void:
	# 物理减速
	player.velocity.x = move_toward(player.velocity.x, 0, 10.0)
	player.velocity.z = move_toward(player.velocity.z, 0, 10.0)
	player.move_and_slide()
	
	# --- 条件转移判断 (读取 Player 数据) ---
	
	# 1. 未接地且按了滑翔 -> 滑翔
	if not player.is_grounded and player.glide_just_pressed:
		state_machine.transition_to("glide")
		return

	# 2. 如果按了跳跃键 -> 起跳预备 (JumpPrepare)
	if player.is_grounded and player.jump_just_pressed:
		state_machine.transition_to("jumpprepare")
		return
	
	# 3. 如果有方向输入 -> 跑动
	if player.input_dir.length() > 0:
		state_machine.transition_to("run")
