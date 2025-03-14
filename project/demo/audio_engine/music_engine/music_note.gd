class_name MusicNote extends Resource
	
@export_range(50,70) var midi_note:MidiNotes.MidiNote
@export_range(0.1,10) var duration:float
@export_range(0,1,0.05) var velocity:float
@export_range(0,1,0.05) var articulation:float
@export_range(0,1,0.05) var timbre:float

var freq:float: 
	get(): return MidiNotes.midi_to_pitch(midi_note)
