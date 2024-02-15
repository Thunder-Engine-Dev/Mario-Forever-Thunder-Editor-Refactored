extends EntityBody2D

@export_category("Enemy Death")
## Initial speed of the body
@export var initial_speed: float = 100
## Maximum of random buff for [member initial_speed]
@export var extra_speed_rand: float = 100
## Angle of initial speed. The direction is rotated from [code]Vector2.UP[/code]
@export_range(0, 90, 0.001, "degrees") var angle: float = 45


func _ready() -> void:
	velocality = (initial_speed + randf_range(0, extra_speed_rand)) * Vector2.UP.rotated(global_rotation + deg_to_rad(randf_range(-angle, angle)))

func _physics_process(delta: float) -> void:
	calculate_gravity()
	calculate_damp()
	move_and_slide()
