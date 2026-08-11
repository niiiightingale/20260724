class_name GroundedState
extends State

func enter() -> void:
	player.travel_to_anim("MoveBlend")

func physics_update(delta: float) -> void:
	# 1. 应用重力
	player.velocity.y -= player.fall_gravity * delta
	# 条件 1：走出悬崖（不再接地） -> 切入空中状态 Air
	if not player.is_grounded:
		state_machine.transition_to("air_state")
		return
		
	# 判读按了 interact 键 && ClimbComponent 允许攀爬
	if Input.is_action_just_pressed("interact"):
		var climb_comp = player.find_child("ClimbComponent", true, false) as ClimbComponent
		if climb_comp and climb_comp.can_start_climb():
			# 自主发起切转场！
			state_machine.transition_to("climb_ladder_state")
			return

	
	# --- 惯性物理计算 (统一处理 Idle / Walk / Run 的平滑过渡) ---
	var target_velocity_x = player.move_direction.x * player.run_speed
	var target_velocity_z = player.move_direction.z * player.run_speed

	# 玩家有方向输入 -> 按照 acceleration 逼近目标速度
	if player.input_dir.length() > 0:
		player.velocity.x = lerp(player.velocity.x, target_velocity_x, player.acceleration * delta)
		player.velocity.z = lerp(player.velocity.z, target_velocity_z, player.acceleration * delta)
		player.rotate_towards_move_direction(delta)
	# 玩家无输入 -> 按照 friction 阻尼自然滑行减速到 0（实现静止 Idle）
	else:
		player.velocity.x = lerp(player.velocity.x, 0.0, player.friction * delta)
		player.velocity.z = lerp(player.velocity.z, 0.0, player.friction * delta)

	player.move_and_slide()
