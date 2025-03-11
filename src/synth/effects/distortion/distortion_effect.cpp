#include "distortion_effect.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

const char *DistortionEffect::PARAM_DRIVE = "drive";
const char *DistortionEffect::PARAM_MIX = "mix";
const char *DistortionEffect::PARAM_OUTPUT_GAIN = "output_gain";

DistortionEffect::DistortionEffect() {
	// Initialize parameters
	Ref<ModulatedParameter> drive_param = memnew(ModulatedParameter);
	drive_param->set_base_value(1.0f); // Unity gain by default
	set_parameter(PARAM_DRIVE, drive_param);

	Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
	mix_param->set_base_value(0.5f); // 50% mix by default
	set_parameter(PARAM_MIX, mix_param);

	Ref<ModulatedParameter> output_gain_param = memnew(ModulatedParameter);
	output_gain_param->set_base_value(1.0f); // Unity gain by default
	set_parameter(PARAM_OUTPUT_GAIN, output_gain_param);
}

DistortionEffect::~DistortionEffect() {
	
}

void DistortionEffect::_bind_methods() {
	// Intentionally left blank.  Subclasses will bind their own methods.
}
}
