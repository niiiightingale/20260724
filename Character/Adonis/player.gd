# player.gd
# 角色主控脚本：负责节点装配、依赖注入、视角转译及全局重力物理管控
extends CharacterBody3D
class_name Player

# --- 节点引用（公开为强类型属性供组件/状态安全访问） ---
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var state_machine: StateMachine = $StateMachine
@onready var animation_controller: AnimationController = $AnimationController
@export var anim_player: AnimationPlayer
@export var ground_raycast: RayCast3D
@export var visual_mesh: Node3D
@export var skeleton: Skeleton3D
@export var camera: Camera3D

# ==========================================
# --- 统一参数配置区 (Inspector 可视化调节) ---
# ==========================================
@export_group("移动与表现参数")
@export var run_speed: float = 6.0
@export var rotation_speed: float = 12.0 ## 角色根节点转向平滑速度
@export var anim_speed_scale: float = 1.0 ## 动画与位移全局播放速率系数 (1.0 为原速，1.2 为加速)

@export_group("物理与高程")
@export var jump_velocity: float = 10.0
@export var fall_gravity: float = 24.0

# ==========================================
# --- 实时运行数据与物理开关 ---
# ==========================================
var input_dir: Vector2 = Vector2.ZERO
var move_direction: Vector3 = Vector3.ZERO
var is_grounded: bool = false
var is_gravity_enabled: bool = true ## 控制重力解算开关 (供状态节点控制)
var horizontal_speed: float = 0.0
var vertical_velocity: float = 0.0


func _ready() -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()
		
	# --- 显式依赖注入（装配中心） ---
	if animation_controller != null:
		animation_controller.init(self)
		
	if state_machine != null:
		state_machine.init(self)


func _physics_process(delta: float) -> void:
	# 1. 收集玩家 2D 输入
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# 2. 视角转译计算绝对世界移动方向
	_update_move_direction()
	
	# 3. 维护接地状态供 StateMachine 消费
	is_grounded = is_on_floor() or (ground_raycast != null and ground_raycast.is_colliding())
	
	# 4. 集中重力解算 (仅当重力开关开启且未在地面时施加)
	if is_gravity_enabled and not is_on_floor():
		velocity.y -= fall_gravity * delta
		
	# 5. 记录基础物理数据
	vertical_velocity = velocity.y
	horizontal_speed = Vector2(velocity.x, velocity.z).length()


## 计算基于相机视角的绝对移动方向 (对齐 View Space 标准坐标)
func _update_move_direction() -> void:
	if camera == null:
		move_direction = Vector3(input_dir.x, 0.0, input_dir.y).normalized()
		return

	var cam_basis: Basis = camera.global_transform.basis
	var forward: Vector3 = -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	var right: Vector3 = cam_basis.x
	right.y = 0.0
	right = right.normalized()
	
	move_direction = (right * input_dir.x + forward * -input_dir.y).normalized()


## 供外部/State 显式调用的转向辅助函数 (旋转 Player 物理根节点)
func rotate_towards_move_direction(delta: float) -> void:
	if move_direction.length() > 0.1:
		var target_rotation: Basis = Transform3D().looking_at(move_direction, Vector3.UP).basis
		global_transform.basis = global_transform.basis.slerp(
			target_rotation, 
			rotation_speed * delta
		)


## ✨ 控制物理重力系统开关 (如攀爬/飞行状态设为 false，地面/空中状态设为 true)
func set_gravity_enabled(enabled: bool) -> void:
	is_gravity_enabled = enabled


## ✨ 施加垂直脉冲速度 (供跳跃/冲刺等状态调用)
func apply_vertical_impulse(impulse: float) -> void:
	velocity.y = impulse
