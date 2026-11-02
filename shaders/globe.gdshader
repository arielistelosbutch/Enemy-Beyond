shader_type spatial;
render_mode unshaded;
// The globe: day colours, night side with town lights, a soft terminator,
// a lat/long grid and a thin atmosphere rim. UV comes from the local normal.

uniform sampler2D day_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D night_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 sun_dir = vec3(1.0, 0.0, 0.0);   // in globe-local space
uniform float grid = 1.0;

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
	// atmosphere rim
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 3.0);
	c += vec3(0.2, 0.4, 0.9) * rim * (0.25 + 0.6 * k);
	ALBEDO = c;
}
