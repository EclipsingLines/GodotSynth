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

	###########################################
	#  This only works with the timer delay!  #
	###########################################
	
	#await get_tree().create_timer(0.0).timeout
	play_notes()
	###########################################

func play_notes():
	print("Play Note: 62 at " + String.num(Time.get_ticks_usec()))
	play_note(62)
	#call_deferred("play_note",62)
	#await get_tree().create_timer(0.0).timeout
	print("Play Note: 65 at " + String.num(Time.get_ticks_usec()))
	#play_note(65)
	#call_deferred("play_note",65)
	#await get_tree().create_timer(0.0).timeout
	print("Play Note: 67 at " + String.num(Time.get_ticks_usec()))
	#play_note(67)
	#call_deferred("play_note", 67)

func play_note(note):
	var context: SynthNoteContext = synth.get_context()
	print("Await context: " + String.num(note) + " at " + String.num(Time.get_ticks_usec()))
	print("Note On: " + String.num(note) + " at " + String.num(Time.get_ticks_usec()))
	context.note_on(note, 1.0)
	#context.call_deferred("note_on", note, 1.0)
