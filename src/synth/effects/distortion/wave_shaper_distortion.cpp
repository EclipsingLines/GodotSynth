#include "wave_shaper_distortion.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>

namespace godot {

// Define parameter name constants
const char *WaveShaperDistortion::PARAM_DRIVE = "drive";
const char *WaveShaperDistortion::PARAM_MIX = "mix";
const char *WaveShaperDistortion::PARAM_OUTPUT_GAIN = "output_gain";
const char *WaveShaperDistortion::PARAM_SHAPE = "shape";
const char *WaveShaperDistortion::PARAM_SYMMETRY = "symmetry";

void WaveShaperDistortion::_bind_methods() {
    // Bind parameter accessors
    ClassDB::bind_method(D_METHOD("set_drive_parameter", "param"), &WaveShaperDistortion::set_drive_parameter);
    ClassDB::bind_method(D_METHOD("get_drive_parameter"), &WaveShaperDistortion::get_drive_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "drive_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_drive_parameter", "get_drive_parameter");
            
    ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &WaveShaperDistortion::set_mix_parameter);
    ClassDB::bind_method(D_METHOD("get_mix_parameter"), &WaveShaperDistortion::get_mix_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_mix_parameter", "get_mix_parameter");
            
    ClassDB::bind_method(D_METHOD("set_output_gain_parameter", "param"), &WaveShaperDistortion::set_output_gain_parameter);
    ClassDB::bind_method(D_METHOD("get_output_gain_parameter"), &WaveShaperDistortion::get_output_gain_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "output_gain_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_output_gain_parameter", "get_output_gain_parameter");
            
    ClassDB::bind_method(D_METHOD("set_shape_parameter", "param"), &WaveShaperDistortion::set_shape_parameter);
    ClassDB::bind_method(D_METHOD("get_shape_parameter"), &WaveShaperDistortion::get_shape_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "shape_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_shape_parameter", "get_shape_parameter");
            
    ClassDB::bind_method(D_METHOD("set_symmetry_parameter", "param"), &WaveShaperDistortion::set_symmetry_parameter);
    ClassDB::bind_method(D_METHOD("get_symmetry_parameter"), &WaveShaperDistortion::get_symmetry_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "symmetry_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_symmetry_parameter", "get_symmetry_parameter");
}

WaveShaperDistortion::WaveShaperDistortion() {
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
    
    Ref<ModulatedParameter> shape_param = memnew(ModulatedParameter);
    shape_param->set_base_value(0.5f);  // Medium shape (cubic)
    shape_param->set_mod_min(0.0f);     // Sine-like shape
    shape_param->set_mod_max(1.0f);     // Aggressive shape
    set_parameter(PARAM_SHAPE, shape_param);
    
    Ref<ModulatedParameter> symmetry_param = memnew(ModulatedParameter);
    symmetry_param->set_base_value(0.5f);  // Symmetric
    symmetry_param->set_mod_min(0.0f);     // Negative bias
    symmetry_param->set_mod_max(1.0f);     // Positive bias
    set_parameter(PARAM_SYMMETRY, symmetry_param);
}

WaveShaperDistortion::~WaveShaperDistortion() {
    // Clean up resources
}

float WaveShaperDistortion::process_sample(float sample, const Ref<SynthNoteContext> &context) {
    if (!context.is_valid())
        return sample; // Return original sample if context is invalid
    
    // Get parameter values
    float drive = 0.5f;      // Default: 50% drive
    float mix = 1.0f;        // Default: 100% wet
    float output_gain = 0.7f; // Default: 70% output gain
    float shape = 0.5f;       // Default: medium shape
    float symmetry = 0.5f;    // Default: symmetric
    
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
    
    Ref<ModulatedParameter> shape_param = get_parameter(PARAM_SHAPE);
    if (shape_param.is_valid()) {
        shape = shape_param->get_value(context);
    }
    
    Ref<ModulatedParameter> symmetry_param = get_parameter(PARAM_SYMMETRY);
    if (symmetry_param.is_valid()) {
        symmetry = symmetry_param->get_value(context);
    }
    
    // Scale drive to get more extreme effect at higher values
    float scaled_drive = 1.0f + drive * 9.0f; // Range 1-10
    
    float input = sample;
    
    // Apply symmetry (bias the input signal)
    float symmetry_offset = (symmetry - 0.5f) * 0.5f; // Range -0.25 to 0.25
    float biased_input = input + symmetry_offset;
    
    // Apply drive
    float x = biased_input * scaled_drive;
    
    // Clamp input to prevent extreme values
    x = Math::clamp(x, -1.5f, 1.5f);
    
    float distorted;
    
    // Apply different waveshaping functions based on shape parameter
    if (shape < 0.33f) {
        // Sine-like shape (softer)
        // y = sin(x * π/2)
        float shape_factor = shape * 3.0f; // 0 to 1 within this range
        float sine_shape = std::sin(x * Math_PI * 0.5f);
        float cubic_shape = 1.5f * x - 0.5f * x * x * x;
        distorted = sine_shape * (1.0f - shape_factor) + cubic_shape * shape_factor;
    } else if (shape < 0.66f) {
        // Cubic shape (medium)
        // y = 1.5x - 0.5x³
        float shape_factor = (shape - 0.33f) * 3.0f; // 0 to 1 within this range
        float cubic_shape = 1.5f * x - 0.5f * x * x * x;
        float arctan_shape = (2.0f / Math_PI) * std::atan(x * Math_PI * 0.5f);
        distorted = cubic_shape * (1.0f - shape_factor) + arctan_shape * shape_factor;
    } else {
        // Arctangent shape (harder)
        // y = (2/π) * atan(x * π/2)
        float shape_factor = (shape - 0.66f) * 3.0f; // 0 to 1 within this range
        float arctan_shape = (2.0f / Math_PI) * std::atan(x * Math_PI * 0.5f);
        float hard_shape = x / (std::abs(x) + 0.2f); // More aggressive shape
        distorted = arctan_shape * (1.0f - shape_factor) + hard_shape * shape_factor;
    }
    
    // Mix dry/wet
    float output = input * (1.0f - mix) + distorted * mix;
    
    // Apply output gain
    return output * output_gain;
}

void WaveShaperDistortion::reset() {
    // No state to reset for this effect
}

float WaveShaperDistortion::get_tail_length() const {
    // Distortion effects don't have a tail
    return 0.0f;
}

Ref<SynthAudioEffect> WaveShaperDistortion::duplicate() const {
    Ref<WaveShaperDistortion> new_effect = memnew(WaveShaperDistortion);
    
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
void WaveShaperDistortion::set_drive_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_DRIVE, param);
    }
}

Ref<ModulatedParameter> WaveShaperDistortion::get_drive_parameter() const {
    return get_parameter(PARAM_DRIVE);
}

void WaveShaperDistortion::set_mix_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_MIX, param);
    }
}

Ref<ModulatedParameter> WaveShaperDistortion::get_mix_parameter() const {
    return get_parameter(PARAM_MIX);
}

void WaveShaperDistortion::set_output_gain_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_OUTPUT_GAIN, param);
    }
}

Ref<ModulatedParameter> WaveShaperDistortion::get_output_gain_parameter() const {
    return get_parameter(PARAM_OUTPUT_GAIN);
}

void WaveShaperDistortion::set_shape_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_SHAPE, param);
    }
}

Ref<ModulatedParameter> WaveShaperDistortion::get_shape_parameter() const {
    return get_parameter(PARAM_SHAPE);
}

void WaveShaperDistortion::set_symmetry_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_SYMMETRY, param);
    }
}

Ref<ModulatedParameter> WaveShaperDistortion::get_symmetry_parameter() const {
    return get_parameter(PARAM_SYMMETRY);
}

} // namespace godot
