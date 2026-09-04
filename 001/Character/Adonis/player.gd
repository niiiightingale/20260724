# player.gd
# 角色主控脚本：负责节点装配、依赖注入、鼠标射线拾取、寻路目标下发及全局重力物理管控
extends CharacterBody3D
class_name Player

# --- 节点引用（公开为强类型属性供组件/状态安全访问） ---
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var state_machine: StateMachine = $StateMachine
@onready var animation_controller: AnimationController = $AnimationController
@export var nav_agent: NavigationAgent3D
@export var anim_player: AnimationPlayer
@export var ground_raycast: RayCast3D
@export var visual_mesh: Node3D
@export var skeleton: Skeleton3D
@export var camera: Camera3D

# ==========================================
# --- 统一参数配置区 (Inspector 可视化调节) ---
# ==========================================
@export_group("移动与表现参数")
@export var rotation_speed: float = 12.0 ## 角色根节点转向平滑速度
@export var anim_speed_scale: float = 1.0 ## 动画与位移全局播放速率系数

@export_group("物理与高程")
@export var fall_gravity: float = 24.0

# ==========================================
# --- 实时运行数据与物理开关 ---
# ==========================================
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


## 捕获未处理的鼠标点击输入并投射世界坐标射线
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_cast_ray_to_ground(mouse_event.position)


func _physics_process(delta: float) -> void:
	# 1. 维护接地状态供 StateMachine 消费
	is_grounded = is_on_floor() or (ground_raycast != null and ground_raycast.is_colliding())
	
	# 2. 集中重力解算 (仅当重力开关开启且未在地面时施加)
	if is_gravity_enabled and not is_on_floor():
		velocity.y -= fall_gravity * delta
		
	# 3. 记录基础物理数据
	vertical_velocity = velocity.y
	horizontal_speed = Vector2(velocity.x, velocity.z).length()


## 向 3D 空间投射物理射线获取地面点击坐标并注入寻路代理
func _cast_ray_to_ground(screen_pos: Vector2) -> void:
	if camera == null:
		return
		
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var to: Vector3 = from + dir * 1000.0
	
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	
	var result: Dictionary = space_state.intersect_ray(query)
	if not result.is_empty():
		var hit_position: Vector3 = result["position"]
		set_nav_target(hit_position)


## 下发寻路目标点给 NavigationAgent3D
func set_nav_target(target: Vector3) -> void:
	if nav_agent != null:
		nav_agent.target_position = target


## 供外部/State 显式调用的转向辅助函数 (旋转 Player 物理根节点)
func rotate_towards_move_direction(delta: float) -> void:
	if move_direction.length() > 0.1:
		var target_rotation: Basis = Transform3D().looking_at(move_direction, Vector3.UP).basis
		global_transform.basis = global_transform.basis.slerp(
			target_rotation, 
			rotation_speed * delta
		)


## 控制物理重力系统开关 (如攀爬/飞行状态设为 false，地面/空中状态设为 true)
func set_gravity_enabled(enabled: bool) -> void:
	is_gravity_enabled = enabled


## 施加垂直脉冲速度 (供跳跃/冲刺等状态调用)
func apply_vertical_impulse(impulse: float) -> void:
	velocity.y = impulse
