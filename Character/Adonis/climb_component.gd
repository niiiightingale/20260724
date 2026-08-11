# climb_component.gd
extends Node
class_name ClimbComponent

@export var character: CharacterBody3D
@export var chest_raycast: RayCast3D 

@export var max_align_angle_deg: float = 60.0 
@export var align_duration: float = 0.15        

var current_ladder: Ladder3D = null
var is_top_entry: bool = false # ✨【核心】记录是否是从梯子顶端触发进入的


func _ready() -> void:
	if character == null and get_parent() is CharacterBody3D:
		character = get_parent() as CharacterBody3D


func set_current_ladder(ladder: Ladder3D, is_top: bool = false) -> void:
	current_ladder = ladder
	is_top_entry = is_top # 标记触发入口类型


func clear_current_ladder(ladder: Ladder3D) -> void:
	if current_ladder == ladder:
		current_ladder = null
		is_top_entry = false


func is_chest_colliding() -> bool:
	if chest_raycast == null:
		return true
	return chest_raycast.is_colliding()


func can_start_climb() -> bool:
	if current_ladder == null or character == null:
		return false

	var ladder_forward: Vector3 = -current_ladder.global_transform.basis.z
	ladder_forward.y = 0.0
	ladder_forward = ladder_forward.normalized()

	var rot_target: Node3D = _get_target_mesh()
	var player_forward: Vector3 = -rot_target.global_transform.basis.z
	player_forward.y = 0.0
	player_forward = player_forward.normalized()

	var angle_deg: float = rad_to_deg(player_forward.angle_to(-ladder_forward))
	return absf(angle_deg) <= max_align_angle_deg


# 平滑吸附 (支持顶端对齐)
func smooth_align_to_ladder(target_ladder: Ladder3D = null, is_top: bool = false) -> void:
	var ladder = target_ladder if target_ladder != null else current_ladder
	if ladder == null or character == null:
		return

	# 获取对齐 Transform (顶端对齐 vs 常规对齐)
	var target_tf: Transform3D = ladder.get_climb_transform_for(character.global_position, is_top)
	var rot_target: Node3D = _get_target_mesh()

	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(character, "global_position:x", target_tf.origin.x, align_duration)
	tween.tween_property(character, "global_position:z", target_tf.origin.z, align_duration)
	
	if is_top:
		# 顶端对齐时，将 Y 坐标放到高台入口处
		tween.tween_property(character, "global_position:y", target_tf.origin.y, align_duration)

	var start_basis: Basis = rot_target.global_transform.basis
	var target_basis: Basis = target_tf.basis
	tween.tween_method(
		func(weight: float):
			rot_target.global_transform.basis = start_basis.slerp(target_basis, weight),
		0.0, 1.0, align_duration
	)
	await tween.finished


func _get_target_mesh() -> Node3D:
	if character != null and character.get("visual_mesh") != null:
		var mesh_node: Node3D = character.get("visual_mesh") as Node3D
		if mesh_node:
			return mesh_node
	return character
