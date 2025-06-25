shader_type canvas_item;

uniform vec2 scroll_speed = vec2(0.1, 0.0);
uniform float fog_strength = 0.5;
uniform float time_scale = 0.2;

// TIME — встроенный в canvas_item
void fragment() {
    // 1) движение шума
	vec2 uv = -UV * 2.0 + scroll_speed * (TIME * time_scale);
    float noise_value = texture(TEXTURE, uv).r;
    float base_alpha    = fog_strength * (1.0 - noise_value);

    // 2) маска по высоте: снизу (y→1) полная сила, кверху (y→0) → 0
    //    параметров smoothstep можно подбирать
    float height_mask = smoothstep(0.1, 0.5, UV.y);

    float alpha = base_alpha * height_mask;
    COLOR = vec4(1.0, 1.0, 1.0, alpha);
}
