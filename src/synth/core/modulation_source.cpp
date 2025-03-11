#include "modulation_source.h"
#include "synth_note_context.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void ModulationSource::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_value", "context"), &ModulationSource::get_value);
	ClassDB::bind_method(D_METHOD("reset"), &ModulationSource::reset);
}

float ModulationSource::get_value(const Ref<SynthNoteContext> &context) const {
	// Base implementation returns 0, to be overridden by derived classes
	return 0.0f;
}

void ModulationSource::reset() {
	// Base implementation does nothing, to be overridden by derived classes
	UtilityFunctions::print("ModulationSource::reset called");
}

} // namespace godot
