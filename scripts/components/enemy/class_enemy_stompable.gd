@tool
@icon("res://icons/enemy_touch_stomp.svg")
class_name EnemyStompable extends EnemyTouch

## Component inheriting [EnemyTouch], but allows the character to stomp onto the [member Component.root] ([Area2D]).
##
## This component works similar to [EnemyTouch]; however, when it comes to such situation where a character stomps onto the [i]head[/i] of the area, the character will not get hurt, with being-stomped event triggered. 

## Emitted when a stomp is failed.[br]
## [br]
## [b]Note:[/b] This will be emitted [u]before[/u] the emission of [signal on_touched_by_character].
signal on_stomp_failed(character: Character)

## Emitted when a stomp is successful.
## [br]
## [b]Note:[/b] This will be emitted [u]before[/u] the emission of [signal on_touched_by_character].
signal on_stomp_succeeded(character: Character)

@export_group("Stomp")
## Angle in tolerance, which stands for the direction that the character stomps onto the enemy.[br]
## [br]
## The direction is calculated by making the global position of the [member Component.root] ([Area2D]) subtract from global location of the character, normalized, which is definitely an arrow pointing from the character's global position to the area's.[br]
## [br]
## Whether a stomp is successful or not is determined by the angle between this direction and [member up_direction](rotated by area's [member Node2D.global_rotation]).
## If a angle is lower than [member tolerance], then the stomp is failed; otherwise, it is successful.
@export_range(0, 60, 0.001, "degrees") var tolerance: float = 45
## Up direction of successful stomp. See [member tolerance] for details.
@export var up_direction: Vector2 = Vector2.UP:
	set(value):
		if value.is_zero_approx():
			printerr("The up_direction should not be a zero vector!")
			return
		
		up_direction = value.normalized()
## Offset of the hit center.[br]
## [br]
## This is used to make offset for the hit center of the [Area2D] to ensure the safe stomp.
@export var offset: Vector2
## Delay to prevent from damaging the character when a stomp is successful.
@export_range(0, 2, 0.001, "suffix:s") var stomp_delay: float = 0.08
@export_group("Sounds", "sound_")
@export var sound_stomped: AudioStream = preload("res://assets/sounds/stomp.wav")

var _delay: SceneTreeTimer


## [code]virtual[/code] Called when a character collides the [member Component.root] ([Area2D]).
func _character_touched(character: Character) -> void:
	if !is_instance_valid(character):
		return
	
	if character_damagible && !_delay && !_is_stomp_success(character):
		character.hurt()


func _is_stomp_success(character: Character) -> bool:
	var direction := character.get_center().direction_to((root as Area2D).global_position)
	var dot := direction.dot(-up_direction)
	return dot >= cos(deg_to_rad(tolerance))


func _on_character_touched(body: Node2D) -> void:
	if !body is Character:
		return
	
	var chara := body as Character # Character
	if _is_stomp_success(chara):
		Sound.play_2d(sound_stomped, root)
		
		_delay = get_tree().create_timer(stomp_delay, false)
		_delay.timeout.connect(func() -> void:
			_delay = null
		)
		
		on_stomp_succeeded.emit(chara)
	else:
		on_stomp_failed.emit(chara)
	
	super(chara)
