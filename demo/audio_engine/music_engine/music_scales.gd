# Scale Database Class
class_name MusicScales

enum ScaleType {
	MAJOR,
	NATURAL_MINOR,
	HARMONIC_MINOR,
	DORIAN,
	PHRYGIAN,
	LYDIAN,
	MIXOLYDIAN,
	PENTATONIC_MAJOR,
	PENTATONIC_MINOR,
	HIRAJOSHI,
	HUNGARIAN_MINOR,
	ARABIC
}

static var scale_intervals = {
	ScaleType.MAJOR: [0, 2, 4, 5, 7, 9, 11],
	ScaleType.NATURAL_MINOR: [0, 2, 3, 5, 7, 8, 10],
	ScaleType.HARMONIC_MINOR: [0, 2, 3, 5, 7, 8, 11],
	ScaleType.DORIAN: [0, 2, 3, 5, 7, 9, 10],
	ScaleType.PHRYGIAN: [0, 1, 3, 5, 7, 8, 10],
	ScaleType.LYDIAN: [0, 2, 4, 6, 7, 9, 11],
	ScaleType.MIXOLYDIAN: [0, 2, 4, 5, 7, 9, 10],
	ScaleType.PENTATONIC_MAJOR: [0, 2, 4, 7, 9],
	ScaleType.PENTATONIC_MINOR: [0, 3, 5, 7, 10],
	ScaleType.HIRAJOSHI: [0, 2, 3, 7, 8],
	ScaleType.HUNGARIAN_MINOR: [0, 2, 3, 6, 7, 8, 11],
	ScaleType.ARABIC: [0, 1, 4, 5, 7, 8, 11]
}

static func get_scale(root: int = 64, scale_type: ScaleType = ScaleType.LYDIAN, octaves: int = 1) -> Array[int]:
	var notes:Array[int] = []
	for octave in range(octaves):
		for interval in scale_intervals[scale_type]:
			notes.append(root + (octave * 12) + interval)
	return notes
