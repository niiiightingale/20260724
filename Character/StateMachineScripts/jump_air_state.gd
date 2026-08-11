class_name JumpAirState
extends State

func enter() -> void:
	# 告诉 AnimationTree 接入 AirState 混合节点
	player.travel_to_anim("JumpAirState")
