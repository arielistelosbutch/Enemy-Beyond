shader_type spatial;
// Enemy Beyond world material: PS1-style vertex jitter + world-space
// triplanar pixel textures (nearest filtering), lit by Godot's normal lights.
render_mode diffuse_lambert, specular_schlick_ggx;
// (0.50: the same world material, with a metal sheen for guns, machines and their alloy)

uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool use_tex = true;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float uv_scale = 0.5;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float jitter = 1.0;          // 0 = off
uniform float metal = 0.0;
uniform float rough = 0.6;
uniform vec2 snap_res = vec2(320.0, 180.0);
uniform float wind = 0.0;            // >0: top of the mesh sways (trees, wheat)
global uniform float wind_strength;  // set by the mission (storm = stronger)

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	if (wind > 0.0) {
		vec3 o = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		float ph = TIME * 1.3 + o.x * 0.35 + o.z * 0.27;
		float gust = 0.6 + 0.4 * sin(TIME * 0.37 + o.x * 0.05);
		float s = wind * h * gust * max(wind_strength, 0.3);
		VERTEX.x += (sin(ph) + 0.35 * sin(ph * 2.7 + VERTEX.z)) * s;
		VERTEX.z += cos(ph * 0.8 + 1.3) * s * 0.6;
	}
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (jitter > 0.0 && clip.w > 0.0) {
		vec2 ndc = clip.xy / clip.w;
		vec2 res = snap_res / jitter;
		ndc = floor(ndc * res + 0.5) / res;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 c = albedo.rgb;
	if (use_tex) {
		vec3 b = abs(w_nrm);
		b = pow(b, vec3(4.0));
		b /= (b.x + b.y + b.z);
		vec3 p = w_pos * uv_scale;
		vec3 tx = texture(tex, p.zy).rgb;
		vec3 ty = texture(tex, p.xz).rgb;
		vec3 tz = texture(tex, p.xy).rgb;
		c *= tx * b.x + ty * b.y + tz * b.z;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
	EMISSION = emission_color * emission_energy;
}
