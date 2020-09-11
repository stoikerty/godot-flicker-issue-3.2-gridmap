extends KinematicBody

const FLOOR_NORMAL = Vector3(0.0, 1.0, 0.0)

export var jump_force = 9.8

var gravity = 9.8
var jump_velocity = gravity * 1.45
var overall_multiplier = 4
var fall_multiplier = 3
var low_jump_multiplier = 2

var vertical_velocity = 0.0
var horizontal_velocity_x = 0.0
var horizontal_velocity_y = 0.0
var flapping_enabled = false
var is_flapping = false
var flaps_count = 0
var flap_height_reached = false

func _ready():
	set_process(true)
	set_process_input(true)
	pass
	
func calculate_vertical_velocity():
	return jump_velocity * 1.15

func process_vertical_velocity(delta, jump_button_held_down):
	# var numberSign = '+' if vertical_velocity >= 0 else ''
	# var printed_velocity = numberSign + str(vertical_velocity).pad_decimals(2).pad_zeros(2)
	var max_flaps = 12

	if (!jump_button_held_down):
		is_flapping = false
		flaps_count = 0
		flap_height_reached = false

	if (vertical_velocity < 0):
		# print(flaps_count, ' ', printed_velocity, ' v - reached_height, falling')

		if (flapping_enabled && jump_button_held_down):
			# flap again
			if (vertical_velocity < -4):
				is_flapping = true

				if (flaps_count > 12):
					flap_height_reached = true

				if (flap_height_reached):
					flaps_count -= 1
					if (flaps_count > max_flaps / 1.5):
						return 5
					if (flaps_count > max_flaps / 2):
						return 4.5
					if (flaps_count > max_flaps / 3):
						return 3
					if (flaps_count > 0):
						return 2
				elif (!flap_height_reached):
					# keep flapping
					flaps_count += 1
					return 6
				
			return vertical_velocity - (gravity * delta)
			# return vertical_velocity

		return vertical_velocity - (gravity * overall_multiplier * fall_multiplier * delta)

	if (vertical_velocity > 0 && jump_button_held_down):
		# print(printed_velocity, ' ^ - jump_button held_down')
		
		if (is_flapping):
			# fall slower
			return vertical_velocity - (gravity * (overall_multiplier * 1.2 / clamp(flaps_count,2.2,3.4)) * delta)

		return vertical_velocity - (gravity * overall_multiplier * delta)
		
	# print(flaps_count, ' ', printed_velocity, ' > - jump_button let go')
	return vertical_velocity - (gravity * overall_multiplier * low_jump_multiplier * delta)


func calculate_velocity(direction_strength, velocity, delta):
	var overall_speed_multiplier = 0.85
	var movement_speed = 9.8 * 1.2 * overall_speed_multiplier
	var analogue_movement_speed = movement_speed * abs(direction_strength) if abs(direction_strength) > 0 else movement_speed
	var speed_up_multiplier = 5
	var speed_down_multiplier = 6.5
	var min_direction_strength = 0
	
	if (direction_strength > min_direction_strength && velocity < analogue_movement_speed):
		if (velocity < 0):
			return velocity + (analogue_movement_speed * speed_down_multiplier * delta)
		else:
			return velocity + (analogue_movement_speed * speed_up_multiplier * delta)
	elif (direction_strength < -min_direction_strength && velocity > -analogue_movement_speed):
		if (velocity > 0):
			return velocity - (analogue_movement_speed * speed_down_multiplier * delta)
		else:
			return velocity - (analogue_movement_speed * speed_up_multiplier * delta)
	elif (velocity > 0):
		if (velocity < 1):
			if (velocity > 0.05):
				return velocity / 2
			else:
				return 0
		else:
			return velocity - (analogue_movement_speed * speed_down_multiplier * delta)
	elif (velocity < 0):
		if (velocity > -1):
			if (velocity < -0.05):
				return velocity / 2
			else:
				return 0
		else:
			return velocity + (analogue_movement_speed * speed_down_multiplier * delta)
			
	return velocity


func calculate_horizontal_movement(delta):
	var deadZoneLimit = 0.38
	var horizontal_movement = clamp(Input.get_action_strength("right") - Input.get_action_strength("left"), -deadZoneLimit, deadZoneLimit) * (1/deadZoneLimit)
	var vertical_movement = clamp(Input.get_action_strength("down") - Input.get_action_strength("up"), -deadZoneLimit, deadZoneLimit) * (1/deadZoneLimit)
	# print('--> ', horizontal_movement, ' - ', vertical_movement)
	horizontal_velocity_x = calculate_velocity(horizontal_movement, horizontal_velocity_x, delta)
	horizontal_velocity_y = calculate_velocity(vertical_movement, horizontal_velocity_y, delta)

	# add camera rotation
	var camera_rotation = $CameraBoundNode.rotation_degrees.y if $CameraBoundNode else 0

	return Vector2(horizontal_velocity_x, horizontal_velocity_y).rotated(deg2rad(-camera_rotation))

# -------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		vertical_velocity = calculate_vertical_velocity()
	if event.is_action_pressed("context"):
		flapping_enabled = !flapping_enabled
		
func _process(delta):
	if not is_on_floor():
		var jump_button_pressed = Input.get_action_strength("jump");
		vertical_velocity = process_vertical_velocity(delta, jump_button_pressed)
	
	var horizontal_movement = calculate_horizontal_movement(delta);
	var velocity = Vector3(horizontal_movement.x, vertical_velocity, horizontal_movement.y)

	move_and_slide(velocity, FLOOR_NORMAL)

	if is_on_floor() or is_on_ceiling():
		vertical_velocity = 0.0
