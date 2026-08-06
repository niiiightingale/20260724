class_name JumpPrepareState
extends State

@export var prepare_time: float = 0.12 # 前摇持续时间（与动画长度匹配）
var timer: float = 0.0

func enter() -> void:
	timer = prepare_time
	# 驱动动画状态机切到 jump_prepare 节点
	player.travel_to_anim("jump_prepare")

func physics_update(delta: float) -> void:
	timer -= delta
	
	# 前摇期间限制水平移动，保持惯性减速
	player.velocity.x = lerp(player.velocity.x, 0.0, player.friction * delta)
	player.velocity.z = lerp(player.velocity.z, 0.0, player.friction * delta)
	player.move_and_slide()

	# 前摇时间到 -> 赋予向上初速度，切入空中状态 Air
	if timer <= 0.0:
		player.velocity.y = player.jump_velocity
		state_machine.transition_to("air_state") # 注意：这里填你 StateMachine 节点下 InAirState 的名字
