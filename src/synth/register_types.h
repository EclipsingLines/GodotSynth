#ifndef EXAMPLE_REGISTER_TYPES_H
#define EXAMPLE_REGISTER_TYPES_H

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void initialize_gdextension_types(ModuleInitializationLevel p_level);
void uninitialize_gdextension_types(ModuleInitializationLevel p_level);
void register_core_classes();
void register_modulation_sources();
void register_va_classes();

#endif // EXAMPLE_REGISTER_TYPES_H
