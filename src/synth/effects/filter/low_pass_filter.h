#ifndef LOW_PASS_FILTER_H
#define LOW_PASS_FILTER_H

#include "state_variable_filter.h"

namespace godot {

class LowPassFilter : public StateVariableFilter {
    GDCLASS(LowPassFilter, StateVariableFilter)

protected:
    static void _bind_methods();

public:
    LowPassFilter();
    ~LowPassFilter();
    
    Ref<SynthAudioEffect> duplicate() const override;
};

} // namespace godot

#endif // LOW_PASS_FILTER_H
