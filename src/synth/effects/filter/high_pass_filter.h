#ifndef HIGH_PASS_FILTER_H
#define HIGH_PASS_FILTER_H

#include "state_variable_filter.h"

namespace godot {

class HighPassFilter : public StateVariableFilter {
    GDCLASS(HighPassFilter, StateVariableFilter)

protected:
    static void _bind_methods();

public:
    HighPassFilter();
    ~HighPassFilter();
    
    Ref<SynthAudioEffect> duplicate() const override;
};

} // namespace godot

#endif // HIGH_PASS_FILTER_H
