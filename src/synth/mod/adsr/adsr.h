#pragma once
#include "../../core/modulation_source.h"
#include <algorithm>
#include <godot_cpp/classes/curve.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

namespace godot {

class ADSR : public ModulationSource {
	GDCLASS(ADSR, ModulationSource);

public:
	virtual Ref<ModulationSource> duplicate() const override {
		Ref<ADSR> dup;
		dup.instantiate();
		dup->set_attack(attack);
		dup->set_decay(decay);
		dup->set_sustain(sustain_level);
		dup->set_release(release);
		
		// Duplicate the curve if it exists
		if (visual_curve.is_valid()) {
			Ref<Curve> new_curve = visual_curve->duplicate();
			dup->set_curve(new_curve);
		}
		
		return dup;
	}

public:
	// The envelope stages.
	enum Stage {
		ATTACK,
		DECAY,
		SUSTAIN,
		RELEASE,
		OFF
	};

private:
	// ADSR parameters.
	float attack;
	float decay;
	float sustain_level;
	float release;
	float total_time;
	float release_level;
	// For display only: a fixed sustain duration for visualizing the curve.
	Ref<Curve> visual_curve;
	float default_sustain_time;
	
	// State variables
	mutable float current_level;
	mutable Stage current_stage;
	mutable double stage_start_time;  // Stores the note_time when the current stage began
	mutable float release_start_level; // Stores the level at the start of release

	// Update the curve's baked points based on ADSR parameters for visualization.
	void _update_curve();

protected:
	static void _bind_methods();

public:
	ADSR();
	~ADSR();

	// Implement ModulationSource interface
	float get_value(const Ref<SynthNoteContext> &context) const override;
	void reset() override;

	// Curve used for visuals
	// TODO: Make custom UI inspector for mod sources
	Ref<Curve> get_curve() const;
	void set_curve(Ref<Curve> p_curve);

	// ADSR parameter setters/getters.
	void set_attack(float p_attack);
	float get_attack() const;

	void set_decay(float p_decay);
	float get_decay() const;

	void set_sustain(float p_sustain);
	float get_sustain() const;

	void set_release(float p_release);
	float get_release() const;
};

} // namespace godot
VARIANT_ENUM_CAST(ADSR::Stage);
