shader_type spatial;

uniform sampler2D mterrain_heightmap;
uniform sampler2D mterrain_normals;
uniform vec3 region_world_position;
uniform float region_size;
uniform float region_a;
uniform float region_b;
varying vec2 world_uv;
varying vec2 region_uv;

void vertex(){
	world_uv = (NODE_POSITION_WORLD + VERTEX).xz;
	region_uv = (world_uv - region_world_position.xz)/region_size;
	region_uv = region_uv*region_a + region_b;
	VERTEX.y = texture(mterrain_heightmap, region_uv).r;
	vec3 n = texture(mterrain_normals, region_uv).rgb;
	n = fma(n,vec3(2.0),vec3(-1.0));
	NORMAL = n;
	//Scale world uv for terrain texture
	world_uv /= 10.0;
}

void fragment(){
	ALBEDO = vec3(0.3);
}
