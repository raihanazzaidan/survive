extends Resource
class_name InvItem

enum Importance { ESSENTIAL, HELPFUL, OPTIONAL }

@export var name: String = ""
@export var texture: Texture2D
@export_multiline var description: String = ""
@export var importance: Importance = Importance.HELPFUL
@export_multiline var importance_reason: String = ""
