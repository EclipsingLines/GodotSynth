#include "high_pass_filter.h"

namespace godot {

void HighPassFilter::_bind_methods() {
    // No additional methods needed
}

HighPassFilter::HighPassFilter() {
    // Set filter type to high pass
    set_filter_type(FilterType::HIGHPASS);
}

HighPassFilter::~HighPassFilter() {
    // Clean up resources
}

Ref<SynthAudioEffect> HighPassFilter::duplicate() const {
    Ref<HighPassFilter> new_filter = memnew(HighPassFilter);
    
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
