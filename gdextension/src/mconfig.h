#ifndef MCONFIG
#define MCONFIG


#define M_IMAGE_LAYER_ON



#define M_DEBUG
//#undef M_DEBUG

#define M_SIZE_LIST_STRING "8,16,32,64,128,256,512,1024,2048"
#define M_SIZE_LIST        {8,16,32,64,128,256,512,1024,2048}
#define M_H_SCALE_LIST_STRING "0.25,0.5,1,2,4,8,16,32"
#define M_H_SCALE_LIST        {0.25,0.5,1,2,4,8,16,32}

#define M_DEF_MAX_HEIGHT 1000
#define M_DEF_MIN_HEIGHT 0

#define M_MAIN 0
#define M_L 1
#define M_R 2
#define M_T 3
#define M_B 4
#define M_LT 5
#define M_RT 6
#define M_LB 7
#define M_RB 8
#define M_LRTB 9
#define M_MAX_EDGE 10

//You should add also everything start with mterrain_ prefix to the list bellow
#define M_SHADER_RESERVE_UNIFORMS "region_world_position,region_size,region_a,region_b,min_lod,world_pos,region_uv"

#define M_DEAFAULT_SHADER_PATH "res://addons/m_terrain/start.gdshader"
#define M_DEAFAULT_MATERIAL_PATH "res://addons/m_terrain/start_material.res"
#define M_SHOW_REGION_SHADER_PATH "res://addons/m_terrain/show_region.gdshader"

#endif