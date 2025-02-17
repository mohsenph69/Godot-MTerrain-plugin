shader_type spatial;
render_mode unshaded,cull_disabled, world_vertex_coords;

varying float is_inner;
varying vec3 pos_local;
varying vec3 normal_local;

void vertex() {
	normal_local = abs(NORMAL);
	if(dot(VERTEX,NORMAL) < 0.0){ // inner BOX
		is_inner = 1.;
		pos_local = VERTEX;
	} else { // outer BOX
		is_inner = 0.;
		pos_local = VERTEX;
	}
}
vec3 hsv_adjustment(vec3 col, float hue_offset, float sat_offset, float val_offset) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(col.bg, K.wz), vec4(col.gb, K.xy), step(col.b, col.g));
	vec4 q = mix(vec4(p.xyw, col.r), vec4(col.r, p.yzx), step(p.x, col.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	vec3 hsv = vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
	hsv.x += hue_offset / 360.0;
	hsv.y += sat_offset;
	hsv.z += val_offset;
	K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	p.xyz = abs(fract(hsv.xxx + K.xyz) * 6.0 - K.www);
	return hsv.z * mix(K.xxx, clamp(p.xyz - K.xxx, 0.0, 1.0), hsv.y);
}
void fragment() {
	float speed = .1; //pow(max(abs(pos_local.x), max(abs(pos_local.z), abs(pos_local.y))), .65)* 0.001;
	float line_count = 10. * (1. + step(0.5,is_inner)*.5 );
	float line_width = 0.15 + (is_inner * 0.4);
	float offset = TIME * 0.05;
	float result = step(normal_local.y + normal_local.x + fract((TIME*abs(pos_local.z*speed) + pos_local.y) / 2. / pos_local.z * line_count), line_width);
	result = max(result, step(normal_local.y + normal_local.z + fract((TIME*abs(pos_local.x*speed) + pos_local.y) / 2. / pos_local.x * line_count), line_width));
	result = max(result, step(normal_local.z + normal_local.x + fract((TIME*abs(pos_local.y*speed) + pos_local.z) / 2. / pos_local.y * line_count), line_width));

	ALPHA = result ; //+ (.15* is_inner);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = hsv_adjustment(normal_local, 50. + (180.*is_inner), -0.05 , -0.6 - (0.25* is_inner));


}
