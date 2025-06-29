shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

/* из GD-скрипта */
uniform vec2  center_uv       = vec2(0.5);
uniform vec2  screen_size     = vec2(1280.0, 720.0);
uniform float time            = 0.0;

/* контролирует прозрачность сцены вне колец */
uniform float base_alpha      : hint_range(0.0,1.0) = 0.5;
/* финальный фейд внутри колец */
uniform float fade_out        = 1.0;

/* волновые параметры */
uniform float ring_speed      = 350.0;  // px/сек
uniform float ring_width      = 80.0;   // px

/* дисперсия RGB */
uniform float red_off         = 1.2;
uniform float green_off       = 0.8;
uniform float blue_off        = 0.4;
uniform float disper_strength = 2.0;

/* блюр/свечение/рефлекс */
uniform float blur_px         = 6.0;
uniform float glow_strength   = 0.4;
uniform float reflect_strength = 0.6;

/* HSV → RGB */
vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0,1.0/3.0,2.0/3.0))*6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p-1.0,0.0,1.0), c.y);
}
/* безопасная выборка */
vec3 tap(vec2 uv) {
    return texture(SCREEN_TEXTURE, clamp(uv,0.0,1.0)).rgb;
}
/* маска одного кольца */
float ring_mask(float d, float r, float w) {
    float h = w * 0.5;
    float a = smoothstep(r - h, r,     d);
    float b = smoothstep(r,     r + h, d);
    return clamp(a - b, 0.0, 1.0);
}

void fragment() {
    vec2 uv    = SCREEN_UV;
    vec2 dv    = uv - center_uv;
    float dist = length(dv * screen_size);

    /* радиусы и ширины трёх колец */
    float r1 = time * ring_speed;
    float w1 = ring_width;
    float r2 = r1 + w1 * 1.3;
    float w2 = w1 * 1.55;
    float r3 = r2 + w2 * 1.3;
    float w3 = w2 * 1.55;

    /* маски колец */
    float m1 = ring_mask(dist, r1, w1);
    float m2 = ring_mask(dist, r2, w2);
    float m3 = ring_mask(dist, r3, w3);
    float finalMask = max(max(m1, m2), m3);

    /* базовый цвет сцены */
    vec3 base = tap(uv);
    vec3 outcol = base;

    /* рассчёт кольцевого эффекта */
    vec2 dir = normalize(dv + 1e-4);
    float blur_uv = blur_px / screen_size.x;

    for(int i = 0; i < 3; i++) {
        float m = (i==0 ? m1 : (i==1 ? m2 : m3));
        float w = (i==0 ? w1 : (i==1 ? w2 : w3));
        if(m < 0.001) continue;

        /* RGB-дисперсия + блюр */
        float amp = m * disper_strength;
        vec2 ru = uv + dir * amp * red_off   * 0.002;
        vec2 gu = uv + dir * amp * green_off * 0.002;
        vec2 bu = uv + dir * amp * blue_off  * 0.002;

        vec3 rc = 0.5 * tap(ru - dir * blur_uv) + 0.5 * tap(ru + dir * blur_uv);
        vec3 gc = 0.5 * tap(gu - dir * blur_uv) + 0.5 * tap(gu + dir * blur_uv);
        vec3 bc = 0.5 * tap(bu - dir * blur_uv) + 0.5 * tap(bu + dir * blur_uv);
        vec3 chroma = vec3(rc.r, gc.g, bc.b);

        /* зеркальный рефлекс */
        float refl_uv = w * 0.15 / screen_size.x;
        vec3 reflex = tap(uv - dir * refl_uv);

        /* радужное свеченье */
        float hue = fract(time * 0.2 + float(i) * 0.1);
        vec3 rainbow = hsv2rgb(vec3(hue, 1.0, 1.0));

        /* glow */
        float glow = smoothstep(0.0, 0.3, m);

        vec3 ringcol = mix(chroma, reflex, reflect_strength)
                     + rainbow * (0.25 + glow_strength * glow);

        outcol = mix(outcol, ringcol, m);
    }

    /* итоговая прозрачность: base_alpha вне колец → fade_out внутри */
    float alpha = mix(base_alpha, fade_out, finalMask);
    COLOR = vec4(outcol, alpha);
}
