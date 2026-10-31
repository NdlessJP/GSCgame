extends Node
## Development helper: renders every screen and writes a PNG of each one.
##
##   xvfb-run -a godot --path . res://tools/screenshot_tour.tscn
##
## The images are written to user://screenshots/.

const SHOT_DIR: String = "user://screenshots"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	await _shoot("res://scenes/main_menu/main_menu.tscn", "01_main_menu.png", 30)
	await _shoot("res://scenes/main_menu/main_menu.tscn", "06_controls.png", 30, true)
	await _shoot("res://scenes/party/party_setup.tscn", "02_party_setup.png", 30)
	await _shoot("res://scenes/quests/quest_select.tscn", "03_quest_select.png", 30)
	Game.pending_quest_id = &"quest_cinder_road"
	await _shoot("res://scenes/battle/battle.tscn", "04_battle.png", 200)
	Game.last_battle_victory = true
	Game.last_results = {
		"xp": 120, "currency": 60, "items": [],
		"levels": {&"kael_vondar": {"level": 2, "xp": 40, "levels_gained": 1}},
		"stats": {
			"duration": 42.6, "damage_dealt": 1840, "damage_taken": 612,
			"abilities": 23, "breaks": 4, "defeated": 11,
		},
	}
	await _shoot("res://scenes/battle/results_screen.tscn", "05_results.png", 30)
	print("screenshots written to ", ProjectSettings.globalize_path(SHOT_DIR))
	get_tree().quit(0)


func _shoot(scene_path: String, file_name: String, frames: int, show_help: bool = false) -> void:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		print("could not load ", scene_path)
		return
	var scene: Node = packed.instantiate()
	add_child(scene)
	if show_help:
		for child: Node in scene.get_children():
			if child is HelpOverlay:
				(child as HelpOverlay).visible = true
	for i in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s" % [SHOT_DIR, file_name]
	var error: int = image.save_png(path)
	print("%s -> %s (error %d, %dx%d)" % [scene_path, path, error, image.get_width(), image.get_height()])
	scene.queue_free()
	await get_tree().process_frame
