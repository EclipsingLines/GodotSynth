#ifndef KEYBOARD_TRACKING_MOD_SOURCE_H
#define KEYBOARD_TRACKING_MOD_SOURCE_H

#include "../../core/modulation_source.h"

namespace godot {

class KeyboardTrackingModSource : public ModulationSource {
	GDCLASS(KeyboardTrackingModSource, ModulationSource)

private:
	int center_note;
	float note_range;
	float min_value;
	float max_value;

protected:
	static void _bind_methods();

public:
	KeyboardTrackingModSource();
	~KeyboardTrackingModSource();

	// Override the base class method to provide keyboard tracking modulation
	virtual float get_value(const Ref<SynthNoteContext> &context) const override;
	
	// Reset is not needed for keyboard tracking (it's stateless)
	virtual void reset() override;
	
	// Create a duplicate of this modulation source
	virtual Ref<ModulationSource> duplicate() const override;

	// Setters and getters
	void set_center_note(int p_note);
	int get_center_note() const;
	
	void set_note_range(float p_range);
	float get_note_range() const;
	
	void set_min_value(float p_min);
	float get_min_value() const;
	
	void set_max_value(float p_max);
	float get_max_value() const;
};

} // namespace godot

#endif // KEYBOARD_TRACKING_MOD_SOURCE_H
