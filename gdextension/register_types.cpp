#include "register_types.h"
#include "src/register.h"


using namespace godot;

void initialize_mterrain_gdextension(ModuleInitializationLevel p_level) {
	initialize_mterrain(p_level);
}

void uninitialize_mterrain_gdextension(ModuleInitializationLevel p_level) {
	uninitialize_mterrain(p_level);
}

extern "C" {
// Initialization.
GDExtensionBool GDE_EXPORT test_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_mterrain_gdextension);
	init_obj.register_terminator(uninitialize_mterrain_gdextension);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}