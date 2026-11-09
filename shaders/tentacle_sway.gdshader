// Tentacles that live (Levit, Levit Mírotvůrce, Nádor): every one sways on its own, harder towards the tip,
// and they trail behind when the creature moves. Model space; the root of the tentacles is at "top" (Y).
shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.5, 0.1, 0.3, 1.0);
uniform float roughness = 0.3;
uniform float metallic = 0.0;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float top = -0.05;          // where the tentacles hang from
uniform float amp = 0.09;           // how far a tip swings (at 1 m below the root)
uniform float speed = 1.0;
instance uniform vec3 vel = vec3(0.0);   // the creature's velocity in model space (set from alien.gd)

void vertex() {
	float d = max(0.0, top - VERTEX.y);
	float w = d * d;
	float ph = atan(VERTEX.x, VERTEX.z) * 3.0;                 // each tentacle its own rhythm
	vec3 off = vec3(sin(TIME * 1.6 * speed + ph + d * 3.0), 0.0, cos(TIME * 1.25 * speed + ph * 1.3 + d * 2.5)) * amp * w;
	vec2 v = vel.xz;
	off.xz -= v * 0.11 * w;                                   // they trail behind
	off.y += length(v) * 0.045 * w;                           // and lift a little at speed
	VERTEX += off;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission.rgb;
}
