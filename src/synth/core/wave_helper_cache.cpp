#include "wave_helper_cache.h"
#include <cmath>

namespace godot {

WaveHelperCache *WaveHelperCache::singleton = nullptr;

void WaveHelperCache::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "resolution", "pulse_width_step"), &WaveHelperCache::initialize, DEFVAL(4096), DEFVAL(0.01f));
    ClassDB::bind_method(D_METHOD("get_sample", "phase", "type", "pulse_width"), &WaveHelperCache::get_sample);
    ClassDB::bind_method(D_METHOD("clear_cache"), &WaveHelperCache::clear_cache);
}

WaveHelperCache::WaveHelperCache() : resolution(4096), pulse_width_step(0.01f) {
    singleton = this;
}

WaveHelperCache::~WaveHelperCache() {
    if (singleton == this) {
        singleton = nullptr;
    }
}

void WaveHelperCache::initialize(int p_resolution, float p_pulse_width_step) {
    resolution = p_resolution;
    pulse_width_step = p_pulse_width_step;
    
    // Pre-generate common waveforms with default pulse width
    generate_waveform(WaveHelper::SINE, 0.5f);
    generate_waveform(WaveHelper::TRIANGLE, 0.5f);
    generate_waveform(WaveHelper::SAW, 0.5f);
    generate_waveform(WaveHelper::SQUARE, 0.5f);
    
    // For square and pulse, generate a few common pulse widths
    for (float pw = 0.1f; pw <= 0.9f; pw += 0.2f) {
        generate_waveform(WaveHelper::SQUARE, pw);
        generate_waveform(WaveHelper::PULSE, pw);
    }
    
    UtilityFunctions::print("WaveHelperCache initialized with resolution: " + String::num(resolution));
}

void WaveHelperCache::generate_waveform(WaveHelper::WaveType type, float pulse_width) {
    int pw_key = get_pulse_width_key(pulse_width);
    
    // Check if this waveform is already cached
    if (wave_cache.find(type) != wave_cache.end() && 
        wave_cache[type].find(pw_key) != wave_cache[type].end()) {
        return;
    }
    
    // Create a new vector for this waveform
    std::vector<float> samples(resolution);
    
    // Generate the waveform
    for (int i = 0; i < resolution; i++) {
        float phase = static_cast<float>(i) / resolution;
        samples[i] = WaveHelper::get_wave_sample(phase, type, pulse_width);
    }
    
    // Store in cache
    wave_cache[type][pw_key] = std::move(samples);
}

float WaveHelperCache::get_sample(float phase, WaveHelper::WaveType type, float pulse_width) {
    // Ensure phase is in [0, 1) range
    phase = fmod(phase, 1.0f);
    if (phase < 0.0f) phase += 1.0f;
    
    int pw_key = get_pulse_width_key(pulse_width);
    
    // Check if we need to generate this waveform
    if (wave_cache.find(type) == wave_cache.end() || 
        wave_cache[type].find(pw_key) == wave_cache[type].end()) {
        generate_waveform(type, pulse_width);
    }
    
    // Get the sample from the cache
    const std::vector<float> &samples = wave_cache[type][pw_key];
    
    // Convert phase to sample index
    int index = static_cast<int>(phase * resolution);
    if (index >= resolution) index = 0; // Safety check
    
    return samples[index];
}

int WaveHelperCache::get_pulse_width_key(float pulse_width) const {
    // Quantize pulse width to reduce cache size
    return static_cast<int>(round(pulse_width / pulse_width_step));
}

void WaveHelperCache::clear_cache() {
    wave_cache.clear();
    UtilityFunctions::print("WaveHelperCache cleared");
}

WaveHelperCache *WaveHelperCache::get_singleton() {
    return singleton;
}

} // namespace godot
