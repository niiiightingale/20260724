class_name JumpPrepareState
extends State

@export var anim_name: String = "jump_prepare"

func enter() -> void:
	if player.anim_player:
		player.anim_player.play(anim_name)
		# 监听动画播放结束信号
		if not player.anim_player.animation_finished.is_connected(_on_animation_finished):
			player.anim_player.animation_finished.connect(_on_animation_finished)

func exit() -> void:
	# 退出状态时断开信号绑定，防止误触发
	if player.anim_player and player.anim_player.animation_finished.is_connected(_on_animation_finished):
		player.anim_player.animation_finished.disconnect(_on_animation_finished)

func physics_update(_delta: float) -> void:
	# 保持水平方向摩擦减速
	player.velocity.x = move_toward(player.velocity.x, 0, 10.0)
	player.velocity.z = move_toward(player.velocity.z, 0, 10.0)
	player.move_and_slide()

func _on_animation_finished(anim_played: String) -> void:
	if anim_played == anim_name:
		# 前摇播放完毕：给予向上初速度，并正式切入上升状态
		player.velocity.y = player.jump_velocity
		state_machine.transition_to("rise")
