class_name ArpeggioGenerator extends RefCounted

enum Shape{Ascending, Descending, UpDown, Random}

static func generate_arpeggio(notes:Array[MusicNote], length:int, shape:Shape = Shape.Ascending, octave:int = 1) -> Array[MusicNote]:
	var arp:Array[Dictionary] = []
	var current_step:int = 0
	
	for i in range(length):
		var note_index = wrapi(current_step, 0, notes.size())
		var note = notes[note_index]
		var octave_variance =mini( (note_index / current_step) , octave)
		note.midi_note += octave_variance
		note.velocity = randf_range(0.6,0.9)
		note.articulation = 0.8 if randf() < 0.7 else 0.4
		notes.append(note)

		current_step += get_direction_for_shape(shape) * get_steps_for_shape(shape)
	
	return notes
	
static func get_direction_for_shape(shape:Shape) -> int:
	match shape:
		Shape.Ascending:
			return 1
		Shape.Descending:
			return -1
		Shape.UpDown:
			return 1
	
	return 1

static func get_steps_for_shape(shape:Shape) -> int:
	match shape:
		Shape.Ascending:
			return 1
		Shape.Descending:
			return 1
		Shape.UpDown:
			return 2
	
	return 1
