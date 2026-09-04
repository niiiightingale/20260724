# grid_manager.gd
# 空间离散网格管理器：作为网格世界的单一事实来源 (Single Source of Truth)，维护网格尺寸、边界与占用哈希表
extends Node3D
class_name GridManager

## 实体成功在网格中转移占位广播信号
signal actor_moved(actor: Node3D, from_pos: Vector2i, to_pos: Vector2i)
## 实体移动请求被阻挡广播信号
signal move_denied(actor: Node3D, target_pos: Vector2i)

const DEFAULT_CELL_WIDTH: float = 0.5
const DEFAULT_CELL_HEIGHT: float = 0.5

@export_group("网格配置")
@export var cell_size: Vector2 = Vector2(DEFAULT_CELL_WIDTH, DEFAULT_CELL_HEIGHT): ## 单个网格单元尺寸 (米)
	set(value):
		cell_size = Vector2(maxf(value.x, 0.1), maxf(value.y, 0.1))
@export var grid_bounds: Rect2i = Rect2i(-10, -10, 20, 20) ## 网格合法逻辑坐标矩形边界

@export_group("外部依赖注入 (Explicit Dependencies)")
@export var visualizer: GridVisualizer3D = null ## 关联的网格可视化组件引用

# 逻辑占用字典映射表：Vector2i -> Node3D 实体
var occupied_cells: Dictionary[Vector2i, Node3D] = {}


## 节点初始化：严格校验并装配可视化组件
func _ready() -> void:
	if visualizer != null:
		visualizer.setup(cell_size, grid_bounds)


## 将离散二维网格坐标转换为连续三维世界坐标 (XZ 平面)
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var world_x: float = float(grid_pos.x) * cell_size.x
	var world_z: float = float(grid_pos.y) * cell_size.y
	return Vector3(world_x, 0.0, world_z)


## 将连续三维世界坐标转换为最近的离散二维网格坐标
func world_to_grid(world_pos: Vector3) -> Vector2i:
	var grid_x: int = int(roundf(world_pos.x / cell_size.x))
	var grid_y: int = int(roundf(world_pos.z / cell_size.y))
	return Vector2i(grid_x, grid_y)


## 校验指定单元格是否超出边界或被其他实体占用
func is_cell_blocked(grid_pos: Vector2i) -> bool:
	if not grid_bounds.has_point(grid_pos):
		return true
	return occupied_cells.has(grid_pos)


## 初始注册实体占位
func register_actor(actor: Node3D, initial_pos: Vector2i) -> void:
	assert(actor != null, "[GridManager] 注册实体不可为空！")
	assert(grid_bounds.has_point(initial_pos), "[GridManager] 注册坐标超出网格边界！")
	assert(not occupied_cells.has(initial_pos), "[GridManager] 注册坐标已被占用！")

	occupied_cells[initial_pos] = actor


## 注销实体占位
func unregister_actor(grid_pos: Vector2i) -> void:
	if occupied_cells.has(grid_pos):
		occupied_cells.erase(grid_pos)


## 请求原子转移占位：先校验目标合法性，成功则立即更新占用表
func request_move(actor: Node3D, from_pos: Vector2i, to_pos: Vector2i) -> bool:
	assert(actor != null, "[GridManager] 请求移动的实体不可为空！")

	if is_cell_blocked(to_pos):
		move_denied.emit(actor, to_pos)
		return false

	if occupied_cells.has(from_pos) and occupied_cells[from_pos] == actor:
		occupied_cells.erase(from_pos)

	occupied_cells[to_pos] = actor
	actor_moved.emit(actor, from_pos, to_pos)
	return true
