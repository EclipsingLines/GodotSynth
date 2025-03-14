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

		// Copy curve types
		dup->set_attack_type(attack_type);
		dup->set_decay_type(decay_type);
		dup->set_release_type(release_type);

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

	// The envelope curve types.
	enum CurveType {
		LINEAR,
		EXPONENTIAL,
		LOGARITHMIC
	};

private:
	// ADSR parameters.
	float attack;
	float decay;
	float sustain_level;
	float release;
	float total_time;
	float release_level;

	float default_sustain_time;

	// Curve type for each stage
	CurveType attack_type;
	CurveType decay_type;
	CurveType release_type;

	// State variables
	mutable float current_level;
	mutable Stage current_stage;
	mutable double stage_start_time; // Stores the note_time when the current stage began
	mutable float release_start_level; // Stores the level at the start of release

protected:
	static void _bind_methods();

public:
	ADSR();
	~ADSR();

	// Implement ModulationSource interface
	float get_value(const Ref<SynthNoteContext> &context) const override;
	void reset() override;

	// ADSR parameter setters/getters.
	void set_attack(float p_attack);
	float get_attack() const;

	void set_decay(float p_decay);
	float get_decay() const;

	void set_sustain(float p_sustain);
	float get_sustain() const;

	void set_release(float p_release);
	float get_release() const;

	// Curve type setters/getters
	void set_attack_type(CurveType p_type);
	CurveType get_attack_type() const;

	void set_decay_type(CurveType p_type);
	CurveType get_decay_type() const;

	void set_release_type(CurveType p_type);
	CurveType get_release_type() const;
};

} // namespace godot
VARIANT_ENUM_CAST(ADSR::Stage);
VARIANT_ENUM_CAST(ADSR::CurveType);
