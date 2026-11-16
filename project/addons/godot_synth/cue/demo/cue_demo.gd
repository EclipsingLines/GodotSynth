extends Node
## Demo of the adaptive cue runtime: a button per state and stinger, a slider for the game param,
## labels for the current state, the pending state and the cycle.

const CUE_PATH := "res://addons/godot_synth/cue/demo/forest_demo.cue"
const PlayerScript = preload("res://addons/godot_synth/cue/cue_player.gd")

var player: PlayerScript
var state_label: Label
var pending_label: Label
var cycle_label: Label
var param_label: Label
var diag_label: Label
var param_name: String = ""

func _ready() -> void:
	player = PlayerScript.new()
	player.name = "CuePlayer"
	add_child(player)
	var diagnostics: Array[Dictionary] = player.load_cue(CUE_PATH)
	player.diagnostics = diagnostics  # keeps the last load_cue() result on the node for callers/tests to read
	_build_ui(diagnostics)
	if player.is_loaded():
		player.play()

func _build_ui(diagnostics: Array[Dictionary]) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	layer.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "GodotSynth cue demo: forest_demo.cue"
	box.add_child(title)

	state_label = Label.new()
	pending_label = Label.new()
	cycle_label = Label.new()
	diag_label = Label.new()
	box.add_child(state_label)
	box.add_child(pending_label)
	box.add_child(cycle_label)
	box.add_child(diag_label)
	var messages: Array[String] = []
	for d: Dictionary in diagnostics:
		messages.append("%s %d:%d %s" % [d["severity"], d["line"], d["col"], d["message"]])
	diag_label.text = "Loaded" if player.is_loaded() and messages.is_empty() else "\n".join(messages)

	if not player.is_loaded():
		return

	var states_row := HBoxContainer.new()
	box.add_child(states_row)
	for state_name in player.get_state_names():
		var b := Button.new()
		b.text = "State: " + state_name
		b.pressed.connect(_on_state_pressed.bind(state_name))
		states_row.add_child(b)

	var stingers_row := HBoxContainer.new()
	box.add_child(stingers_row)
	for stinger_name in player.get_stinger_names():
		var b := Button.new()
		b.text = "Stinger: " + stinger_name
		b.pressed.connect(_on_stinger_pressed.bind(stinger_name))
		stingers_row.add_child(b)

	var params := player.get_param_names()
	if params.size() > 0:
		param_name = params[0]
		var range := player.get_param_range(param_name)
		param_label = Label.new()
		box.add_child(param_label)
		var slider := HSlider.new()
		slider.min_value = range.x
		slider.max_value = range.y
		slider.step = 0.01
		slider.custom_minimum_size = Vector2(300, 24)
		slider.value = player.get_param(param_name)
		slider.value_changed.connect(_on_param_changed)
		box.add_child(slider)
		_on_param_changed(slider.value)

func _on_state_pressed(state_name: String) -> void:
	player.set_state(state_name)

func _on_stinger_pressed(stinger_name: String) -> void:
	player.stinger(stinger_name)

func _on_param_changed(value: float) -> void:
	player.set_param(param_name, value)
	param_label.text = "%s: %.2f" % [param_name, player.get_param(param_name)]

func _process(_delta: float) -> void:
	if player == null or not player.is_loaded():
		return
	state_label.text = "Current state: " + player.get_state()
	var pending := player.get_pending_state()
	pending_label.text = "Next state: " + (pending if pending != "" else "-")
	cycle_label.text = "Cycle: %.2f" % player.get_current_cycle()
