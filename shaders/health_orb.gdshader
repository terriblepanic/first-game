shader_type canvas_item; // Тип шейдера: применяется к элементам канвы
render_mode blend_mix, unshaded; // Режим: смешанное наложение без освещения

// Параметры эффектов (включение/выключение)
uniform bool light_effect = false;                // Включить эффект подсветки шарика
uniform bool border_exclusion_effect = false;     // Включить эффект исключения бордера
uniform bool wave_fix_on_border = false;          // Исправить волну на границе
uniform bool transparent_empty = false;           // Сделать пустые области прозрачными

// Основные параметры воды
uniform vec4 water_color: source_color = vec4(1, 0, 0, 1);         // Цвет воды
uniform float water_wave_speed : hint_range(-100, 100, 0.01) = 2;  // Скорость волны
uniform float water_wave_ci: hint_range(0, 2, 0.01) = 0.05;        // Интенсивность волны
uniform float water_back_lightness: hint_range(0, 1, 0.01) = 0.8;  // Фоновая яркость воды
uniform float wave_num : hint_range(0, 8, 1) = 2;                  // Количество волн

// Параметры шарика
uniform vec4 ball_color: source_color = vec4(1, 1, 1, 0);    // Цвет шарика
uniform float ball_border_ci : hint_range(0, 50, 1) = 5;         // Интенсивность границы шарика
uniform float ball_light_speed : hint_range(-100, 100, 0.01) = 2; // Скорость перемещения подсветки шарика

// Эффект наклонной плоскости
uniform bool plane_inclined_effect = false;                     // Включить эффект наклона плоскости
uniform float plane_inclined_ratio : hint_range(0., 0.5, 0.01) = 0.05; // Коэффициент наклона

// Временные параметры
uniform float iniTime = 0.; // Начальное время

// Высоты для двух состояний (текущая и предыдущая)
uniform float height : hint_range(0, 1, 0.01) = 0.5;   // Текущая высота воды (0–1)
uniform float oheight : hint_range(0, 1, 0.01) = 0.5;  // Предыдущая высота воды (0–1)

// Эффект вибрации
uniform bool vibration_effect = false;                       // Включить эффект вибрации
uniform float vibration_time = 0;                            // Смещение времени для вибрации
uniform float vibration_effect_timelength: hint_range(0, 10, 0.01) = 4; // Длительность вибрации
uniform float vibration_speed : hint_range(-100, 100, 0.01) = 8;       // Частота вибрации
uniform float vibration_magnitude : hint_range(0, 10, 0.01) = 0.25;    // Амплитуда вибрации
uniform float vibration_wave_ci: hint_range(0, 2, 0.01) = 0.3;         // Интенсивность волны при вибрации

// Коэффициенты преломления
uniform float refraction_ratio_glass: hint_range(0, 10, 0.01) = 0.2;  // Преломление для стекла
uniform float refraction_ratio_water: hint_range(0, 10, 0.01) = 0.6;  // Преломление для воды

// Вспомогательная функция наложения: базовый цвет + смешивание по альфа
vec4 ontop(vec4 base, vec4 blend){
    return mix(base, blend, blend.a);
}

// Инверсия цвета (обратный эффект)
vec4 reverse(vec4 base){
    return vec4(mod(base.rgb + 1. , 2.), base.a);
}

// Эффект исключения (exclusion blend)
vec4 exclusion(vec4 base, vec4 blend){
    return base + blend - 2.0 * base * blend * base;
}

// Функция плавного затухания (экспоненциальная кривая)
float easeOutExpo(float x){
    return x == 1. ? 1. : 1. - pow(2., -10. * x);
}

// Смещение UV для искажения текстуры
vec2 shiftuv(vec2 uv, float shiftratio) {
    vec2 suv = (uv - 0.5) * 2.0;
    return (suv + sign(suv) * suv * suv * -1.0 * shiftratio) * 0.5 + 0.5;
}

void fragment() {
    // Проверка: если пусто и прозрачность включена — пропустить рендер
    bool skip_render = transparent_empty && height <= 0.0 && oheight <= 0.0;
    if (!skip_render && distance(UV, vec2(0.5, 0.5)) <= 0.5) {
        // Базовая инициализация временных переменных и UV
        float NTIME = vibration_effect ? TIME + vibration_time : TIME + vibration_effect_timelength;
        vec2 uv = (UV - 0.5) * 0.5;
        vec2 suv = UV * 0.5 - 0.5;

        // Параметры коррекции волны по границе
        float a = wave_fix_on_border ? 2.0 : 1.0;
        float b = wave_fix_on_border ? 1.0 : 0.5;

        // Заглушки для цветов воды и стекла
        vec4 Cw = vec4(0.0);
        vec4 Cg = vec4(0.0);

    } else {
        // Вне круга – полная прозрачность
        COLOR = vec4(0.0);
    }

    // Повторная инициализация (дублируется логика выше)
    float NTIME = vibration_effect ? TIME + vibration_time : TIME + vibration_effect_timelength;
    vec2 uv = (UV - 0.5) * 0.5;
    vec2 suv = UV * 0.5 - 0.5;
    float a = wave_fix_on_border ? 2.0 : 1.0;
    float b = wave_fix_on_border ? 1.0 : 0.5;
    vec4 Cw = vec4(0.0);
    vec4 Cg = vec4(0.0);

    if (distance(UV, vec2(0.5, 0.5)) > 0.5) {
        // Вне круга – прозрачность
        COLOR = vec4(0.0);
    } else {
        // Статический случай: вода полностью заполнена
        if (height == 1.0) {
            COLOR = vec4(water_color.rgb, 1.0);
        }
        // Динамический случай: волны
        else {
            // Нормировка времени вибрации
            float t = (NTIME - TIME) / vibration_effect_timelength;

            // Смещение высоты для наклонной плоскости
            float dH = plane_inclined_effect
                       ? sin(mod((UV.x + TIME * water_wave_speed) * PI, TAU)) * plane_inclined_ratio
                       : 0.0;
            float dHo = plane_inclined_effect
                        ? sin(mod((UV.x - TIME * water_wave_speed) * PI + PI, TAU)) * plane_inclined_ratio
                        : 0.0;

            // Высота с учётом вибрации
            float H = vibration_effect
                      ? mix(height - uv.x * sin(t * PI * vibration_speed), height, t)
                      : height;
            float oH = vibration_effect ? oheight : oheight;

            // Интенсивность волны при вибрации
            float CI = vibration_effect
                       ? mix((water_wave_ci + vibration_wave_ci) * vibration_magnitude, water_wave_ci, t)
                       : water_wave_ci;

            // Основная логика заполнения водой и расчёт затенения
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

            // Перекрытие основной волны
            if (sin((cos(suv.x * PI * a + PI * b) + NTIME * water_wave_speed) * wave_num) * CI
                + (1.0 - H) < UV.y + dH) {
                COLOR = vec4(water_color);
            }

            // Подрисовка границы наклонной плоскости
            if (plane_inclined_effect && plane_inclined_ratio != 0.0
                && UV.y <= 1.0 - height + 0.005 && UV.y >= 1.0 - height - 0.005) {
                COLOR = COLOR + (sin(UV.x + TIME) + 1.0) * 0.08;
            }
        }

        // Эффект подсветки шарика
        float L = 0.0;
        if (light_effect) {
            L = cos(distance(UV, sin(suv * suv) + NTIME * ball_light_speed)) * 0.25;
        }
		
		// формируем отдельный слой шарика (контур + подсветка), умножая на ball_color
		vec4 ballLayer = vec4(
			vec3(1.0),
			pow(distance(UV, vec2(0.5, 0.5)) * 2.0, ball_border_ci) + L
		) * ball_color;

		// накладываем бордер/исключение
		vec4 result = border_exclusion_effect
			? exclusion(COLOR, ballLayer)
			: ontop   (COLOR, ballLayer);

	    // сохраняем прозрачность шарика
	    result.a *= ball_color.a;
	    COLOR = result;
    }
}
