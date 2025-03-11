#ifndef NOTE_DURATION_MOD_SOURCE_H
#define NOTE_DURATION_MOD_SOURCE_H

#include "../../core/modulation_source.h"

namespace godot {

class NoteDurationModSource : public ModulationSource {
	GDCLASS(NoteDurationModSource, ModulationSource)

private:
	float attack_time;
	float max_time;
	float min_value;
	float max_value;
	bool invert;

protected:
	static void _bind_methods();

public:
	NoteDurationModSource();
	~NoteDurationModSource();

	// Override the base class method to provide note duration modulation
	virtual float get_value(const Ref<SynthNoteContext> &context) const override;
	
	// Reset is not needed for note duration (it's stateless)
	virtual void reset() override;
	
	// Create a duplicate of this modulation source
	virtual Ref<ModulationSource> duplicate() const override;

	// Setters and getters
	void set_attack_time(float p_time);
	float get_attack_time() const;
	
	void set_max_time(float p_time);
	float get_max_time() const;
	
	void set_min_value(float p_min);
	float get_min_value() const;
	
	void set_max_value(float p_max);
	float get_max_value() const;
	
	void set_invert(bool p_invert);
	bool get_invert() const;
};

} // namespace godot

#endif // NOTE_DURATION_MOD_SOURCE_H
