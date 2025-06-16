shader_type canvas_item;
render_mode blend_mix;

// hint_screen_texture с nearest фильтрацией для резкости пикселей
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D gradient; // чтобы градиент был "шаговым"
uniform float spread = 0.5;
uniform float cutoff = 0.1;
uniform float size = 1.0;
uniform float speed = 1.0;
uniform float ray1_density = 8.0;
uniform float ray2_density = 30.0;
uniform float ray2_intensity = 0.3;
uniform float core_intensity = 2.0;
uniform bool hdr = false;
uniform float seed = 5.0;

float random(vec2 _uv) {
    return fract(sin(dot(_uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(in vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0-2.0 * f);
    return mix(a, b, u.x) + (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

vec4 screen(vec4 base, vec4 blend){
    return 1.0 - (1.0 - base) * (1.0 - blend);
}

void fragment() {
    // Получаем размер экрана в пикселях
    vec2 screen_size = vec2(textureSize(SCREEN_TEXTURE, 0));
    
    // Квантуем UV для "пикселизации" выборки на экране (делаем шаг 1 пиксель)
    vec2 pixel_uv = floor(SCREEN_UV * screen_size) / screen_size;
    
    // Центрируем UV относительно 0.5 и масштабируем по size
    vec2 centered_uv = (UV - 0.5) * size;
    
    // Делаем "пикселизацию" координат для лучей (шаг зависит от желаемого уровня детализации)
    float pixel_step = 0.05; // например, шаг 0.05 для угла и радиуса (подбирай под свою игру)
    
    // Квантуем radius и angle для "ступенчатости"
    float radius = floor(length(centered_uv) / pixel_step) * pixel_step;
    float angle = floor((atan(centered_uv.y, centered_uv.x) + 3.14159265) / pixel_step) * pixel_step * 10.0;
    
    vec2 ray1 = vec2(angle * ray1_density + TIME * speed + seed + sin(angle * 3.0), radius * 2.0);
    vec2 ray2 = vec2(angle * ray2_density + TIME * speed * 1.5 + seed + cos(angle * 2.0), radius * 2.0);
    
    float cut = 1.0 - smoothstep(cutoff, cutoff + 0.2, radius);
    ray1 *= cut;
    ray2 *= cut;
    
    float rays = hdr ? 
        noise(ray1) + (noise(ray2) * ray2_intensity) :
        clamp(noise(ray1) + (noise(ray2) * ray2_intensity), 0., 1.);
    
    rays *= smoothstep(spread, spread * 0.3, radius);
    float core = smoothstep(0.2, 0.0, radius) * core_intensity;
    rays += core;
    
    // Квантуем координату для градиента (чтобы не было плавного цвета)
    float grad_coord = floor(rays * 16.0) / 16.0; // 16 уровней цвета, подбирай по вкусу
    
    vec4 gradient_color = texture(gradient, vec2(grad_coord, 0.5));
    vec3 shine = vec3(rays) * gradient_color.rgb;
    
    // Пиксельная выборка с размытой текстурой - тоже с квантацией UV
    float blur_amount = radius * 0.1;
    vec2 blur_uv = pixel_uv + floor(centered_uv * blur_amount * screen_size) / screen_size;
    vec4 blurred = texture(SCREEN_TEXTURE, blur_uv);
    
    shine = screen(blurred, vec4(shine, rays)).rgb;
    
    COLOR = vec4(shine, rays * gradient_color.a);
}
