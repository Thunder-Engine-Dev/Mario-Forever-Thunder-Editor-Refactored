class_name Component extends Classes.HiddenNode

## Class that used under a [Node] to be a tag to provide
## extra behaviors for the tagged node
##
##

## [NodePath] to the root node
@export_category("Component")
@export var disabled: bool
@export var root_path: NodePath = ^".."

## Root node in [Node] type by [member root_path] from the component
var root: Node


func _ready() -> void:
	root = get_node_or_null(root_path)
