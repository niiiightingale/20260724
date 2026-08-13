# grounded_state.gd
# 地面状态：接管输入速度映射、TimeScale 播放速率驱动与 Root Motion 水平转译，重力交由 Player 集中解算
extends State
class_name GroundedState

@export_group("动画平滑参数")
@export var blend_acceleration: float = 10.0 ## 混合参数 (0.0~3.0) 切换平滑度

# 实时 BlendSpace 混合位置 (0.0: Idle, 1.0: Walk, 2.0: Run, 3.0: Fast Run)
var current_blend_speed: float = 0.0


## 进入地面状态
func enter() -> void:
	current_blend_speed = 0.0
	if player != null:
		# 确保物理重力解算处于开启状态
		player.set_gravity_enabled(true)
		if player.animation_controller != null:
			player.animation_controller.travel_to_anim(&"LocomotionTree")


## 物理帧更新：纯粹计算 X/Z 轴 Root Motion 速度，不覆盖 Y 轴物理
func physics_update(delta: float) -> void:
	if player == null or player.animation_controller == null:
		return

	# 1. 离地状态切出检查
	if not player.is_grounded and state_machine.states.has(&"air_state"):
		state_machine.transition_to(&"air_state")
		return

	# 2. 依据修饰按键与 input_dir 计算目标混合速度
	var target_blend: float = 0.0
	if player.input_dir != Vector2.ZERO:
		if Input.is_action_pressed("walk") or Input.is_key_pressed(KEY_CTRL):
			target_blend = 1.0 # Walk
		elif Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT):
			target_blend = 3.0 # Fast Run
		else:
			target_blend = 2.0 # Run
	else:
		target_blend = 0.0 # Standing Idle

	# 3. 注入全局播放速率 (TimeScale) 并驱动 AnimationTree 混合参数
	player.animation_controller.set_locomotion_time_scale(player.anim_speed_scale)
	
	current_blend_speed = move_toward(current_blend_speed, target_blend, blend_acceleration * delta)
	player.animation_controller.set_locomotion_blend(current_blend_speed)

	# 4. 旋转 Player 物理根节点朝向移动方向
	player.rotate_towards_move_direction(delta)

	# 5. 提取当前帧 Root Motion 局部位移增量
	var root_delta_pos: Vector3 = player.animation_controller.get_root_motion_delta_position()

	# 6. 将局部 Root Motion 增量转译至 Player 全局坐标系
	var global_move_delta: Vector3 = player.global_transform.basis * -root_delta_pos
	var target_velocity: Vector3 = global_move_delta / delta

	# 7. 纯粹更新 X 和 Z 水平速度，绝不修改 Y 轴 (垂直速度完全由 Player.gd 重力与 move_and_slide() 接管)
	player.velocity.x = target_velocity.x
	player.velocity.z = target_velocity.z

	# 8. 调用 Godot 内置物理碰撞驱动
	player.move_and_slide()
