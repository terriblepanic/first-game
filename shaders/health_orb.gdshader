shader_type canvas_item;
render_mode blend_mix, unshaded;


uniform bool light_effect = false;
uniform bool border_exclusion_effect = false;
uniform bool wave_fix_on_border = false;

uniform bool transparent_empty = false;

uniform vec4 water_color: source_color = vec4(1, 0, 0, 1);
uniform float water_wave_speed : hint_range(-100, 100, 0.01) = 2;
uniform float water_wave_ci: hint_range(0, 2, 0.01) = 0.05;
uniform float water_back_lightness: hint_range(0, 1, 0.01) = 0.8;
uniform vec4 ball_color: source_color = vec4(vec3(1), 1);
uniform float ball_border_ci : hint_range(0, 50, 1) = 5;
uniform float ball_light_speed : hint_range(-100, 100, 0.01) = 2;
uniform float wave_num : hint_range(0, 8, 1) = 2;

uniform bool plane_inclined_effect = false;
uniform float plane_inclined_ratio : hint_range(0., 0.5, 0.01) = 0.05;

uniform float iniTime = 0.;

uniform float height : hint_range(0, 1, 0.01) = 0.5;
uniform float oheight : hint_range(0, 1, 0.01) = 0.5;

uniform bool vibration_effect = false;
uniform float vibration_time = 0;
uniform float vibration_effect_timelength: hint_range(0, 10, 0.01) = 4;
uniform float vibration_speed : hint_range(-100, 100, 0.01) = 8;
uniform float vibration_magnitude : hint_range(0, 10, 0.01) = 0.25;
uniform float vibration_wave_ci: hint_range(0, 2, 0.01) = 0.3;

uniform float refraction_ratio_glass: hint_range(0, 10, 0.01) = 0.2;
uniform float refraction_ratio_water: hint_range(0, 10, 0.01) = 0.6;

vec4 ontop(vec4 base, vec4 blend){
    return mix(base, blend, blend.a);
}

vec4 reverse(vec4 base){
    return vec4(mod(base.rgb + 1. , 2.), base.a);
}

vec4 exclusion(vec4 base, vec4 blend){
    return base + blend - 2.0 * base * blend * base;
}

float easeOutExpo(float x){
    return x == 1. ? 1. : 1. - pow(2., -10. * x);
}

vec2 shiftuv(vec2 uv, float shiftratio) {
    vec2 suv = (uv - 0.5) * 2.0;
    return (suv + sign(suv) * suv * suv * -1.0 * shiftratio) * 0.5 + 0.5;
}

void fragment() {
    if (transparent_empty && height <= 0.0 && oheight <= 0.0) {
        COLOR = vec4(0.0);
        return;
    }

    float NTIME = vibration_effect ? TIME + vibration_time : TIME + vibration_effect_timelength;

    vec2 uv = (UV - 0.5) * 0.5;
    vec2 suv = UV * 0.5 - 0.5;

    float a = wave_fix_on_border ? 2.0 : 1.0;
    float b = wave_fix_on_border ? 1.0 : 0.5;
    vec4 Cw = vec4(0.0);
    vec4 Cg = vec4(0.0);

    if (distance(UV, vec2(0.5, 0.5)) > 0.5) {
        COLOR = vec4(0.0);
    } else {
        // Static empty water
        if (height == 0.0) {
            float oH = oheight;
            if ((1.0 - oH) < UV.y) {
                COLOR = vec4(water_color) * 0.5;
            } else if ((1.0 - oH) <= UV.y) {
                COLOR = vec4(water_color * water_back_lightness) * 0.5;
            } else {
                COLOR = vec4(water_color.rgb, 1.0);
            }
        }
        // Static full water
        else if (height == 1.0) {
            COLOR = vec4(water_color.rgb, 1.0);
        }
        // Dynamic wave case
        else {
            float t = (NTIME - TIME) / vibration_effect_timelength;
            float dH = plane_inclined_effect
                       ? sin(mod((UV.x + TIME * water_wave_speed) * PI, TAU)) * plane_inclined_ratio
                       : 0.0;
            float dHo = plane_inclined_effect
                        ? sin(mod((UV.x - TIME * water_wave_speed) * PI + PI, TAU)) * plane_inclined_ratio
                        : 0.0;
            float H = vibration_effect
                      ? mix(height - uv.x * sin(t * PI * vibration_speed), height, t)
                      : height;
            float oH = vibration_effect ? oheight : oheight;
            float CI = vibration_effect
                       ? mix((water_wave_ci + vibration_wave_ci) * vibration_magnitude, water_wave_ci, t)
                       : water_wave_ci;

            if (sin((cos(suv.x * PI * a) + NTIME * water_wave_speed) * wave_num) * CI + (1.0 - H)
                < UV.y + dHo) {
                COLOR = vec4(water_color * water_back_lightness);
            } else {
                if (height - oheight != 0.0) {
                    if (sin((cos(suv.x * PI * a + PI * b) + NTIME * water_wave_speed) * wave_num)
                        * CI + (1.0 - oH) < UV.y + dH) {
                        COLOR = vec4(water_color) * 0.5;
                    } else if (sin((cos(suv.x * PI * a) + NTIME * water_wave_speed) * wave_num)
                               * CI + (1.0 - oH) < UV.y + dHo) {
                        COLOR = vec4(water_color * water_back_lightness) * 0.5;
                    } else {
                        COLOR = vec4(0.0);
                    }
                } else {
                    COLOR = vec4(0.0);
                }
            }

            if (sin((cos(suv.x * PI * a + PI * b) + NTIME * water_wave_speed) * wave_num) * CI
                + (1.0 - H) < UV.y + dH) {
                COLOR = vec4(water_color);
            }

            if (plane_inclined_effect && plane_inclined_ratio != 0.0
                && UV.y <= 1.0 - height + 0.005 && UV.y >= 1.0 - height - 0.005) {
                COLOR = COLOR + (sin(UV.x + TIME) + 1.0) * 0.08;
            }
        }

        float L = 0.0;
        if (light_effect) {
            L = cos(distance(UV, sin(suv * suv) + NTIME * ball_light_speed)) * 0.25;
        }

        COLOR = border_exclusion_effect
                ? exclusion(
                    COLOR,
                    vec4(
                        vec3(1.0),
                        pow(distance(UV, vec2(0.5, 0.5)) * 2.0, ball_border_ci) + L
                    ) * ball_color
                  )
                : ontop(
                    COLOR,
                    vec4(
                        vec3(1.0),
                        pow(distance(UV, vec2(0.5, 0.5)) * 2.0, ball_border_ci) + L
                    ) * ball_color
                  );
        COLOR.a = 1.0;
    }
}
