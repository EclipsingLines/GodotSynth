#include "low_pass_filter.h"

namespace godot {

void LowPassFilter::_bind_methods() {
    // No additional methods needed
}

LowPassFilter::LowPassFilter() {
    // Set filter type to low pass
    set_filter_type(FilterType::LOWPASS);
}

LowPassFilter::~LowPassFilter() {
    // Clean up resources
}

Ref<SynthAudioEffect> LowPassFilter::duplicate() const {
    Ref<LowPassFilter> new_filter = memnew(LowPassFilter);
    
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
