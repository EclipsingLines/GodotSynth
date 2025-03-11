#ifndef SHELF_FILTER_H
#define SHELF_FILTER_H

#include "filter_effect.h"

namespace godot {

class ShelfFilter : public FilterEffect {
    GDCLASS(ShelfFilter, FilterEffect)

private:
    // Filter state variables
    float x1 = 0.0f;
    float x2 = 0.0f;
    float y1 = 0.0f;
    float y2 = 0.0f;

protected:
    static void _bind_methods();

public:
    ShelfFilter();
    ~ShelfFilter();
    
    float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
    void reset() override;
    
    // Set shelf type (low or high)
    void set_low_shelf();
    void set_high_shelf();
    bool is_low_shelf() const;
    
    Ref<SynthAudioEffect> duplicate() const override;
};

} // namespace godot

#endif // SHELF_FILTER_H
