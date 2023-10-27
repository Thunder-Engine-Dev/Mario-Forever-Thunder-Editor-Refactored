extends Node2D

@export_category("Spray")
@export var target_fluid_id: StringName
@export_group("Collision")
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:px") var actual_fluid_detection_radius: float = 8

@onready var caster: ShapeCast2D = $ShapeCast2D


func _ready() -> void:
	caster.force_shapecast_update()
	
	if !caster.is_colliding():
		return
	
	var normal: Vector2 = caster.get_collision_normal(0)
	if normal:
		global_rotation = normal.angle() + PI/2
	
	var collider := caster.get_collider(0) as AreaFluid2D
	if !collider || collider.fluid_id != target_fluid_id:
		return
	
	caster.shape = caster.shape.duplicate() as CircleShape2D
	caster.shape.radius = actual_fluid_detection_radius
	caster.force_shapecast_update()
	
	var in_or_out: bool = !caster.is_colliding()
	var down: Vector2 = Vector2.DOWN.rotated(global_rotation)
	
	match in_or_out:
		true:
			for i in 1024:
				global_position += down
				caster.force_shapecast_update()
				
				if caster.get_collision_count():
					global_position -= down
					break
		false:
			for i in 1024:
				global_position -= down
				caster.force_shapecast_update()
				
				if !caster.get_collision_count():
					break
