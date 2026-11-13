shader_type spatial;
render_mode unshaded;
// The globe: day colours, night side with town lights, a soft terminator,
// a lat/long grid and a thin atmosphere rim. UV comes from the local normal.

uniform sampler2D day_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D night_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 sun_dir = vec3(1.0, 0.0, 0.0);   // in globe-local space
uniform float grid = 1.0;
// 0.69: picking the first base - the blocs of 1990 (rgb = colour, a = number / 16)
uniform sampler2D region_tex : filter_nearest, repeat_disable;
uniform float regions = 0.0;
uniform float hl_bloc = 0.0;      // the bloc under the mouse (its a), 0 = none

varying vec3 lnorm;

void vertex() {
	lnorm = normalize(VERTEX);
}

void fragment() {
	vec3 n = normalize(lnorm);
	float lon = atan(n.x, n.z);
	float lat = asin(clamp(n.y, -1.0, 1.0));
	vec2 uv = vec2(lon / 6.2831853 + 0.5, 0.5 - lat / 3.1415926);
	vec3 day = texture(day_tex, uv).rgb;
	vec3 night = texture(night_tex, uv).rgb;
	float l = dot(n, normalize(sun_dir));
	float k = smoothstep(-0.12, 0.18, l);
	vec3 c = mix(day * 0.08 + night * 1.2, day * (0.35 + 0.75 * max(l, 0.0)), k);
	// grid every 15 degrees
	float g = 0.0;
	if (grid > 0.0) {
		vec2 dg = vec2(lon, lat) / 0.2617994;
		vec2 f = abs(fract(dg) - 0.5);
		g = 1.0 - smoothstep(0.47, 0.5, max(f.x, f.y));
		g = smoothstep(0.0, 1.0, (max(f.x, f.y) - 0.485) * 60.0);
	}
	c += vec3(0.15, 0.3, 0.5) * g * 0.35;
	if (regions > 0.0) {
		vec4 r = texture(region_tex, uv);
		if (r.a > 0.01) {
			float hl = 1.0 - step(0.02, abs(r.a - hl_bloc));
			c = mix(c, r.rgb, 0.18 + 0.32 * hl);
			// the border: a neighbour of another bloc (or the sea)
			vec2 px = 1.0 / vec2(textureSize(region_tex, 0));
			// a border with another bloc: bright; the coast (sea next to it): faint
			float edge = 0.0;
			vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
			for (int i = 0; i < 4; i++) {
				float na = texture(region_tex, uv + offs[i]).a;
				if (abs(na - r.a) > 0.02) {
					edge = max(edge, na < 0.01 ? 0.22 : 0.75);
				}
			}
			c = mix(c, vec3(1.0, 0.95, 0.8), edge);
		}
	}
	// atmosphere rim
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 3.0);
	c += vec3(0.2, 0.4, 0.9) * rim * (0.25 + 0.6 * k);
	ALBEDO = c;
}
