class_name AreaFluid extends Area2D

## [AreaFluid] is an field in which characters is able to swim.
##
## [b]Note:[/b] This node is only avaiable for [Character].
## For modification on general [EntityBody2D]s, see [member Area2D.gravity_space_override]

@export_group("For Character", "character_")
## Scales for properties, going to be modified, of a characters that.[br]
## [br]
## [b]Note:[/b] The keys are of [NodePath] or [String] type while the values belong to one of the numeric types.[br]
## [br]
## [b]Warning:[/b] Only numberic types are supported; otherwise, an error would be thrown!
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:x") var character_max_falling_speed_scale: float = 1.0

var _characters: Array[Character]


func _init() -> void:
	process_physics_priority = -128 # Needs this line to make sure the _property_update() will be called before all nodes in the current scene

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	_property_update() # This will be called BEFORE all nodes get the virtual method called
	_property_revert.call_deferred() # This will be called AFTER all nodes get the virtual method called


#region == Updating and Reverting Data ==
func _property_update() -> void:
	for i in _characters:
		i.max_falling_speed *= character_max_falling_speed_scale

func _property_revert() -> void:
	for i in _characters:
		i.max_falling_speed /= character_max_falling_speed_scale
#endregion

#region == Area Detections ==
func _on_body_entered(body: Node2D) -> void:
	if body is Character && !body in _characters:
		_characters.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Mario && body in _characters:
		_characters.erase(body)
#endregion
