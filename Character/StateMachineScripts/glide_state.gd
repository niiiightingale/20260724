class_name GlideState
extends State

var current_tilt_x: float = 0.0
var current_tilt_z: float = 0.0

func enter() -> void:
	player.travel_to_anim("glide")
	if player.glider_mesh:
		player.glider_mesh.visible = true

func exit() -> void:
	if player.glider_mesh:
		player.glider_mesh.visible = false
	
	# 退出滑翔时重置姿态
	if player.visual_mesh:
		player.visual_mesh.rotation_degrees.x = 0.0
		player.visual_mesh.rotation_degrees.z = 0.0

func physics_update(delta: float) -> void:
	# 1. 重力与缓降
	player.velocity.y -= player.glide_gravity * delta
	player.velocity.y = max(player.velocity.y, player.max_glide_fall_speed)

	# 2. 独立使用 glide_rotation_speed 进行慢速转向
	_update_glide_rotation(delta)

	# 3. 气动牵引移动
	_update_glide_velocity(delta)

	player.move_and_slide()

	# 4. 纠正后的倾斜摆动
	_apply_parachute_tilt(delta)

	# --- 状态转移判定 ---
	if player.is_grounded:
		state_machine.transition_to("land")
		return

	if player.glide_just_pressed:
		state_machine.transition_to("air_state")

# 伞面慢速转向
func _update_glide_rotation(delta: float) -> void:
	if player.input_dir.length() > 0.1 and player.visual_mesh:
		var target_rotation = Transform3D().looking_at(player.move_direction, Vector3.UP).basis
		# 显式使用 player.glide_rotation_speed
		player.visual_mesh.global_transform.basis = player.visual_mesh.global_transform.basis.slerp(
			target_rotation, 
			player.glide_rotation_speed * delta
		)

# 基于伞朝向的气动加速度推进
func _update_glide_velocity(delta: float) -> void:
	var forward_dir: Vector3 = -player.visual_mesh.global_transform.basis.z
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()

	if player.input_dir.length() > 0:
		var target_x = forward_dir.x * player.glide_speed
		var target_z = forward_dir.z * player.glide_speed
		
		player.velocity.x = lerp(player.velocity.x, target_x, player.glide_acceleration * delta)
		player.velocity.z = lerp(player.velocity.z, target_z, player.glide_acceleration * delta)
	else:
		player.velocity.x = lerp(player.velocity.x, 0.0, player.glide_friction * delta)
		player.velocity.z = lerp(player.velocity.z, 0.0, player.glide_friction * delta)

# 修正方向后的降落伞摆动
func _apply_parachute_tilt(delta: float) -> void:
	if not player.visual_mesh:
		return

	# W 键时 input_dir.y 为 -1，取正号后 target_tilt_x 为 +20°（身子向后仰）
	# S 键时 input_dir.y 为 +1，取正号后 target_tilt_x 为 -20°（身子向前倾）
	var target_tilt_x = player.input_dir.y * player.glide_tilt_angle
	var target_tilt_z = -player.input_dir.x * player.glide_tilt_angle

	current_tilt_x = lerp(current_tilt_x, target_tilt_x, 4.0 * delta)
	current_tilt_z = lerp(current_tilt_z, target_tilt_z, 4.0 * delta)

	player.visual_mesh.rotation_degrees.x = current_tilt_x
	player.visual_mesh.rotation_degrees.z = current_tilt_z
