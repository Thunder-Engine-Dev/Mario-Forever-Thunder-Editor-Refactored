extends Component

## Emitted when the attacker is received
signal received_attacker(attacker: Component, receiver: Component)

## Filter modes
enum FilterModes {
	INCLUDE, ## The attacker will be ignored only if (one of) the attacker's thing is NOT in the list
	EXCLUDE ## The attacker will be ignored only if (one of) the attacker's thing is in the list
}

## Temporary reference to attacker.gd
const Attacker: Script = preload("./attacker.gd")

@export_category("Attack Receiver")
@export_group("Filter")
@export_subgroup("IDs")
## Filters the attackers with ids listed in this property
@export var filter_ids: Array[StringName]
## [enum FilterModes] of [member filter_ids]:[br]
@export var filter_id_mode: FilterModes = FilterModes.INCLUDE
@export_subgroup("Features")
## Filters the attackers with features listed in this property
@export var filter_features: Array[StringName]
## [enum FilterModes] of [member filter_features]:[br]
@export var filter_feature_mode: FilterModes = FilterModes.INCLUDE


# Called by attacker
func _receive_attacker(attacker: Component) -> void:
	match filter_id_mode:
		FilterModes.INCLUDE when !attacker.attacker_id in filter_ids:
			return
		FilterModes.EXCLUDE when attacker.attacker_id in filter_ids:
			return
	
	for i: StringName in attacker.attacker_features:
		match filter_feature_mode:
			FilterModes.INCLUDE when !i in filter_features:
				return
			FilterModes.EXCLUDE when i in filter_features:
				return
	
	received_attacker.emit(attacker, self)
	attacker.receiver_called_back.emit(self)
