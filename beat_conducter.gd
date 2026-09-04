# beat_conductor.gd
# 节拍发生与判定器：基于 Timer 循环、二元合规判定 (成功/失败) 与单拍防重判机制
extends Node
class_name BeatConductor

## 节拍到达广播信号
signal beat_hit(beat_index: int)

const SECONDS_PER_MINUTE: float = 60.0

@export_group("外部依赖注入 (Explicit Dependencies)")
@export var beat_timer: Timer = null ## 驱动节拍周期的计时器引用
@export var click_audio: AudioStreamPlayer = null ## 节拍提示音播放器引用

@export_group("节奏与判定配置")
@export var bpm: float = 60.0: ## 每分钟节拍数 (Beats Per Minute)
	set(value):
		bpm = maxf(value, 1.0)
		_update_timer_wait_time()
@export var tolerance_sec: float = 0.2 ## 节拍有效判定容差区间 (秒)

var current_beat_index: int = 0
var has_acted_this_beat: bool = false


## 节点初始化：严格断言依赖并启动计时
func _ready() -> void:
	assert(beat_timer != null, "[BeatConductor] beat_timer 依赖未注入！")
	_update_timer_wait_time()
	beat_timer.timeout.connect(_on_beat_timer_timeout)
	if beat_timer.is_inside_tree() and beat_timer.is_stopped():
		beat_timer.start()


## 计时器周期回调：重置单拍行为标记、播放提示音并广播节拍信号
func _on_beat_timer_timeout() -> void:
	current_beat_index += 1
	has_acted_this_beat = false

	if click_audio != null:
		click_audio.play()

	beat_hit.emit(current_beat_index)


## 尝试消费当前拍（核心判定接口）：检查防重判与容差窗口，返回是否合规
func try_consume_beat() -> bool:
	assert(beat_timer != null, "[BeatConductor] beat_timer 未配置！")
	if has_acted_this_beat or beat_timer.is_stopped():
		return false

	var time_offset: float = get_current_time_offset()
	if time_offset <= tolerance_sec:
		has_acted_this_beat = true
		return true

	return false


## 获取当前节拍的时间偏差绝对值
func get_current_time_offset() -> float:
	assert(beat_timer != null, "[BeatConductor] beat_timer 未配置！")
	if beat_timer.is_stopped():
		return 0.0
	var time_left: float = beat_timer.time_left
	var wait_time: float = beat_timer.wait_time
	return minf(time_left, wait_time - time_left)


## 动态刷新 Timer 的 wait_time
func _update_timer_wait_time() -> void:
	if beat_timer != null:
		beat_timer.wait_time = SECONDS_PER_MINUTE / bpm
