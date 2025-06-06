shader_type canvas_item;
render_mode skip_vertex_transform, unshaded;

// убрали blend_add!

uniform sampler2D screen_tex  : hint_screen_texture;
uniform vec2      light_pos   = vec2(0.5, 0.2);
uniform float     decay       = 0.95;
uniform int       samples     = 64;
uniform float     weight      = 0.005;
uniform float     threshold   = 0.1;

void fragment() {
    vec2 uv   = SCREEN_UV;
    vec2 dir  = (light_pos - uv) / float(samples);

    float decay_acc = 1.0;
    vec2 coord     = uv;
    float sum      = 0.0;

    for (int i = 0; i < samples; i++) {
        coord += dir;
        float b = dot(texture(screen_tex, coord).rgb, vec3(0.333));
        float occ = smoothstep(threshold, threshold*2.0, b);
        sum += occ * decay_acc * weight;
        decay_acc *= decay;
    }

    vec3 scene = texture(screen_tex, uv).rgb;
    vec3 rays  = vec3(sum);
    // вот единственное место, где мы миксуем
    vec3 final = scene + rays;
    COLOR = vec4(final, 1.0);
}
