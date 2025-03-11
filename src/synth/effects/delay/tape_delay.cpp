#include "tape_delay.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>

namespace godot {

// Define parameter name constants
const char *TapeDelay::PARAM_DELAY_TIME = "delay_time";
const char *TapeDelay::PARAM_FEEDBACK = "feedback";
const char *TapeDelay::PARAM_MIX = "mix";
const char *TapeDelay::PARAM_SATURATION = "saturation";
const char *TapeDelay::PARAM_WOW_AMOUNT = "wow_amount";
const char *TapeDelay::PARAM_FILTERING = "filtering";

void TapeDelay::_bind_methods() {
    // Bind parameter accessors
    ClassDB::bind_method(D_METHOD("set_delay_time_parameter", "param"), &TapeDelay::set_delay_time_parameter);
    ClassDB::bind_method(D_METHOD("get_delay_time_parameter"), &TapeDelay::get_delay_time_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "delay_time_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_delay_time_parameter", "get_delay_time_parameter");
            
    ClassDB::bind_method(D_METHOD("set_feedback_parameter", "param"), &TapeDelay::set_feedback_parameter);
    ClassDB::bind_method(D_METHOD("get_feedback_parameter"), &TapeDelay::get_feedback_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "feedback_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_feedback_parameter", "get_feedback_parameter");
            
    ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &TapeDelay::set_mix_parameter);
    ClassDB::bind_method(D_METHOD("get_mix_parameter"), &TapeDelay::get_mix_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_mix_parameter", "get_mix_parameter");
            
    ClassDB::bind_method(D_METHOD("set_saturation_parameter", "param"), &TapeDelay::set_saturation_parameter);
    ClassDB::bind_method(D_METHOD("get_saturation_parameter"), &TapeDelay::get_saturation_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "saturation_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_saturation_parameter", "get_saturation_parameter");
            
    ClassDB::bind_method(D_METHOD("set_wow_parameter", "param"), &TapeDelay::set_wow_parameter);
    ClassDB::bind_method(D_METHOD("get_wow_parameter"), &TapeDelay::get_wow_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "wow_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_wow_parameter", "get_wow_parameter");
            
    ClassDB::bind_method(D_METHOD("set_filtering_parameter", "param"), &TapeDelay::set_filtering_parameter);
    ClassDB::bind_method(D_METHOD("get_filtering_parameter"), &TapeDelay::get_filtering_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "filtering_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_filtering_parameter", "get_filtering_parameter");
}

TapeDelay::TapeDelay() {
    // Initialize delay buffer (2 seconds at 44.1kHz)
    delay_buffer.resize(88200, 0.0f);
    write_position = 0;
    read_position = 0.0f;
    last_delay_time = 0.5f;
    
    // Initialize filter states
    lp_state = 0.0f;
    hp_state = 0.0f;
    
    // Initialize wow and flutter
    wow_phase = 0.0f;
    
    // Create default parameters
    Ref<ModulatedParameter> delay_time_param = memnew(ModulatedParameter);
    delay_time_param->set_base_value(0.5f); // 500ms delay
    delay_time_param->set_mod_min(0.01f);   // 10ms minimum
    delay_time_param->set_mod_max(2.0f);    // 2 seconds maximum
    set_parameter(PARAM_DELAY_TIME, delay_time_param);
    
    Ref<ModulatedParameter> feedback_param = memnew(ModulatedParameter);
    feedback_param->set_base_value(0.3f);  // 30% feedback
    feedback_param->set_mod_min(0.0f);     // No feedback
    feedback_param->set_mod_max(0.95f);    // Almost 100% feedback (avoid instability)
    set_parameter(PARAM_FEEDBACK, feedback_param);
    
    Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
    mix_param->set_base_value(0.5f);  // 50% wet/dry mix
    mix_param->set_mod_min(0.0f);     // Dry only
    mix_param->set_mod_max(1.0f);     // Wet only
    set_parameter(PARAM_MIX, mix_param);
    
    Ref<ModulatedParameter> saturation_param = memnew(ModulatedParameter);
    saturation_param->set_base_value(0.2f);  // 20% saturation
    saturation_param->set_mod_min(0.0f);     // No saturation
    saturation_param->set_mod_max(1.0f);     // Full saturation
    set_parameter(PARAM_SATURATION, saturation_param);
    
    Ref<ModulatedParameter> wow_param = memnew(ModulatedParameter);
    wow_param->set_base_value(0.1f);  // 10% wow and flutter
    wow_param->set_mod_min(0.0f);     // No wow and flutter
    wow_param->set_mod_max(0.5f);     // Significant wow and flutter
    set_parameter(PARAM_WOW_AMOUNT, wow_param);
    
    Ref<ModulatedParameter> filtering_param = memnew(ModulatedParameter);
    filtering_param->set_base_value(0.3f);  // 30% filtering
    filtering_param->set_mod_min(0.0f);     // No filtering
    filtering_param->set_mod_max(1.0f);     // Full filtering
    set_parameter(PARAM_FILTERING, filtering_param);
}

TapeDelay::~TapeDelay() {
    // Clean up resources
}

float TapeDelay::process_sample(float sample, const Ref<SynthNoteContext> &context) {
    if (!context.is_valid())
        return sample; // Return original sample if context is invalid
        
    // Get parameter values
    float delay_time = 0.5f;  // Default: 500ms
    float feedback = 0.3f;    // Default: 30%
    float mix = 0.5f;         // Default: 50% wet/dry
    float saturation = 0.2f;  // Default: 20% saturation
    float wow_amount = 0.1f;  // Default: 10% wow and flutter
    float filtering = 0.3f;   // Default: 30% filtering
    
    Ref<ModulatedParameter> delay_param = get_parameter(PARAM_DELAY_TIME);
    if (delay_param.is_valid()) {
        delay_time = delay_param->get_value(context);
    }
    
    Ref<ModulatedParameter> fb_param = get_parameter(PARAM_FEEDBACK);
    if (fb_param.is_valid()) {
        feedback = fb_param->get_value(context);
    }
    
    Ref<ModulatedParameter> mix_param = get_parameter(PARAM_MIX);
    if (mix_param.is_valid()) {
        mix = mix_param->get_value(context);
    }
    
    Ref<ModulatedParameter> sat_param = get_parameter(PARAM_SATURATION);
    if (sat_param.is_valid()) {
        saturation = sat_param->get_value(context);
    }
    
    Ref<ModulatedParameter> wow_param = get_parameter(PARAM_WOW_AMOUNT);
    if (wow_param.is_valid()) {
        wow_amount = wow_param->get_value(context);
    }
    
    Ref<ModulatedParameter> filter_param = get_parameter(PARAM_FILTERING);
    if (filter_param.is_valid()) {
        filtering = filter_param->get_value(context);
    }
    
    // Calculate sample rate (assuming 44.1kHz)
    const float sample_rate = 44100.0f;
    
    // Calculate time change rate for pitch shifting effect
    float time_change_rate = (delay_time - last_delay_time) / sample_rate;
    last_delay_time = delay_time;
    
    // Calculate filter coefficients
    float lp_coeff = std::exp(-2.0f * Math_PI * (1000.0f + 7000.0f * (1.0f - filtering)) / sample_rate);
    float hp_coeff = std::exp(-2.0f * Math_PI * (20.0f + 300.0f * filtering) / sample_rate);
    
    // Update wow and flutter
    wow_phase += 2.0f * Math_PI * 0.5f / sample_rate; // 0.5 Hz LFO
    if (wow_phase > 2.0f * Math_PI) {
        wow_phase -= 2.0f * Math_PI;
    }
    
    float wow_mod = wow_amount * 0.005f * std::sin(wow_phase); // +/- 0.5% variation
    float current_delay_time = delay_time * (1.0f + wow_mod);
    
    // Calculate delay in samples
    float delay_samples = current_delay_time * sample_rate;
    
    // Calculate read position with wraparound
    float read_pos = write_position - delay_samples;
    while (read_pos < 0) {
        read_pos += delay_buffer.size();
    }
    
    // Fractional read with linear interpolation
    int read_pos_int = static_cast<int>(read_pos);
    float frac = read_pos - read_pos_int;
    int read_pos_next = (read_pos_int + 1) % delay_buffer.size();
    
    // Read delayed sample with interpolation
    float delayed_sample = delay_buffer[read_pos_int] * (1.0f - frac) + 
                          delay_buffer[read_pos_next] * frac;
    
    // Apply filtering (tape-like EQ)
    // Low-pass filter
    lp_state = lp_state * lp_coeff + delayed_sample * (1.0f - lp_coeff);
    
    // High-pass filter
    hp_state = hp_state * hp_coeff + lp_state * (1.0f - hp_coeff);
    
    delayed_sample = hp_state;
    
    // Apply saturation (tape-like distortion)
    if (saturation > 0.0f) {
        // Soft clipping with variable amount
        float drive = 1.0f + 3.0f * saturation;
        delayed_sample = std::tanh(delayed_sample * drive) / drive;
    }
    
    // Write to delay buffer with feedback
    delay_buffer[write_position] = sample + delayed_sample * feedback;
    
    // Increment and wrap write position
    write_position = (write_position + 1) % delay_buffer.size();
    
    // Mix dry and wet signals
    return sample * (1.0f - mix) + delayed_sample * mix;
}

void TapeDelay::reset() {
    // Clear delay buffer
    std::fill(delay_buffer.begin(), delay_buffer.end(), 0.0f);
    write_position = 0;
    read_position = 0.0f;
    last_delay_time = 0.5f;
    
    // Reset filter states
    lp_state = 0.0f;
    hp_state = 0.0f;
    
    // Reset wow and flutter
    wow_phase = 0.0f;
    
    // Log that the delay effect has been reset
    UtilityFunctions::print("TapeDelay: Reset called - buffer cleared");
}

float TapeDelay::get_tail_length() const {
    // Get the delay time parameter
    float delay_time = 0.5f;  // Default: 500ms
    float feedback = 0.3f;    // Default: 30%
    
    Ref<ModulatedParameter> delay_param = get_parameter(PARAM_DELAY_TIME);
    if (delay_param.is_valid()) {
        delay_time = delay_param->get_base_value();
    }
    
    Ref<ModulatedParameter> fb_param = get_parameter(PARAM_FEEDBACK);
    if (fb_param.is_valid()) {
        feedback = fb_param->get_base_value();
    }
    
    // Calculate tail length based on delay time and feedback
    // For a delay effect, the tail length depends on how many times the signal
    // will repeat at an audible level. We use a threshold of -60dB (0.001 amplitude)
    
    if (feedback < 0.001f) {
        return delay_time;  // Just one repeat
    }
    
    // Calculate number of repeats to reach -60dB
    // Formula: feedback^n < 0.001, solve for n: n = log(0.001)/log(feedback)
    float repeats = std::log(0.001f) / std::log(feedback);
    if (repeats < 0) {
        // If feedback > 1 (which shouldn't happen but just in case),
        // this would give a negative value, so cap it
        repeats = 10.0f;
    }
    
    // Return total tail length: delay_time * repeats
    return delay_time * repeats;
}

Ref<SynthAudioEffect> TapeDelay::duplicate() const {
    Ref<TapeDelay> new_delay = memnew(TapeDelay);
    
    // Copy parameters
    Dictionary params = get_parameters();
    Array param_names = params.keys();
    for (int i = 0; i < param_names.size(); i++) {
        String name = param_names[i];
        Ref<ModulatedParameter> param = params[name];
        if (param.is_valid()) {
            Ref<ModulatedParameter> new_param = memnew(ModulatedParameter);
            new_param->set_base_value(param->get_base_value());
            new_param->set_mod_min(param->get_mod_min());
            new_param->set_mod_max(param->get_mod_max());
            
            // Copy modulation source if available
            Ref<ModulationSource> mod_source = param->get_mod_source();
            if (mod_source.is_valid()) {
                new_param->set_mod_source(mod_source);
            }
            
            new_delay->set_parameter(name, new_param);
        }
    }
    
    return new_delay;
}

// Parameter accessors
void TapeDelay::set_delay_time_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_DELAY_TIME, param);
    }
}

Ref<ModulatedParameter> TapeDelay::get_delay_time_parameter() const {
    return get_parameter(PARAM_DELAY_TIME);
}

void TapeDelay::set_feedback_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_FEEDBACK, param);
    }
}

Ref<ModulatedParameter> TapeDelay::get_feedback_parameter() const {
    return get_parameter(PARAM_FEEDBACK);
}

void TapeDelay::set_mix_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_MIX, param);
    }
}

Ref<ModulatedParameter> TapeDelay::get_mix_parameter() const {
    return get_parameter(PARAM_MIX);
}

void TapeDelay::set_saturation_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_SATURATION, param);
    }
}

Ref<ModulatedParameter> TapeDelay::get_saturation_parameter() const {
    return get_parameter(PARAM_SATURATION);
}

void TapeDelay::set_wow_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_WOW_AMOUNT, param);
    }
}

Ref<ModulatedParameter> TapeDelay::get_wow_parameter() const {
    return get_parameter(PARAM_WOW_AMOUNT);
}

void TapeDelay::set_filtering_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_FILTERING, param);
    }
}

Ref<ModulatedParameter> TapeDelay::get_filtering_parameter() const {
    return get_parameter(PARAM_FILTERING);
}

} // namespace godot
