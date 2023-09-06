//Include this before Vertex function
vec4 get_texture256(in sampler2D _tex,in sampler2DArray _tex_arr,in vec2 _uv){
	vec2 px_pos = vec2(textureSize(_tex,0))*(region_uv - region_b);
	ivec2 ipx_pos = ivec2(px_pos);
	float s00 = texelFetch(_tex,ipx_pos,0).r*255.0;
	float s01 = texelFetch(_tex,ipx_pos+ivec2(1,0),0).r*255.0;
	float s10 = texelFetch(_tex,ipx_pos+ivec2(0,1),0).r*255.0;
	float s11 = texelFetch(_tex,ipx_pos+ivec2(1,1),0).r*255.0;
	vec4 a00 = texture(_tex_arr,vec3(_uv,s00));
	vec4 a01 = texture(_tex_arr,vec3(_uv,s01));
	vec4 a10 = texture(_tex_arr,vec3(_uv,s10));
	vec4 a11 = texture(_tex_arr,vec3(_uv,s11));
	px_pos = fract(px_pos);
	vec4 t = mix(a00,a01,px_pos.x);
	vec4 b = mix(a10,a11,px_pos.x);
	return mix(t,b,px_pos.y);
}