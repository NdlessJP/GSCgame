extends Node
## Headless test runner.
##
##   godot --headless --path . res://tests/test_runner.tscn
##
## Exits with code 0 when every check passes and 1 otherwise.  The runner is a
## scene (not a `--script`) so that the autoload singletons are registered
## before the test scripts are compiled.

var _failed: int = 0
var _passed: int = 0
var _save_backup: String = ""


func _ready() -> void:
	# Keep the player's profile untouched by the test run.
	if FileAccess.file_exists(SaveService.SAVE_PATH):
		var file: FileAccess = FileAccess.open(SaveService.SAVE_PATH, FileAccess.READ)
		_save_backup = file.get_as_text()
		file.close()
	# Watchdog so a broken test can never hang the run.
	var watchdog: SceneTreeTimer = get_tree().create_timer(120.0)
	watchdog.timeout.connect(func() -> void:
		print("=== TIMEOUT: the test run was aborted ===")
		get_tree().quit(2))
	_run.call_deferred()


func _run() -> void:
	# Wait for the first frames so that the autoload singletons are ready.
	await get_tree().process_frame
	await get_tree().process_frame

	print("=== Ashen Vanguard test suite ===")
	var database: GameDatabase = GameDatabase.load_all()
	if not database.load_issues.is_empty():
		for issue: String in database.load_issues:
			print("  content issue: %s" % issue)
	print("loaded content: %d characters, %d enemies, %d items, %d quests" % [
		database.characters.size(), database.enemies.size(),
		database.equipment.size(), database.quests.size()])

	var combat: TestKit.Result = CombatTests.run(database)
	_report("combat", combat)

	var progression: TestKit.Result = ProgressionTests.run(database)
	_report("progression", progression)

	var flow: TestKit.Result = await BattleFlowTests.run(self)
	_report("battle flow", flow)

	# Restore the profile that was there before the test run.
	if _save_backup != "":
		var restore: FileAccess = FileAccess.open(SaveService.SAVE_PATH, FileAccess.WRITE)
		restore.store_string(_save_backup)
		restore.close()

	print("=== %d passed, %d failed ===" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _report(suite: String, result: TestKit.Result) -> void:
	_passed += result.passed
	_failed += result.failed
	var status: String = "OK" if result.failed == 0 else "FAILED"
	print("[%s] %s  (%d checks, %d failed)" % [suite, status, result.passed + result.failed, result.failed])
	for failure: String in result.failures:
		print("    - %s" % failure)
