extends Component


func _ready() -> void:
	var root := get_root() as LevelTimer
	if !root:
		return
	root.timer_over.connect(_on_time_up_killed_all_players)


## Kills all players
func _on_time_up_killed_all_players() -> void:
	if disabled:
		return
	var players := CharactersManager2D.get_characters_getter().get_characters()
	for i: CharacterEntity2D in players:
		i.die()
