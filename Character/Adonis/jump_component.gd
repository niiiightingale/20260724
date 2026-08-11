# JumpComponent.gd
# 悬崖情境跳跃组件：适配 AnimationTree 1D 混合空间 (JumpAirState) 与 状态机 (jump_air_state)
extends Node
class_name JumpComponent

# ----------------------------------------------------
# 信号声明
# ----------------------------------------------------
signal jump_started
signal jump_finished

# ----------------------------------------------------
# 检查器 Export 配置
# ----------------------------------------------------
@export_group("宿主与节点绑定")
@export var character: CharacterBody3D     # 宿主角色 (Player)
@export var anim_player: AnimationPlayer  # 用于读取单次动画剪辑的时长 (get_animation().length)

@export_group("输入与判定配置")
@export var jump_action_name: StringName = &"jump"
@export var max_align_angle_deg: float = 15.0  # 触发允许的最大角度偏差 (度)
@export var align_duration: float = 0.12        # 平滑转向对齐的时长 (秒)

@export_group("State 状态机名称 (全小写)")
@export var state_prepare: String = "jump_prepare"     # 1. 原地屈膝蓄力状态
@export var state_jump_air: String = "jump_air_state"  # 2. 空中贝塞尔曲线运动状态
@export var state_land: String = "land"          # 3. 落地缓冲状态

@export_group("AnimationTree 混合空间路径")
# 对应 AnimationTree 内部 1D BlendSpace 的混合点参数路径
@export var blend_param_path: String = "parameters/JumpAirState/blend_position"

# ----------------------------------------------------
# 运行时变量
# ----------------------------------------------------
var current_ledge: JumpLedge3D = null
var is_jumping: bool = false


func _ready() -> void:
	if character == null and get_parent() is CharacterBody3D:
		character = get_parent() as CharacterBody3D
		
	if anim_player == null and character != null:
		anim_player = character.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _unhandled_input(event: InputEvent) -> void:
	if is_jumping or current_ledge == null:
		return

	if event.is_action_pressed(jump_action_name):
		# 1. 优先校验玩家面向角度是否正对着要跳的断崖 (15度阈值)
		if not _is_facing_ledge_target():
			print("【JumpComponent】角度未对齐，拒绝跳跃")
			return

		get_viewport().set_input_as_handled()
		execute_jump()


func set_current_ledge(ledge: JumpLedge3D) -> void:
	current_ledge = ledge
	print("【JumpComponent】进入悬崖跳跃区：", ledge.name)

func clear_current_ledge(ledge: JumpLedge3D) -> void:
	if current_ledge == ledge:
		current_ledge = null
		print("【JumpComponent】离开悬崖跳跃区")


# ----------------------------------------------------
# 核心：角度对齐校验
# ----------------------------------------------------
func _is_facing_ledge_target() -> bool:
	if character == null or current_ledge == null:
		return false

	var start_pos: Vector3 = character.global_position
	var points: Array[Vector3] = current_ledge.get_jump_points(start_pos)
	var end_pos: Vector3 = points[2]

	var target_dir: Vector3 = (end_pos - start_pos)
	target_dir.y = 0.0
	
	if target_dir.length_squared() < 0.001:
		return true
		
	target_dir = target_dir.normalized()

	# 获取实际旋转的目标网格 ($Adonis / visual_mesh) 真正的正前方
	var rot_target: Node3D = _get_target_mesh()
	var current_forward: Vector3 = -rot_target.global_transform.basis.z
	current_forward.y = 0.0
	current_forward = current_forward.normalized()

	var angle_rad: float = current_forward.angle_to(target_dir)
	var angle_deg: float = rad_to_deg(angle_rad)

	return absf(angle_deg) <= max_align_angle_deg


# ----------------------------------------------------
# JumpComponent.gd

func execute_jump() -> void:
	# 1. 基础安全校验
	if current_ledge == null or is_jumping or character == null:
		return

	# 2. 提前缓存悬崖参数 (防止 await 期间 current_ledge 被 Area3D 设为 null)
	var ledge: JumpLedge3D = current_ledge
	var duration: float = ledge.jump_duration
	
	var start_pos: Vector3 = character.global_position
	var points: Array[Vector3] = ledge.get_jump_points(start_pos)
	var p0: Vector3 = points[0] # 起点
	var p1: Vector3 = points[1] # 拱顶 (最高点)
	var p2: Vector3 = points[2] # 终点 (对面平台)

	is_jumping = true
	jump_started.emit()

	# 3. 阶段 0：平滑对齐朝向 (面向 P2)
	var jump_dir: Vector3 = (p2 - p0)
	jump_dir.y = 0.0
	if jump_dir.length_squared() > 0.001:
		await _smooth_rotate_to_direction(jump_dir.normalized())

	# 4. 阶段 1：切换到 jump_prepare 屈膝蓄力，原地等待动作做完
	_switch_state(state_prepare)
	await _wait_anim_duration(state_prepare)

	# 5. 阶段 2：离地起飞，切入 jump_air_state 状态
	_switch_state(state_jump_air)

	# 6. 【核心改进】：使用单一连贯的 Tween，匀速 t 从 0.0 跑到 1.0
	var tween: Tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	tween.tween_method(
		func(t: float):
			# A. 二次贝塞尔曲线天然带来：水平匀速前进 + 垂直自然重力减速与加速！
			character.global_position = _quadratic_bezier(p0, p1, p2, t)
			
			# B. 实时更新 1D 混合空间的 blend_position (-1.0 全Rise -> 0.0 顶点 -> 1.0 全Fall)
			var blend_position: float = remap(t, 0.0, 1.0, -1.0, 1.0)
			_update_jump_air_blend(blend_position),
		0.0, 
		1.0, 
		duration
	)

	# 等待抛物线运动一气呵成完成
	await tween.finished

	# 7. 阶段 3：落地交接给 land_state
	is_jumping = false # 解除输入拦截
	_switch_state(state_land)
	
	jump_finished.emit()


# ----------------------------------------------------
# 辅助函数：驱动 AnimationTree 设置 blend_position
# ----------------------------------------------------
func _update_jump_air_blend(value: float) -> void:
	if character and character.get("anim_tree") != null:
		var anim_tree: AnimationTree = character.get("anim_tree") as AnimationTree
		if anim_tree:
			anim_tree.set(blend_param_path, clampf(value, -1.0, 1.0))


# 辅助函数：自动寻找 Player 身上的网格旋转节点 ($Adonis / visual_mesh)
func _get_target_mesh() -> Node3D:
	if character != null and character.get("visual_mesh") != null:
		var mesh_node: Node3D = character.get("visual_mesh") as Node3D
		if mesh_node:
			return mesh_node
	return character


# 辅助函数：平滑旋转转向目标向量
func _smooth_rotate_to_direction(target_dir: Vector3) -> void:
	var rot_target: Node3D = _get_target_mesh()
	if rot_target == null:
		return

	var target_basis: Basis = Transform3D().looking_at(target_dir, Vector3.UP).basis
	
	if rot_target.global_transform.basis.z.dot(-target_dir) > 0.999:
		rot_target.global_transform.basis = target_basis
		return

	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var start_basis: Basis = rot_target.global_transform.basis
	
	tween.tween_method(
		func(weight: float):
			rot_target.global_transform.basis = start_basis.slerp(target_basis, weight),
		0.0,
		1.0,
		align_duration
	)
	await tween.finished


# 辅助函数：切换状态机
func _switch_state(state_name: String) -> void:
	if character and character.get("state_machine") != null:
		character.state_machine.transition_to(state_name)


# 辅助函数：读取单次动画剪辑的时长
func _wait_anim_duration(anim_name: StringName) -> void:
	var length: float = 0.2
	if anim_player and anim_player.has_animation(anim_name):
		length = anim_player.get_animation(anim_name).length
		
	if length > 0.0:
		await get_tree().create_timer(length).timeout


# 二次贝塞尔曲线计算公式
func _quadratic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var q0: Vector3 = p0.lerp(p1, t)
	var q1: Vector3 = p1.lerp(p2, t)
	return q0.lerp(q1, t)
