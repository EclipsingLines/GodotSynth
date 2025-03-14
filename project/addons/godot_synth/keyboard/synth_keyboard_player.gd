class_name SynthPlayer extends Node

@export var sound:SynthConfiguration
# Called when the node enters the scene tree for the first time.
var synth
var active_notes = {}  # Dictionary to track active notes by ID -> array of contexts
var released_notes = [] # Array to track notes that have been released but still have active tails

func _ready() -> void:
	synth = AudioSynthPlayer.new()
	synth.configuration = sound
	add_child(synth)
	for key in %HBoxContainer.get_children():
		if key is PianoKey:
			key.trigger_note.connect(play_note)
			key.stop_note.connect(stop_note)

func _process(_delta: float) -> void:
	# Check for finished notes and remove them from the released_notes array
	var i = released_notes.size() - 1
	while i >= 0:
		var context = released_notes[i]
		if context and context.is_note_finished():
			# Explicitly unref the context to ensure it's properly released
			released_notes[i] = null
			released_notes.remove_at(i)
		i -= 1

func stop_note(id:int):
	if id in active_notes and active_notes[id].size() > 0:
		# Get the oldest context (first one in the array)
		var context:SynthNoteContext = (active_notes[id] as Array).pop_back()
		# Call note_off on the context
		if context:
			# Make sure the context is valid before calling note_off
			if is_instance_valid(context):
				context.note_off(context.absolute_time)
				# Add to released notes array to track until tail is finished
				released_notes.append(context)
			else:
				print("Context is not valid!")
		
		# Remove the entry if no more contexts for this ID
		if active_notes[id].size() == 0:
			active_notes.erase(id)
	
func play_note(midi:MidiNotes.MidiNote, id:int):
	var note_instance := MusicNote.new(midi)
	note_instance.velocity = 1
	note_instance.midi_note = midi
	
	# Create array for this ID if it doesn't exist
	if not active_notes.has(id):
		active_notes[id] = Array()
	
	# Add a new context to the array for this ID
	var context:SynthNoteContext = synth.get_context();
	
	# Make sure any previous context for this note is properly released
	if id in active_notes and active_notes[id].size() > 0:
		var old_contexts = active_notes[id].duplicate()
		for old_context in old_contexts:
			if old_context and is_instance_valid(old_context) and old_context.is_note_active_state():
				old_context.note_off(old_context.absolute_time)
				released_notes.append(old_context)
	
	# Start the new note
	context.note_on(note_instance.midi_note, note_instance.velocity)
	(active_notes[id] as Array).push_front(context)
	
