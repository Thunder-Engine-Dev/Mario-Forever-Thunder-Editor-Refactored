extends Node

signal player_fell_to_death(player: EntityPlayer2D)

@export_category("Death Area")
@export var death_detection_margin: float = 48
@export var dyable_after_level_finished: bool = true


func _process(_delta: float) -> void:
	var pls := PlayersManager.get_all_available_players()
	if pls.is_empty():
		return
	
	for i: EntityPlayer2D in pls:
		if !dyable_after_level_finished && i.state_machine.is_state(&"level_finished"):
			continue
		
		var rect := i.get_viewport_rect()
		var vpos := i.get_global_transform_with_canvas().get_origin()
		var angl := i.get_gravity_vector().angle()
		var die := false
		
		if vpos.x > rect.size.x + death_detection_margin && angl >= -PI/4 && angl <= PI/4:
			die = true
		elif vpos.y > rect.size.y + death_detection_margin && angl >= PI/4 && angl <= 3*PI/4:
			die = true
		elif vpos.x < rect.position.x - death_detection_margin && angl >= 3*PI/4 || angl <= -3*PI/4:
			die = true
		elif vpos.y < rect.position.y - death_detection_margin && angl >= -3*PI/4 && angl <= -PI/4:
			die = true
		
		if die:
			player_fell_to_death.emit(i)
			i.die()
