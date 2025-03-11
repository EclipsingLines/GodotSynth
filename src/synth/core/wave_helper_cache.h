#ifndef WAVE_HELPER_CACHE_H
#define WAVE_HELPER_CACHE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <vector>
#include <unordered_map>
#include "../core/wave_helper.h"

namespace godot {

class WaveHelperCache : public RefCounted {
    GDCLASS(WaveHelperCache, RefCounted);

private:
    static WaveHelperCache *singleton;
    
    // Cache structure: waveform type -> pulse width -> samples
    std::unordered_map<int, std::unordered_map<int, std::vector<float>>> wave_cache;
    
    // Resolution of the cached waveforms (number of samples per cycle)
    int resolution;
    
    // Quantization step for pulse width (to limit cache size)
    float pulse_width_step;
    
    // Generate a waveform and store it in the cache
    void generate_waveform(WaveHelper::WaveType type, float pulse_width);
    
    // Get the quantized pulse width key
    int get_pulse_width_key(float pulse_width) const;

protected:
    static void _bind_methods();

public:
    WaveHelperCache();
    ~WaveHelperCache();
    
    // Initialize the cache with a specific resolution
    void initialize(int p_resolution = 4096, float p_pulse_width_step = 0.01f);
    
    // Get a sample from the cached waveform
    float get_sample(float phase, WaveHelper::WaveType type, float pulse_width);
    
    // Clear the cache
    void clear_cache();
    
    // Get the singleton instance
    static WaveHelperCache *get_singleton();
};

} // namespace godot

#endif // WAVE_HELPER_CACHE_H
