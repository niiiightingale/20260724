# climb_ladder_state.gd
# 状态机：纯数学区间 + 登顶/下梯动画独立拆分 + 骨骼落点碰撞追赶归位 (无RootMotion天坑)
class_name ClimbLadderState
extends State

@export_group("攀爬参数设置")
@export var climb_speed: float = 2.5        # 攀爬匀速升降速度 (米/秒)
@export var hips_bone_name: String = "hips" # 角色重心骨骼名字 (用于抓取视觉绝对落点)

@export_group("触发高度偏移")
@export var climb_top_trigger_offset: float = 0.2 # 向上爬到 (Y_top - offset) 触发登顶翻越

@export_group("动画配置")
@export var prepare_anim: String = "climb_ladder_prepare"      # 底端进入时播放一次的准备姿态
@export var step_anim: String = "climb_ladder"              # 攀爬循环动画 (按住W/S播放，松开冻结)
@export var finish_anim: String = "climb_ladder_finish"        # 正向登顶翻越动画
@export var down_prepare_anim: String = "climb_ladder_downprepare" # ✨【新增】高台向下进入梯子的下挂动画

var climb_comp: ClimbComponent = null
var active_ladder: Ladder3D = null 
var is_transiting: bool = false # 是否正在播放登顶/下梯过渡动画


func enter() -> void:
	climb_comp = player.find_child("ClimbComponent", true, false) as ClimbComponent
	
	if player == null or climb_comp == null or climb_comp.current_ladder == null:
		state_machine.transition_to("grounded_state")
		return

	active_ladder = climb_comp.current_ladder
	player.velocity = Vector3.ZERO
	is_transiting = false

	# 分流处理：顶端下梯 vs 底端上梯
	if climb_comp.is_top_entry:
		_perform_top_enter()
	else:
		_perform_bottom_enter()


func exit() -> void:
	_set_anim_speed(1.0)
	active_ladder = null
	is_transiting = false


func physics_update(delta: float) -> void:
	if active_ladder == null:
		state_machine.transition_to("grounded_state")
		return

	# 过渡动画播放期间禁用 WASD 响应
	if is_transiting:
		return

	# A. 按 interact 键主动脱离梯子
	if Input.is_action_just_pressed("interact"):
		state_machine.transition_to("grounded_state")
		return

	# B. 获取 W / S 输入
	var climb_input: float = Input.get_axis("move_backward", "move_forward")

# C. ----------------------------------------------------
	# 玩家按下 W / S 键：确保切入 step_anim，解冻速度，匀速推坐标
	# ----------------------------------------------------
	if absf(climb_input) > 0.1:
		var climb_dir: float = signf(climb_input)

		# ✨ 1. 只有当前动画不是 step_anim 时才触发播放，避免每帧重复重置！
		if _get_current_anim_name() != step_anim:
			_play_anim(step_anim)

		# ✨ 2. 有输入时，恢复播放速度为 1.0
		_set_anim_speed(1.0)

		if climb_dir > 0.0:
			# ==================== 向上爬 (W) ====================
			var top_trigger_y: float = active_ladder.get_top_y() - climb_top_trigger_offset
			if player.global_position.y >= top_trigger_y:
				print("【ClimbState】达到登顶触发高度，开始登顶翻越！")
				_perform_finish()
				return

			player.global_position.y += climb_speed * delta

		else:
			# ==================== 向下爬 (S) ====================
			if player.global_position.y <= (active_ladder.get_bottom_y() + 0.1):
				state_machine.transition_to("grounded_state")
				return

			player.global_position.y -= climb_speed * delta

	# D. ----------------------------------------------------
	# ✨ 松开 WASD 按键：保持在 step_anim，仅将 speed_scale 设为 0 定格当前帧！
	# ----------------------------------------------------
	else:
		player.velocity = Vector3.ZERO
		# ✨ 无输入时，直接冻结动画速度为 0，不再切任何姿态，也不触发 play()
		_set_anim_speed(0.0)


# ----------------------------------------------------
# 1. 底端地面进入梯子
# ----------------------------------------------------
func _perform_bottom_enter() -> void:
	await climb_comp.smooth_align_to_ladder(active_ladder, false)
	_set_anim_speed(1.0)
	_play_anim(prepare_anim)


# ----------------------------------------------------
# ✨ 2. 顶端高台进入梯子：播放 climb_ladder_downprepare 动画并追赶归位
# ----------------------------------------------------
func _perform_top_enter() -> void:
	is_transiting = true
	player.velocity = Vector3.ZERO

	# 1. 自动对齐到高台入口边缘
	await climb_comp.smooth_align_to_ladder(active_ladder, true)

	# 2. 正向播放下挂动画 climb_ladder_downprepare
	_set_anim_speed(1.0)
	_play_anim(down_prepare_anim)

	# 3. 提前 0.05 秒等待下挂动画结束
	var anim_duration: float = _get_anim_length(down_prepare_anim)
	var wait_time: float = maxf(0.05, anim_duration - 0.05)
	await get_tree().create_timer(wait_time).timeout

	# 4. ✨抓取角色 hips 骨骼在下挂结束时的真实世界坐标，把 CharacterBody3D 追赶追过去！
	var final_landing_position: Vector3 = _get_visual_bone_global_position()
	player.global_position = final_landing_position

	# 5. 清重置 Flag，直接接轨 step_anim 攀爬姿态并定格在第 0 帧
	climb_comp.is_top_entry = false
	is_transiting = false

	_play_anim(step_anim)
	_set_anim_speed(0.0)


# ----------------------------------------------------
# 3. 向上登顶翻越大高台 (播放 climb_ladder_finish)
# ----------------------------------------------------
func _perform_finish() -> void:
	is_transiting = true
	player.velocity = Vector3.ZERO

	_set_anim_speed(1.0)
	_play_anim(finish_anim)

	var anim_duration: float = _get_anim_length(finish_anim)

	# 提前 0.05 秒等待登顶动画结束
	var wait_time: float = maxf(0.05, anim_duration - 0.05)
	await get_tree().create_timer(wait_time).timeout

	# ✨抓取登顶翻越结束时 hips 骨骼在高台上的真实坐标并归位
	var final_landing_position: Vector3 = _get_visual_bone_global_position()
	player.global_position = final_landing_position

	is_transiting = false
	# 切回平地自由移动
	state_machine.transition_to("grounded_state")


# ----------------------------------------------------
# 辅助工具函数
# ----------------------------------------------------
func _get_visual_bone_global_position() -> Vector3:
	var skeleton: Skeleton3D = player.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		var bone_idx: int = skeleton.find_bone(hips_bone_name)
		if bone_idx != -1:
			var bone_global_transform: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)
			return bone_global_transform.origin

	var forward_dir: Vector3 = -player.global_transform.basis.z
	return player.global_position + Vector3(0, 0.5, 0) + (forward_dir * 0.3)


func _get_anim_length(anim_name: String) -> float:
	if player and player.get("animation_player") != null:
		var ap: AnimationPlayer = player.animation_player as AnimationPlayer
		if ap and ap.has_animation(anim_name):
			return ap.get_animation(anim_name).length
	return 0.8


func _set_anim_speed(spd: float) -> void:
	if player and player.get("animation_player") != null:
		var ap: AnimationPlayer = player.animation_player as AnimationPlayer
		if ap:
			ap.speed_scale = spd


func _play_anim(anim_name: String) -> void:
	if anim_name != "" and player != null and player.has_method("travel_to_anim"):
		player.travel_to_anim(anim_name)

# 获取当前正在播放的动画名称 (兼容 AnimationPlayer 与 AnimationTree)
func _get_current_anim_name() -> String:
	if player == null:
		return ""
	
	# 1. 优先从 AnimationPlayer 获取
	if player.get("animation_player") != null:
		var ap: AnimationPlayer = player.animation_player as AnimationPlayer
		if ap and ap.is_playing():
			return ap.current_animation
			
	# 2. 从 AnimationTree 状态机获取 (若使用 AnimationTree)
	if player.get("anim_tree") != null:
		var at: AnimationTree = player.anim_tree as AnimationTree
		if at:
			var playback = at.get("parameters/playback")
			if playback:
				return playback.get_current_node()

	return ""
