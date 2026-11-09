#include "reverb.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/core/math.hpp>
#include <cmath>

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

void Reverb::allocate_delay_lines() {
    // Prime numbers for early reflection delays (in samples at DELAY_TUNING_RATE)
    const int early_delays[8] = {607, 743, 821, 941, 1061, 1151, 1223, 1327};

    // Prime numbers for late reverb delays (in samples at DELAY_TUNING_RATE)
    const int late_delays[4] = {1453, 1597, 1747, 1867};

    const float scale = sample_rate / DELAY_TUNING_RATE;

    // Initialize delay lines for early reflections (8 delay lines)
    early_delay_lines.resize(8);
    early_positions.assign(8, 0);
    for (int i = 0; i < 8; i++) {
        int length = static_cast<int>(Math::round(early_delays[i] * scale));
        early_delay_lines[i].assign(length < 1 ? 1 : length, 0.0f);
    }

    // Initialize delay lines for late reverb (4 delay lines)
    late_delay_lines.resize(4);
    late_positions.assign(4, 0);
    for (int i = 0; i < 4; i++) {
        int length = static_cast<int>(Math::round(late_delays[i] * scale));
        late_delay_lines[i].assign(length < 1 ? 1 : length, 0.0f);
    }

    // Initialize filter states
    lp_states.assign(4, 0.0f);
    hp_states.assign(4, 0.0f);
}

Reverb::Reverb() {
    allocate_delay_lines();

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

Reverb::Settings Reverb::read_settings(const Ref<SynthNoteContext> &context) const {
    Settings s;

    Ref<ModulatedParameter> room_size_param = get_parameter(PARAM_ROOM_SIZE);
    if (room_size_param.is_valid()) {
        s.room_size = room_size_param->get_value(context);
    }

    Ref<ModulatedParameter> damping_param = get_parameter(PARAM_DAMPING);
    if (damping_param.is_valid()) {
        s.damping = damping_param->get_value(context);
    }

    Ref<ModulatedParameter> width_param = get_parameter(PARAM_WIDTH);
    if (width_param.is_valid()) {
        s.width = width_param->get_value(context);
    }

    Ref<ModulatedParameter> mix_param = get_parameter(PARAM_MIX);
    if (mix_param.is_valid()) {
        s.mix = mix_param->get_value(context);
    }

    Ref<ModulatedParameter> pre_delay_param = get_parameter(PARAM_PRE_DELAY);
    if (pre_delay_param.is_valid()) {
        s.pre_delay = pre_delay_param->get_value(context);
    }

    Ref<ModulatedParameter> diffusion_param = get_parameter(PARAM_DIFFUSION);
    if (diffusion_param.is_valid()) {
        s.diffusion = diffusion_param->get_value(context);
    }

    return s;
}

void Reverb::process_wet(float input, const Settings &s, float &wet_left, float &wet_right) {
    // Feedback of the late network, from room size. Loop gain never exceeds
    // this (see below), so the network always decays.
    const float feedback = 0.7f + Math::clamp(s.room_size, 0.0f, 1.0f) * 0.25f;

    // Damping coefficients
    const float lp_coeff = s.damping * 0.4f + 0.2f; // Low-pass coefficient (0.2 to 0.6)
    const float hp_coeff = 0.01f + s.damping * 0.05f; // High-pass coefficient (0.01 to 0.06)

    // Share of each line's feedback taken from the other three lines
    const float diffusion_amount = Math::clamp(s.diffusion * 0.5f, 0.0f, 0.5f);

    // Early reflections: even lines feed the left side, odd lines the right.
    float early_left = 0.0f;
    float early_right = 0.0f;
    for (int j = 0; j < 8; j++) {
        float delayed = early_delay_lines[j][early_positions[j]];

        // Diffusion: blend in the previous line
        if (j > 0) {
            delayed += early_delay_lines[j - 1][early_positions[j - 1]] * diffusion_amount;
        }

        early_delay_lines[j][early_positions[j]] = input * (0.7f - j * 0.08f); // Later reflections are quieter
        early_positions[j] = (early_positions[j] + 1) % early_delay_lines[j].size();

        const float tap = delayed * (1.0f - j * 0.1f);
        if (j % 2 == 0) {
            early_left += tap;
        } else {
            early_right += tap;
        }
    }
    // Same overall level as the old mono sum (sum * 0.25) when averaged.
    early_left *= 0.5f;
    early_right *= 0.5f;

    // Late reverb input. With a pre-delay, the late network is fed from the
    // early reflections (which start 14 ms or more later) instead of the dry input.
    const float late_input = (s.pre_delay > 0.0f) ? 0.5f * (early_left + early_right) : input;

    // Feedback delay network: read and damp every line first...
    float damped[4];
    float hp_out[4];
    float damped_sum = 0.0f;
    for (int j = 0; j < 4; j++) {
        const float delayed = late_delay_lines[j][late_positions[j]];

        lp_states[j] = lp_states[j] * lp_coeff + delayed * (1.0f - lp_coeff);
        damped[j] = lp_states[j];
        damped_sum += damped[j];

        // High-pass on the output to remove DC
        hp_out[j] = delayed - hp_states[j];
        hp_states[j] = hp_states[j] * (1.0f - hp_coeff) + delayed * hp_coeff;
    }

    // ...then write each line back with a convex blend of its own damped
    // output and the mean of the other three, scaled by `feedback`. The blend
    // has gain <= 1, so the loop gain is <= feedback < 1. (The old version
    // added the cross terms on top of the full feedback, which gave a loop
    // gain above 1 at the default settings, so it could blow up.)
    for (int j = 0; j < 4; j++) {
        const float others = (damped_sum - damped[j]) * (1.0f / 3.0f);
        const float blended = damped[j] * (1.0f - diffusion_amount) + others * diffusion_amount;
        late_delay_lines[j][late_positions[j]] = late_input + blended * feedback;
        late_positions[j] = (late_positions[j] + 1) % late_delay_lines[j].size();
    }

    // Lines 0 and 2 on the left, 1 and 3 on the right
    const float late_left = (hp_out[0] + hp_out[2]) * 0.5f;
    const float late_right = (hp_out[1] + hp_out[3]) * 0.5f;

    const float room = Math::clamp(s.room_size, 0.0f, 1.0f);
    wet_left = early_left * (1.0f - room) + late_left * room;
    wet_right = early_right * (1.0f - room) + late_right * room;
}

float Reverb::process_sample(float sample, const Ref<SynthNoteContext> &context) {
    if (!context.is_valid())
        return sample; // Return original sample if context is invalid

    const Settings s = read_settings(context);
    float wet_left;
    float wet_right;
    process_wet(sample, s, wet_left, wet_right);

    // Mono: the mid of the stereo output (width does not apply).
    const float wet = 0.5f * (wet_left + wet_right);
    return sample * (1.0f - s.mix) + wet * s.mix;
}

bool Reverb::is_stereo() const {
    return true;
}

void Reverb::process_stereo(float &left, float &right, const Ref<SynthNoteContext> &context) {
    if (!context.is_valid()) {
        return;
    }

    const Settings s = read_settings(context);
    float wet_left;
    float wet_right;
    process_wet(0.5f * (left + right), s, wet_left, wet_right);

    // Width scales the side signal: 0 is mono, 1 keeps the full spread.
    const float width = Math::clamp(s.width, 0.0f, 1.0f);
    const float mid = 0.5f * (wet_left + wet_right);
    const float side = 0.5f * (wet_left - wet_right) * width;

    left = left * (1.0f - s.mix) + (mid + side) * s.mix;
    right = right * (1.0f - s.mix) + (mid - side) * s.mix;
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
}

void Reverb::set_sample_rate(float p_sample_rate) {
    SynthAudioEffect::set_sample_rate(p_sample_rate);

    // Main thread only, before playback: reallocating here is allowed
    allocate_delay_lines();
}

float Reverb::get_tail_length() const {
    float room_size = 0.5f; // Default value

    Ref<ModulatedParameter> room_size_param = get_parameter(PARAM_ROOM_SIZE);
    if (room_size_param.is_valid()) {
        room_size = room_size_param->get_base_value();
    }

    // Time for the late network to decay by 60 dB: passes through an average
    // late line (about 38 ms) until feedback^passes reaches 0.001, plus the
    // longest early reflection.
    const float feedback = 0.7f + Math::clamp(room_size, 0.0f, 1.0f) * 0.25f;
    const float average_late_seconds = 1666.0f / DELAY_TUNING_RATE;
    const float passes = std::log(0.001f) / std::log(feedback);
    return passes * average_late_seconds + 1327.0f / DELAY_TUNING_RATE;
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

    new_reverb->set_sample_rate(sample_rate);

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
