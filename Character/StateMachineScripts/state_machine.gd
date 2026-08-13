# state_machine.gd
# 状态机：支持动态子节点注册、StringName 指针比对优化及快捷切回地面状态
class_name StateMachine
extends Node

# 状态切换信号 (发送 StringName)
signal state_changed(new_state_name: StringName)

var current_state: State = null
var states: Dictionary = {} # Dictionary[StringName, State]


## 初始化状态机 (由 Player._ready 显式调用进行依赖注入)
func init(player: CharacterBody3D) -> void:
	states.clear()
	
	# 自动遍历并注册所有子状态节点
	for child: Node in get_children():
		if child is State:
			var key: StringName = StringName(child.name.to_lower())
			states[key] = child
			child.player = player
			child.state_machine = self

	# 默认切入 grounded_state 节点
	if states.has(&"grounded_state"):
		current_state = states[&"grounded_state"]
		current_state.enter()
		state_changed.emit(&"grounded_state")
	else:
		push_error("【StateMachine】初始化失败：找不到注册名为 'grounded_state' 的地面状态节点！")


func _unhandled_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)


func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


## 核心状态切换接口 (使用 StringName 字面量，如 transition_to(&"grounded_state"))
func transition_to(target_state_name: StringName) -> void:
	var key: StringName = StringName(target_state_name.to_lower())
	if not states.has(key):
		push_error("【StateMachine】错误：试图切换到未注册的状态 -> " + String(target_state_name))
		return
	
	if current_state != null:
		current_state.exit()
	
	current_state = states[key] as State
	current_state.enter()
	
	state_changed.emit(current_state.name)


## 快捷接口：方便直接切回地面状态 (零参数调用)
func transition_to_grounded() -> void:
	transition_to(&"grounded_state")
