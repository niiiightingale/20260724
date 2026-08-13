# ladder_3d.gd
@tool
extends Node3D
class_name Ladder3D

@export_group("参照物与模型设置")
@export var ladder_mesh: Node3D: # 用于提供绝对空间对齐参照物的模型节点
	set(v):
		ladder_mesh = v
		_update_debug_visuals()

@export_group("梯子尺寸与偏移设置")
@export var ladder_height: float = 3.0: # 梯子高度 (米)
	set(v):
		ladder_height = maxf(0.5, v)
		_update_debug_visuals()

@export var align_offset_z: float = 0.25: # 准备动作与梯子平面的标准对齐距离 (米)
	set(v):
		align_offset_z = maxf(0.0, v)
		_update_debug_visuals()

@export_group("3D 编辑器调试可视化")
@export var show_debug_in_editor: bool = true:
	set(v):
		show_debug_in_editor = v
		_update_debug_visuals()

# 内部私有调试节点与检测区域缓存
var bottom_detect_area: Area3D = null
var top_detect_area: Area3D = null

var _debug_bottom_ring: MeshInstance3D = null
var _debug_top_ring: MeshInstance3D = null
var _debug_bottom_arrow: MeshInstance3D = null
var _debug_top_arrow: MeshInstance3D = null


func _ready() -> void:
	_update_debug_visuals()
	if not Engine.is_editor_hint():
		_set_debug_visible(false)
		_setup_areas()


## 获取参照物节点的绝对世界 Transform (若未指定 ladder_mesh 则降级使用 self)
func get_mesh_transform() -> Transform3D:
	if ladder_mesh != null:
		return ladder_mesh.global_transform
	return global_transform


## 获取底端世界 Y 轴高度
func get_bottom_y() -> float:
	return get_mesh_transform().origin.y


## 获取顶端世界 Y 轴高度
func get_top_y() -> float:
	return get_mesh_transform().origin.y + ladder_height


## 获取底端吸附点世界 Transform (面朝梯子，-Z 指向梯子正面)
func get_bottom_align_transform(player_current_y: float = -999.0) -> Transform3D:
	var mesh_tf: Transform3D = get_mesh_transform()
	var align_pos: Vector3 = mesh_tf.origin + (mesh_tf.basis.z * align_offset_z)
	
	if player_current_y > -900.0:
		align_pos.y = player_current_y
	else:
		align_pos.y = get_bottom_y()
		
	# 面朝梯子：保持 ladder_mesh 原始 Basis
	return Transform3D(mesh_tf.basis, align_pos)


## 获取顶端吸附点世界 Transform (背靠梯子/面向高台内侧，-Z 指向高台内侧)
func get_top_align_transform() -> Transform3D:
	var mesh_tf: Transform3D = get_mesh_transform()
	var align_pos: Vector3 = mesh_tf.origin - (mesh_tf.basis.z * align_offset_z)
	align_pos.y = get_top_y()
	
	# 背靠梯子：将 Basis 绕 Y 轴旋转 180°
	var top_basis: Basis = mesh_tf.basis.rotated(Vector3.UP, PI)
	return Transform3D(top_basis, align_pos)


# ==========================================
# --- 检测区域事件与信号绑定 ---
# ==========================================

func _setup_areas() -> void:
	for child in get_children():
		if child is Area3D:
			if child.name == "BottomDetectArea":
				bottom_detect_area = child as Area3D
			elif child.name == "TopDetectArea":
				top_detect_area = child as Area3D

	if bottom_detect_area != null:
		bottom_detect_area.body_entered.connect(func(body: Node3D) -> void:
			var comp: ClimbComponent = _extract_climb_comp(body)
			if comp != null:
				comp.set_current_ladder(self, false)
		)
		bottom_detect_area.body_exited.connect(func(body: Node3D) -> void:
			var comp: ClimbComponent = _extract_climb_comp(body)
			if comp != null:
				comp.clear_current_ladder(self)
		)

	if top_detect_area != null:
		top_detect_area.body_entered.connect(func(body: Node3D) -> void:
			var comp: ClimbComponent = _extract_climb_comp(body)
			if comp != null:
				comp.set_current_ladder(self, true)
		)
		top_detect_area.body_exited.connect(func(body: Node3D) -> void:
			var comp: ClimbComponent = _extract_climb_comp(body)
			if comp != null:
				comp.clear_current_ladder(self)
		)


func _extract_climb_comp(node: Node) -> ClimbComponent:
	if "climb_component" in node and node.climb_component is ClimbComponent:
		return node.climb_component as ClimbComponent
	return null


# ==========================================
# --- 3D 编辑器可视化构建逻辑 ---
# ==========================================

func _set_debug_visible(visible_state: bool) -> void:
	if _debug_bottom_ring != null:
		_debug_bottom_ring.visible = visible_state
	if _debug_top_ring != null:
		_debug_top_ring.visible = visible_state


func _update_debug_visuals() -> void:
	if not Engine.is_editor_hint():
		return

	if not show_debug_in_editor:
		_set_debug_visible(false)
		return

	_ensure_debug_nodes_exist()
	_set_debug_visible(true)

	var base_transform: Transform3D = Transform3D.IDENTITY
	if ladder_mesh != null:
		base_transform = ladder_mesh.transform

	var bottom_local_pos: Vector3 = base_transform.origin + (base_transform.basis.z * align_offset_z)
	var top_local_pos: Vector3 = base_transform.origin - (base_transform.basis.z * align_offset_z)
	top_local_pos.y += ladder_height

	_debug_bottom_ring.transform = Transform3D(base_transform.basis, bottom_local_pos)
	
	var top_local_basis: Basis = base_transform.basis.rotated(Vector3.UP, PI)
	_debug_top_ring.transform = Transform3D(top_local_basis, top_local_pos)


func _ensure_debug_nodes_exist() -> void:
	if _debug_bottom_ring == null:
		_debug_bottom_ring = MeshInstance3D.new()
		_debug_bottom_ring.name = "_DebugBottomRing"
		add_child(_debug_bottom_ring)
		_debug_bottom_ring.mesh = _create_ring_mesh(Color(1.0, 0.2, 0.2, 0.8))

		_debug_bottom_arrow = MeshInstance3D.new()
		_debug_bottom_arrow.name = "_DebugBottomArrow"
		_debug_bottom_ring.add_child(_debug_bottom_arrow)
		_debug_bottom_arrow.mesh = _create_arrow_mesh(Color(1.0, 0.2, 0.2, 0.9))
		_debug_bottom_arrow.position = Vector3(0.0, 0.0, -0.08)
		_debug_bottom_arrow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

	if _debug_top_ring == null:
		_debug_top_ring = MeshInstance3D.new()
		_debug_top_ring.name = "_DebugTopRing"
		add_child(_debug_top_ring)
		_debug_top_ring.mesh = _create_ring_mesh(Color(0.2, 1.0, 0.2, 0.8))

		_debug_top_arrow = MeshInstance3D.new()
		_debug_top_arrow.name = "_DebugTopArrow"
		_debug_top_ring.add_child(_debug_top_arrow)
		_debug_top_arrow.mesh = _create_arrow_mesh(Color(0.2, 1.0, 0.2, 0.9))
		_debug_top_arrow.position = Vector3(0.0, 0.0, -0.08)
		_debug_top_arrow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)


func _create_ring_mesh(color: Color) -> CylinderMesh:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.05
	cylinder.height = 0.03
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cylinder.material = mat
	return cylinder


func _create_arrow_mesh(color: Color) -> PrismMesh:
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.05, 0.2, 0.025)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	prism.material = mat
	return prism
