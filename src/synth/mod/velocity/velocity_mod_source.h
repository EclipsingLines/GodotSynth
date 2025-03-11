#ifndef VELOCITY_MOD_SOURCE_H
#define VELOCITY_MOD_SOURCE_H

#include "../../core/modulation_source.h"

namespace godot {

class VelocityModSource : public ModulationSource {
	GDCLASS(VelocityModSource, ModulationSource)

private:
	float min_value;
	float max_value;
	bool bipolar;

protected:
	static void _bind_methods();

public:
	VelocityModSource();
	~VelocityModSource();

	// Override the base class method to provide velocity-based modulation
	virtual float get_value(const Ref<SynthNoteContext> &context) const override;
	
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
};

} // namespace godot

#endif // VELOCITY_MOD_SOURCE_H
