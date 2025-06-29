shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform vec4 flame_color : source_color = vec4(1.0, 0.3, 0.0, 1.0);
uniform float speed : hint_range(1.0, 10.0) = 3.0;
uniform float noise_scale : hint_range(1.0, 50.0) = 10.0;

// Simple noise function
float noise(vec2 p) {
    vec2 ip = floor(p);
    vec2 fp = fract(p);
    fp = fp * fp * (3.0 - 2.0 * fp);
    
    float n = ip.x + ip.y * 57.0;
    float a = fract(sin(n) * 43758.5453);
    float b = fract(sin(n + 1.0) * 43758.5453);
    float c = fract(sin(n + 57.0) * 43758.5453);
    float d = fract(sin(n + 58.0) * 43758.5453);
    
    return mix(mix(a, b, fp.x), mix(c, d, fp.x), fp.y);
}

void fragment() {
    // Sample the text texture
    vec4 text_color = texture(TEXTURE, UV);
    
    // Create flame effect only where text exists (based on alpha)
    if (text_color.a > 0.0) {
        // Create animated noise for flame effect
        float n = noise(UV * noise_scale + vec2(0.0, TIME * -speed));
        
        // Mix between flame colors based on noise and vertical position
        float flame_intensity = n * (1.0 - UV.y);
        vec4 flame = mix(flame_color, base_color, flame_intensity);
        
        // Preserve the text's alpha channel
        COLOR = vec4(flame.rgb, text_color.a);
    } else {
        // Keep transparent pixels transparent
        COLOR = vec4(0.0);
    }
}