@tool
extends Object
class_name  MTerrainSettings



static func add_projects_settings()->void:
	if not ProjectSettings.has_setting(MHlodNode3D.state_data_get_prop_name()):
		ProjectSettings.set(MHlodNode3D.state_data_get_prop_name(),MHlodNode3D.state_data_get_cache_size())
		ProjectSettings.add_property_info({
		"name":MHlodNode3D.state_data_get_prop_name(),
		"class_name":&"",
		"type":TYPE_INT,
		"hint":PROPERTY_HINT_NONE,
		"hint_string":"",
		"usage":PROPERTY_USAGE_DEFAULT
		})
		ProjectSettings.set_initial_value(MHlodNode3D.state_data_get_prop_name(),MHlodNode3D.state_data_get_cache_size())
