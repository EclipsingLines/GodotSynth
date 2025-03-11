#Rhythms database
class_name MusicRhythms
enum RhythmType {
	Ballad,        # Long-short-long
	Waltz,       # 3/4 time
	Electronic, # Straight 16ths
	Swing,     # Swing feel
	Ambient		# Sparse, loose
	}

static var rhythm_intervals = {
	RhythmType.Ballad: [1.5, 0.5, 2.0],        # Long-short-long
	RhythmType.Waltz: [0.75, 0.75, 1.5],       # 3/4 time
	RhythmType.Electronic: [0.25, 0.25, 0.25, 0.25], # Straight 16ths
	RhythmType.Swing: [0.333, 0.667, 1.0],     # Swing feel
	RhythmType.Ambient: [2.0, 2.0, 2.0] 		# Sparse, loose
}

static func get_rhythm(rhythm:RhythmType) -> Array:
	return rhythm_intervals[rhythm]
