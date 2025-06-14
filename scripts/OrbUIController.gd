# OrbUIController.gd
# Контроллер визуального отображения орба (шарика) с эффектами вибрации, предупреждения и «поглощения»
extends Node

# Возможные состояния орба
enum OrbState { IDLE, DECREASING, INCREASING, EMPTY, FULL }

# Текущее состояние
var state: OrbState = OrbState.FULL

# Узел, в котором создаются твины (анимации)
var p_node: Node

# Текущая и предыдущая высота заполнения (0.0–1.0)
var H: float = 1.0
var oH: float = 1.0

# Включить/отключить эффекты
var vibration_effect = true # эффект вибрации при попадании
var alert_effect = true # эффект предупреждения при низком уровне

# Параметры вибрации
var vibration_effect_timelength = 1.0
var vibration_trans_type = Tween.TRANS_LINEAR
var vibration_ease_type = Tween.EASE_IN_OUT

# Параметры «поглощения» (уменьшения высоты)
var consume_delay = 0.0
var consume_timelength = 0.0
var consume_timelength_fordeath = 1.0
var consume_trans_type = Tween.TRANS_SPRING
var consume_ease_type = Tween.EASE_IN_OUT

# Параметры наклона плоскости (эффект ускорения/замедления)
var plane_inclined_ratio_from = 0.0
var plane_inclined_ratio_to = 0.2
var tween_raise_and_release_time = 2.0
var inclined_t = 0.0
var plane_inclined_transition_type = Tween.TRANS_QUAD
var plane_inclined_ease_type = Tween.EASE_IN

# Порог, при котором активируется эффект предупреждения
var alert_height = 0.15

# Цвета шара в разных состояниях
var ball_color = Color(1.0, 1.0, 1.0, 1.0) # обычный цвет
var alert_ball_color = Color(1.0, 0.3, 0.1, 1.0) # цвет при предупреждении
var death_ball_color = Color(0.1, 0.1, 0.1, 0.5) # цвет при «смерти» (H <= 0)

# Включить или отключить состояние «смерти»
var death_state_enabled := true

# Базовый цвет воды, используется для сброса
var base_water_color: Color

# Твины для разных эффектов
var vibration_tween: Tween
var consume_tween: Tween
var inclined_tween: Tween

# Материал шара, параметры которого будут изменяться
var target_material: Material = null


# Обновление внутреннего состояния в зависимости от заполнения
func _apply_base_state(value: float) -> void:
        if value <= 0.0:
                state = OrbState.EMPTY
        elif value >= 1.0:
                state = OrbState.FULL
        elif state != OrbState.INCREASING and state != OrbState.DECREASING:
                state = OrbState.IDLE


# Сброс всех эффектов и параметров к начальным
func Reset():
                H = 1.0
                oH = 1.0
                state = OrbState.FULL
                target_material.set_shader_parameter('height', H)
		target_material.set_shader_parameter('oheight', H)
		target_material.set_shader_parameter('vibration_effect', false)
		target_material.set_shader_parameter('light_effect', false)
		target_material.set_shader_parameter('ball_color', ball_color)
		if base_water_color:
				target_material.set_shader_parameter('water_color', base_water_color)


# Установить высоту заполнения (например, при инициализации)
func SetH(P: float, MAXP: float):
        H = P / MAXP
        oH = H
        _apply_base_state(H)
        target_material.set_shader_parameter('height', H)
        target_material.set_shader_parameter('oheight', H)
	target_material.set_shader_parameter('light_effect', false)
	target_material.set_shader_parameter('ball_color', ball_color)

	# Если выше порога предупреждения, отключаем warning-эффект
	if H >= alert_height and alert_effect:
		target_material.set_shader_parameter('light_effect', false)
		target_material.set_shader_parameter('ball_color', ball_color)


# Задать родительский узел для создания твинов
func SetOwner(node: Node):
		p_node = node

# Включить/выключить состояние «смерти»
func SetDeathStateEnabled(enabled: bool) -> void:
		death_state_enabled = enabled


# Привязать материал шара, параметры которого будем менять
func SetShader(mat: Material):
		target_material = mat
		if target_material:
				base_water_color = target_material.get_shader_parameter("water_color")


# Обработка «удара» (изменение текущей/предыдущей высоты и запуск эффектов)
func GetHit(P: float, oP: float, MAXP: float):
        if not target_material:
                return

        # Вычисляем новую нормализованную высоту
        var prev_h: float = target_material.get_shader_parameter('height')
        H = max(P / MAXP, 0.0)
        oH = H
        target_material.set_shader_parameter('oheight', oH)
        state = H < prev_h ? OrbState.DECREASING : state

		# Если шар «умер»
	if H <= 0.0:
		target_material.set_shader_parameter('light_effect', false)
		if death_state_enabled:
			target_material.set_shader_parameter('ball_color', death_ball_color)
			if base_water_color:
				target_material.set_shader_parameter('water_color', base_water_color)
		else:
			target_material.set_shader_parameter('ball_color', ball_color)
	# Иначе проверяем состояние предупреждения
	elif alert_effect:
		if H <= alert_height:
			target_material.set_shader_parameter('light_effect', true)
			target_material.set_shader_parameter('ball_color', alert_ball_color)
		else:
			target_material.set_shader_parameter('light_effect', false)
			target_material.set_shader_parameter('ball_color', ball_color)

	# Обновляем высоту и вибрацию в шейдере
	target_material.set_shader_parameter('height', H)
	target_material.set_shader_parameter('vibration_effect', vibration_effect)
	target_material.set_shader_parameter('vibration_effect_timelength', vibration_effect_timelength)

	# Создаем/перезапускаем твины вибрации
	if vibration_tween:
		vibration_tween.kill()
		vibration_tween = newtween()
		vibration_tween.tween_method(get_hit_vbm, 0.0, vibration_effect_timelength, vibration_effect_timelength).set_trans(vibration_trans_type).set_ease(vibration_ease_type)
	else:
		vibration_tween = newtween()
		vibration_tween.tween_method(get_hit_vbm, 0.0, vibration_effect_timelength, vibration_effect_timelength).set_trans(vibration_trans_type).set_ease(vibration_ease_type)

		# Убираем твин «поглощения», если он активен
                if consume_tween:
                        consume_tween.kill()
                        consume_tween = null

        _apply_base_state(H)


# Эффект ускорения: наклон плоскости «вверх»
func SpeedUp() -> void:
	target_material.set_shader_parameter('plane_inclined_effect', true)
	# Рассчитываем текущее смещение по времени твина
	if inclined_tween:
		inclined_t = max(inclined_t - inclined_tween.get_total_elapsed_time(), 0.0)
	else:
		inclined_t = 0.0

	var t = tween_raise_and_release_time - inclined_t
	var ci_11 = plane_inclined_ratio_from
	var ci_12 = plane_inclined_ratio_to
	var rao = inclined_t / tween_raise_and_release_time
	ci_11 = (ci_12 - ci_11) * rao + ci_11

	Transition(ci_11, ci_12, t, plane_inclined_transition_type, plane_inclined_ease_type)


# Эффект замедления: наклон плоскости «вниз»
func SpeedDown():
	target_material.set_shader_parameter('plane_inclined_effect', true)
	if inclined_tween:
		inclined_t = min(inclined_t + inclined_tween.get_total_elapsed_time(), tween_raise_and_release_time)
	else:
		inclined_t = 0.0

	var t = inclined_t
	var ci_11 = plane_inclined_ratio_from
	var ci_12 = plane_inclined_ratio_to
	var rao = 1.0 - (inclined_t / tween_raise_and_release_time)
	ci_12 = ci_12 - (ci_12 - ci_11) * rao

	Transition(ci_12, ci_11, t, plane_inclined_transition_type, plane_inclined_ease_type)


# Универсальный твин для наклона плоскости
func Transition(from: float, to: float, time_length: float, trans_type: Tween.TransitionType, ease_type: Tween.EaseType):
	if inclined_tween:
		inclined_tween.kill()
	inclined_tween = newtween()
	if from != to:
		inclined_tween.tween_method(tween_inclined_ratio, from, to, time_length).set_trans(trans_type).set_ease(ease_type)


# Вспомогательный метод создания твина через родительский узел
func newtween():
		if p_node:
				return p_node.create_tween()
		return create_tween()


# Callback для обновления параметра вибрации в шейдере
func get_hit_vbm(i: float):
	target_material.set_shader_parameter('vibration_time', i)
	if i >= vibration_effect_timelength - 0.0001: target_material.set_shader_parameter('vibration_effect', false)


# Плавное обновление значения без вибрации, для регенерации
func SetSmooth(P: float, MAXP: float):
        if not target_material:
                return

        var new_H: float = clamp(P / MAXP, 0.0, 1.0)
        if abs(new_H - H) < 0.001:
                return

        oH = target_material.get_shader_parameter("height") # читаем актуальное значение
        H = new_H
        state = H > oH ? OrbState.INCREASING : state
        _apply_base_state(H)

        if consume_tween:
                consume_tween.kill()

        # Сначала вручную обновим oheight (старый уровень)
        target_material.set_shader_parameter("oheight", oH)

        # А теперь анимируем до нового уровня
        var tween_time := max(0.1, abs(H - oH) * 0.25)
        consume_tween = newtween()
        consume_tween.tween_method(
                func(value: float):
                target_material.set_shader_parameter("height", value),
                oH, H, tween_time
        ).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
        consume_tween.tween_callback(Callable(self, "_apply_base_state").bind(H))


# Callback для обновления параметра наклона плоскости
func tween_inclined_ratio(i: float):
	target_material.set_shader_parameter('plane_inclined_ratio', float("%10.2f" % i))
