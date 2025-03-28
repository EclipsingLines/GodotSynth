#ifndef MS20_FILTER_H
#define MS20_FILTER_H

#include "filter_effect.h"

namespace godot {

class MS20Filter : public FilterEffect {
	GDCLASS(MS20Filter, FilterEffect)
public:
	static const char *PARAM_SATURATION;

private:
	// Filter state variables
	float x1 = 0.0f;
	float x2 = 0.0f;
	float y1 = 0.0f;
	float y2 = 0.0f;

	// Coefficients
	float a1 = 0.0f;
	float a2 = 0.0f;
	float b0 = 1.0f;
	float b1 = 0.0f;
	float b2 = 0.0f;

	// Saturation function
	float saturate(float x, float p_saturation) const;

protected:
	static void _bind_methods();

public:
	MS20Filter();
	~MS20Filter();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;

	// Saturation parameter accessors
	void set_saturation_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_saturation_parameter() const;
	void set_saturation_base_value(float p_value);
	float get_saturation_base_value() const;

	Ref<SynthAudioEffect> duplicate() const override;
};

} // namespace godot

#endif // MS20_FILTER_H
