extends CanvasLayer

@onready var lives: Label = $Frame/LivesX
@onready var scores: Label = $Frame/LivesX/Scores
@onready var coins: Label = $Frame/CoinsX/Coins
@onready var game_over: Label = $Frame/GameOver
@onready var sound_game_over: AudioStreamPlayer = $SoundGameOver


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	Data.signals.player_data_changed.connect(
		func(data: StringName, value: int) -> void:
			match data:
				&"player_lives":
					var fpl := PlayersManager.get_first_player()
					var fpln := &"PLAYER" if !fpl else fpl.nickname
					lives.text = fpln + " × %s" % [str(value)]
				&"player_scores":
					scores.text = str(value)
				&"player_coins":
					coins.text = str(value)
	, CONNECT_DEFERRED)
	
	EventsManager.signals.game_over.connect(
		func() -> void:
			game_over.visible = true
			sound_game_over.play()
	)
	
	Data.data_init_signal_emit()
