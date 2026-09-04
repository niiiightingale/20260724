# npc_instruction_agent.gd
# 巡逻实体指令驱动控制器：按节拍顺序执行离散移动与转向指令流，解耦表现层旋转与逻辑网格位移
extends Node
class_name NPCInstructionAgent

enum CommandType {
	STEP = 0,       ## 沿当前面向步进一格
	TURN_LEFT = 1,  ## 逆时针原地转向 90 度
	TURN_RIGHT = 2, ## 顺时针原地转向 90 度
	WAIT = 3,       ## 原地等待单拍
}

const ROTATION_TWEEN_DURATION: float = 0.12

# 严格按顺时针定义的四个离散正交网格基向量
const DIR_CYCLE: Array[Vector2i] = [
	Vector2i(0, -1), # 0: 北 (Z-)
	Vector2i(1, 0),  # 1: 东 (X+)
	Vector2i(0, 1),  # 2: 南 (Z+)
	Vector2i(-1, 0)  # 3: 西 (X-)
]

@export_group("外部依赖注入 (Explicit Dependencies)")
@export var actor: GridActor = null ## 关联的网格步进执行者
@export var visual_pivot: Node3D = null ## 关联的视觉旋转承载节点

@export_group("巡逻指令流配置")
@export var initial_facing: Vector2i = Vector2i(0, -1) ## 初始逻辑面向 (默认北向)
@export var loop_instructions: bool = true ## 执行完毕后是否循环
@export var instructions: Array[CommandType] = [
	CommandType.STEP,
	CommandType.STEP,
	CommandType.TURN_LEFT,
	CommandType.STEP,
	CommandType.STEP,
	CommandType.TURN_LEFT,
	CommandType.STEP,
	CommandType.STEP,
	CommandType.TURN_LEFT,
	CommandType.STEP,
	CommandType.STEP,
	CommandType.TURN_LEFT
]

var conductor_ref: BeatConductor = null
var current_dir_index: int = 0
var instruction_pointer: int = 0
var rotate_tween: Tween = null


## 外部依赖显式装配：建立网格初始状态并订阅节拍源
func setup(conductor: BeatConductor, manager: GridManager, start_pos: Vector2i) -> void:
	assert(conductor != null, "[NPCInstructionAgent] conductor 依赖不可为空！")
	assert(manager != null, "[NPCInstructionAgent] manager 依赖不可为空！")
	assert(actor != null, "[NPCInstructionAgent] actor 依赖未指定！")
	assert(visual_pivot != null, "[NPCInstructionAgent] visual_pivot 依赖未指定！")

	conductor_ref = conductor
	current_dir_index = _resolve_direction_index(initial_facing)

	actor.setup(manager, start_pos)
	_update_visual_orientation(false)

	if not conductor_ref.beat_hit.is_connected(_on_beat_hit):
		conductor_ref.beat_hit.connect(_on_beat_hit)


## 节拍广播回调：按拍消费指令序列
func _on_beat_hit(_beat_index: int) -> void:
	assert(actor != null, "[NPCInstructionAgent] actor 引用为空！")
	if instructions.is_empty() or instruction_pointer >= instructions.size():
		return

	if actor.is_moving:
		push_warning("[NPCInstructionAgent] 上一次步进尚未完成，可能步进时间大于单拍间隔！")
		return

	var cmd: CommandType = instructions[instruction_pointer]
	_execute_command(cmd)


## 执行单条指令
func _execute_command(cmd: CommandType) -> void:
	match cmd:
		CommandType.STEP:
			var facing_dir: Vector2i = DIR_CYCLE[current_dir_index]
			var success: bool = actor.try_step(facing_dir)
			if success:
				_advance_pointer()
			else:
				var target_pos: Vector2i = actor.current_grid_pos + facing_dir
				print_rich("[color=yellow][NPC BLOCKED][/color] 步进受阻，目标位置: ", target_pos)

		CommandType.TURN_LEFT:
			current_dir_index = (current_dir_index + 3) % 4
			_update_visual_orientation(true)
			_advance_pointer()

		CommandType.TURN_RIGHT:
			current_dir_index = (current_dir_index + 1) % 4
			_update_visual_orientation(true)
			_advance_pointer()

		CommandType.WAIT:
			_advance_pointer()


## 步进指令程序计数器
func _advance_pointer() -> void:
	instruction_pointer += 1
	if instruction_pointer >= instructions.size() and loop_instructions:
		instruction_pointer = 0


## 获取二维方向向量在状态环中的索引
func _resolve_direction_index(dir: Vector2i) -> int:
	var idx: int = DIR_CYCLE.find(dir)
	assert(idx != -1, "[NPCInstructionAgent] 非法的初始面向向量: " + str(dir))
	return idx
	


## 依据离散逻辑面向插值驱动视觉组件旋转
func _update_visual_orientation(use_tween: bool) -> void:
	var facing_dir: Vector2i = DIR_CYCLE[current_dir_index]
	var target_yaw: float = atan2(float(-facing_dir.x), float(-facing_dir.y))

	if not use_tween:
		visual_pivot.rotation.y = target_yaw
		return

	if rotate_tween != null and rotate_tween.is_valid():
		rotate_tween.kill()

	rotate_tween = create_tween()
	rotate_tween.set_trans(Tween.TRANS_QUAD)
	rotate_tween.set_ease(Tween.EASE_OUT)
	rotate_tween.tween_property(visual_pivot, ^"rotation:y", target_yaw, ROTATION_TWEEN_DURATION)
