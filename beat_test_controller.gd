# beat_test_controller.gd
# 节拍系统集成测试与装配调度控制器：负责测试场景的依赖装配及空格测试输入转发
extends Node
class_name BeatTestController

@export_group("外部依赖注入 (Explicit Dependencies)")
@export var conductor: BeatConductor = null ## 关联的节拍发生器组件引用
@export var clock: BeatClock3D = null ## 关联的 3D 节拍时钟视觉组件引用


## 节点初始化：严格断言依赖项并完成组件装配与信号监听
func _ready() -> void:
	assert(conductor != null, "[BeatTestController] conductor 依赖未注入！")
	assert(clock != null, "[BeatTestController] clock 依赖未注入！")

	# 装配阶段：将节拍源注入到视觉时钟组件中
	clock.setup(conductor)

	# 订阅节拍到达广播
	conductor.beat_hit.connect(_on_beat_hit)


## 输入监听：拦截 ui_accept (空格键)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		_handle_action_input()


## 处理单次行动输入：调用 Conductor 消费节拍并输出判定
func _handle_action_input() -> void:
	assert(conductor != null, "[BeatTestController] conductor 为空，无法执行判定！")

	var offset: float = conductor.get_current_time_offset()

	if conductor.has_acted_this_beat:
		print_rich("[color=yellow][SPAM / IGNORED][/color] 当前拍已消耗，忽略连按操作。")
		return

	var is_success: bool = conductor.try_consume_beat()
	if is_success:
		print_rich("[color=green][HIT SUCCESS][/color] 判定合规！当前时间偏差: [color=cyan]%.4f s[/color]" % offset)
	else:
		print_rich("[color=red][HIT MISS][/color] 判定违规/脱节！时间偏差过大: [color=orange]%.4f s[/color] (容差: %.2f s)" % [offset, conductor.tolerance_sec])


## 节拍广播回调：正拍到达提示
func _on_beat_hit(beat_index: int) -> void:
	print_rich("[color=gray][BEAT PULSE][/color] 第 [b]%d[/b] 拍到达" % beat_index)
