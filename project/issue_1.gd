extends Control

var sound: VASynthConfiguration
var stream: AudioStream
var synth: AudioSynthPlayer

signal play_note_async

# I have to reproduce this enum because I cannot access it in the context of my code
enum ModulationType {
	MODULATION_ADDITIVE,
	MODULATION_MULTIPLICATIVE,
	MODULATION_ABSOLUTE,
	MODULATION_GATE
}

# I have to reproduce this enum because I cannot access it in the context of my code
enum WaveType {
	SINE = 0,
	SQUARE,
	TRIANGLE,
	SAW,
	LOG_SAW,
	EXP_SAW,
	PULSE,
	NOISE,
	SUPER_SAW,
	SUB_SQUARE,
	PULSE_TRAIN,
	SINE_FOLD,
	ADDITIVE,
	SYNC_SAW,
	WAVE_TYPE_MAX
}

func _ready() -> void:
	synth = AudioSynthPlayer.new()
	stream = AudioStream.new()

	sound = VASynthConfiguration.new()
	sound.waveform_modulation = ModulatedParameter.new()
	var amplitude_modulation_parameter: ModulatedParameter = ModulatedParameter.new()
	amplitude_modulation_parameter.base_value = 0.0
	amplitude_modulation_parameter.mod_amount = 1.0
	amplitude_modulation_parameter.mod_type = ModulationType.MODULATION_ADDITIVE
	var amplituede_modulation_adsr: ADSR = ADSR.new()
	amplituede_modulation_adsr.attack = 0.1
	amplituede_modulation_adsr.attack_type = ADSR.LINEAR
	amplituede_modulation_adsr.decay = 0.3
	amplituede_modulation_adsr.decay_type = ADSR.LINEAR
	amplituede_modulation_adsr.sustain_level = 0.7
	amplituede_modulation_adsr.release = 0.5
	amplituede_modulation_adsr.release_type = ADSR.LINEAR
	amplitude_modulation_parameter.source = amplituede_modulation_adsr
	sound.amplitude_modulation = amplitude_modulation_parameter
	sound.pitch_modulation = ModulatedParameter.new()
	sound.pulse_width_modulation = ModulatedParameter.new()
	
	sound.top_waveform = int(WaveType.SINE)
	sound.middle_waveform = int(WaveType.SINE)
	sound.bottom_waveform = int(WaveType.SINE)
	
	#sound.effect_chain = EffectChain.new()
	#var effect:DelayEffect = DelayEffect.new()
	#sound.effect_chain.add_effect(effect)
	
	#synth.stream = stream
	synth.configuration = sound
	synth.max_polyphony = 8
	synth.polyphony = 8
	self.add_child(synth)

	# Issue #1: before the fix only the last note of each chord was heard.
	# Both chords below are started within a single frame, with no timer workaround.
	play_notes()
	await get_tree().create_timer(2.0).timeout
	play_notes_queued()

# Chord 1: plain get_context() + note_on(), all in the same frame.
func play_notes():
	var contexts := []
	for note in [62, 65, 69]:
		print("Play Note: %d at %d" % [note, Time.get_ticks_usec()])
		contexts.append(play_note(note))
	await get_tree().create_timer(1.0).timeout
	for context in contexts:
		context.note_off(context.absolute_time)

# Chord 2: queued API (play_note_on_context / play_note_off_context).
func play_notes_queued():
	var contexts := []
	for note in [60, 64, 67]:
		print("Queue Note: %d at %d" % [note, Time.get_ticks_usec()])
		var context: SynthNoteContext = synth.get_context()
		synth.play_note_on_context(context, note, 1.0)
		contexts.append(context)
	await get_tree().create_timer(1.0).timeout
	for context in contexts:
		synth.play_note_off_context(context)

func play_note(note) -> SynthNoteContext:
	var context: SynthNoteContext = synth.get_context()
	context.note_on(note, 1.0)
	return context
