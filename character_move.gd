extends CharacterBody3D

@export_group("移动设置")
@export var speed: float = 5.0
@export var rotation_speed: float = 10.0

# 确保这里的节点路径与你场景树的实际层级完全一致
@onready var animation_player: AnimationPlayer = $Anemone/AnimationPlayer

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 获取二维输入 (-1 到 1 之间)
	# 注意：W键(forward)对应的是 y = -1，S键(backward)对应的是 y = 1
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# 初始化移动方向向量
	var move_direction := Vector3.ZERO
	
	if input_dir != Vector2.ZERO:
		# ========== 核心：基于摄像机视角的移动 ==========
		# 1. 获取当前场景中的主摄像机
		var camera := get_viewport().get_camera_3d()
		
		if camera:
			# 2. 获取摄像机在 XZ 平面上的“前”和“右”向量，并归一化
			var cam_forward := -camera.global_transform.basis.z
			var cam_right := camera.global_transform.basis.x
			
			cam_forward.y = 0
			cam_right.y = 0
			cam_forward = cam_forward.normalized()
			cam_right = cam_right.normalized()
			
			# 3. 将玩家的输入（input_dir）映射到摄像机的方向上
			# 因为 W 键（前进）的 input_dir.y 是负数，所以用减法把它转正并乘以前方向量
			move_direction = (cam_right * input_dir.x - cam_forward * input_dir.y).normalized()
		else:
			# 如果场景里没有摄像机（防错），退回到世界坐标移动
			move_direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	if move_direction != Vector3.ZERO:
		# 速度计算：方向 * 标量速度
		velocity.x = move_direction.x * speed
		velocity.z = move_direction.z * speed
		
		# ========== 核心：修正模型正面向着 +Z 轴的问题 ==========
		# Godot 默认是 atan2(-x, -z) 代表面向 -Z。
		# 既然你的模型正面朝着 +Z，我们把公式里 x 和 z 前面的负号去掉！
		# 这样计算出的角度就是以 +Z 为前方的。
		var target_angle := atan2(move_direction.x, move_direction.z)
		
		# 平滑旋转角色
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
		
		# 播放你目前的 walk 动画
		if animation_player.current_animation != "run":
			animation_player.play("run")
	else:
		# 无输入时平滑减速至 0
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
		# 如果你有 idle (待机) 动画，这里可以改成 animation_player.play("idle")
		if animation_player.is_playing() and animation_player.current_animation == "run":
			animation_player.play("idle")

	move_and_slide()
