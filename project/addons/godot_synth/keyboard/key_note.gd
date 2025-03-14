class_name PianoKey extends Control
@export var note:MidiNotes.MidiNote
@onready var label
var note_on = false
func _ready() -> void:
	for child in get_children():
		if child is Button:
			(child as Button).button_down.connect(_on_button_down)
			(child as Button).button_up.connect(_on_button_up)
		if child is Label:
			label = child as Label
			(child as Label).text = (MidiNotes.MidiNote.keys()[note] as String).replace("Sharp","#")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if note_on:
		modulate = Color8(255,0,0,255)# Color.RED
	else:
		modulate = Color8(255,255,255,255) #Color.WHITE_SMOKE
	pass

signal trigger_note(note:MidiNotes.MidiNote, id:int)
signal stop_note(id:int)

func _on_button_down() -> void:
	note_on = true
	trigger_note.emit(note, get_instance_id())


func _on_button_up() -> void:
	note_on = false
	stop_note.emit(get_instance_id())
