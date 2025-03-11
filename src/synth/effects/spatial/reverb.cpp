#include "reverb.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/core/math.hpp>

namespace godot {

// Define parameter name constants
const char *Reverb::PARAM_ROOM_SIZE = "room_size";
const char *Reverb::PARAM_DAMPING = "damping";
const char *Reverb::PARAM_WIDTH = "width";
const char *Reverb::PARAM_MIX = "mix";
const char *Reverb::PARAM_PRE_DELAY = "pre_delay";
const char *Reverb::PARAM_DIFFUSION = "diffusion";

void Reverb::_bind_methods() {
    // Bind parameter accessors
    ClassDB::bind_method(D_METHOD("set_room_size_parameter", "param"), &Reverb::set_room_size_parameter);
    ClassDB::bind_method(D_METHOD("get_room_size_parameter"), &Reverb::get_room_size_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "room_size_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_room_size_parameter", "get_room_size_parameter");
            
    ClassDB::bind_method(D_METHOD("set_damping_parameter", "param"), &Reverb::set_damping_parameter);
    ClassDB::bind_method(D_METHOD("get_damping_parameter"), &Reverb::get_damping_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "damping_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_damping_parameter", "get_damping_parameter");
            
    ClassDB::bind_method(D_METHOD("set_width_parameter", "param"), &Reverb::set_width_parameter);
    ClassDB::bind_method(D_METHOD("get_width_parameter"), &Reverb::get_width_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "width_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_width_parameter", "get_width_parameter");
            
    ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &Reverb::set_mix_parameter);
    ClassDB::bind_method(D_METHOD("get_mix_parameter"), &Reverb::get_mix_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_mix_parameter", "get_mix_parameter");
            
    ClassDB::bind_method(D_METHOD("set_pre_delay_parameter", "param"), &Reverb::set_pre_delay_parameter);
    ClassDB::bind_method(D_METHOD("get_pre_delay_parameter"), &Reverb::get_pre_delay_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "pre_delay_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_pre_delay_parameter", "get_pre_delay_parameter");
            
    ClassDB::bind_method(D_METHOD("set_diffusion_parameter", "param"), &Reverb::set_diffusion_parameter);
    ClassDB::bind_method(D_METHOD("get_diffusion_parameter"), &Reverb::get_diffusion_parameter);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "diffusion_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
            "set_diffusion_parameter", "get_diffusion_parameter");
}

Reverb::Reverb() {
    // Initialize delay lines for early reflections (8 delay lines)
    early_delay_lines.resize(8);
    early_positions.resize(8, 0);
    
    // Prime numbers for early reflection delays (in samples)
    const int early_delays[8] = {607, 743, 821, 941, 1061, 1151, 1223, 1327};
    
    // Initialize early reflection delay lines
    for (int i = 0; i < 8; i++) {
        early_delay_lines[i].resize(early_delays[i], 0.0f);
    }
    
    // Initialize delay lines for late reverb (4 delay lines)
    late_delay_lines.resize(4);
    late_positions.resize(4, 0);
    
    // Prime numbers for late reverb delays (in samples)
    const int late_delays[4] = {1453, 1597, 1747, 1867};
    
    // Initialize late reverb delay lines
    for (int i = 0; i < 4; i++) {
        late_delay_lines[i].resize(late_delays[i], 0.0f);
    }
    
    // Initialize filter states
    lp_states.resize(4, 0.0f);
    hp_states.resize(4, 0.0f);
    
    // Create default parameters
    Ref<ModulatedParameter> room_size_param = memnew(ModulatedParameter);
    room_size_param->set_base_value(0.5f); // Medium room
    room_size_param->set_mod_min(0.1f);    // Small room
    room_size_param->set_mod_max(0.95f);   // Large hall
    set_parameter(PARAM_ROOM_SIZE, room_size_param);

    Ref<ModulatedParameter> damping_param = memnew(ModulatedParameter);
    damping_param->set_base_value(0.5f); // Medium damping
    damping_param->set_mod_min(0.0f);    // No damping
    damping_param->set_mod_max(0.9f);    // Heavy damping
    set_parameter(PARAM_DAMPING, damping_param);

    Ref<ModulatedParameter> width_param = memnew(ModulatedParameter);
    width_param->set_base_value(0.7f); // 70% stereo width
    width_param->set_mod_min(0.0f);    // Mono
    width_param->set_mod_max(1.0f);    // Full stereo
    set_parameter(PARAM_WIDTH, width_param);
    
    Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
    mix_param->set_base_value(0.3f); // 30% wet/dry mix
    mix_param->set_mod_min(0.0f);    // Dry only
    mix_param->set_mod_max(1.0f);    // Wet only
    set_parameter(PARAM_MIX, mix_param);
    
    Ref<ModulatedParameter> pre_delay_param = memnew(ModulatedParameter);
    pre_delay_param->set_base_value(0.02f); // 20ms pre-delay
    pre_delay_param->set_mod_min(0.0f);     // No pre-delay
    pre_delay_param->set_mod_max(0.1f);     // 100ms pre-delay
    set_parameter(PARAM_PRE_DELAY, pre_delay_param);
    
    Ref<ModulatedParameter> diffusion_param = memnew(ModulatedParameter);
    diffusion_param->set_base_value(0.6f); // 60% diffusion
    diffusion_param->set_mod_min(0.0f);    // No diffusion
    diffusion_param->set_mod_max(0.9f);    // High diffusion
    set_parameter(PARAM_DIFFUSION, diffusion_param);
}

Reverb::~Reverb() {
    // Cleanup if needed
}

float Reverb::process_sample(float sample, const Ref<SynthNoteContext> &context) {
    if (!context.is_valid())
        return sample; // Return original sample if context is invalid
    
    // Get parameter values
    float room_size = 0.5f;  // Default: medium room
    float damping = 0.5f;    // Default: medium damping
    float width = 0.7f;      // Default: 70% stereo width
    float mix = 0.3f;        // Default: 30% wet/dry
    float pre_delay = 0.02f; // Default: 20ms pre-delay
    float diffusion = 0.6f;  // Default: 60% diffusion
    
    Ref<ModulatedParameter> room_size_param = get_parameter(PARAM_ROOM_SIZE);
    if (room_size_param.is_valid()) {
        room_size = room_size_param->get_value(context);
    }
    
    Ref<ModulatedParameter> damping_param = get_parameter(PARAM_DAMPING);
    if (damping_param.is_valid()) {
        damping = damping_param->get_value(context);
    }
    
    Ref<ModulatedParameter> width_param = get_parameter(PARAM_WIDTH);
    if (width_param.is_valid()) {
        width = width_param->get_value(context);
    }
    
    Ref<ModulatedParameter> mix_param = get_parameter(PARAM_MIX);
    if (mix_param.is_valid()) {
        mix = mix_param->get_value(context);
    }
    
    Ref<ModulatedParameter> pre_delay_param = get_parameter(PARAM_PRE_DELAY);
    if (pre_delay_param.is_valid()) {
        pre_delay = pre_delay_param->get_value(context);
    }
    
    Ref<ModulatedParameter> diffusion_param = get_parameter(PARAM_DIFFUSION);
    if (diffusion_param.is_valid()) {
        diffusion = diffusion_param->get_value(context);
    }
    
    // Calculate pre-delay in samples (assuming 44.1kHz sample rate)
    int pre_delay_samples = static_cast<int>(pre_delay * 44100.0f);
    
    // Calculate feedback amount based on room size
    float feedback = 0.7f + room_size * 0.25f;
    
    // Calculate damping coefficients
    float lp_coeff = damping * 0.4f + 0.2f; // Low-pass coefficient (0.2 to 0.6)
    float hp_coeff = 0.01f + damping * 0.05f; // High-pass coefficient (0.01 to 0.06)
    
    // Calculate diffusion amount
    float diffusion_amount = diffusion * 0.5f;
    
    float input = sample;
    float early_sum = 0.0f;
    float late_sum = 0.0f;
    
    // Process early reflections
    for (int j = 0; j < 8; j++) {
        // Read from delay line
        float delayed = early_delay_lines[j][early_positions[j]];
        
        // Apply diffusion (cross-feedback between delay lines)
        if (j > 0) {
            delayed += early_delay_lines[j-1][early_positions[j-1]] * diffusion_amount;
        }
        
        // Write to delay line
        early_delay_lines[j][early_positions[j]] = input * (0.7f - j * 0.08f); // Decreasing gain for later reflections
        
        // Increment position with wraparound
        early_positions[j] = (early_positions[j] + 1) % early_delay_lines[j].size();
        
        // Add to output sum
        early_sum += delayed * (1.0f - j * 0.1f); // Decreasing gain for later reflections
    }
    
    // Scale early reflections
    early_sum *= 0.25f;
    
    // Process late reverb (with pre-delay)
    float late_input = input;
    
    // Apply pre-delay (use early reflection as pre-delay source)
    if (pre_delay_samples > 0) {
        late_input = early_sum;
    }
    
    // Process through feedback delay network
    for (int j = 0; j < 4; j++) {
        // Read from delay line
        float delayed = late_delay_lines[j][late_positions[j]];
        
        // Apply damping (simple low-pass filter)
        lp_states[j] = lp_states[j] * lp_coeff + delayed * (1.0f - lp_coeff);
        
        // Apply high-pass filter to remove DC offset
        float hp_out = delayed - hp_states[j];
        hp_states[j] = hp_states[j] * (1.0f - hp_coeff) + delayed * hp_coeff;
        
        // Calculate feedback input
        float fb_input = late_input;
        
        // Add cross-feedback from other delay lines
        for (int k = 0; k < 4; k++) {
            if (k != j) {
                int pos = (late_positions[k] + pre_delay_samples) % late_delay_lines[k].size();
                fb_input += late_delay_lines[k][pos] * diffusion_amount * 0.25f;
            }
        }
        
        // Write to delay line with feedback
        late_delay_lines[j][late_positions[j]] = fb_input + lp_states[j] * feedback;
        
        // Increment position with wraparound
        late_positions[j] = (late_positions[j] + 1) % late_delay_lines[j].size();
        
        // Add to output sum
        late_sum += hp_out;
    }
    
    // Scale late reverb
    late_sum *= 0.25f;
    
    // Combine early reflections and late reverb
    float reverb_out = early_sum * (1.0f - room_size) + late_sum * room_size;
    
    // Apply stereo width (for mono input, this doesn't do much but is ready for stereo implementation)
    float stereo_out = reverb_out * width;
    
    // Mix dry and wet signals
    return input * (1.0f - mix) + stereo_out * mix;
}

void Reverb::reset() {
    // Clear all delay lines
    for (auto &line : early_delay_lines) {
        std::fill(line.begin(), line.end(), 0.0f);
    }
    
    for (auto &line : late_delay_lines) {
        std::fill(line.begin(), line.end(), 0.0f);
    }
    
    // Reset positions
    std::fill(early_positions.begin(), early_positions.end(), 0);
    std::fill(late_positions.begin(), late_positions.end(), 0);
    
    // Reset filter states
    std::fill(lp_states.begin(), lp_states.end(), 0.0f);
    std::fill(hp_states.begin(), hp_states.end(), 0.0f);
    
    UtilityFunctions::print("Reverb: Reset called - all buffers cleared");
}

float Reverb::get_tail_length() const {
    // Return a tail length based on room size (up to 3 seconds)
    float room_size = 0.5f; // Default value
    
    Ref<ModulatedParameter> room_size_param = get_parameter(PARAM_ROOM_SIZE);
    if (room_size_param.is_valid()) {
        room_size = room_size_param->get_base_value();
    }
    
    return 1.0f + room_size * 2.0f; // 1 to 3 seconds based on room size
}

Ref<SynthAudioEffect> Reverb::duplicate() const {
    Ref<Reverb> new_reverb = memnew(Reverb);
    
    // Copy parameters
    Dictionary params = get_parameters();
    Array param_names = params.keys();
    for (int i = 0; i < param_names.size(); i++) {
        String name = param_names[i];
        Ref<ModulatedParameter> param = params[name];
        if (param.is_valid()) {
            Ref<ModulatedParameter> new_param = param->duplicate();
            new_reverb->set_parameter(name, new_param);
        }
    }
    
    return new_reverb;
}

// Parameter accessors
void Reverb::set_room_size_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_ROOM_SIZE, param);
    }
}

Ref<ModulatedParameter> Reverb::get_room_size_parameter() const {
    return get_parameter(PARAM_ROOM_SIZE);
}

void Reverb::set_damping_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_DAMPING, param);
    }
}

Ref<ModulatedParameter> Reverb::get_damping_parameter() const {
    return get_parameter(PARAM_DAMPING);
}

void Reverb::set_width_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_WIDTH, param);
    }
}

Ref<ModulatedParameter> Reverb::get_width_parameter() const {
    return get_parameter(PARAM_WIDTH);
}

void Reverb::set_mix_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_MIX, param);
    }
}

Ref<ModulatedParameter> Reverb::get_mix_parameter() const {
    return get_parameter(PARAM_MIX);
}

void Reverb::set_pre_delay_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_PRE_DELAY, param);
    }
}

Ref<ModulatedParameter> Reverb::get_pre_delay_parameter() const {
    return get_parameter(PARAM_PRE_DELAY);
}

void Reverb::set_diffusion_parameter(const Ref<ModulatedParameter> &param) {
    if (param.is_valid()) {
        set_parameter(PARAM_DIFFUSION, param);
    }
}

Ref<ModulatedParameter> Reverb::get_diffusion_parameter() const {
    return get_parameter(PARAM_DIFFUSION);
}

} // namespace godot
