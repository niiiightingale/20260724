class_name LandState
extends State

@export var land_time: float = 0.15
var timer: float = 0.0

func enter() -> void:
	timer = land_time
	player.travel_to_anim("land")

func physics_update(delta: float) -> void:
	timer -= delta

	# 1. 条件转移：如果有移动输入，允许玩家打断落地硬直，立即切回移动
	if player.input_dir.length() > 0:
		state_machine.transition_to("grounded_state")
		return

	# 2. 条件转移：如果落地瞬间又按了跳跃 -> 再次进入起跳前摇
	if player.jump_just_pressed:
		state_machine.transition_to("jumpprepare")
		return

	# 落地惯性减速
	player.velocity.x = lerp(player.velocity.x, 0.0, player.friction * delta)
	player.velocity.z = lerp(player.velocity.z, 0.0, player.friction * delta)
	player.move_and_slide()

	# 缓冲自然结束 -> 切回 Idle
	if timer <= 0.0:
		state_machine.transition_to("grounded_state")
