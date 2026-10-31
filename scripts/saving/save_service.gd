class_name SaveService
extends RefCounted
## Local save/load service.  The save file is plain JSON in the Godot user data
## directory so it can be inspected and repaired by hand.
##
## Robustness rules:
##  * the file is written atomically (temp file + rename),
##  * a missing file is not an error, it simply yields a fresh profile,
##  * a corrupted or unreadable file is moved aside and a fresh profile is
##    returned instead of crashing at startup,
##  * unknown content ids are dropped by Game.validate_loaded_state().

const SAVE_PATH: String = "user://ashen_vanguard.save.json"
const TEMP_PATH: String = "user://ashen_vanguard.save.tmp.json"
const CORRUPT_PATH: String = "user://ashen_vanguard.save.corrupt.json"
const SCHEMA_VERSION: int = 1


static func save_state(state: GameState) -> bool:
	if state == null:
		return false
	var payload: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
	}
	payload.merge(state.to_dict(), true)
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: could not open %s (error %d)" % [TEMP_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	# Atomic-ish replace.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var error: int = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(TEMP_PATH),
		ProjectSettings.globalize_path(SAVE_PATH))
	if error != OK:
		push_error("SaveService: could not finalise save file (error %d)" % error)
		return false
	return true


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Loads the profile.  Always returns a usable GameState.
## The dictionary contains: ok (bool), state (GameState), message (String).
static func load_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"ok": true, "state": GameState.new(), "message": "No save found, starting a new profile."}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "state": GameState.new(), "message": "Save file could not be opened."}
	var text: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	var error: int = parser.parse(text)
	if error != OK:
		_quarantine()
		return {
			"ok": false,
			"state": GameState.new(),
			"message": "Save file was corrupted and has been moved aside. A fresh profile was started.",
		}
	var data: Variant = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		_quarantine()
		return {
			"ok": false,
			"state": GameState.new(),
			"message": "Save file was not a valid profile and has been moved aside.",
		}
	var dict: Dictionary = data
	var version: int = int(dict.get("schema_version", 0))
	if version != SCHEMA_VERSION:
		_quarantine()
		return {
			"ok": false,
			"state": GameState.new(),
			"message": "Save file used schema version %d but %d is expected. A fresh profile was started." % [version, SCHEMA_VERSION],
		}
	return {"ok": true, "state": GameState.from_dict(dict), "message": "Profile loaded."}


static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


static func _quarantine() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(SAVE_PATH),
			ProjectSettings.globalize_path(CORRUPT_PATH))
