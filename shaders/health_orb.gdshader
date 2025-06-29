shader_type canvas_item;
render_mode blend_mix, unshaded;

/*──────────────────────────────
  СТАРЫЕ UNIFORM-Ы (НЕ ТРОГАТЬ)
  ──────────────────────────────*/
uniform bool   pixelate               = true;
uniform int    pixel_scale  : hint_range(1, 32, 1) = 4;

uniform bool   light_effect           = false;
uniform bool   border_exclusion_effect = false;
uniform bool   wave_fix_on_border     = false;
uniform bool   transparent_empty      = false;

uniform bool   glow_effect            = true;
uniform vec4   glow_color  : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float  glow_size   : hint_range(0.0, 2.0, 0.01) = 0.8;
uniform float  glow_intensity : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float  glow_pulse_speed : hint_range(0.0, 10.0, 0.01) = 2.0;

uniform vec4   water_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float  water_wave_speed  : hint_range(-100, 100, 0.01) = 2.0;
uniform float  water_wave_ci     : hint_range(0, 2, 0.01) = 0.05;
uniform float  water_back_lightness : hint_range(0, 1, 0.01) = 0.8;
uniform float  wave_num          : hint_range(0, 8, 1) = 2.0;

uniform vec4   ball_color   : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float  ball_border_ci : hint_range(0, 50, 1) = 5.0;
uniform float  ball_light_speed : hint_range(-100, 100, 0.01) = 2.0;

uniform bool   plane_inclined_effect = false;
uniform float  plane_inclined_ratio  : hint_range(0.0, 0.5, 0.01) = 0.05;

uniform float  iniTime      = 0.0;
uniform float  height       : hint_range(0, 1, 0.01) = 0.5;
uniform float  oheight      : hint_range(0, 1, 0.01) = 0.5;

uniform bool   vibration_effect = false;
uniform float  vibration_time   = 0.0;
uniform float  vibration_effect_timelength : hint_range(0, 10, 0.01) = 4.0;
uniform float  vibration_speed  : hint_range(-100, 100, 0.01) = 8.0;
uniform float  vibration_magnitude : hint_range(0, 10, 0.01) = 0.25;
uniform float  vibration_wave_ci   : hint_range(0, 2, 0.01) = 0.3;

uniform float  refraction_ratio_glass : hint_range(0, 10, 0.01) = 0.2;
uniform float  refraction_ratio_water : hint_range(0, 10, 0.01) = 0.6;

/*──────────────────────────────
  НОВЫЕ «ФИШКИ» — по умолчанию OFF
  ──────────────────────────────*/
uniform bool   ring_effect            = false;              // главный рубильник

uniform float  fill_percent : hint_range(0.0, 1.0, 0.01) = 1.0;           // заполнение 0–1
uniform float  ring_width   : hint_range(0.01, 0.5, 0.01) = 0.15;          // толщина кольца
uniform float  ring_glow_intensity     = 1.0;
uniform float  ring_glow_width         = 0.02;

uniform vec3   ring_colour            : source_color = vec3(0.00, 0.16, 0.13);
uniform vec3   ring_inner_glow_colour : source_color = vec3(0.00, 1.00, 1.00);
uniform vec3   ring_outer_glow_colour : source_color = vec3(1.00, 0.80, 0.10);

uniform vec3   fill_inner_colour      : source_color = vec3(0.35, 1.00, 1.00);
uniform vec3   fill_outer_colour      : source_color = vec3(0.00, 0.35, 1.00);

/*──────────────────────────────
              ФУНКЦИИ
  ──────────────────────────────*/
vec4 ontop(vec4 base, vec4 blend)     { return mix(base, blend, blend.a); }
vec4 exclusion(vec4 base, vec4 blend) { return base + blend - 2.0 * base * blend * base; }

/*──────────────────────────────
              MAIN
  ──────────────────────────────*/
void fragment() {
    /*── 1. Pixel-snap (как было) ──*/
    vec2 px_step = SCREEN_PIXEL_SIZE * float(max(pixel_scale, 1));
    vec2 pUV     = floor(UV / px_step) * px_step + px_step * 0.5;
    vec2 qUV     = pixelate ? pUV : UV;

    /*── 2. Базовые переменные ──*/
    float NTIME  = vibration_effect ? TIME + vibration_time : TIME + vibration_effect_timelength;
    vec2  suv    = qUV * 0.5 - 0.5;            // -0.25 … +0.25
    vec2  uv     = (qUV - 0.5) * 0.5;          // -0.25 … +0.25
    float a      = wave_fix_on_border ? 2.0 : 1.0;
    float b      = wave_fix_on_border ? 1.0 : 0.5;

    /*── 3. Быстрый выход (как было) ──*/
    bool skip_render = transparent_empty && height <= 0.0 && oheight <= 0.0;
    if (skip_render || distance(qUV, vec2(0.5)) > 0.5) {
        COLOR = vec4(0.0);
    } else {
        /*──────────── ВОДА ───────────*/
        if (height == 1.0) {
            COLOR = vec4(water_color.rgb, 1.0);
        } else {
            float t   = vibration_effect ? (NTIME - TIME) / vibration_effect_timelength : 0.0;
            float dH  = plane_inclined_effect
                      ? sin(mod((qUV.x + TIME * water_wave_speed) * PI, TAU)) * plane_inclined_ratio : 0.0;
            float dHo = plane_inclined_effect
                      ? sin(mod((qUV.x - TIME * water_wave_speed) * PI + PI, TAU)) * plane_inclined_ratio : 0.0;

            float H   = vibration_effect ? mix(height - uv.x * sin(t * PI * vibration_speed), height, t) : height;
            float oH  = vibration_effect ? oheight : oheight;

            float CI  = vibration_effect
                      ? mix((water_wave_ci + vibration_wave_ci) * vibration_magnitude, water_wave_ci, t)
                      : water_wave_ci;

            if (sin((cos(suv.x * PI * a) + NTIME * water_wave_speed) * wave_num) * CI + (1.0 - H) < qUV.y + dHo) {
                COLOR = vec4(water_color.rgb * water_back_lightness, water_color.a);
            } else {
                if (height - oheight != 0.0) {
                    if (sin((cos(suv.x * PI * a + PI * b) + NTIME * water_wave_speed) * wave_num) * CI + (1.0 - oH) < qUV.y + dH) {
                        COLOR = vec4(water_color.rgb, water_color.a) * 0.5;
                    } else if (sin((cos(suv.x * PI * a) + NTIME * water_wave_speed) * wave_num) * CI + (1.0 - oH) < qUV.y + dHo) {
                        COLOR = vec4(water_color.rgb * water_back_lightness, water_color.a) * 0.5;
                    } else {
                        COLOR = vec4(0.0);
                    }
                } else {
                    COLOR = vec4(0.0);
                }
            }

            if (sin((cos(suv.x * PI * a + PI * b) + NTIME * water_wave_speed) * wave_num) * CI + (1.0 - H) < qUV.y + dH) {
                COLOR = vec4(water_color);
            }

            if (plane_inclined_effect && plane_inclined_ratio != 0.0 &&
                qUV.y <= 1.0 - height + 0.005 && qUV.y >= 1.0 - height - 0.005) {
                COLOR.rgb += (sin(qUV.x + TIME) + 1.0) * 0.08;
            }
        }

        /*──────────── ШАР ───────────*/
        float L = 0.0;
        if (light_effect) {
            L = cos(distance(qUV, sin(suv * suv) + NTIME * ball_light_speed)) * 0.25;
        }

        if (glow_effect) {
            float pulse = sin(TIME * glow_pulse_speed) * 0.5 + 0.5;
            float dist  = distance(qUV, vec2(0.5));
            float glow  = smoothstep(glow_size, 0.0, dist);
            vec4  glow_layer = glow_color * glow * glow_intensity * pulse;

            COLOR.rgb += glow_layer.rgb * glow_layer.a;
            COLOR.a    = clamp(COLOR.a + glow_layer.a, 0.0, 1.0);
        }

        vec4 ballLayer = vec4(vec3(1.0),
                              pow(distance(qUV, vec2(0.5)) * 2.0, ball_border_ci) + L) * ball_color;

        vec4 result = border_exclusion_effect ? exclusion(COLOR, ballLayer) : ontop(COLOR, ballLayer);
        result.a *= ball_color.a;
        COLOR = result;
    }

    /*────────────────────────────────────
            4. ДОПОЛНИТЕЛЬНОЕ КОЛЬЦО
      ────────────────────────────────────*/
    if (ring_effect) {
        /* координаты: центр в (0,0), радиус 1 */
        vec2 rUV = (qUV - vec2(0.5)) * 2.0;
        float dist = length(rUV);

        /* маски */
        float outerMask   = step(dist, 1.0);
        float innerMask   = step(dist, 1.0 - ring_width);
        float ringMask    = outerMask - innerMask;

        /* заливка */
        float fillMask    = innerMask;
        float fillLevel   = mix(-1.0, 1.0, clamp(fill_percent, 0.0, 1.0)); // -1 низ, +1 верх
        float fillInside  = step(rUV.y, fillLevel) * fillMask;

        /* градиент цвета заливки */
        float fy = (rUV.y + 1.0) * 0.5;                // 0 (низ) … 1 (верх)
        vec3  fillCol = mix(fill_inner_colour, fill_outer_colour, fy);

        /* свечение кольца */
        float glowEdge  = smoothstep(1.0 - ring_glow_width, 1.0, dist);
        float glowInner = smoothstep(1.0 - ring_width, 1.0 - ring_width + ring_glow_width, dist);
        float glowVal   = (1.0 - glowEdge) + (1.0 - glowInner);
        vec3  glowCol   = ring_inner_glow_colour * glowInner +
                          ring_outer_glow_colour * glowEdge;

        /* итог */
        vec3 ringCol    = ring_colour * ringMask +
                          glowCol * glowVal * ring_glow_intensity;

        vec3 addRGB     = ringCol + fillCol * fillInside;
        float addAlpha  = clamp(ringMask + fillInside, 0.0, 1.0);

        COLOR = ontop(COLOR, vec4(addRGB, addAlpha));
    }
}
