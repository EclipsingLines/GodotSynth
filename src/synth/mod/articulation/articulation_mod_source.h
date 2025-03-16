#pragma once
#include "../../core/modulation_source.h"
#include "../../core/synth_note_context.h"

namespace godot {

class ArticulationModSource : public ModulationSource {
	GDCLASS(ArticulationModSource, ModulationSource);

private:
	float min_value;
	float max_value;
	bool bipolar;

public:
	ArticulationModSource();
	~ArticulationModSource();

	// Get the articulation value from the note context
	float get_value(const Ref<SynthNoteContext> &context) const override;
	// Reset is not needed for velocity (it's stateless)
	virtual void reset() override;
	// Create a duplicate of this modulation source
	virtual Ref<ModulationSource> duplicate() const override;

	// Setters and getters
	void set_min_value(float p_min);
	float get_min_value() const;

	void set_max_value(float p_max);
	float get_max_value() const;

	void set_bipolar(bool p_bipolar);
	bool get_bipolar() const;

protected:
	static void _bind_methods();
};
} //namespace godot