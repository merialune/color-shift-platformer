extends CharacterBody2D

# Core Movement
@export var SPEED = 140.0           # Base movement speed
@export var ACCELERATION = 1800.0    # Ground acceleration
@export var FRICTION = 1000.0       # Ground friction
@export var AIR_RESISTANCE = 200.0   # Air friction
@export var TURN_BOOST = 1.4        # Acceleration multiplier when turning

# Jump Properties
@export var JUMP_VELOCITY = -260.0   # Initial jump force
@export var JUMP_RELEASE_FORCE = 0.4 # Jump cut multiplier
@export var JUMP_GRAVITY = 900.0     # Normal jump gravity
@export var FALL_GRAVITY = 1200.0    # Faster falling gravity
@export var APEX_GRAVITY = 400.0     # Reduced gravity near jump peak
@export var APEX_THRESHOLD = 20.0    # Velocity range for apex float
@export var MAX_FALL_SPEED = 400.0   # Terminal velocity

# Jump Helpers
@export var COYOTE_TIME = 0.12      # Time to jump after leaving platform
@export var JUMP_BUFFER_TIME = 0.12  # Time to pre-press jump
@export var LANDING_LAG = 0.08      # Brief slowdown on landing
@export var EDGE_NUDGE = 4.0        # Pixels to nudge toward platforms

# State Tracking
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var landing_timer = 0.0
var was_on_floor = false
var just_jumped = false
var last_direction = 0.0
var is_jumping = false

# Color system enums and constants
enum PlayerColor { RED, BLUE, YELLOW }

# Dictionary mapping colors to their collision layers
const COLOR_LAYERS = {
	PlayerColor.RED: 2,    # Layer 2 for red collision
	PlayerColor.BLUE: 3,   # Layer 3 for blue collision
	PlayerColor.YELLOW: 4  # Layer 4 for yellow collision
}

const COLOR_MASKS = {
	PlayerColor.RED: 2,
	PlayerColor.BLUE: 3,
	PlayerColor.YELLOW: 4,
}

# Dictionary mapping colors to their visual colors
const COLOR_VALUES = {
	PlayerColor.RED: Color(1, 0, 0, 1),      # Pure red
	PlayerColor.BLUE: Color(0, 0, 1, 1),     # Pure blue
	PlayerColor.YELLOW: Color(1, 1, 0, 1)    # Pure yellow
}

# Current state
var current_color: PlayerColor = PlayerColor.RED
@export var color_transition_speed: float = 0.2

# Node references (assign these in the editor)
@onready var sprite = $AnimatedSprite2D
@onready var color_particles = $ColorParticles

func _ready():
	# Initialize state
	was_on_floor = is_on_floor()
	
	 # Initialize with red color
	set_collision_color(PlayerColor.RED)
	sprite.modulate = COLOR_VALUES[PlayerColor.RED]

func _physics_process(delta):
	var on_floor = is_on_floor()
	
	# Update timers
	if not on_floor and was_on_floor and not just_jumped:
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(0, coyote_timer - delta)
	
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = max(0, jump_buffer_timer - delta)
	
	# Handle landing lag
	if on_floor and not was_on_floor:
		landing_timer = LANDING_LAG
		velocity.x *= 0.6  # Slight speed reduction on landing
	landing_timer = max(0, landing_timer - delta)
	
	# Apply variable gravity based on state
	var gravity_mult = 1.0
	if abs(velocity.y) < APEX_THRESHOLD:
		gravity_mult = APEX_GRAVITY / JUMP_GRAVITY  # Reduced gravity at apex
	elif velocity.y > 0:
		gravity_mult = FALL_GRAVITY / JUMP_GRAVITY  # Increased gravity when falling
	
	# Apply gravity
	if not on_floor:
		velocity.y += JUMP_GRAVITY * gravity_mult * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)
	
	# Handle jump
	if (on_floor or coyote_timer > 0) and (
		Input.is_action_just_pressed("ui_accept") or jump_buffer_timer > 0):
		velocity.y = JUMP_VELOCITY
		is_jumping = true
		just_jumped = true
		coyote_timer = 0
		jump_buffer_timer = 0
	else:
		just_jumped = false
	
	# Variable jump height
	if is_jumping and Input.is_action_just_released("ui_accept"):
		if velocity.y < 0:
			velocity.y *= JUMP_RELEASE_FORCE
		is_jumping = false
	
	# Get movement direction
	var direction = Input.get_axis("ui_left", "ui_right")
	var target_speed = direction * SPEED
	
	# Apply turning boost
	if sign(direction) != sign(last_direction) and direction != 0:
		target_speed *= TURN_BOOST
	
	# Apply acceleration or friction
	var accel = ACCELERATION
	if not on_floor:
		accel = AIR_RESISTANCE
	elif landing_timer > 0:
		accel *= 0.5  # Reduced acceleration during landing lag
	
	if direction != 0:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	
	# Edge nudging (help stick to platforms)
	if on_floor and abs(velocity.x) < EDGE_NUDGE * 2:
		var space_state = get_world_2d().direct_space_state
		var params = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + Vector2(EDGE_NUDGE * sign(velocity.x), 5)
		)
		var result = space_state.intersect_ray(params)
		if result:
			velocity.x = EDGE_NUDGE * sign(velocity.x)
	
	# Update state tracking
	was_on_floor = on_floor
	last_direction = direction if direction != 0 else last_direction
	
	# Move the character
	move_and_slide()

func _input(_event):
	# Handle color change input
	if not is_changing_color:
		if Input.is_action_just_pressed("switch_red"):
			change_color(PlayerColor.RED)
			print("Switching to red")
		elif Input.is_action_just_pressed("switch_blue"):
			change_color(PlayerColor.BLUE)
			print("Switching to blue")
		elif Input.is_action_just_pressed("switch_yellow"):
			change_color(PlayerColor.YELLOW)
			print("Switching to yellow")

var is_changing_color = false

func change_color(new_color: PlayerColor):
	if current_color == new_color or is_changing_color:
		return
	
	is_changing_color = true
	
	# Immediately update collision
	set_collision_color(new_color)
	
	# Start color transition
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", 
		COLOR_VALUES[new_color], 
		color_transition_speed
	).set_trans(Tween.TRANS_SINE)
	
	# Optional: Add color change effects
	spawn_color_particles(new_color)
	# play_color_sound(new_color)
	
	current_color = new_color
	
	# Wait for transition to complete
	await tween.finished
	is_changing_color = false
	
	print("Changing to color: ", new_color)  # 0 = RED, 1 = BLUE, 2 = YELLOW
	print("Current collision layers: ", get_collision_layer())  # Shows all active collision layers

func set_collision_color(color: PlayerColor):
	# Reset all color collision masks
	for layer in COLOR_LAYERS.values():
		set_collision_layer_value(layer, false)
	
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)
	set_collision_mask_value(4, false)
	
	# Enable collision only for the matching color
	set_collision_layer_value(COLOR_LAYERS[color], true)
	set_collision_mask_value(COLOR_MASKS[color], true)

func spawn_color_particles(color: PlayerColor):
	if color_particles:
		# Set particle color
		color_particles.color = COLOR_VALUES[color]
		
		# Emit burst of particles
		color_particles.restart()
		color_particles.emitting = true
