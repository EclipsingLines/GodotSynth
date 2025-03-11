#pragma once
#include "../../core/modulation_source.h"
#include "../../core/wave_helper.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

class LFO : public ModulationSource {
	GDCLASS(LFO, ModulationSource);

public:
	virtual Ref<ModulationSource> duplicate() const override {
		Ref<LFO> dup;
		dup.instantiate();
		dup->set_rate(rate);
		dup->set_wave_type(wave_type);
		dup->set_amplitude(amplitude);
		dup->set_phase_offset(phase_offset);
		dup->set_pulse_width(pulse_width);
		return dup;
	}

private:
	float rate; // Frequency in Hz
	WaveHelper::WaveType wave_type;
	float amplitude;
	float phase_offset;
	double phase;
	float pulse_width;

protected:
	static void _bind_methods();

public:
	LFO();
	~LFO();

	// Process the LFO at the given time (in seconds)
	float process(float time);

	// Implement ModulationSource interface
	float get_value(const Ref<SynthNoteContext> &context) const override;
	void reset() override;

	void set_pulse_width(float p_pulse_width);
	float get_pulse_width() const;

	// Parameter setters/getters
	void set_rate(float p_rate);
	float get_rate() const;

	void set_wave_type(WaveHelper::WaveType p_wave_type);
	WaveHelper::WaveType get_wave_type() const;

	void set_amplitude(float p_amplitude);
	float get_amplitude() const;

	void set_phase_offset(float p_phase_offset);
	float get_phase_offset() const;
};

} // namespace godot
