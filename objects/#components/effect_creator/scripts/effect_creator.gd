class_name EffectCreator extends Classes.HiddenMarker2D

## Emitted when the effect is finished
signal effect_finished

@export_category("Effect Creator")
@export var effect: PackedScene
@export_node_path("Node2D") var create_on: NodePath = ^".."
@export_group("Visiblity Inheritance")
@export_flags("Y Sort Enabled", "Z Index", "Z as Relative") var inheritances: int = 0b110

@onready var base := get_node(create_on) as Node2D
@onready var root := get_parent() as Node2D


func create_effect(times: int = 1, interval: float = 1) -> void:
	if !effect:
		return
	
	for i in times:
		var e := effect.instantiate()
		if !e is Node2D:
			e.queue_free()
			return
		
		e = e as Node2D
		root.add_sibling(e)
		e.global_transform = global_transform
		
		# Inheritance
		if (inheritances >> 0) & 1:
			e.y_sort_enabled = y_sort_enabled
		if (inheritances >> 1) & 1:
			e.z_index = z_index
		if (inheritances >> 2) & 1:
			e.z_as_relative = z_as_relative
		
		if times > 1 && interval > 0:
			await get_tree().create_timer(interval, false).timeout
	
	effect_finished.emit()
