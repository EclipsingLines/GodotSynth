#ifndef NOTCH_FILTER_H
#define NOTCH_FILTER_H

#include "state_variable_filter.h"

namespace godot {

class NotchFilter : public StateVariableFilter {
	GDCLASS(NotchFilter, StateVariableFilter)

public:
	// Parameter names
	static constexpr const char *PARAM_BANDWIDTH = "bandwidth";

protected:
	static void _bind_methods();

public:
	NotchFilter();
	~NotchFilter();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;

	// Parameter accessors
	void set_bandwidth_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_bandwidth_parameter() const;

	Ref<SynthAudioEffect> duplicate() const override;
};

} // namespace godot

#endif // NOTCH_FILTER_H
