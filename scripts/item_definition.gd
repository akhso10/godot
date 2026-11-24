class_name SchoolItem
extends Resource

@export var item_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var world_model: PackedScene
@export var item_type: StringName
@export var stackable: bool
@export var max_stack: int = 1
@export var quest_item: bool = true
@export var usable: bool
