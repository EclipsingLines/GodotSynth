#include "clip_distortion.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>

namespace godot {

// Define parameter name constants
const char *ClipDistortion::PARAM_DRIVE = "drive";
const char *ClipDistortion::PARAM_MIX = "mix";
const char *ClipDistortion::PARAM_OUTPUT_GAIN = "output_gain";
const char *ClipDistortion::PARAM_THRESHOLD = "threshold";
const char *ClipDistortion::PARAM_HARDNESS = "hardness";

void ClipDistortion::_bind_methods() {
    // Bind parameter accessors
    ClassDB::bind_method(D_METHOD("set_drive_parameter", "param"), &ClipDistortion::set_drive_parameter);
    ClassDB::bind_method(D_METHOD("get_drive_parameter"), &ClipDistortion::get_drive_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "drive_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_drive_parameter", "get_drive_parameter");
            
    ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &ClipDistortion::set_mix_parameter);
    ClassDB::bind_method(D_METHOD("get_mix_parameter"), &ClipDistortion::get_mix_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_mix_parameter", "get_mix_parameter");
            
    ClassDB::bind_method(D_METHOD("set_output_gain_parameter", "param"), &ClipDistortion::set_output_gain_parameter);
    ClassDB::bind_method(D_METHOD("get_output_gain_parameter"), &ClipDistortion::get_output_gain_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "output_gain_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_output_gain_parameter", "get_output_gain_parameter");
            
    ClassDB::bind_method(D_METHOD("set_threshold_parameter", "param"), &ClipDistortion::set_threshold_parameter);
    ClassDB::bind_method(D_METHOD("get_threshold_parameter"), &ClipDistortion::get_threshold_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "threshold_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_threshold_parameter", "get_threshold_parameter");
            
    ClassDB::bind_method(D_METHOD("set_hardness_parameter", "param"), &ClipDistortion::set_hardness_parameter);
    ClassDB::bind_method(D_METHOD("get_hardness_parameter"), &ClipDistortion::get_hardness_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "hardness_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_hardness_parameter", "get_hardness_parameter");
}

ClipDistortion::ClipDistortion() {
    // Create default parameters
    Ref<ModulatedParameter> drive_param = memnew(ModulatedParameter);
    drive_param->set_base_value(0.5f); // 50% drive
    drive_param->set_mod_min(0.0f);    // No drive
    drive_param->set_mod_max(1.0f);    // Maximum drive
    set_parameter(PARAM_DRIVE, drive_param);
    
    Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
    mix_param->set_base_value(1.0f);  // 100% wet by default
    mix_param->set_mod_min(0.0f);     // Dry only
    mix_param->set_mod_max(1.0f);     // Wet only
    set_parameter(PARAM_MIX, mix_param);
    
    Ref<ModulatedParameter> output_gain_param = memnew(ModulatedParameter);
    output_gain_param->set_base_value(0.7f);  // Slight reduction to prevent clipping
    output_gain_param->set_mod_min(0.0f);     // Silence
    output_gain_param->set_mod_max(1.5f);     // Boost
    set_parameter(PARAM_OUTPUT_GAIN, output_gain_param);
    
    Ref<ModulatedParameter> threshold_param = memnew(ModulatedParameter);
    threshold_param->set_base_value(0.5f);  // Medium threshold
    threshold_param->set_mod_min(0.01f);    // Very low threshold (more distortion)
    threshold_param->set_mod_max(1.0f);     // High threshold (less distortion)
    set_parameter(PARAM_THRESHOLD, threshold_param);
    
    Ref<ModulatedParameter> hardness_param = memnew(ModulatedParameter);
    hardness_param->set_base_value(0.5f);  // Medium hardness (mix of soft and hard clipping)
    hardness_param->set_mod_min(0.0f);     // Soft clipping
    hardness_param->set_mod_max(1.0f);     // Hard clipping
    set_parameter(PARAM_HARDNESS, hardness_param);
}

ClipDistortion::~ClipDistortion() {
    // Clean up resources
}

// Fast approximation of tanh that's suitable for audio
inline float fast_tanh(float x) {
    float x2 = x * x;
    return x * (27.0f + x2) / (27.0f + 9.0f * x2);
}

float ClipDistortion::process_sample(float sample, const Ref<SynthNoteContext> &context) {
    if (!context.is_valid())
        return sample; // Return original sample if context is invalid
    
    // Get parameter values
    float drive = 0.5f;      // Default: 50% drive
    float mix = 1.0f;        // Default: 100% wet
    float output_gain = 0.7f; // Default: 70% output gain
    float threshold = 0.5f;   // Default: medium threshold
    float hardness = 0.5f;    // Default: medium hardness
    
    Ref<ModulatedParameter> drive_param = get_parameter(PARAM_DRIVE);
    if (drive_param.is_valid()) {
        drive = drive_param->get_value(context);
    }
    
    Ref<ModulatedParameter> mix_param = get_parameter(PARAM_MIX);
    if (mix_param.is_valid()) {
        mix = mix_param->get_value(context);
    }
    
    Ref<ModulatedParameter> output_gain_param = get_parameter(PARAM_OUTPUT_GAIN);
    if (output_gain_param.is_valid()) {
        output_gain = output_gain_param->get_value(context);
    }
    
    Ref<ModulatedParameter> threshold_param = get_parameter(PARAM_THRESHOLD);
    if (threshold_param.is_valid()) {
        threshold = threshold_param->get_value(context);
    }
    
    Ref<ModulatedParameter> hardness_param = get_parameter(PARAM_HARDNESS);
    if (hardness_param.is_valid()) {
        hardness = hardness_param->get_value(context);
    }
    
    // Scale drive to get more extreme effect at higher values
    float scaled_drive = 1.0f + drive * 19.0f; // Range 1-20
    
    // Apply threshold
    float clip_level = threshold * 0.9f + 0.1f; // Range 0.1-1.0
    
    float input = sample;
    float amplified = input * scaled_drive;
    float distorted;
    
    // Interpolate between soft and hard clipping based on hardness
    if (hardness < 0.01f) {
        // Pure soft clipping (tanh)
        distorted = fast_tanh(amplified);
    } else if (hardness > 0.99f) {
        // Pure hard clipping
        distorted = Math::clamp(amplified, -clip_level, clip_level);
    } else {
        // Mix between soft and hard clipping
        float soft_clip = fast_tanh(amplified);
        float hard_clip = Math::clamp(amplified, -clip_level, clip_level);
        distorted = soft_clip * (1.0f - hardness) + hard_clip * hardness;
    }
    
    // Mix dry/wet
    float output = input * (1.0f - mix) + distorted * mix;
    
    // Apply output gain
    return output * output_gain;
}

void ClipDistortion::reset() {
    // No state to reset for this effect
}

float ClipDistortion::get_tail_length() const {
    // Distortion effects don't have a tail
    return 0.0f;
}

Ref<SynthAudioEffect> ClipDistortion::duplicate() const {
    Ref<ClipDistortion> new_effect = memnew(ClipDistortion);
    
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
            
            new_effect->set_parameter(name, new_param);
        }
    }
    
    return new_effect;
}

// Parameter accessors
void ClipDistortion::set_drive_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_DRIVE, param);
    }
}

Ref<ModulatedParameter> ClipDistortion::get_drive_parameter() const {
    return get_parameter(PARAM_DRIVE);
}

void ClipDistortion::set_mix_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_MIX, param);
    }
}

Ref<ModulatedParameter> ClipDistortion::get_mix_parameter() const {
    return get_parameter(PARAM_MIX);
}

void ClipDistortion::set_output_gain_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_OUTPUT_GAIN, param);
    }
}

Ref<ModulatedParameter> ClipDistortion::get_output_gain_parameter() const {
    return get_parameter(PARAM_OUTPUT_GAIN);
}

void ClipDistortion::set_threshold_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_THRESHOLD, param);
    }
}

Ref<ModulatedParameter> ClipDistortion::get_threshold_parameter() const {
    return get_parameter(PARAM_THRESHOLD);
}

void ClipDistortion::set_hardness_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_HARDNESS, param);
    }
}

Ref<ModulatedParameter> ClipDistortion::get_hardness_parameter() const {
    return get_parameter(PARAM_HARDNESS);
}

} // namespace godot
