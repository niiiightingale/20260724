# state_machine.gd
# 状态机：负责子状态节点注册、显式依赖注入、StringName 状态流转与默认状态激活
extends Node
class_name StateMachine

# 状态切换信号 (携带 StringName 状态标识)
signal state_changed(new_state_name: StringName)

var current_state: State = null
var states: Dictionary = {} # Dictionary[StringName, State]


## 初始化状态机：自动注册子节点并完成显式依赖注入 (由 Player._ready 显式调用)
func init(player: CharacterBody3D) -> void:
	states.clear()
	
	for child: Node in get_children():
		if child is State:
			var key: StringName = StringName(child.name.to_lower())
			states[key] = child
			child.player = player
			child.state_machine = self

	# 默认优先切入 idle_state，回退兼容 grounded_state
	if states.has(&"idle_state"):
		current_state = states[&"idle_state"]
		current_state.enter()
		state_changed.emit(&"idle_state")
	elif states.has(&"grounded_state"):
		current_state = states[&"grounded_state"]
		current_state.enter()
		state_changed.emit(&"grounded_state")
	else:
		push_error("【StateMachine】初始化失败：未找到默认初始状态节点 (idle_state 或 grounded_state)！")


## 将未处理输入分发给当前活跃状态
func _unhandled_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)


## 帧更新逻辑分发
func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


## 物理帧更新逻辑分发
func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


## 核心状态切换接口 (显式使用 StringName 字面量，如 transition_to(&"walk_state"))
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


## 快捷接口：切回默认地面状态
func transition_to_grounded() -> void:
	if states.has(&"idle_state"):
		transition_to(&"idle_state")
	else:
		transition_to(&"grounded_state")
