extends Node
class_name Initialize

@export var player: Player = null
@export var camera_controller: CameraController = null

func _ready() -> void:
	if camera_controller != null and player != null:
		camera_controller.setup(player)
