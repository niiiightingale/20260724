extends Label

@export var state_machine: StateMachine

func _ready() -> void:
	# 如果没有在 Inspector 面板中手动拖入引用，则尝试自动寻找路径
	if not state_machine:
		state_machine = get_node_or_null("../../StateMachine")

	if state_machine:
		# 1. 绑定状态机的切换信号
		state_machine.state_changed.connect(_on_state_changed)
		
		# 2. 如果初始化时已经有 current_state，先显示当前状态
		if state_machine.current_state:
			text = "STATE: " + state_machine.current_state.name
	else:
		text = "STATE: [StateMachine Unassigned]"

# 信号回调
func _on_state_changed(new_state_name: String) -> void:
	text = "STATE: " + new_state_name
