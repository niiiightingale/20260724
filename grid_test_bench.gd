# grid_test_bench.gd
# 网格集成测试场景装配器：负责统一初始化、显式注入所有组件依赖，杜绝树盲搜
extends Node3D
class_name GridTestBench

@export_group("场景装配依赖 (Explicit Scene Wiring)")
@export var conductor: BeatConductor = null
@export var grid_manager: GridManager = null
@export var player_actor: GridActor = null
@export var player_controller: PlayerGridController = null
@export var beat_clock: BeatClock3D = null
@export var npc_agent: NPCInstructionAgent = null

@export_group("初始生成配置")
@export var player_start_pos: Vector2i = Vector2i(0, 0)
@export var npc_start_pos: Vector2i = Vector2i(2, 2)


## 场景启动时统一装配所有组件依赖与信号拓扑
func _ready() -> void:
	assert(conductor != null, "[GridTestBench] conductor 未注入！")
	assert(grid_manager != null, "[GridTestBench] grid_manager 未注入！")
	assert(player_actor != null, "[GridTestBench] player_actor 未注入！")
	assert(player_controller != null, "[GridTestBench] player_controller 未注入！")
	assert(beat_clock != null, "[GridTestBench] beat_clock 未注入！")

	# 1. 装配玩家系统
	player_actor.setup(grid_manager, player_start_pos)
	player_controller.setup(conductor, player_actor)

	# 2. 装配视觉时钟
	beat_clock.setup(conductor)

	# 3. 装配指令巡逻 NPC
	if npc_agent != null:
		npc_agent.setup(conductor, grid_manager, npc_start_pos)
