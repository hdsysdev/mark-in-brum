extends Node
## Bootstrap entry point. Boots autoload-owned services into a usable state,
## then loads the main GameRoot scene and hands over control.


func _ready() -> void:
	# Small delay lets engine window/surface settle on Web before announcing.
	await get_tree().process_frame
	GameEvents.game_ready.emit()
	_change_to_game_root()


func _change_to_game_root() -> void:
	const GAME_ROOT_PATH: String = "res://scenes/main/game_root.tscn"
	if not ResourceLoader.exists(GAME_ROOT_PATH):
		# Task 1 stage: GameRoot does not exist yet. Stay alive and announce only.
		return
	get_tree().change_scene_to_file(GAME_ROOT_PATH)
	GameEvents.session_started.emit()
