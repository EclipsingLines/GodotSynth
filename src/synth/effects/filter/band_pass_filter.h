#ifndef BAND_PASS_FILTER_H
#define BAND_PASS_FILTER_H

#include "state_variable_filter.h"

namespace godot {

class BandPassFilter : public StateVariableFilter {
    GDCLASS(BandPassFilter, StateVariableFilter)

protected:
    static void _bind_methods();

public:
    BandPassFilter();
    ~BandPassFilter();
    
    Ref<SynthAudioEffect> duplicate() const override;
};

} // namespace godot

#endif // BAND_PASS_FILTER_H
