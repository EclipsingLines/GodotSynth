#pragma once
#include <godot_cpp/classes/resource.hpp>

namespace godot {

class SynthNoteContext;

class ModulationSource : public Resource {
	GDCLASS(ModulationSource, Resource);

protected:
	static void _bind_methods();

public:
	ModulationSource() = default;
	virtual ~ModulationSource() = default;

	// Get the modulation value at the given context
	virtual float get_value(const Ref<SynthNoteContext> &context) const;

	// Reset the modulation source state
	virtual void reset();

	// Create a duplicate of this modulation source
	virtual Ref<ModulationSource> duplicate() const = 0;
};

} // namespace godot
