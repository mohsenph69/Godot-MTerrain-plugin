cmake_minimum_required(VERSION 3.6)

project(mterrain)
string(ASCII 27 ESC)



set(MTERRAIN_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/include)

set(IS_MAIN_CMAKE_BUILD FALSE)
if(CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    set(IS_MAIN_CMAKE_BUILD TRUE)
    message(STATUS "${ESC}[1;34mMain terrain build is deteted: please put the repo in addons/m_terrain directory${ESC}[0m ")
else()
    message(STATUS "${ESC}[1;34musing terrain as subdirectory is deteted. Please add godot-cpp subdirectory before this${ESC}[0m ")
endif()


if(IS_MAIN_CMAKE_BUILD)
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/godot-cpp)
endif()

if(NOT TARGET godot-cpp)
    if(IS_MAIN_CMAKE_BUILD)
        message(FATAL_ERROR "no godot-cpp target is found")
    else()
        message(FATAL_ERROR "mterrain subdirectoy should add after adding godot-cpp subdirectory! no godot-cpp directory is detected")
    endif()
endif()

get_target_property(GODOTCPP_TARGET godot-cpp GODOTCPP_TARGET)
get_target_property(GODOTCPP_ARCH godot-cpp GODOTCPP_ARCH)
get_target_property(GODOTCPP_PRECISION godot-cpp GODOTCPP_PRECISION)
get_target_property(GODOTCPP_SUFFIX godot-cpp GODOTCPP_SUFFIX)
get_target_property(GODOTCPP_SUFFIX_GENEX godot-cpp GODOTCPP_SUFFIX_GENEX)


set(CPP_PLATFORM "")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(CPP_PLATFORM "linux")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(CPP_PLATFORM "windows")
elseif(CMAKE_SYSTEM_NAME STREQUAL "MSYS")
    set(CPP_PLATFORM "windows")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set(CPP_PLATFORM "macos")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Android")
    set(CPP_PLATFORM "android")
elseif(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(CPP_PLATFORM "ios")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
    set(CPP_PLATFORM "web")
else()
    message(FATAL_ERROR "Unsupported platform: ${CMAKE_SYSTEM_NAME}")
endif()

message(STATUS "CPP_PLATFORM = ${CPP_PLATFORM}")

# set lib name
set(MTERRAIN_LIB_NAME "MTerrain${GODOTCPP_SUFFIX}")


# set prefix name
set(MTERRAIN_LIB_PREFIX "lib")
if(CMAKE_SYSTEM_NAME STREQUAL "Windows" OR CMAKE_SYSTEM_NAME STREQUAL "MSYS")
    set(MTERRAIN_LIB_PREFIX "")
endif()

# geting output directory
set(OUTPUT_DIR "")
if(IS_MAIN_CMAKE_BUILD)
    get_filename_component(PARENT_DIR ${CMAKE_CURRENT_SOURCE_DIR} DIRECTORY)
    get_filename_component(GRAND_PARENT_DIR ${PARENT_DIR} DIRECTORY)
    get_filename_component(GODOT_PROJECT_DIR ${GRAND_PARENT_DIR} DIRECTORY)
    get_filename_component(PARENT_DIR_NAME ${PARENT_DIR} NAME)
    get_filename_component(GRAND_PARENT_DIR_NAME ${GRAND_PARENT_DIR} NAME)
    if(NOT PARENT_DIR_NAME STREQUAL "m_terrain")
        message(FATAL_ERROR "parent_directory name in main build should be m_terrain, change it and clear the generate cmake files")
    endif()
    if(NOT GRAND_PARENT_DIR_NAME STREQUAL "addons")
        message(FATAL_ERROR "grand_parent_directory name in main build should be addons, change it and clear the generate cmake files")
    endif()
    set(OUTPUT_DIR ${GODOT_PROJECT_DIR}/mterrain)
else()
    set(OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR})
endif()

message(status " ------------- Building mterrain -----------")
message(status "${ESC}[1;33m -> PLATFORM: ${CPP_PLATFORM}${ESC}[0m")
message(status "${ESC}[1;33m -> GODOTCPP_TARGET: ${GODOTCPP_TARGET}${ESC}[0m")
message(status "${ESC}[1;33m -> GODOTCPP_ARCH: ${GODOTCPP_ARCH}${ESC}[0m")
message(status "${ESC}[1;33m -> GODOTCPP_PRECISION: ${GODOTCPP_PRECISION}${ESC}[0m")
message(status "${ESC}[1;33m -> MTERRAIN OUTPUT_DIR: ${OUTPUT_DIR}${ESC}[0m")
#message(status "${ESC}[1;33m -> MTERRAIN_LIB_NAME: ${MTERRAIN_LIB_NAME}${ESC}[0m")
message(status " ------------- -----------------  ------------")

file(GLOB TERRAIN_SRC 
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/util/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/hlod/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/grass/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/navmesh/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/octmesh/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/path/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/height_brushes/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/color_brushes/*.cpp
    )

## adding register in case is main build
if(IS_MAIN_CMAKE_BUILD)
    set(TERRAIN_SRC ${TERRAIN_SRC} "register_types.cpp")
endif()

file(GLOB TERRAIN_HEADER 
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/util/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/hlod/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/grass/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/navmesh/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/octmesh/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/path/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/height_brushes/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/color_brushes/*.h
    )

if(GODOTCPP_TARGET STREQUAL "template_debug")
    file(GLOB EDITOR_SRC ${CMAKE_CURRENT_SOURCE_DIR}/src/editor/*.cpp)
    list(APPEND TERRAIN_SRC ${EDITOR_SRC})
endif()

# adding target
if(IS_MAIN_CMAKE_BUILD)
    add_library(mterrain SHARED ${TERRAIN_SRC})
else()
    add_library(mterrain STATIC ${TERRAIN_SRC})
    target_include_directories(mterrain INTERFACE ${MTERRAIN_INCLUDE_DIR})
endif()

target_link_libraries(mterrain PUBLIC godot-cpp)
target_include_directories(mterrain PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

if(NOT DEFINED GODOTCPP_SYMBOL_VISIBILITY OR
   GODOTCPP_SYMBOL_VISIBILITY STREQUAL "")
    set(GODOTCPP_SYMBOL_VISIBILITY hidden)
endif()

set_target_properties(
    mterrain
    PROPERTIES
        CXX_STANDARD 17
        CXX_EXTENSIONS OFF
        CXX_VISIBILITY_PRESET ${GODOTCPP_SYMBOL_VISIBILITY}

        POSITION_INDEPENDENT_CODE ON
        BUILD_RPATH_USE_ORIGIN ON

        # Try to ensure only static libraries are selected to be linked to.
        LINK_SEARCH_START_STATIC ON
        LINK_SEARCH_END_STATIC ON

        # NOTE: Wrapping the output variables inside a generator expression
        # prevents msvc generator from adding addition Config Directories
        LIBRARY_OUTPUT_DIRECTORY "$<1:${OUTPUT_DIR}>"
        RUNTIME_OUTPUT_DIRECTORY "$<1:${OUTPUT_DIR}>"
        PDB_OUTPUT_DIRECTORY     "$<1:${OUTPUT_DIR}>" #MSVC Only, ignored on other platforms

        PREFIX "${MTERRAIN_LIB_PREFIX}"
        OUTPUT_NAME ${MTERRAIN_LIB_NAME}
        # TODO rename the file for both CMake and SCons

        # Some IDE's respect this property to logically group targets
        FOLDER "godot-cpp"
)

# copying the gdextension file
if(IS_MAIN_CMAKE_BUILD)
    if(GODOTCPP_PRECISION STREQUAL "single")
        configure_file(${CMAKE_CURRENT_SOURCE_DIR}/MTerrain.txt
                        ${OUTPUT_DIR}/MTerrain.gdextension COPYONLY)
    else()
        configure_file(${CMAKE_CURRENT_SOURCE_DIR}/MTerrain_double.txt
                        ${OUTPUT_DIR}/MTerrain.gdextension COPYONLY)
    endif()
endif()


# COPY include
file(REMOVE_RECURSE ${MTERRAIN_INCLUDE_DIR})
file(MAKE_DIRECTORY ${MTERRAIN_INCLUDE_DIR}/mterrain)
foreach(HEADER ${TERRAIN_HEADER})
    file(RELATIVE_PATH REL_PATH ${CMAKE_CURRENT_SOURCE_DIR}/src ${HEADER})
    get_filename_component(REL_PATH_DIR ${REL_PATH} DIRECTORY)
    file(MAKE_DIRECTORY "${MTERRAIN_INCLUDE_DIR}/mterrain/${REL_PATH_DIR}")
    configure_file(${HEADER} "${MTERRAIN_INCLUDE_DIR}/mterrain/${REL_PATH}" COPYONLY)
endforeach()