/* godot-cpp integration testing project.
 *
 * This is free and unencumbered software released into the public domain.
 */

#include "register_types.h"

#include <gdextension_interface.h>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "mterrain.h"
#include "mgrid.h"
#include "mchunk_generator.h"
#include "mchunks.h"
#include "mraw16.h"
#include "mregion.h"
#include "mbrush_manager.h"
#include "mcollision.h"

#include "grass/mgrass.h"

using namespace godot;

void initialize_test_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	ClassDB::register_class<MTerrain>();
	ClassDB::register_class<MGrid>();
	ClassDB::register_class<MChunkGenerator>();
	ClassDB::register_class<MChunks>();
	ClassDB::register_class<MRegion>();
	ClassDB::register_class<MRaw16>();
	ClassDB::register_class<MBrushManager>();
	ClassDB::register_class<MCollision>();
	ClassDB::register_class<MGrass>();
}

void uninitialize_test_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {}

}

extern "C" {
// Initialization.
GDExtensionBool GDE_EXPORT test_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_test_module);
	init_obj.register_terminator(uninitialize_test_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}