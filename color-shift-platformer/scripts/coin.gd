extends Area2D


func _on_body_entered(_body: Node2D) -> void:
	await get_tree().create_timer(0.06).timeout
	queue_free()
