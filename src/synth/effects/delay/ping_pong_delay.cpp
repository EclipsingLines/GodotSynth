#include "ping_pong_delay.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>

namespace godot {

// Define parameter name constants
const char *PingPongDelay::PARAM_DELAY_TIME = "delay_time";
const char *PingPongDelay::PARAM_FEEDBACK = "feedback";
const char *PingPongDelay::PARAM_MIX = "mix";
const char *PingPongDelay::PARAM_CROSS_FEEDBACK = "cross_feedback";
const char *PingPongDelay::PARAM_OFFSET = "offset";

void PingPongDelay::_bind_methods() {
    // Bind parameter accessors
    ClassDB::bind_method(D_METHOD("set_delay_time_parameter", "param"), &PingPongDelay::set_delay_time_parameter);
    ClassDB::bind_method(D_METHOD("get_delay_time_parameter"), &PingPongDelay::get_delay_time_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "delay_time_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_delay_time_parameter", "get_delay_time_parameter");
            
    ClassDB::bind_method(D_METHOD("set_feedback_parameter", "param"), &PingPongDelay::set_feedback_parameter);
    ClassDB::bind_method(D_METHOD("get_feedback_parameter"), &PingPongDelay::get_feedback_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "feedback_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_feedback_parameter", "get_feedback_parameter");
            
    ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &PingPongDelay::set_mix_parameter);
    ClassDB::bind_method(D_METHOD("get_mix_parameter"), &PingPongDelay::get_mix_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_mix_parameter", "get_mix_parameter");
            
    ClassDB::bind_method(D_METHOD("set_cross_feedback_parameter", "param"), &PingPongDelay::set_cross_feedback_parameter);
    ClassDB::bind_method(D_METHOD("get_cross_feedback_parameter"), &PingPongDelay::get_cross_feedback_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "cross_feedback_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_cross_feedback_parameter", "get_cross_feedback_parameter");
            
    ClassDB::bind_method(D_METHOD("set_offset_parameter", "param"), &PingPongDelay::set_offset_parameter);
    ClassDB::bind_method(D_METHOD("get_offset_parameter"), &PingPongDelay::get_offset_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "offset_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_offset_parameter", "get_offset_parameter");
}

PingPongDelay::PingPongDelay() {
    // Initialize delay buffers (2 seconds at 44.1kHz)
    delay_buffer_1.resize(88200, 0.0f);
    delay_buffer_2.resize(88200, 0.0f);
    buffer_position_1 = 0;
    buffer_position_2 = 0;
    
    // Create default parameters
    Ref<ModulatedParameter> delay_time_param = memnew(ModulatedParameter);
    delay_time_param->set_base_value(0.4f); // 400ms delay
    delay_time_param->set_mod_min(0.05f);   // 50ms minimum
    delay_time_param->set_mod_max(1.5f);    // 1.5 seconds maximum
    set_parameter(PARAM_DELAY_TIME, delay_time_param);
    
    Ref<ModulatedParameter> feedback_param = memnew(ModulatedParameter);
    feedback_param->set_base_value(0.4f);  // 40% feedback
    feedback_param->set_mod_min(0.0f);     // No feedback
    feedback_param->set_mod_max(0.9f);     // 90% feedback
    set_parameter(PARAM_FEEDBACK, feedback_param);
    
    Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
    mix_param->set_base_value(0.5f);  // 50% wet/dry mix
    mix_param->set_mod_min(0.0f);     // Dry only
    mix_param->set_mod_max(1.0f);     // Wet only
    set_parameter(PARAM_MIX, mix_param);
    
    Ref<ModulatedParameter> cross_feedback_param = memnew(ModulatedParameter);
    cross_feedback_param->set_base_value(0.7f);  // 70% cross feedback
    cross_feedback_param->set_mod_min(0.0f);     // No cross feedback
    cross_feedback_param->set_mod_max(1.0f);     // Full cross feedback
    set_parameter(PARAM_CROSS_FEEDBACK, cross_feedback_param);
    
    Ref<ModulatedParameter> offset_param = memnew(ModulatedParameter);
    offset_param->set_base_value(0.5f);  // 50% offset
    offset_param->set_mod_min(0.0f);     // No offset
    offset_param->set_mod_max(1.0f);     // Full offset
    set_parameter(PARAM_OFFSET, offset_param);
}

PingPongDelay::~PingPongDelay() {
    // Clean up resources
}

float PingPongDelay::process_sample(float sample, const Ref<SynthNoteContext> &context) {
    if (!context.is_valid())
        return sample; // Return original sample if context is invalid
    
    // Get parameter values
    float delay_time = 0.4f;     // Default: 400ms
    float feedback = 0.4f;       // Default: 40%
    float mix = 0.5f;            // Default: 50% wet/dry
    float cross_feedback = 0.7f; // Default: 70% cross feedback
    float offset = 0.5f;         // Default: 50% offset
    
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
    
    Ref<ModulatedParameter> cross_fb_param = get_parameter(PARAM_CROSS_FEEDBACK);
    if (cross_fb_param.is_valid()) {
        cross_feedback = cross_fb_param->get_value(context);
    }
    
    Ref<ModulatedParameter> offset_param = get_parameter(PARAM_OFFSET);
    if (offset_param.is_valid()) {
        offset = offset_param->get_value(context);
    }
    
    // Calculate sample rate (assuming 44.1kHz)
    const float sample_rate = 44100.0f;
    
    // Calculate delay in samples
    int delay_samples_1 = static_cast<int>(delay_time * sample_rate);
    if (delay_samples_1 >= delay_buffer_1.size()) {
        delay_samples_1 = delay_buffer_1.size() - 1;
    }
    
    // Calculate second delay with offset
    int delay_samples_2 = static_cast<int>(delay_time * (1.0f + offset * 0.5f) * sample_rate);
    if (delay_samples_2 >= delay_buffer_2.size()) {
        delay_samples_2 = delay_buffer_2.size() - 1;
    }
    
    float input = sample;
    
    // Calculate read positions with wraparound
    int read_pos_1 = buffer_position_1 - delay_samples_1;
    if (read_pos_1 < 0) {
        read_pos_1 += delay_buffer_1.size();
    }
    
    int read_pos_2 = buffer_position_2 - delay_samples_2;
    if (read_pos_2 < 0) {
        read_pos_2 += delay_buffer_2.size();
    }
    
    // Read delayed samples
    float delayed_sample_1 = delay_buffer_1[read_pos_1];
    float delayed_sample_2 = delay_buffer_2[read_pos_2];
    
    // Write to delay buffers with cross-feedback
    delay_buffer_1[buffer_position_1] = input + delayed_sample_2 * feedback * cross_feedback;
    delay_buffer_2[buffer_position_2] = delayed_sample_1 * feedback;
    
    // Increment and wrap buffer positions
    buffer_position_1 = (buffer_position_1 + 1) % delay_buffer_1.size();
    buffer_position_2 = (buffer_position_2 + 1) % delay_buffer_2.size();
    
    // Mix dry and wet signals
    // For ping-pong effect, we combine both delay lines
    float wet_signal = (delayed_sample_1 + delayed_sample_2) * 0.5f;
    return input * (1.0f - mix) + wet_signal * mix;
}

void PingPongDelay::reset() {
    // Clear delay buffers
    std::fill(delay_buffer_1.begin(), delay_buffer_1.end(), 0.0f);
    std::fill(delay_buffer_2.begin(), delay_buffer_2.end(), 0.0f);
    buffer_position_1 = 0;
    buffer_position_2 = 0;
    
    // Log that the delay effect has been reset
    UtilityFunctions::print("PingPongDelay: Reset called - buffers cleared");
}

float PingPongDelay::get_tail_length() const {
    // Get the delay time and feedback parameters
    float delay_time = 0.4f;  // Default: 400ms
    float feedback = 0.4f;    // Default: 40%
    float offset = 0.5f;      // Default: 50% offset
    
    Ref<ModulatedParameter> delay_param = get_parameter(PARAM_DELAY_TIME);
    if (delay_param.is_valid()) {
        delay_time = delay_param->get_base_value();
    }
    
    Ref<ModulatedParameter> fb_param = get_parameter(PARAM_FEEDBACK);
    if (fb_param.is_valid()) {
        feedback = fb_param->get_base_value();
    }
    
    Ref<ModulatedParameter> offset_param = get_parameter(PARAM_OFFSET);
    if (offset_param.is_valid()) {
        offset = offset_param->get_base_value();
    }
    
    // Calculate the longest delay time (including offset)
    float longest_delay = delay_time * (1.0f + offset * 0.5f);
    
    // Calculate tail length based on delay time and feedback
    if (feedback < 0.001f) {
        return longest_delay;  // Just one repeat
    }
    
    // Calculate number of repeats to reach -60dB
    float repeats = std::log(0.001f) / std::log(feedback);
    if (repeats < 0) {
        repeats = 10.0f;
    }
    
    // Return total tail length: longest_delay * repeats
    return longest_delay * repeats;
}

Ref<SynthAudioEffect> PingPongDelay::duplicate() const {
    Ref<PingPongDelay> new_delay = memnew(PingPongDelay);
    
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
void PingPongDelay::set_delay_time_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_DELAY_TIME, param);
    }
}

Ref<ModulatedParameter> PingPongDelay::get_delay_time_parameter() const {
    return get_parameter(PARAM_DELAY_TIME);
}

void PingPongDelay::set_feedback_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_FEEDBACK, param);
    }
}

Ref<ModulatedParameter> PingPongDelay::get_feedback_parameter() const {
    return get_parameter(PARAM_FEEDBACK);
}

void PingPongDelay::set_mix_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_MIX, param);
    }
}

Ref<ModulatedParameter> PingPongDelay::get_mix_parameter() const {
    return get_parameter(PARAM_MIX);
}

void PingPongDelay::set_cross_feedback_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_CROSS_FEEDBACK, param);
    }
}

Ref<ModulatedParameter> PingPongDelay::get_cross_feedback_parameter() const {
    return get_parameter(PARAM_CROSS_FEEDBACK);
}

void PingPongDelay::set_offset_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_OFFSET, param);
    }
}

Ref<ModulatedParameter> PingPongDelay::get_offset_parameter() const {
    return get_parameter(PARAM_OFFSET);
}

} // namespace godot
