class_name MusicTheme extends RefCounted

var root_note: int
var scale_type: MusicScales.ScaleType
var base_notes: Array
var notes:Array[MusicNote] = []
var current_variation: int = 0
var rhythm_bpm: float = 60.0
var rhythm_pattern: MusicRhythms.RhythmType

func _init(root: int = 60, scale: MusicScales.ScaleType = MusicScales.ScaleType.MAJOR, bpm: float = 80.0):
	root_note = root
	scale_type = scale
	rhythm_bpm = bpm
	generate_base_theme()

func generate_base_theme():
	base_notes = MusicScales.get_scale(root_note, scale_type)
	#var degrees = MusicScales.get_scale(root_note,MusicScales.ScaleType.HARMONIC_MINOR)
	#base_notes = degrees.map(func(d): return base_notes[d % base_notes.size()])
	# Add rhythmic motif (call-response pattern)
	notes = [
		MusicNote.new( base_notes[0], 1.5),
		MusicNote.new( base_notes[2], 0.5),
		MusicNote.new( base_notes[3], 2.0),
		MusicNote.new( base_notes[1], 1.0),
		]
func generate_variation(intensity: float = 0.5) -> Array[MusicNote]:
	var variation:Array[MusicNote] = []
	
	# Create variations using music theory techniques
	for note in notes:
		var new_note = note.duplicate()
		
		# Apply variation techniques
		if randf() < intensity:
			# Octave displacement
			if randf() < 0.3:
				new_note.midi_note += 12 * (1 if randf() > 0.5 else -1)
			
			# Neighbor tone ornamentation
			if randf() < 0.4:
				new_note.midi_note += [-1, 1].pick_random()
				new_note.duration *= 0.5
				variation.append(new_note)
				new_note = note.duplicate()  # Return to original
			
			# Rhythmic displacement
			if randf() < 0.3:
				new_note.duration *= [0.5, 1.5].pick_random()
			
			# Sequence repetition
			if randf() < 0.2:
				var seq_length = randi_range(2, 3)
				var step = [-2, -1, 1, 2].pick_random()
				for s in seq_length:
					var seq_note = new_note.duplicate()
					seq_note.midi_note += step * s
					variation.append(seq_note)
		
		variation.append(new_note)
	
	return apply_rhythm_pattern(variation)

func apply_rhythm_pattern(notes: Array[MusicNote]) -> Array[MusicNote]:
	var pattern = MusicRhythms.get_rhythm(rhythm_pattern)
	var note_index = 0
	
	# Quantize durations to rhythm pattern
	for note in notes:
		note.duration = pattern[note_index % pattern.size()] * (60.0 / rhythm_bpm)
		note_index += 1
		
		# Add occasional triplets
		if randf() < 0.15:
			notes.insert(note_index + 1, MusicNote.new(note.midi_note - 1, note.duration * 0.333))
			notes.insert(note_index + 2, MusicNote.new(note.midi_note - 2, note.duration * 0.333))
			
			note_index += 2
	
	return notes
