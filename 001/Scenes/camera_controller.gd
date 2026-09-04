# camera_controller.gd
# 摄像机主控制器：管理自由平滑旋转 (支持按键与鼠标中键拖拽) 与 90° 象限步进旋转，支持正交滚轮缩放与软跟随
extends Node3D
class_name CameraController

## 旋转控制模式枚举
enum RotationMode {
	FREE_SMOOTH, ## 自由平滑旋转模式 (支持持续按键与鼠标中键拖拽)
	STEPPED_90   ## 90° 象限步进模式 (点按单次转 90°，基于最短角度路径插值)
}

@export_group("外部依赖注入 (Explicit Dependencies)")
@export var phantom_camera: PhantomCamera3D = null ## 挂载于子层级的 PhantomCamera3D 实例引用
@export var target_camera: Camera3D = null ## 场景中实际负责渲染的 MainCamera3D 引用

@export_group("旋转控制模式配置")
@export var rotation_mode: RotationMode = RotationMode.FREE_SMOOTH ## 当前启用的旋转模式

@export_group("90° 象限旋转参数 (Stepped 90°)")
@export var stepped_rotation_speed: float = 12.0 ## 象限模式偏航角平滑插值速率

@export_group("自由旋转参数 (Free Smooth)")
@export var free_rotation_speed: float = 3.0 ## 键盘按键驱动自由旋转的角速度 (弧度/秒)
@export var mouse_sensitivity: float = 0.005 ## 鼠标中键拖拽灵敏度 (弧度/像素)
@export var free_rotation_smooth_speed: float = 16.0 ## 自由旋转模式角度平滑插值速率

@export_group("正交变焦配置")
@export var min_ortho_size: float = 8.0 ## 正交相机最小视口尺寸 (最大放大)
@export var max_ortho_size: float = 30.0 ## 正交相机最大视口尺寸 (最大缩小)
@export var zoom_step: float = 1.5 ## 单次滚轮滚动的正交尺寸变化量
@export var zoom_smooth_speed: float = 10.0 ## 正交尺寸插值平滑速率

@export_group("软跟随阻尼配置")
@export var follow_smooth_speed: float = 8.0 ## 轴心追随目标坐标的平滑速度

# 跟随目标引用 (由 setup 显式注入)
var follow_target: Node3D = null

# 状态内部变量
var current_quadrant_index: int = 0
var target_yaw: float = 0.0
var target_ortho_size: float = 16.553
var is_middle_mouse_dragging: bool = false


## 外部显式依赖注入：由关卡入口初始化并绑定跟随目标
func setup(target_node: Node3D) -> void:
	follow_target = target_node
	if target_camera != null and target_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		target_ortho_size = target_camera.size


## 输入事件监听：处理旋转事件 (点按/中键拖拽) 与鼠标滚轮缩放事件
func _unhandled_input(event: InputEvent) -> void:
	# 1. 鼠标中键拖拽旋转状态捕获 (自由旋转模式专用)
	if event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button_event.button_index == MOUSE_BUTTON_MIDDLE:
			is_middle_mouse_dragging = mouse_button_event.pressed

		# 滚轮缩放事件处理
		if mouse_button_event.pressed:
			if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_apply_zoom(-zoom_step)
			elif mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_apply_zoom(zoom_step)

	# 2. 鼠标移动拖拽偏航解算
	if event is InputEventMouseMotion and is_middle_mouse_dragging:
		var mouse_motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if rotation_mode == RotationMode.FREE_SMOOTH:
			target_yaw -= mouse_motion_event.relative.x * mouse_sensitivity
			target_yaw = wrapf(target_yaw, -PI, PI)

	# 3. 90° 象限模式点按事件捕获
	if rotation_mode == RotationMode.STEPPED_90:
		if event.is_action_pressed(&"camera_rotate_left"):
			_step_rotate(1)
		elif event.is_action_pressed(&"camera_rotate_right"):
			_step_rotate(-1)


## 帧渲染循环：平滑插值偏航角与正交相机视口尺寸
func _process(delta: float) -> void:
	# 1. 自由旋转模式下的键盘持续按键输入捕获
	if rotation_mode == RotationMode.FREE_SMOOTH:
		var rotate_axis: float = Input.get_axis(&"camera_rotate_right", &"camera_rotate_left")
		if not is_zero_approx(rotate_axis):
			target_yaw += rotate_axis * free_rotation_speed * delta
			target_yaw = wrapf(target_yaw, -PI, PI)

	# 2. 统一通过 lerp_angle 执行偏航角平滑插值
	var current_smooth_speed: float = free_rotation_smooth_speed if rotation_mode == RotationMode.FREE_SMOOTH else stepped_rotation_speed
	rotation.y = lerp_angle(rotation.y, target_yaw, current_smooth_speed * delta)

	# 3. 正交视口尺寸平滑插值
	if target_camera != null and target_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var current_size: float = target_camera.size
		target_camera.size = lerpf(current_size, target_ortho_size, zoom_smooth_speed * delta)


## 物理帧循环：平滑软跟随注入的目标全局坐标
func _physics_process(delta: float) -> void:
	if follow_target != null:
		var target_pos: Vector3 = follow_target.global_position
		global_position = global_position.lerp(target_pos, follow_smooth_speed * delta)


## 触发 90° 象限步进旋转 (离散索引更新并转译为规范弧度)
func _step_rotate(direction_step: int) -> void:
	current_quadrant_index = (current_quadrant_index + direction_step) % 4
	if current_quadrant_index < 0:
		current_quadrant_index += 4

	var raw_angle: float = float(current_quadrant_index) * (PI / 2.0)
	target_yaw = wrapf(raw_angle, -PI, PI)


## 累加并钳制正交缩放目标尺寸
func _apply_zoom(delta_size: float) -> void:
	target_ortho_size = clampf(target_ortho_size + delta_size, min_ortho_size, max_ortho_size)
