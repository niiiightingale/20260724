# grid_actor.gd
# 网格步进实体基类：管理整数坐标 Vector2i 与世界坐标平滑补间，彻底解耦物理引擎
extends Node3D
class_name GridActor

## 实体开始步进补间信号
signal step_started(target_grid_pos: Vector2i)
## 实体完成步进补间信号
signal step_finished(new_grid_pos: Vector2i)
## 实体步进受阻信号
signal step_blocked(target_grid_pos: Vector2i)

const DEFAULT_STEP_DURATION: float = 0.15

@export_group("移动动画配置")
@export var step_duration: float = DEFAULT_STEP_DURATION ## 单元格移动平滑补间耗时 (秒)

var current_grid_pos: Vector2i = Vector2i.ZERO
var is_moving: bool = false
var grid_manager: GridManager = null
var move_tween: Tween = null


## 外部显式依赖注入：注册网格并同步初始世界位置
func setup(manager: GridManager, initial_grid_pos: Vector2i) -> void:
	assert(manager != null, "[GridActor] GridManager 注入失败：实例为 null！")
	grid_manager = manager
	current_grid_pos = initial_grid_pos
	grid_manager.register_actor(self, current_grid_pos)
	global_position = grid_manager.grid_to_world(current_grid_pos)


## 请求沿指定四向网格基向量移动一格
func try_step(direction: Vector2i) -> bool:
	assert(grid_manager != null, "[GridActor] GridManager 未注入！")
	if is_moving:
		return false

	var target_grid_pos: Vector2i = current_grid_pos + direction
	var can_move: bool = grid_manager.request_move(self, current_grid_pos, target_grid_pos)

	if not can_move:
		step_blocked.emit(target_grid_pos)
		return false

	_execute_movement_tween(target_grid_pos)
	return true


## 执行平滑补间位移
func _execute_movement_tween(target_pos: Vector2i) -> void:
	is_moving = true
	step_started.emit(target_pos)

	var target_world: Vector3 = grid_manager.grid_to_world(target_pos)

	if move_tween != null and move_tween.is_valid():
		move_tween.kill()

	move_tween = create_tween()
	move_tween.set_trans(Tween.TRANS_QUAD)
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.tween_property(self, ^"global_position", target_world, step_duration)
	move_tween.tween_callback(_on_step_completed.bind(target_pos))


## 补间完成回调：更新内部坐标状态并解除移动锁
func _on_step_completed(new_pos: Vector2i) -> void:
	current_grid_pos = new_pos
	is_moving = false
	step_finished.emit(new_pos)
