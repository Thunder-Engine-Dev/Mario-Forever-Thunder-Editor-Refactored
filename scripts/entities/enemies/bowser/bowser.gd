extends Walker2D

signal bowser_in_screen ## Emitted when the bowser comes in the screen. This is used to trigger the hud to display.
signal bowser_defeated ## Emitted when the bowser dies.
signal bowser_health_changed ## Emitted when the [member health] gets changed.
signal bowser_damaged ## Emitted when bowser gets damaged.

@export_category("Bowser")
@export_range(1, 20, 1, "or_greater", "suffix:♥") var health: int = 5:
	set(value):
		health = value
		bowser_health_changed.emit()
@export_range(0, 20, 0.001, "suffix:s") var invulnerability_duration: float = 2
@export_group("Defense")
@export_range(0, 100) var defendable_stomps: int = 1
@export_range(0, 1000) var defendable_attacks: int = 5
@export_group("Movement", "movement_")
@export var movement_left_edge: ShapeCast2D
@export var movement_right_edge: ShapeCast2D
@export var movement_jumpable: ShapeCast2D
@export_range(0, 20, 0.001, "suffix:s") var movement_halt_interval: float = 0.5
@export_range(0, 20, 0.001, "suffix:s") var movement_halt_interval_extra: float = 2.5
@export_range(0, 20, 0.001, "suffix:s") var movement_halting_duration: float = 0.5
@export_range(0, 20, 0.001, "suffix:s") var movement_halting_duration_extra: float = 1.5
@export_range(0, 1, 0.001, "suffix:px/s") var movement_jumping_speed: float = 300
@export_range(0, 20, 0.001, "suffix:s") var movement_jumping_interval: float = 0.5
@export_range(0, 20, 0.001, "suffix:s") var movement_jumping_interval_extra: float = 1.5
@export_group("Attack")
@export var attack_to_next_delay: PackedFloat32Array = [2]
@export var attack_list: Array[StringName] = [&"flame"]
@export_subgroup("Multiflame")
@export_range(2, 30) var multiflame_amount: int = 3
@export_range(0, 360, 0.001, "degrees") var multiflame_central_angle: float = 15
@export_group("References")
@export_node_path("AnimatedSprite2D") var sprite_path: NodePath = ^"AnimatedSprite2D"
@export_node_path("EnemyStompable") var enemy_stompable_path: NodePath = ^"EffectBox/EnemyStompable"
@export_node_path("Instantiater2D") var flame_path: NodePath = ^"Flame"
@export_node_path("Instantiater2D") var hammer_path: NodePath = ^"Hammer"
@export_node_path("Instantiater2D") var corpse_path: NodePath = ^"Corpse"
@export_group("Sounds", "sound_")
@export var sound_hurt: AudioStream = preload("res://assets/sounds/bowser_hurt.wav")
@export var sound_death: AudioStream = preload("res://assets/sounds/bowser_died.wav")

var lock_walking: bool:
	set(value):
		lock_walking = value
		
		if lock_walking:
			_speed = velocality.x
			velocality.x = 0
		else:
			velocality.x = _speed
			_speed = 0

var _state: StringName = &"idle"

var _attack_index: int
var _speed: float
var _invulnerable: bool
var _defended_stomp: int
var _defended_attacks: int

@onready var _sprite: AnimatedSprite2D = get_node(sprite_path)
@onready var _enemy_stompable: EnemyStompable = get_node(enemy_stompable_path)
@onready var _flame: Instantiater2D = get_node(flame_path)
@onready var _hammer: Instantiater2D = get_node(hammer_path)
@onready var _corpse: Instantiater2D = get_node(corpse_path)

@onready var _timer_halt: Timer = $TimerHalt
@onready var _timer_jump: Timer = $TimerJump
@onready var _timer_attack: Timer = $TimerAttack


func _ready() -> void:
	super()
	
	health = health # Triggers setter to help with the emission of bowser_health_changed
	
	_timer_halt.start(_get_rand(movement_halt_interval, movement_halt_interval_extra))
	_timer_halt.timeout.connect(_on_halt)
	_timer_jump.start(_get_rand(movement_jumping_interval, movement_jumping_interval_extra))
	_timer_jump.timeout.connect(_on_jump)
	_timer_attack.start(attack_to_next_delay[0])
	_timer_attack.timeout.connect(_on_attack)

func _process(_delta: float) -> void:
	# Animations
	if _state == &"idle":
		_sprite.play(&"default" if is_on_floor() else &"jump")

func _physics_process(_delta: float) -> void:
	calculate_gravity()
	move_and_slide(enable_real_velocity)
	
	_update_dir()
	
	if movement_left_edge:
		for i in movement_left_edge.get_collision_count():
			if movement_left_edge.get_collider(i) == self && velocality.x < 0:
				turn_wall()
	if movement_right_edge:
		for j in movement_right_edge.get_collision_count():
			if movement_right_edge.get_collider(j) == self && velocality.x > 0:
				turn_wall()


func _update_dir() -> void:
	var np := Character.Getter.get_nearest(get_tree(), global_position)
	if !np:
		return
	set_meta(&"facing", Transform2DAlgo.get_direction_to_regardless_transform(global_position, np.global_position, global_transform))

#region == Movement ==
func _on_halt() -> void:
	lock_walking = true
	await _get_time(movement_halting_duration, movement_halting_duration_extra)
	
	if !_state in [&"idle", &"flame", &"multiflame"]:
		return
	
	lock_walking = false
	_timer_halt.start(_get_rand(movement_halt_interval, movement_halt_interval_extra))

func _on_jump() -> void:
	if !movement_jumpable:
		return
	
	var jumpable: bool = false
	for i in movement_jumpable.get_collision_count():
		if movement_jumpable.get_collider(i) == self && is_on_floor():
			jumpable = true
			break
	if !jumpable:
		return
	
	jump(movement_jumping_speed)
	
	await collided_floor
	
	_timer_halt.start(_get_rand(movement_halt_interval, movement_halt_interval_extra))
#endregion

#region == Attack ==
func _on_attack() -> void:
	match attack_list[_attack_index]:
		&"flame":
			_state = &"flame"
			_sprite.play(&"flame")
			await _sprite.animation_finished
			
			# The first child should me flame
			var flame := _flame.instantiate(0) as Walker2D
			flame.initial_direction = InitDirection.BY_VELOCITY
			flame.velocality.x = absf(flame.velocality.x) * get_meta(&"facing", 1)
			
			_sprite.play(&"open_mouth")
			await _sprite.animation_finished
			_sprite.play(&"default")
			_state = &"flame"
		&"multiflame":
			_state = &"multiflame"
			_sprite.play(&"flame_charged")
			await _get_time(1.5, 0)
			
			# The first child should me flame
			for i in multiflame_amount:
				var flame := _flame.instantiate(0) as Walker2D
				flame.global_rotation_degrees -= multiflame_central_angle / 2
				flame.global_rotation_degrees += multiflame_central_angle * i / float(multiflame_amount - 1)
				flame.initial_direction = InitDirection.BY_VELOCITY
				flame.velocality.x = absf(flame.velocality.x) * get_meta(&"facing", 1)
			
			_sprite.play(&"open_mouth")
			await _sprite.animation_finished
			_sprite.play(&"default")
			_state = &"flame"
	
	# Add attack index
	_attack_index += 1
	# Reset attack index
	if _attack_index > attack_list.size() - 1:
		_attack_index = 0
	
	_timer_attack.start(attack_to_next_delay[_attack_index])
#endregion

#region == Getters ==
func _get_rand(base: float, extra: float) -> float:
	return randf_range(base, base + extra)

func _get_time(base: float, extra: float) -> Signal:
	return get_tree().create_timer(_get_rand(base, extra), false).timeout
#endregion

#region == Health
func hurt(damage: int = 1) -> void:
	if _invulnerable:
		return
	
	_defended_attacks = 0
	_defended_stomp = 0
	
	health -= damage
	
	if health > 0:
		Sound.play_2d(sound_hurt, self)
		
		_invulnerable = true
		_enemy_stompable.stompable = false
		
		Effects.flash(self, invulnerability_duration, 0.5)
		await get_tree().create_timer(invulnerability_duration, false).timeout
		
		_invulnerable = false
		_enemy_stompable.stompable = true
	else:
		Sound.play_2d(sound_death, self)
		Events.EventTimeDown.get_signals().time_down_paused.emit()
		bowser_defeated.emit()
#endregion

#region == External signal callbacks ==
func _on_attacker_attacked() -> void:
	if _invulnerable:
		return
	
	_defended_attacks += 1
	if _defended_attacks >= defendable_attacks:
		hurt()

func _on_stomped() -> void:
	if _invulnerable:
		return
	
	_defended_stomp += 1
	if _defended_stomp >= defendable_stomps:
		hurt()

func _on_bowser_defeated() -> void:
	var items := _corpse.instantiate_all()
	for i in items:
		if i is EntityBody2D:
			i.set_meta(&"facing", get_meta(&"facing", 1))

func _on_bowser_entered_screen() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	bowser_in_screen.emit()
#endregion
