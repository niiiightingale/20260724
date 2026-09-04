# beat_clock_3d.gd
# 3D 头顶节拍时钟表现层控制器：监听节拍广播，驱动指针 MeshInstance3D 绕局部指定轴进行可配置角度的跳步旋转，并在整圈后规范化归零
extends Node3D
class_name BeatClock3D

@export_group("外部依赖注入 (Explicit Dependencies)")
@export var hand_mesh: MeshInstance3D = null ## 旋转指针网格实例引用 (模型原点为几何旋转中心)

@export_group("指针跳动动画配置")
@export_range(1.0, 360.0, 1.0) var step_angle_degrees: float = 90.0 ## 单拍旋转步进角度 (度数)
@export var step_duration: float = 0.08 ## 单拍跳步补间过渡时间 (秒)

var target_angle_rad: float = 0.0
var active_tween: Tween = null


## 外部显式依赖注入：连接节拍发生器的 beat_hit 广播信号 (具备幂等性守卫)
func setup(conductor: BeatConductor) -> void:
	assert(conductor != null, "[BeatClock3D] 注入失败：conductor 为 null！")
	if not conductor.beat_hit.is_connected(_on_beat_hit):
		conductor.beat_hit.connect(_on_beat_hit)


## 节点初始化：校验自身节点依赖
func _ready() -> void:
	assert(hand_mesh != null, "[BeatClock3D] hand_mesh 依赖未注入！")


## 节拍信号回调：累加目标角度并驱动指针执行补间，补间后执行周期规范化
func _on_beat_hit(_beat_index: int) -> void:
	assert(hand_mesh != null, "[BeatClock3D] hand_mesh 未指定！")

	var step_rad: float = deg_to_rad(step_angle_degrees)
	target_angle_rad -= step_rad

	if active_tween != null and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_QUAD)
	active_tween.set_ease(Tween.EASE_OUT)
	active_tween.tween_property(hand_mesh, ^"rotation:z", target_angle_rad, step_duration)
	active_tween.tween_callback(_normalize_rotation_cycle)


## 补间完成回调：消除整圈累加，防止数值无限膨胀
func _normalize_rotation_cycle() -> void:
	if absf(target_angle_rad) >= TAU:
		target_angle_rad = wrapf(target_angle_rad, -TAU, 0.0)
		hand_mesh.rotation.z = target_angle_rad
