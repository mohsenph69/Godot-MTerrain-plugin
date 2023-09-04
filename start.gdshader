shader_type spatial;



uniform sampler2D mterrain_heightmap:filter_nearest;
uniform sampler2D mterrain_normals:filter_nearest;
uniform sampler2D mterrain_splatmap:filter_nearest;

uniform vec3 region_world_position;
uniform float region_size;
uniform float region_a;
uniform float region_b;
varying vec3 world_pos;
varying vec2 region_uv;

varying vec3 splatmap;
varying flat float alpha;
void vertex(){
	world_pos = (NODE_POSITION_WORLD + VERTEX);
	region_uv = (world_pos.xz - region_world_position.xz)/region_size;
	region_uv = region_uv*region_a + region_b;
	VERTEX.y = texture(mterrain_heightmap, region_uv).r;
	world_pos.y = VERTEX.y;
	vec3 n = texture(mterrain_normals, region_uv).rgb;
	n = fma(n,vec3(2.0),vec3(-1.0));
	NORMAL = n;
	//Scale world uv for terrain texture
	world_pos /= 10.0;
	
	vec4 s = texture(mterrain_splatmap,region_uv);
	splatmap = s.rgb;
	alpha = s.a;
}

void fragment(){
	uint state = uint(alpha*255.0);
	if( (state&uint(1))==uint(1)){
		discard;
	}
	vec4 s = texture(mterrain_splatmap,region_uv);
	ALBEDO = splatmap;

}
