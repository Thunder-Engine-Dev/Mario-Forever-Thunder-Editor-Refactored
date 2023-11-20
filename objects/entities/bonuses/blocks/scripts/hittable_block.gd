extends AnimatableBody2D

## Abstract class that provides basic properties and functions for bonus blocks
##
##

## Emitted when the block gets hit from the bottom
signal got_hit_bottom(by_area: Area2D, hitter: Classes.BlockHitter)

## Emitted when the block gets hit from the side
signal got_hit_side(by_area: Area2D, hitter: Classes.BlockHitter)

## Emitted when the block gets hit from the top
signal got_hit_top(by_area: Area2D, hitter: Classes.BlockHitter)

const DIAG := cos(PI/4)

@export_category("Hittable Block")
## Decides the collision direction, affected by [member Node2D.global_rotation]
@export var up_direction: Vector2 = Vector2.UP:
	set(value):
		up_direction = value.normalized()
## Received types from [constant Classes.BlockHitter]
@export var hitter_types: Array[StringName]
@export_group("Visibility")
## If [code]true[/code], the node will not be able to collide with any
## body, nor can the body be seen
@export var transparent: bool:
	set(value):
		transparent = value
		if !transparent:
			return
		
		if !is_node_ready():
			await ready
		
		if sprite:
			sprite.visible = false
		collision_layer = 0
		collision_mask = 0
@export_group("Sounds", "sound_")
@export var sound_hit: AudioStream

@onready var sprite: Node2D = Process.get_child_in_group(self, &"#hittable_block_sprite") as Node2D
@onready var sprite_pos: Vector2 = sprite.position if sprite else Vector2.ZERO
@onready var visiblility: bool = sprite.visible if sprite else true
@onready var col_layer: int = collision_layer
@onready var col_mask: int = collision_mask


## Called by [constant Classes.BlockHitter]
func block_got_hit(area: Area2D, by: Classes.BlockHitter, directions: int = 0b111) -> void:
	if !area || !by:
		return
	
	# Filter out-of-range hitters
	var in_target: int = 0
	for i: StringName in by.hitter_targets:
		if !i in hitter_types:
			continue
		in_target += 1
	if !in_target:
		return
	
	Sound.play_sound_2d(self, sound_hit)
	
	var dot := get_hitting_direction_dot_up(area)
	
	if dot > DIAG && (directions >> 0) & 1:
		got_hit_bottom.emit(area, by)
	elif dot <= DIAG && dot >= -DIAG && (directions >> 1) & 1:
		got_hit_side.emit(area, by)
	elif (directions >> 2) & 1:
		got_hit_top.emit(area, by)

## Restore the block from being transparent
func restore_from_transparency() -> void:
	if !transparent:
		return
	transparent = false
	
	if sprite:
		sprite.visible = visiblility
	collision_layer = col_layer
	collision_mask = col_mask


## Hitting animation
func hit_animation(by_area: Area2D) -> void:
	const PIXELS := 8.0
	
	var dot := get_hitting_direction_dot_up(by_area)
	var to := Vector2.ZERO
	
	if dot > DIAG:
		to = Vector2.UP * PIXELS
	elif dot <= DIAG && dot >= -DIAG:
		var dot_side := get_area_hitting_direction(by_area).dot(-up_direction.orthogonal())
		if dot_side > 0:
			to = Vector2.RIGHT * PIXELS
		elif dot_side < 0:
			to = Vector2.LEFT * PIXELS
	else:
		to = Vector2.DOWN * PIXELS
	
	if sprite:
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(sprite, "position", sprite_pos + to, 0.1)
		tw.tween_property(sprite, "position", sprite_pos, 0.1)


#region Getters
func get_area_hitting_direction(by_area: Area2D) -> Vector2:
	return (global_position - by_area.global_position).normalized()


func get_hitting_direction_dot_up(by_area: Area2D, direction: Vector2 = Vector2.ZERO) -> float:
	return get_area_hitting_direction(by_area).dot(up_direction.rotated(global_rotation)) if !direction else direction.normalized().dot(up_direction.rotated(global_rotation))


func get_hitting_out_direction(by_area: Area2D, directions: int = 0b111) -> Vector2:
	var dot := get_hitting_direction_dot_up(by_area)
	
	if dot > DIAG && (directions >> 0) & 1:
		return Vector2.UP
	elif dot <= DIAG && dot >= -DIAG && (directions >> 1) & 1:
		return Vector2.RIGHT if get_area_hitting_direction(by_area).dot(-up_direction.rotated(global_rotation).orthogonal()) > 0 else Vector2.LEFT
	elif (directions >> 2) & 1:
		return Vector2.DOWN
	
	return Vector2.ZERO
#endregion
