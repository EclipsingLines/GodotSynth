#include "comb_filter_delay.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/core/math.hpp>

namespace godot {

// Define parameter name constants
const char *CombFilterDelay::PARAM_DELAY_TIME = "delay_time";
const char *CombFilterDelay::PARAM_FEEDBACK = "feedback";
const char *CombFilterDelay::PARAM_MIX = "mix";
const char *CombFilterDelay::PARAM_RESONANCE = "resonance";
const char *CombFilterDelay::PARAM_POLARITY = "polarity";

void CombFilterDelay::_bind_methods() {
    // Bind parameter accessors
    ClassDB::bind_method(D_METHOD("set_resonance_parameter", "param"), &CombFilterDelay::set_resonance_parameter);
    ClassDB::bind_method(D_METHOD("get_resonance_parameter"), &CombFilterDelay::get_resonance_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "resonance_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_resonance_parameter", "get_resonance_parameter");
            
    ClassDB::bind_method(D_METHOD("set_polarity_parameter", "param"), &CombFilterDelay::set_polarity_parameter);
    ClassDB::bind_method(D_METHOD("get_polarity_parameter"), &CombFilterDelay::get_polarity_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "polarity_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_polarity_parameter", "get_polarity_parameter");
}

CombFilterDelay::CombFilterDelay() {
    // Initialize with a default buffer size (1 second at 44.1kHz)
    buffer_position = 0;
    comb_buffer.resize(44100, 0.0f);
    
    // Create default parameters
    Ref<ModulatedParameter> delay_time_param = memnew(ModulatedParameter);
    delay_time_param->set_base_value(0.01f); // 10ms delay (good for comb filtering)
    delay_time_param->set_mod_min(0.001f);   // 1ms minimum
    delay_time_param->set_mod_max(0.05f);    // 50ms maximum
    set_parameter(PARAM_DELAY_TIME, delay_time_param);

    Ref<ModulatedParameter> feedback_param = memnew(ModulatedParameter);
    feedback_param->set_base_value(0.7f); // 70% feedback
    feedback_param->set_mod_min(0.0f);    // No feedback
    feedback_param->set_mod_max(0.95f);   // 95% feedback (avoid instability)
    set_parameter(PARAM_FEEDBACK, feedback_param);

    Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
    mix_param->set_base_value(0.5f); // 50% wet/dry mix
    mix_param->set_mod_min(0.0f);    // Dry only
    mix_param->set_mod_max(1.0f);    // Wet only
    set_parameter(PARAM_MIX, mix_param);
    
    Ref<ModulatedParameter> resonance_param = memnew(ModulatedParameter);
    resonance_param->set_base_value(0.5f); // 50% resonance
    resonance_param->set_mod_min(0.0f);    // No resonance
    resonance_param->set_mod_max(0.99f);   // High resonance (avoid instability)
    set_parameter(PARAM_RESONANCE, resonance_param);
    
    Ref<ModulatedParameter> polarity_param = memnew(ModulatedParameter);
    polarity_param->set_base_value(0.0f); // Positive comb filter
    polarity_param->set_mod_min(0.0f);    // Positive comb filter
    polarity_param->set_mod_max(1.0f);    // Negative comb filter
    set_parameter(PARAM_POLARITY, polarity_param);
}

CombFilterDelay::~CombFilterDelay() {
    // Cleanup if needed
}

float CombFilterDelay::process_sample(float sample, const Ref<SynthNoteContext> &context) {
    if (!context.is_valid())
        return sample; // Return original sample if context is invalid

    // Get parameter values
    float delay_time = 0.01f;  // Default: 10ms
    float feedback = 0.7f;     // Default: 70%
    float mix = 0.5f;          // Default: 50% wet/dry
    float resonance = 0.5f;    // Default: 50% resonance
    float polarity = 0.0f;     // Default: Positive comb filter
    
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
    
    Ref<ModulatedParameter> resonance_param = get_parameter(PARAM_RESONANCE);
    if (resonance_param.is_valid()) {
        resonance = resonance_param->get_value(context);
    }
    
    Ref<ModulatedParameter> polarity_param = get_parameter(PARAM_POLARITY);
    if (polarity_param.is_valid()) {
        polarity = polarity_param->get_value(context);
    }
    
    // Calculate delay in samples (assuming 44.1kHz sample rate)
    int delay_samples = static_cast<int>(delay_time * 44100.0f);
    if (delay_samples < 1) delay_samples = 1;
    if (delay_samples >= comb_buffer.size()) {
        delay_samples = comb_buffer.size() - 1;
    }
    
    // Determine polarity sign (positive or negative comb filter)
    float polarity_sign = (polarity >= 0.5f) ? -1.0f : 1.0f;
    
    // Apply resonance to feedback
    float effective_feedback = feedback * (0.5f + resonance * 0.5f);
    
    float input = sample;
    
    // Calculate read position with wraparound
    int read_pos = buffer_position - delay_samples;
    if (read_pos < 0) {
        read_pos += comb_buffer.size();
    }
    
    // Read delayed sample
    float delayed_sample = comb_buffer[read_pos];
    
    // Calculate comb filtered output
    // For positive comb: input + delayed_sample
    // For negative comb: input - delayed_sample
    float comb_output = input + polarity_sign * delayed_sample;
    
    // Write to delay buffer with feedback
    comb_buffer[buffer_position] = input + delayed_sample * effective_feedback;
    
    // Increment and wrap buffer position
    buffer_position = (buffer_position + 1) % comb_buffer.size();
    
    // Mix dry and wet signals
    return input * (1.0f - mix) + comb_output * mix;
}

void CombFilterDelay::reset() {
    // Clear comb buffer
    std::fill(comb_buffer.begin(), comb_buffer.end(), 0.0f);
    buffer_position = 0;
    
    UtilityFunctions::print("CombFilterDelay: Reset called - buffer cleared");
}

Ref<SynthAudioEffect> CombFilterDelay::duplicate() const {
    Ref<CombFilterDelay> new_filter = memnew(CombFilterDelay);
    
    // Copy parameters
    Dictionary params = get_parameters();
    Array param_names = params.keys();
    for (int i = 0; i < param_names.size(); i++) {
        String name = param_names[i];
        Ref<ModulatedParameter> param = params[name];
        if (param.is_valid()) {
            Ref<ModulatedParameter> new_param = param->duplicate();
            new_filter->set_parameter(name, new_param);
        }
    }
    
    return new_filter;
}

// Parameter accessors
void CombFilterDelay::set_resonance_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_RESONANCE, param);
    }
}

Ref<ModulatedParameter> CombFilterDelay::get_resonance_parameter() const {
    return get_parameter(PARAM_RESONANCE);
}

void CombFilterDelay::set_polarity_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_POLARITY, param);
    }
}

Ref<ModulatedParameter> CombFilterDelay::get_polarity_parameter() const {
    return get_parameter(PARAM_POLARITY);
}

} // namespace godot
