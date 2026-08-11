class_name FallState
extends State

func enter() -> void:
	player.travel_to_anim("fall")

func physics_update(delta: float) -> void:
	pass
