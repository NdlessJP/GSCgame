class_name UITests
extends RefCounted
## Smoke tests for the screens.
##
## Every screen is instantiated, given a few frames and then inspected.  The
## checks are deliberately structural rather than visual: they catch the
## mistakes that are easy to make with containers and anchors (a panel that
## collapses to zero size, a screen that never builds its widgets, an overlay
## that does not cover the viewport).

const SCREENS: Array = [
	["main menu", "res://scenes/main_menu/main_menu.tscn"],
	["party setup", "res://scenes/party/party_setup.tscn"],
	["quest board", "res://scenes/quests/quest_select.tscn"],
	["battle", "res://scenes/battle/battle.tscn"],
	["results", "res://scenes/battle/results_screen.tscn"],
]


static func run(host: Node) -> TestKit.Result:
	var result: TestKit.Result = TestKit.Result.new()
	# The battle screen navigates back to the quest board when there is no
	# quest to run.  That would replace the current scene (the test runner),
	# so a quest is selected for the duration of the test.
	var saved_quest: StringName = Game.pending_quest_id
	Game.pending_quest_id = &"quest_cinder_road"
	for entry: Array in SCREENS:
		await _check_screen(host, String(entry[0]), String(entry[1]), result)
	await _check_help_overlay(host, result)
	Game.pending_quest_id = saved_quest
	return result


## Instantiates one screen and verifies that it built something and that its
## root actually covers the viewport.
static func _check_screen(host: Node, label: String, path: String, result: TestKit.Result) -> void:
	var packed: PackedScene = load(path)
	result.ok(packed != null, "The %s scene exists" % label)
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	result.ok(scene != null, "The %s scene can be instantiated" % label)
	if scene == null:
		return
	host.add_child(scene)
	for i in range(5):
		await host.get_tree().process_frame

	result.ok(scene.get_child_count() > 0, "The %s screen builds its widgets" % label)
	# The root is not always a Control (the battle is a Node2D), so the first
	# Control in the tree is used for the layout checks.
	var control: Control = scene as Control
	if control == null:
		control = _first_control(scene)
	result.ok(control != null, "The %s screen has a control root" % label)
	if control != null:
		result.ok(control.size.x > 100.0 and control.size.y > 100.0,
			"The %s screen covers the viewport (got %s)" % [label, str(control.size)])
		# Every visible button must have a usable size, otherwise it cannot be
		# clicked.
		var buttons: Array[Button] = _collect_buttons(control)
		result.ok(buttons.size() > 0, "The %s screen has buttons" % label)
		var broken: int = 0
		for button: Button in buttons:
			if button.size.x < 4.0 or button.size.y < 4.0:
				broken += 1
		result.ok(broken == 0, "Every button on the %s screen has a usable size (%d broken)" % [label, broken])

	host.remove_child(scene)
	scene.free()
	await host.get_tree().process_frame


## The controls overlay has to cover the whole viewport, otherwise it would
## only dim a corner of the screen.
static func _check_help_overlay(host: Node, result: TestKit.Result) -> void:
	var parent: Control = Control.new()
	parent.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(parent)
	var overlay: HelpOverlay = HelpOverlay.new()
	parent.add_child(overlay)
	for i in range(5):
		await host.get_tree().process_frame
	result.ok(overlay.size.x > 100.0 and overlay.size.y > 100.0,
		"The controls overlay covers the viewport (got %s)" % str(overlay.size))
	result.ok(overlay.visible, "The controls overlay is visible by default")

	host.remove_child(parent)
	parent.free()
	await host.get_tree().process_frame


## Returns the first Control found in the tree.
static func _first_control(node: Node) -> Control:
	if node is Control:
		return node as Control
	for child: Node in node.get_children():
		var found: Control = _first_control(child)
		if found != null:
			return found
	return null


static func _collect_buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	if node is Button:
		found.append(node as Button)
	for child: Node in node.get_children():
		found.append_array(_collect_buttons(child))
	return found
