extends Area2D
## Pemicu dialog reusable untuk Area2D di scene (mis. node "popUpUI").
## Dipasang pada Area2D yang sinyal body_entered-nya sudah terhubung ke
## "_on_body_entered" di scene. Isi dialog diatur lewat Inspector / .tscn.
## Dialog hanya tampil sekali (selama sesi) jika one_shot = true.

@export var dialogue_id: String = ""
@export var is_hint: bool = false
@export var title: String = ""
@export var lines: PackedStringArray = PackedStringArray()
@export var use_player_portrait: bool = true
@export var one_shot: bool = true

var _waiting: bool = false


func _on_body_entered(body: Node2D) -> void:
	if _waiting or not _is_player(body):
		return
	if _already_seen():
		return
	_waiting = true
	# Tunggu transisi layar selesai agar dialog tidak muncul di balik fade.
	while GameManager.is_transitioning:
		await get_tree().process_frame
	_waiting = false
	if _already_seen():
		return
	_show()


func _already_seen() -> bool:
	return one_shot and dialogue_id != "" and GameManager.has_seen(dialogue_id)


func _is_player(body: Node2D) -> bool:
	return body.is_in_group("player") or body.name == "mainPlayer" or body.name == "Player"


func _show() -> void:
	var shown := false
	if is_hint:
		shown = DialogueBox.show_hint(lines, title)
	else:
		var portrait: Texture2D = null
		if use_player_portrait:
			portrait = DialogueBox.get_player_portrait()
		shown = DialogueBox.show_dialogue(lines, title, portrait)
	if shown and dialogue_id != "":
		GameManager.mark_seen(dialogue_id)
