#include "lfo.h"
#include "../../core/synth_note_context.h"
#include "../../core/wave_helper_cache.h"

namespace godot {

void LFO::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_rate", "rate"), &LFO::set_rate);
	ClassDB::bind_method(D_METHOD("get_rate"), &LFO::get_rate);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "rate", PROPERTY_HINT_RANGE, "0.01,20.0,0.01"), "set_rate", "get_rate");

	ClassDB::bind_method(D_METHOD("set_wave_type", "wave_type"), &LFO::set_wave_type);
	ClassDB::bind_method(D_METHOD("get_wave_type"), &LFO::get_wave_type);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "wave_type", PROPERTY_HINT_ENUM, WAVE_ENUM_VALUES), "set_wave_type", "get_wave_type");

	ClassDB::bind_method(D_METHOD("set_amplitude", "amplitude"), &LFO::set_amplitude);
	ClassDB::bind_method(D_METHOD("get_amplitude"), &LFO::get_amplitude);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "amplitude", PROPERTY_HINT_RANGE, "0.0,1.0,0.01"), "set_amplitude", "get_amplitude");

	ClassDB::bind_method(D_METHOD("set_phase_offset", "phase_offset"), &LFO::set_phase_offset);
	ClassDB::bind_method(D_METHOD("get_phase_offset"), &LFO::get_phase_offset);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "phase_offset", PROPERTY_HINT_RANGE, "0.0,1.0,0.01"), "set_phase_offset", "get_phase_offset");

	ClassDB::bind_method(D_METHOD("set_pulse_width", "pulse_width"), &LFO::set_pulse_width);
	ClassDB::bind_method(D_METHOD("get_pulse_width"), &LFO::get_pulse_width);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "pulse_width", PROPERTY_HINT_RANGE, "0.01,0.99,0.01"), "set_pulse_width", "get_pulse_width");

	ClassDB::bind_method(D_METHOD("process", "time"), &LFO::process);
	ClassDB::bind_method(D_METHOD("reset"), &LFO::reset);
}

LFO::LFO() :
		rate(1.0f), wave_type(WaveHelper::SINE), amplitude(1.0f), phase_offset(0.0f), phase(0.0), pulse_width(0.5f) {
}

LFO::~LFO() {
}

float LFO::get_value(const Ref<SynthNoteContext> &context) const {
	if (!context.is_valid()) {
		return 0.0f;
	}

	double time = context->get_note_time();
	double calculated_phase = fmod(time * rate + phase_offset, 1.0);
	
	// Use cached waveform if available
	WaveHelperCache *cache = WaveHelperCache::get_singleton();
	if (cache) {
		return amplitude * cache->get_sample(static_cast<float>(calculated_phase), wave_type, pulse_width);
	} else {
		return amplitude * WaveHelper::get_wave_sample(static_cast<float>(calculated_phase), wave_type, pulse_width);
	}
}

float LFO::process(float time) {
	phase = fmod(time * rate + phase_offset, 1.0);
	
	// Use cached waveform if available
	WaveHelperCache *cache = WaveHelperCache::get_singleton();
	if (cache) {
		return amplitude * cache->get_sample(static_cast<float>(phase), wave_type, pulse_width);
	} else {
		return amplitude * WaveHelper::get_wave_sample(static_cast<float>(phase), wave_type, pulse_width);
	}
}

void LFO::reset() {
	phase = 0.0;
}

void LFO::set_pulse_width(float p_pulse_width) {
	pulse_width = Math::clamp(p_pulse_width, 0.01f, 0.99f);
}

float LFO::get_pulse_width() const {
	return pulse_width;
}

void LFO::set_rate(float p_rate) {
	rate = Math::max(0.01f, p_rate);
}

float LFO::get_rate() const {
	return rate;
}

void LFO::set_wave_type(WaveHelper::WaveType p_wave_type) {
	wave_type = p_wave_type;
}

WaveHelper::WaveType LFO::get_wave_type() const {
	return wave_type;
}

void LFO::set_amplitude(float p_amplitude) {
	amplitude = Math::clamp(p_amplitude, 0.0f, 1.0f);
}

float LFO::get_amplitude() const {
	return amplitude;
}

void LFO::set_phase_offset(float p_phase_offset) {
	phase_offset = Math::fmod(p_phase_offset, 1.0f);
}

float LFO::get_phase_offset() const {
	return phase_offset;
}

} // namespace godot
