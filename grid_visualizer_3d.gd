# grid_visualizer_3d.gd
# 网格视觉表现层控制器：根据 GridManager 注入的参数动态更新几何体与 Shader 参数，不承载任何玩法逻辑
extends MeshInstance3D
class_name GridVisualizer3D

const PLANE_SUBDIVIDE_COUNT: int = 2


## 外部显式参数注入：初始化几何体尺寸并下发 Shader Uniform 参数
func setup(cell_size: Vector2, bounds: Rect2i) -> void:
	assert(mesh is PlaneMesh, "[GridVisualizer3D] mesh 必须为 PlaneMesh！")
	assert(material_override is ShaderMaterial, "[GridVisualizer3D] material_override 必须为 ShaderMaterial！")

	var plane_mesh: PlaneMesh = mesh as PlaneMesh
	var shader_mat: ShaderMaterial = material_override as ShaderMaterial

	# 1. 计算视觉平面所需的世界尺寸 (米)
	var world_width: float = float(bounds.size.x) * cell_size.x
	var world_depth: float = float(bounds.size.y) * cell_size.y
	plane_mesh.size = Vector2(world_width, world_depth)

	# 2. 将视觉平面对齐至网格逻辑中心
	var center_grid_x: float = float(bounds.position.x) + float(bounds.size.x) * 0.5 - 0.5
	var center_grid_y: float = float(bounds.position.y) + float(bounds.size.y) * 0.5 - 0.5
	var center_world_x: float = center_grid_x * cell_size.x
	var center_world_z: float = center_grid_y * cell_size.y
	position = Vector3(center_world_x, 0.0, center_world_z)

	# 3. 下发 Shader 参数
	shader_mat.set_shader_parameter(&"cell_size", cell_size)
