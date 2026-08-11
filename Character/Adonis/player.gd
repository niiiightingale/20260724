extends CharacterBody3D

# --- 节点引用 ---
@onready var anim_player: AnimationPlayer = $Adonis/AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var state_machine: StateMachine = $StateMachine
@onready var ground_raycast: RayCast3D = $GroundRayCast
@onready var visual_mesh: Node3D = $Adonis
@onready var jump_component: JumpComponent = $JumpComponent
@onready var skeleton:Skeleton3D = $Adonis/rig/Skeleton3D

@export var camera: Camera3D

# ==========================================
# --- 统一参数配置区 (Inspector 可视化调节) ---
# ==========================================
@export_group("移动与惯性参数")
@export var run_speed: float = 6.0
@export var acceleration: float = 10.0 # 加速度
@export var friction: float = 8.0     # 阻尼/减速度
@export var rotation_speed: float = 6.0 # 模型转向速度

@export_group("跳跃与下落")
@export var jump_velocity: float = 10.0
@export var rise_gravity: float = 20.0
@export var fall_gravity: float = 24.0
@export var air_move_speed: float = 5.0

@export_group("滑翔参数")
@export var glider_mesh: Node3D # 在 Inspector 面板中挂载你的降落伞模型节点
@export var glide_speed: float = 8.0
@export var glide_gravity: float = 2.0
@export var max_glide_fall_speed: float = -2.0
@export var glide_acceleration: float = 1.5      # 极小的滑翔加速度
@export var glide_friction: float = 1.0          # 极小的空气阻力
@export var glide_rotation_speed: float = 1.5   # 缓慢的伞面转向速度
@export var glide_tilt_angle: float = 20.0       # 离心摆动倾斜角


# ==========================================
# --- 实时运行数据 ---
# ==========================================
var input_dir: Vector2 = Vector2.ZERO
var move_direction: Vector3 = Vector3.ZERO

var jump_just_pressed: bool = false
var glide_just_pressed: bool = false

var is_grounded: bool = false
var horizontal_speed: float = 0.0
var vertical_velocity: float = 0.0

# 动画状态机播放控制器
var anim_playback: AnimationNodeStateMachinePlayback

func _ready() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
	# 游戏启动时默认隐藏降落伞
	if glider_mesh:
		glider_mesh.visible = false
		
	if anim_tree:
		anim_tree.active = true
		anim_playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
		
	state_machine.init(self)

func _physics_process(delta: float) -> void:
	if jump_component and jump_component.is_jumping:
		return
	# 1. 收集输入
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	jump_just_pressed = Input.is_action_just_pressed("jump")
	glide_just_pressed = Input.is_action_just_pressed("glide")
	
	# 2. 视角转译与转向
	_update_move_direction()
	
	# 3. 实时速度与接地数据更新
	is_grounded = is_on_floor() or ground_raycast.is_colliding()
	vertical_velocity = velocity.y
	horizontal_speed = Vector2(velocity.x, velocity.z).length()
	
	# 4. 驱动 AnimationTree 内的 BlendSpace 参数
	_update_animation_tree()



# 实时驱动地面/空中 1D 混合空间
func _update_animation_tree() -> void:
	if not anim_tree:
		return
		
	if is_grounded:
		# 驱动地面 MoveBlend (0.0 ~ 1.0)
		var speed_percent: float = clamp(horizontal_speed / run_speed, 0.0, 1.0)
		anim_tree.set("parameters/MoveBlend/blend_position", speed_percent)
	else:
		# 驱动空中 AirState (-1.0 ~ 1.0)
		# 映射规则：以 -15.0(最大下落速度) 到 10.0(起跳速度) 映射到 -1.0 ~ 1.0
		var air_val: float = remap(velocity.y, -15.0, jump_velocity, -1.0, 1.0)
		anim_tree.set("parameters/AirState/blend_position", clamp(air_val, -1.0, 1.0))

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

# 改为供需要旋转的状态主动调用的辅助函数
func rotate_towards_move_direction(delta: float) -> void:
	if move_direction.length() > 0.1 and visual_mesh:
		var target_rotation = Transform3D().looking_at(move_direction, Vector3.UP).basis
		visual_mesh.global_transform.basis = visual_mesh.global_transform.basis.slerp(
			target_rotation, 
			rotation_speed * delta
		)

# 你原有的核心接口
func travel_to_anim(anim_node_name: String) -> void:
	if anim_playback:
		anim_playback.travel(anim_node_name)

# 1. 调控动画播放速度 (传入 0.0 可直接冻结当前帧)
func set_anim_speed(speed: float) -> void:
	if anim_player:
		anim_player.speed_scale = speed

# 2. 获取当前 AnimationTree 节点名称
func get_current_anim() -> String:
	if anim_playback:
		return anim_playback.get_current_node()
	return ""

# 3. 获取指定动画剪辑的时长 (秒)
func get_anim_length(anim_name: String) -> float:
	if anim_player and anim_player.has_animation(anim_name):
		return anim_player.get_animation(anim_name).length
	return 0.8 # 保底时长

# 4. ✨ 抓取 hips 世界绝对坐标并换算为玩家实体 (脚底) 落地坐标
func get_landing_pos_by_hips(bone_name: String = "hips") -> Vector3:
	if skeleton == null:
		return global_position
		
	var bone_idx: int = skeleton.find_bone(bone_name)
	if bone_idx != -1:
		# 抓取 hips 在世界空间的真实绝对 Transform
		var hips_global_tf: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)
		var hips_world_pos: Vector3 = hips_global_tf.origin
		
		# 动态获取默认站立姿态下 hips 的原生腰高 (例如 0.85 米)
		var default_hips_height: float = skeleton.get_bone_pose_position(bone_idx).y
		if default_hips_height <= 0.05:
			default_hips_height = 0.85 # 保底腰高
			
		# 腹部绝对坐标 - 腰高 = 碰撞盒/脚底真正的落地绝对坐标！
		var landing_pos: Vector3 = hips_world_pos
		landing_pos.y -= default_hips_height
		return landing_pos
		
	return global_position
