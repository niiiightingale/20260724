class_name LandState
extends State

@export var anim_name: String = "land"

func enter() -> void:
	if player.anim_player:
		player.anim_player.play(anim_name)
		if not player.anim_player.animation_finished.is_connected(_on_animation_finished):
			player.anim_player.animation_finished.connect(_on_animation_finished)

func exit() -> void:
	if player.anim_player and player.anim_player.animation_finished.is_connected(_on_animation_finished):
		player.anim_player.animation_finished.disconnect(_on_animation_finished)

func physics_update(_delta: float) -> void:
	# 落地减速
	player.velocity.x = move_toward(player.velocity.x, 0, 15.0)
	player.velocity.z = move_toward(player.velocity.z, 0, 15.0)
	player.move_and_slide()

	# --- 打断判定（优化移动手感） ---
	# 如果在落地缓冲期间玩家输入了移动，强制打断缓冲，直接切入 Run
	if player.input_dir.length() > 0:
		state_machine.transition_to("run")

func _on_animation_finished(anim_played: String) -> void:
	if anim_played == anim_name:
		# 缓冲动画播放完毕，自然恢复 Idle
		state_machine.transition_to("idle")
