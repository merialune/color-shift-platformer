extends CharacterBody2D

# Movement Variables
@export var SPEED = 140.0           # Balanced speed for 16x16 player
@export var ACCELERATION = 1800.0    # Quick response but not instant
@export var FRICTION = 1000.0       # Smooth stop
@export var AIR_RESISTANCE = 200.0   # Less friction in air for better control

# Jump Variables
@export var JUMP_VELOCITY = -260.0   # Comfortable jump height
@export var JUMP_RELEASE_FORCE = 0.4 # Multiplier when releasing jump early
@export var MAX_FALL_SPEED = 400    # Terminal velocity
@export var MIN_JUMP_TIME = 0.1     # Minimum time to hold jump

# Get the gravity from the project settings
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var jump_timer = 0.0
var was_jumping = false

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)
	
	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		was_jumping = true
		jump_timer = 0.0
	
	# Variable jump height
	if was_jumping:
		jump_timer += delta
		if jump_timer >= MIN_JUMP_TIME:
			if Input.is_action_just_released("ui_accept"):
				if velocity.y < 0:
					velocity.y *= JUMP_RELEASE_FORCE
				was_jumping = false
	
	# Get movement direction
	var direction = Input.get_axis("ui_left", "ui_right")
	
	# Apply acceleration or friction
	if direction != 0:
		# Accelerate
		velocity.x = move_toward(velocity.x, 
			direction * SPEED, 
			ACCELERATION * delta)
	else:
		# Apply friction
		var friction_force = FRICTION if is_on_floor() else AIR_RESISTANCE
		velocity.x = move_toward(velocity.x, 0, friction_force * delta)
	
	move_and_slide()
