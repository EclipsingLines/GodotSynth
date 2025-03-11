#ifndef STATE_VARIABLE_FILTER_H
#define STATE_VARIABLE_FILTER_H

#include "filter_effect.h"

namespace godot {

class StateVariableFilter : public FilterEffect {
    GDCLASS(StateVariableFilter, FilterEffect)

protected:
    // Filter state variables
    float z1 = 0.0f;
    float z2 = 0.0f;
    
    static void _bind_methods();

public:
    StateVariableFilter();
    ~StateVariableFilter();

    float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
    void reset() override;
    
    Ref<SynthAudioEffect> duplicate() const override;
};

} // namespace godot

#endif // STATE_VARIABLE_FILTER_H
