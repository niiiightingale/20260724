class_name StateMachine
extends Node

# 定义状态切换信号，将新状态的名字传出去
signal state_changed(new_state_name: String)

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

# 改用独立初始化函数，由 Player 在自身的 _ready() 中主动调用
func init(player: CharacterBody3D) -> void:
	# 注册所有子状态节点
	for child in get_children():
		if child is State:
			var state_name = child.name.to_lower()
			states[state_name] = child
			child.player = player
			child.state_machine = self
	
	# 初始化默认状态
	if initial_state:
		current_state = initial_state
		current_state.enter()
		# 发射初始状态名称信号
		state_changed.emit(current_state.name)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition_to(target_state_name: String) -> void:
	var key = target_state_name.to_lower()
	if not states.has(key):
		push_error("错误：试图切换到未注册的状态 -> " + target_state_name)
		return
	
	if current_state:
		current_state.exit()
	
	current_state = states[key]
	current_state.enter()
	
	# 状态切换成功后发射信号
	state_changed.emit(current_state.name)
