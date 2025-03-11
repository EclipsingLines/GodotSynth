#include "band_pass_filter.h"

namespace godot {

void BandPassFilter::_bind_methods() {
    // No additional methods needed
}

BandPassFilter::BandPassFilter() {
    // Set filter type to band pass
    set_filter_type(FilterType::BANDPASS);
}

BandPassFilter::~BandPassFilter() {
    // Clean up resources
}

Ref<SynthAudioEffect> BandPassFilter::duplicate() const {
    Ref<BandPassFilter> new_filter = memnew(BandPassFilter);
    
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
