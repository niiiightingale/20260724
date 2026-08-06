extends CharacterBody3D

# --- 节点引用 ---
@onready var anim_player: AnimationPlayer = $Anemone/AnimationPlayer
@onready var state_machine: StateMachine = $StateMachine
@onready var ground_raycast: RayCast3D = $GroundRayCast
@onready var visual_mesh: Node3D = $Anemone

@export var camera: Camera3D

# ==========================================
# --- 统一参数配置区 (Inspector 可视化调节) ---
# ==========================================
@export_group("移动参数")
@export var run_speed: float = 6.0
@export var rotation_speed: float = 12.0 # 角色转向平滑度

@export_group("跳跃与下落")
@export var jump_velocity: float = 10.0  # 跳跃初始爆发速度
@export var rise_gravity: float = 20.0   # 上升阶段重力
@export var fall_gravity: float = 24.0   # 下落阶段重力
@export var air_move_speed: float = 5.0  # 空中水平移动控制力

@export_group("滑翔参数")
@export var glide_speed: float = 8.0     # 滑翔水平速度
@export var glide_gravity: float = 3.0   # 滑翔下降重力（较小）
@export var max_glide_fall_speed: float = -2.0 # 滑翔最大下落终端速度

# ==========================================
# --- 暴露给 State 读取的实时运行数据 ---
# ==========================================
var input_dir: Vector2 = Vector2.ZERO
var move_direction: Vector3 = Vector3.ZERO

var jump_just_pressed: bool = false
var glide_just_pressed: bool = false

var is_grounded: bool = false
var horizontal_speed: float = 0.0
var vertical_velocity: float = 0.0

func _ready() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
	state_machine.init(self)

func _physics_process(delta: float) -> void:
	# 1. 收集输入
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	jump_just_pressed = Input.is_action_just_pressed("jump")
	glide_just_pressed = Input.is_action_just_pressed("glide")
	
	# 2. 转换基于摄像机的移动向量与旋转
	_update_move_direction()
	_update_rotation(delta)
	
	# 3. 运行环境检测与数据暴露
	is_grounded = is_on_floor() or ground_raycast.is_colliding()
	vertical_velocity = velocity.y
	horizontal_speed = Vector2(velocity.x, velocity.z).length()

func _update_move_direction() -> void:
	if not camera:
		move_direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
		return

	var cam_basis: Basis = camera.global_transform.basis
	var forward: Vector3 = -cam_basis.z
	forward.y = 0
	forward = forward.normalized()
	
	var right: Vector3 = cam_basis.x
	right.y = 0
	right = right.normalized()
	
	move_direction = (right * input_dir.x + forward * -input_dir.y).normalized()

func _update_rotation(delta: float) -> void:
	if move_direction.length() > 0.1 and visual_mesh:
		var target_rotation = Transform3D().looking_at(move_direction, Vector3.UP).basis
		visual_mesh.global_transform.basis = visual_mesh.global_transform.basis.slerp(
			target_rotation, 
			rotation_speed * delta
		)
