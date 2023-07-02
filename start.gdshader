shader_type spatial;

uniform sampler2D mterrain_heightmap;
uniform sampler2D mterrain_normals;
uniform vec3 region_world_position;
uniform float region_size;
uniform float region_a;
uniform float region_b;

void vertex(){
	vec2 region_uv = (NODE_POSITION_WORLD - region_world_position + VERTEX).xz/region_size;
	vec2 terrain_heightmap_uv = region_uv*region_a + region_b;
	VERTEX.y = texture(mterrain_heightmap, terrain_heightmap_uv).r;
	vec3 n = texture(mterrain_normals, terrain_heightmap_uv).rbg;
	n = n*2.0 - 1.0;
	n.y = sqrt(1.0 - n.x*n.x - n.z*n.z);
	//n.z *= -1.0;
	NORMAL = n;
}
