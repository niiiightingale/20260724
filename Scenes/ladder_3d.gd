# ladder_3d.gd
@tool
extends Node3D
class_name Ladder3D

@export_group("梯子尺寸设置")
@export var ladder_height: float = 3.0: # 梯子高度 (米)
	set(v):
		ladder_height = maxf(0.5, v)
		_update_debug_visuals()

@export var step_height: float = 0.27 # 每格横杠间距

@export_group("3D 编辑器调试可视化")
@export var show_debug_in_editor: bool = true:
	set(v):
		show_debug_in_editor = v
		_update_debug_visuals()

var main_detect_area: Area3D = null
var top_detect_area: Area3D = null

var debug_bottom_mesh: MeshInstance3D = null
var debug_top_mesh: MeshInstance3D = null


func _ready() -> void:
	_update_debug_visuals()
	
	if not Engine.is_editor_hint():
		if debug_bottom_mesh: debug_bottom_mesh.visible = false
		if debug_top_mesh: debug_top_mesh.visible = false
		_setup_areas()


func get_bottom_y() -> float:
	return global_position.y

func get_top_y() -> float:
	return global_position.y + ladder_height

func get_climb_transform_for(player_pos: Vector3, is_top: bool = false) -> Transform3D:
	var align_pos: Vector3 = global_position
	align_pos.y = get_top_y() if is_top else player_pos.y
	return Transform3D(global_transform.basis, align_pos)


func _update_debug_visuals() -> void:
	if not Engine.is_editor_hint() and not show_debug_in_editor:
		return

	# 底端红色圈
	if debug_bottom_mesh == null:
		debug_bottom_mesh = MeshInstance3D.new()
		debug_bottom_mesh.name = "_DebugBottomRing"
		add_child(debug_bottom_mesh)
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = 0.4; cylinder.bottom_radius = 0.4; cylinder.height = 0.05
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.2, 0.2, 0.7)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cylinder.material = mat
		debug_bottom_mesh.mesh = cylinder

	# 顶端绿色圈
	if debug_top_mesh == null:
		debug_top_mesh = MeshInstance3D.new()
		debug_top_mesh.name = "_DebugTopRing"
		add_child(debug_top_mesh)
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = 0.4; cylinder.bottom_radius = 0.4; cylinder.height = 0.05
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 1.0, 0.2, 0.7)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cylinder.material = mat
		debug_top_mesh.mesh = cylinder

	debug_bottom_mesh.visible = show_debug_in_editor
	debug_top_mesh.visible = show_debug_in_editor
	debug_bottom_mesh.position = Vector3.ZERO
	debug_top_mesh.position = Vector3(0, ladder_height, 0)


func _setup_areas() -> void:
	main_detect_area = find_child("MainDetectArea", true, false) as Area3D
	top_detect_area = find_child("TopDetectArea", true, false) as Area3D

	if main_detect_area:
		main_detect_area.body_entered.connect(func(body):
			var comp = _find_climb_comp(body)
			if comp: comp.set_current_ladder(self, false)
		)
		main_detect_area.body_exited.connect(func(body):
			var comp = _find_climb_comp(body)
			if comp: comp.clear_current_ladder(self)
		)

	if top_detect_area:
		top_detect_area.body_entered.connect(func(body):
			var comp = _find_climb_comp(body)
			if comp: comp.set_current_ladder(self, true)
		)
		top_detect_area.body_exited.connect(func(body):
			var comp = _find_climb_comp(body)
			if comp: comp.clear_current_ladder(self)
		)


func _find_climb_comp(node: Node) -> ClimbComponent:
	for child in node.get_children():
		if child is ClimbComponent:
			return child as ClimbComponent
	return null
