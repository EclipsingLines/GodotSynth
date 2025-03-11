#include "shelf_filter.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

namespace godot {

void ShelfFilter::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_low_shelf"), &ShelfFilter::set_low_shelf);
    ClassDB::bind_method(D_METHOD("set_high_shelf"), &ShelfFilter::set_high_shelf);
    ClassDB::bind_method(D_METHOD("is_low_shelf"), &ShelfFilter::is_low_shelf);
}

ShelfFilter::ShelfFilter() {
    // Default to low shelf
    set_filter_type(FilterType::LOWSHELF);
}

ShelfFilter::~ShelfFilter() {
    // Clean up resources
}

float ShelfFilter::process_sample(float sample, const Ref<SynthNoteContext> &context) {
    if (!context.is_valid())
        return sample;

    // Get parameter values
    float cutoff_freq = 1000.0f; // Default to 1000 Hz
    float gain_db = 0.0f; // Default gain in dB

    Ref<ModulatedParameter> cutoff_param = get_parameter(PARAM_CUTOFF);
    if (cutoff_param.is_valid()) {
        cutoff_freq = cutoff_param->get_value(context);
        cutoff_freq = Math::clamp(cutoff_freq, 20.0f, 20000.0f);
    }

    Ref<ModulatedParameter> gain_param = get_parameter(PARAM_GAIN);
    if (gain_param.is_valid()) {
        gain_db = gain_param->get_value(context);
    }

    // Get sample rate from context or use default
    float sample_rate = 44100.0f; // TODO: Get from context

    // Convert dB gain to linear gain
    float A = Math::db2linear(gain_db);
    
    // Calculate filter coefficients
    float omega = 2.0f * Math_PI * cutoff_freq / sample_rate;
    float sin_omega = Math::sin(omega);
    float cos_omega = Math::cos(omega);
    float alpha = sin_omega / 2.0f * Math::sqrt((A + 1.0f/A) * (1.0f/0.707f - 1.0f) + 2.0f);
    float beta = 2.0f * Math::sqrt(A) * alpha;

    float a0, a1, a2, b0, b1, b2;

    if (get_filter_type() == FilterType::LOWSHELF) {
        // Low shelf coefficients
        b0 = A * ((A + 1.0f) - (A - 1.0f) * cos_omega + beta);
        b1 = 2.0f * A * ((A - 1.0f) - (A + 1.0f) * cos_omega);
        b2 = A * ((A + 1.0f) - (A - 1.0f) * cos_omega - beta);
        a0 = (A + 1.0f) + (A - 1.0f) * cos_omega + beta;
        a1 = -2.0f * ((A - 1.0f) + (A + 1.0f) * cos_omega);
        a2 = (A + 1.0f) + (A - 1.0f) * cos_omega - beta;
    } else { // HIGHSHELF
        // High shelf coefficients
        b0 = A * ((A + 1.0f) + (A - 1.0f) * cos_omega + beta);
        b1 = -2.0f * A * ((A - 1.0f) + (A + 1.0f) * cos_omega);
        b2 = A * ((A + 1.0f) + (A - 1.0f) * cos_omega - beta);
        a0 = (A + 1.0f) - (A - 1.0f) * cos_omega + beta;
        a1 = 2.0f * ((A - 1.0f) - (A + 1.0f) * cos_omega);
        a2 = (A + 1.0f) - (A - 1.0f) * cos_omega - beta;
    }

    // Normalize coefficients
    b0 /= a0;
    b1 /= a0;
    b2 /= a0;
    a1 /= a0;
    a2 /= a0;

    // Apply biquad filter
    float output = b0 * sample + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;

    // Update state variables
    x2 = x1;
    x1 = sample;
    y2 = y1;
    y1 = output;

    return output;
}

void ShelfFilter::reset() {
    x1 = x2 = y1 = y2 = 0.0f;
}

void ShelfFilter::set_low_shelf() {
    set_filter_type(FilterType::LOWSHELF);
}

void ShelfFilter::set_high_shelf() {
    set_filter_type(FilterType::HIGHSHELF);
}

bool ShelfFilter::is_low_shelf() const {
    return get_filter_type() == FilterType::LOWSHELF;
}

Ref<SynthAudioEffect> ShelfFilter::duplicate() const {
    Ref<ShelfFilter> new_filter = memnew(ShelfFilter);
    
    // Copy filter type (low shelf or high shelf)
    if (is_low_shelf()) {
        new_filter->set_low_shelf();
    } else {
        new_filter->set_high_shelf();
    }
    
    // Copy parameters
    Dictionary params = get_parameters();
    Array param_names = params.keys();
    for (int i = 0; i < param_names.size(); i++) {
        String name = param_names[i];
        Ref<ModulatedParameter> param = params[name];
        if (param.is_valid()) {
            new_filter->set_parameter(name, param->duplicate());
        }
    }
    
    return new_filter;
}

} // namespace godot
