
# Arpeggio Motif Generator
class_name MotifGenerator
extends RefCounted

var scale_notes: Array[int]
var current_position: int = 0
var motif_cache: Array[Array] = []

func _init(root_note: int, scale_type: MusicScales.ScaleType, octaves: int = 2):
	scale_notes = MusicScales.get_scale(root_note, scale_type, octaves)

func generate_motif(length: int, note_lengths: Array[float], pattern: String = "random") -> Array[Dictionary]:
	var motif = []
	var rhythm_pattern = generate_rhythm(note_lengths, length)
	
	match pattern:
		"ascending":
			motif = generate_arpeggio(length, 1, 1)
		"descending":
			motif = generate_arpeggio(length, -1, 1)
		"updown":
			motif = generate_arpeggio(length, 1, 2)
		"random":
			motif = generate_random_motif(length)
	
	# Apply rhythm to notes
	for i in motif.size():
		var j = i % rhythm_pattern.size()
		motif[i]["duration"] = rhythm_pattern[j]
	
	motif_cache.append(motif)
	return motif

func generate_arpeggio(length: int, direction: int, steps: int) -> Array[Dictionary]:
	var notes:Array[Dictionary] = []
	var current_step = current_position
	
	for i in range(length):
		var note_index = wrapi(current_step, 0, scale_notes.size())
		var midi_note = scale_notes[note_index]
		var octave_variance = randi_range(-1, 1) * 12 if randf() < 0.3 else 0
		
		notes.append({
			"midi_note": midi_note + octave_variance,
			"velocity": randf_range(0.6, 0.9),
			"articulation": 0.8 if randf() < 0.7 else 0.4
		})
		
		current_step += direction * steps
		steps += 1 if randf() < 0.3 else 0
	
	current_position = wrapi(current_step, 0, scale_notes.size())
	return notes

func generate_random_motif(length: int) -> Array[Dictionary]:
	var notes:Array[Dictionary] = []
	var last_note = scale_notes[0]
	
	for i in range(length):
		var jump = randi_range(-3, 3)
		var note_index = clamp(last_note + jump, 0, scale_notes.size() - 1)
		last_note = note_index
		
		notes.append({
			"midi_note": scale_notes[note_index],
			"velocity": randf_range(0.5, 1.0),
			"articulation": randf_range(0.3, 0.9)
		})
	
	return notes

func generate_rhythm(note_lengths: Array[float], max_duration: float) -> Array[float]:
	var rhythm:Array[float] = []
	var total_duration = 0.0
	
	while total_duration < max_duration:
		var duration = note_lengths.pick_random()
		if total_duration + duration > max_duration:
			duration = max_duration - total_duration
		rhythm.append(duration)
		total_duration += duration
		
		# Add rest probability
		if randf() < 0.2:
			var rest_duration = duration * randf_range(0.5, 1.5)
			rhythm.append(-rest_duration)  # Negative values represent rests
			total_duration += rest_duration
	
	return rhythm
