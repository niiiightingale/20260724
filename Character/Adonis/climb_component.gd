# climb_component.gd
extends Node
class_name ClimbComponent

@export_group("对齐参数设置")
@export var align_duration: float = 0.25 # 对齐插值平滑时长 (秒)

# 依赖注入持有的宿主引用 (CharacterBody3D 根节点)
var character: Player = null

# 运行期梯子感知数据
var current_ladder: Ladder3D = null
var is_top_entry: bool = false


## 显式依赖注入（由 Player._ready 显式调用）
func init(target_character: CharacterBody3D) -> void:
	character = target_character as Player


## 设置当前梯子与触发入口类型
func set_current_ladder(ladder: Ladder3D, is_top: bool = false) -> void:
	current_ladder = ladder
	is_top_entry = is_top


## 清除当前梯子记录
func clear_current_ladder(ladder: Ladder3D) -> void:
	if current_ladder == ladder:
		current_ladder = null
		is_top_entry = false


## 平滑将 CharacterBody3D 根节点对齐至梯子指定的吸附 Transform
func smooth_align_to_ladder(target_ladder: Ladder3D = null, is_top: bool = false) -> void:
	var ladder: Ladder3D = target_ladder if target_ladder != null else current_ladder
	if ladder == null or character == null:
		return

	# 1. 强制复位 visual_mesh 局部 Transform，消除任何残留的局部偏转
	if character.visual_mesh != null:
		character.visual_mesh.transform = Transform3D.IDENTITY

	# 2. 获取目标的绝对世界 Transform
	var target_tf: Transform3D
	if is_top:
		target_tf = ladder.get_top_align_transform()
	else:
		target_tf = ladder.get_bottom_align_transform(character.global_position.y)

	# 3. 播放 walk 动画作为过渡
	character.animation_controller.travel_to_anim(&"walk")

	# 4. 对齐 CharacterBody3D 根节点的 Transform3D (坐标 + 朝向)
	var start_tf: Transform3D = character.global_transform
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_method(
		func(weight: float) -> void:
			character.global_transform = start_tf.interpolate_with(target_tf, weight),
		0.0, 1.0, align_duration
	)
	
	await tween.finished
