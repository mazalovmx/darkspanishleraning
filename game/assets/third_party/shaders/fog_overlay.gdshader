// 2D Fog Overlay, by blinks. License: CC0 1.0.
// Source: https://godotshaders.com/shader/2d-fog-overlay/ (accessed 2026-10-07)
// Modified for Godot 4: hint_color became source_color, the local named "output"
// was renamed, and the noise sampler repeats and filters. Assign a NoiseTexture2D
// to "noise" and use on a ColorRect covering the area.
shader_type canvas_item;

// Amount of detail.
uniform int octaves = 4;

// Opacity of the output fog.
uniform float starting_amplitude: hint_range(0.0, 0.5) = 0.5;

// Rate of pattern within the fog.
uniform float starting_frequency = 1.0;

// Shift towards transparency (clamped) for sparser fog.
uniform float shift: hint_range(-1.0, 0.0) = -0.2;

// Direction and speed of travel.
uniform vec2 velocity = vec2(1.0, 1.0);

// Color of the fog.
uniform vec4 fog_color: source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Noise texture; any filtered, seamless texture is fine.
uniform sampler2D noise: repeat_enable, filter_linear;

float rand(vec2 uv) {
	float amplitude = starting_amplitude;
	float frequency = starting_frequency;
	float total = 0.0;
	for (int i = 0; i < octaves; i++) {
		total += texture(noise, uv * frequency).x * amplitude;
		amplitude /= 2.0;
		frequency *= 2.0;
	}
	return clamp(total + shift, 0.0, 1.0);
}

void fragment() {
	vec2 motion = vec2(rand(UV + TIME * starting_frequency * velocity));
	COLOR = mix(vec4(0.0), fog_color, rand(UV + motion));
}
