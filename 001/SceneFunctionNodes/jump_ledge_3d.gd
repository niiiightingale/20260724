# JumpLedge3D.gd
@tool # 工具模式：允许在 Godot 编辑器内实时计算并绘制虚线弧线
extends Node3D
class_name JumpLedge3D

@export var jump_duration: float = 0.8 # 跳跃飞行时长 (秒)
@export var arc_height: float = 1.2    # 默认抛物线抬高高度

# ----------------------------------------------------
# Debug 调试弧线与箭头配置
# ----------------------------------------------------
@export_group("Debug 调试弧线")
@export var show_debug_curve: bool = true:
	set(value):
		show_debug_curve = value
		_update_debug_visibility()
		if show_debug_curve:
			_draw_debug_curve()

@export var debug_curve_color: Color = Color(0.0, 1.0, 0.4) # 高亮荧光绿
@export var line_width: float = 0.15                        # 3D 弧线粗细
@export var arrow_size: float = 0.4                         # 终点箭头大小
@export var curve_segments: int = 32                        # 采样密度 (建议偶数，虚线更均匀)

# 运行时内部变量
var _current_player: Node3D = null
var _debug_mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _debug_material: StandardMaterial3D


# 动态获取节点 (防止 @tool 初始化未就绪)
func _get_start_area() -> Area3D:
	return get_node_or_null("StartArea") as Area3D

func _get_target_marker() -> Marker3D:
	return get_node_or_null("TargetMarker") as Marker3D

func _get_apex_marker() -> Marker3D:
	return get_node_or_null("ApexMarker") as Marker3D


func _ready() -> void:
	_setup_debug_nodes()
	
	var start_area = _get_start_area()
	if start_area and not Engine.is_editor_hint():
		if not start_area.body_entered.is_connected(_on_body_entered):
			start_area.body_entered.connect(_on_body_entered)
		if not start_area.body_exited.is_connected(_on_body_exited):
			start_area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if show_debug_curve:
		_draw_debug_curve()


# ----------------------------------------------------
# 初始化 Debug 节点与材质
# ----------------------------------------------------
func _setup_debug_nodes() -> void:
	if _debug_mesh_instance != null:
		return

	_immediate_mesh = ImmediateMesh.new()
	_debug_material = StandardMaterial3D.new()
	_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # 纯色发光
	_debug_material.cull_mode = BaseMaterial3D.CULL_DISABLED            # 渲染双面
	_debug_material.no_depth_test = true                                 # 穿透障碍物渲染
	_debug_material.render_priority = 127                               # 最高渲染优先级

	_debug_mesh_instance = MeshInstance3D.new()
	_debug_mesh_instance.name = "_DebugCurveMesh"
	_debug_mesh_instance.mesh = _immediate_mesh
	_debug_mesh_instance.material_override = _debug_material
	_debug_mesh_instance.custom_aabb = AABB(Vector3(-100, -100, -100), Vector3(200, 200, 200)) # 防剔除
	
	add_child(_debug_mesh_instance)
	_update_debug_visibility()


func _update_debug_visibility() -> void:
	if _debug_mesh_instance:
		_debug_mesh_instance.visible = show_debug_curve


# ----------------------------------------------------
# 核心：绘制虚线带状弧线与落地点箭头
# ----------------------------------------------------
func _draw_debug_curve() -> void:
	if _debug_mesh_instance == null:
		_setup_debug_nodes()

	if _immediate_mesh == null:
		return

	_immediate_mesh.clear_surfaces()
	if not show_debug_curve:
		return

	var points = get_jump_points()
	var p0: Vector3 = points[0]
	var p1: Vector3 = points[1]
	var p2: Vector3 = points[2]

	_debug_material.albedo_color = debug_curve_color

	# 使用 PRIMITIVE_TRIANGLES，方便自由绘制离散的虚线段和最后的箭头
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	# ----------------------------------------------------
	# 1. 绘制虚线弧线 (间隔生成小矩形带)
	# ----------------------------------------------------
	for i in range(curve_segments):
		# 偶数段绘制，奇数段留空，形成虚线效果
		if i % 2 == 0:
			var t_a: float = float(i) / float(curve_segments)
			var t_b: float = float(i + 1) / float(curve_segments)

			var pos_a: Vector3 = _quadratic_bezier(p0, p1, p2, t_a)
			var pos_b: Vector3 = _quadratic_bezier(p0, p1, p2, t_b)

			# 计算线段切线与侧向增宽向量
			var dir_ab: Vector3 = (pos_b - pos_a).normalized()
			var side_dir: Vector3 = dir_ab.cross(Vector3.UP).normalized()
			if side_dir.length_squared() < 0.001:
				side_dir = Vector3.RIGHT

			var half_w: Vector3 = side_dir * (line_width * 0.5)

			var la: Vector3 = to_local(pos_a - half_w)
			var ra: Vector3 = to_local(pos_a + half_w)
			var lb: Vector3 = to_local(pos_b - half_w)
			var rb: Vector3 = to_local(pos_b + half_w)

			# 一个虚线段 = 2个三角形 (矩形)
			_immediate_mesh.surface_add_vertex(la)
			_immediate_mesh.surface_add_vertex(ra)
			_immediate_mesh.surface_add_vertex(lb)

			_immediate_mesh.surface_add_vertex(ra)
			_immediate_mesh.surface_add_vertex(rb)
			_immediate_mesh.surface_add_vertex(lb)

	# ----------------------------------------------------
	# 2. 在终点 P2 绘制指向落地方向的 3D 箭头
	# ----------------------------------------------------
	# 根据贝塞尔曲线在 P2 点的切线向量算出指引方向
	var arrow_dir: Vector3 = (p2 - p1).normalized()
	if arrow_dir.length_squared() < 0.001:
		arrow_dir = (p2 - p0).normalized()

	var arrow_side: Vector3 = arrow_dir.cross(Vector3.UP).normalized()
	if arrow_side.length_squared() < 0.001:
		arrow_side = Vector3.RIGHT

	# 计算箭头三角形的 3 个本地坐标
	var tip: Vector3 = to_local(p2) # 箭头尖端 (P2)
	var base_center: Vector3 = p2 - arrow_dir * arrow_size # 箭头底部中点
	var half_arrow_w: Vector3 = arrow_side * (arrow_size * 0.65) # 箭头翼展宽度

	var base_left: Vector3 = to_local(base_center - half_arrow_w)
	var base_right: Vector3 = to_local(base_center + half_arrow_w)

	# 绘制箭头三角形
	_immediate_mesh.surface_add_vertex(tip)
	_immediate_mesh.surface_add_vertex(base_left)
	_immediate_mesh.surface_add_vertex(base_right)

	_immediate_mesh.surface_end()


# ----------------------------------------------------
# 动态计算起跳起点 P0 (玩家坐标 vs 碰撞盒底部)
# ----------------------------------------------------
func get_start_position() -> Vector3:
	if is_instance_valid(_current_player):
		return _current_player.global_position

	var start_area = _get_start_area()
	if start_area:
		var col_shape: CollisionShape3D = _find_collision_shape(start_area)
		if col_shape and col_shape.shape:
			return _get_shape_bottom_center(col_shape)
		return start_area.global_position

	return global_position


func _get_shape_bottom_center(col_shape: CollisionShape3D) -> Vector3:
	var shape = col_shape.shape
	var center = col_shape.global_position
	var half_height: float = 0.0
	var scale_y: float = col_shape.global_transform.basis.get_scale().y

	if shape is BoxShape3D:
		half_height = (shape as BoxShape3D).size.y * 0.5 * scale_y
	elif shape is CylinderShape3D:
		half_height = (shape as CylinderShape3D).height * 0.5 * scale_y
	elif shape is CapsuleShape3D:
		half_height = (shape as CapsuleShape3D).height * 0.5 * scale_y
	elif shape is SphereShape3D:
		half_height = (shape as SphereShape3D).radius * scale_y

	return center - Vector3(0, half_height, 0)


func get_jump_points(custom_start_pos: Vector3 = Vector3.ZERO) -> Array[Vector3]:
	var p0: Vector3 = custom_start_pos if custom_start_pos != Vector3.ZERO else get_start_position()

	var target_marker = _get_target_marker()
	var p2: Vector3 = target_marker.global_position if target_marker else (p0 + global_transform.basis.z * 5.0)

	var apex_marker = _get_apex_marker()
	var p1: Vector3
	if apex_marker:
		p1 = apex_marker.global_position
	else:
		p1 = (p0 + p2) / 2.0
		p1.y += arc_height

	return [p0, p1, p2]


# ----------------------------------------------------
# 碰撞响应与辅助
# ----------------------------------------------------
func _on_body_entered(body: Node3D) -> void:
	var jump_comp = _find_jump_component(body)
	if jump_comp:
		_current_player = body
		jump_comp.set_current_ledge(self)

func _on_body_exited(body: Node3D) -> void:
	var jump_comp = _find_jump_component(body)
	if jump_comp:
		if _current_player == body:
			_current_player = null
		jump_comp.clear_current_ledge(self)

func _find_jump_component(node: Node) -> JumpComponent:
	for child in node.get_children():
		if child is JumpComponent:
			return child as JumpComponent
	return null

func _find_collision_shape(node: Node) -> CollisionShape3D:
	for child in node.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null

func _quadratic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var q0: Vector3 = p0.lerp(p1, t)
	var q1: Vector3 = p1.lerp(p2, t)
	return q0.lerp(q1, t)
