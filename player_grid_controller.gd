# player_grid_controller.gd
# 玩家网格编排器：监听输入，校验节拍容差窗口，在节奏点驱动 GridActor 步进
extends Node
class_name PlayerGridController

@export_group("外部依赖注入 (Explicit Dependencies)")
@export var conductor: BeatConductor = null ## 关联的节拍发生器引用
@export var actor: GridActor = null ## 关联的网格实体引用


## 外部显式依赖注入
func setup(p_conductor: BeatConductor, p_actor: GridActor) -> void:
	assert(p_conductor != null, "[PlayerGridController] conductor 依赖不可为空！")
	assert(p_actor != null, "[PlayerGridController] actor 依赖不可为空！")
	conductor = p_conductor
	actor = p_actor


## 节点初始化检查
func _ready() -> void:
	if conductor != null and actor != null:
		setup(conductor, actor)


## 输入监听：拦截四向输入指令
func _unhandled_input(event: InputEvent) -> void:
	if actor == null or conductor == null:
		return
	if actor.is_moving:
		return

	var input_dir: Vector2i = _resolve_input_direction(event)
	if input_dir != Vector2i.ZERO:
		_process_step_request(input_dir)


## 解析按键事件为离散四向网格向量
func _resolve_input_direction(event: InputEvent) -> Vector2i:
	if event.is_action_pressed(&"ui_up"):
		return Vector2i.UP # (0, -1) -> 对应世界坐标 Z 轴负向
	if event.is_action_pressed(&"ui_down"):
		return Vector2i.DOWN # (0, 1) -> 对应世界坐标 Z 轴正向
	if event.is_action_pressed(&"ui_left"):
		return Vector2i.LEFT # (-1, 0) -> 对应世界坐标 X 轴负向
	if event.is_action_pressed(&"ui_right"):
		return Vector2i.RIGHT # (1, 0) -> 对应世界坐标 X 轴正向
	return Vector2i.ZERO


## 处理步进节拍判定与实体位移消费
func _process_step_request(direction: Vector2i) -> void:
	var is_beat_valid: bool = conductor.try_consume_beat()
	if not is_beat_valid:
		var offset: float = conductor.get_current_time_offset()
		print_rich("[color=red][MOVE MISS][/color] 节奏未命中，禁止移动！偏差: %.4f s" % offset)
		return

	var moved: bool = actor.try_step(direction)
	if moved:
		print_rich("[color=green][MOVE BEAT HIT][/color] 节奏合规，执行步进: ", direction)
