
shader_type canvas_item;

uniform float threshold : hint_range(0.0, 1.0) = 0.15;
uniform float softness : hint_range(0.0, 0.5) = 0.08;

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    float brightness = (color.r + color.g + color.b) / 3.0;
    float alpha = 1.0 - smoothstep(
        1.0 - threshold - softness,
        1.0 - threshold,
        brightness
    );

    COLOR = vec4(color.rgb, color.a * alpha);
}
