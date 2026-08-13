class_name InAirState
extends State

func enter() -> void:
	# 告诉 AnimationTree 接入 AirState 混合节点
	player.animation_controller.travel_to_anim("AirState")

func physics_update(delta: float) -> void:
	# 1. 重力应用（根据上升/下落选择对应重力，手感更扎实）
	var current_gravity = player.rise_gravity if player.velocity.y > 0 else player.fall_gravity
	player.velocity.y -= current_gravity * delta

	# --- 状态转移判定 ---
	
	# 条件 1：踩到地面 -> 切换到落地缓冲 Land
	if player.is_grounded and player.velocity.y <= 0:
		state_machine.transition_to("land")
		return

	# --- 空中水平移动控制 ---
	var target_x = player.move_direction.x * player.air_move_speed
	var target_z = player.move_direction.z * player.air_move_speed

	if player.input_dir.length() > 0:
		player.velocity.x = lerp(player.velocity.x, target_x, player.acceleration * delta)
		player.velocity.z = lerp(player.velocity.z, target_z, player.acceleration * delta)
	else:
		player.velocity.x = lerp(player.velocity.x, 0.0, player.friction * delta)
		player.velocity.z = lerp(player.velocity.z, 0.0, player.friction * delta)

	player.move_and_slide()
