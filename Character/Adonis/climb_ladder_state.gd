# climb_ladder_state.gd
# 攀爬状态脚本：平滑吸附 -> Root Motion 驱动 Prepare 动画 -> climb_ladder_step 步进驱动
class_name ClimbLadderState
extends State

@export_group("攀爬参数设置")
@export var climb_speed: float = 2.5            # 攀爬匀速升降速度 (米/秒)

# 运行期缓存引用
var climb_comp: ClimbComponent = null
var anim_ctrl: AnimationController = null
var active_ladder: Ladder3D = null
var is_ready_to_climb: bool = false             # 标记准备动作是否完毕，能否响应上下爬动


func enter() -> void:
	is_ready_to_climb = false
	
	# 1. 依赖校验，严禁盲目搜寻节点
	if player != null:
		if "climb_component" in player:
			climb_comp = player.climb_component as ClimbComponent
		if "animation_controller" in player:
			anim_ctrl = player.animation_controller as AnimationController

	if player == null or climb_comp == null or anim_ctrl == null or climb_comp.current_ladder == null:
		state_machine.transition_to(&"grounded_state")
		return

	active_ladder = climb_comp.current_ladder
	
	# 2. 彻底挂起物理速度，不调用 move_and_slide()
	player.velocity = Vector3.ZERO

	# 3. 读取吸附入口类型 (底端 vs 顶端)，驱动 Player 根节点进行 Transform 平滑对齐
	var is_top: bool = climb_comp.is_top_entry
	await climb_comp.smooth_align_to_ladder(active_ladder, is_top)

	# 4. 精确事件驱动：根据顶端/底端入口类型，分流播放相应的准备动画，并在 physics_update 中应用 Root Motion
	if is_top:
		await anim_ctrl.play_anim_and_wait(&"climb_ladder_downprepare")
	else:
		await anim_ctrl.play_anim_and_wait(&"climb_ladder_prepare")

	# 5. 准备动画与 Root Motion 位移完成后，切换至 climb_ladder_step 步进状态，解锁输入控制
	anim_ctrl.travel_to_anim(&"climb_ladder")
	is_ready_to_climb = true


func exit() -> void:
	active_ladder = null
	climb_comp = null
	anim_ctrl = null
	is_ready_to_climb = false
	
	# 退出攀爬状态时恢复 1.0 倍速，避免反向或 0 倍速影响其他状态动画
	if player != null and player.animation_controller != null:
		player.animation_controller.set_anim_time_scale(1.0)


func physics_update(delta: float) -> void:
	if active_ladder == null or anim_ctrl == null:
		state_machine.transition_to(&"grounded_state")
		return

	# ----------------------------------------------------
	# A. 准备动作阶段：提取每帧 Root Motion 增量，驱动 Player 物理实体平滑平移
	# ----------------------------------------------------
	if not is_ready_to_climb:
		var root_delta: Vector3 = anim_ctrl.get_root_motion_delta_position()
		if root_delta.length_squared() > 0.0:
			var world_delta: Vector3 = player.global_transform.basis * root_delta
			player.global_position += world_delta
		return

	# 按 interact 键可主动脱离梯子，返回平地移动
	if Input.is_action_just_pressed(&"interact"):
		state_machine.transition_to(&"grounded_state")
		return

	# ----------------------------------------------------
	# B. 步进阶段：读取 W / S 输入，驱动 Step 动画正/反向播放与 Y 轴匀速升降
	# ----------------------------------------------------
	var climb_input: float = Input.get_axis(&"move_backward", &"move_forward")

	if absf(climb_input) > 0.1:
		if anim_ctrl.get_current_anim() != &"climb_ladder":
			anim_ctrl.travel_to_anim(&"climb_ladder")

		var anim_scale: float = signf(climb_input)
		anim_ctrl.set_anim_time_scale(anim_scale)

		# 沿世界 Y 轴匀速平移
		player.global_position.y += climb_input * climb_speed * delta
	else:
		player.velocity = Vector3.ZERO
		anim_ctrl.set_anim_time_scale(0.0)
