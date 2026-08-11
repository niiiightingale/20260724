extends Node3D

## PhantomCamera3D 第三人称视角控制器组件

@export_group("Target Camera")
@export var phantom_camera: PhantomCamera3D

@export_group("Spring Length (Distance)")
@export var min_spring_length: float = 2.0
@export var max_spring_length: float = 10.0
@export var zoom_sensitivity: float = 0.5

@export_group("Vertical Rotation Offset (Pitch)")
@export var min_vertical_rotation: float = 15.0 # 最近时的最小倾角
@export var max_vertical_rotation: float = 60.0 # 最远时的最大倾角

@export_group("Horizontal Rotation Offset (Yaw)")
@export var rotation_speed: float = 90.0 # 每秒旋转角度 (度/秒)

@export_group("Smooth Interpolation")
@export_range(1.0, 30.0) var smoothness: float = 10.0

# 内部目标控制变量
var _target_spring_length: float
var _target_vertical_rotation: float
var _target_horizontal_rotation: float

# 记录当前的角度状态
var _current_vertical_rotation: float
var _current_horizontal_rotation: float


func _ready() -> void:
	if not phantom_camera:
		push_warning("PhantomCamera3D 实例未在 Inspector 中分配！")
		set_process(false)
		set_process_unhandled_input(false)
		return

	# 初始化目标值与当前值
	_target_spring_length = phantom_camera.spring_length
	
	# 从 PhantomCamera 获取初始的三维旋转角度（X 为 Pitch，Y 为 Yaw）
	var current_rot: Vector3 = phantom_camera.get_third_person_rotation_degrees() if phantom_camera.has_method("get_third_person_rotation_degrees") else Vector3.ZERO
	
	_target_vertical_rotation = current_rot.x
	_target_horizontal_rotation = current_rot.y
	_current_vertical_rotation = current_rot.x
	_current_horizontal_rotation = current_rot.y


func _unhandled_input(event: InputEvent) -> void:
	if not phantom_camera:
		return

	# 处理鼠标滚轮缩放
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_spring_length -= zoom_sensitivity
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_spring_length += zoom_sensitivity

		_target_spring_length = clamp(_target_spring_length, min_spring_length, max_spring_length)

		# 距离计算：越近越平，越远越高
		var t: float = (_target_spring_length - min_spring_length) / (max_spring_length - min_spring_length)
		_target_vertical_rotation = lerp(min_vertical_rotation, max_vertical_rotation, t)


func _process(delta: float) -> void:
	if not phantom_camera:
		return

	# 处理 Q/E 按键水平旋转
	var rotate_direction: float = Input.get_axis("rotate_left", "rotate_right")
	if rotate_direction != 0.0:
		_target_horizontal_rotation += rotate_direction * rotation_speed * delta

	# 计算平滑权重
	var lerp_weight: float = clamp(smoothness * delta, 0.0, 1.0)

	# 1. 应用缩放 (Spring Length)
	phantom_camera.spring_length = lerp(
		phantom_camera.spring_length,
		_target_spring_length,
		lerp_weight
	)

	# 2. 计算 Pitch 俯仰角平滑值
	_current_vertical_rotation = lerp(_current_vertical_rotation, _target_vertical_rotation, lerp_weight)

	# 3. 计算 Yaw 水平旋转平滑值 (使用角度插值防反转)
	var current_h_rad: float = deg_to_rad(_current_horizontal_rotation)
	var target_h_rad: float = deg_to_rad(_target_horizontal_rotation)
	_current_horizontal_rotation = rad_to_deg(lerp_angle(current_h_rad, target_h_rad, lerp_weight))

	# 4. 调用 PhantomCamera3D 官方 Setter 接口更新旋转
	var target_rotation_vec := Vector3(_current_vertical_rotation, _current_horizontal_rotation, 0.0)
	
	if phantom_camera.has_method("set_third_person_rotation_degrees"):
		phantom_camera.set_third_person_rotation_degrees(target_rotation_vec)
	else:
		# 兼容老版本或直接赋值 setter
		phantom_camera.set_vertical_rotation_offset(_current_vertical_rotation)
		phantom_camera.set_horizontal_rotation_offset(_current_horizontal_rotation)
