extends Node2D

func _ready() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		player.eliminated.connect(_on_player_eliminated)


func _on_player_eliminated(_player: Node) -> void:
	var alive := []
	for player in get_tree().get_nodes_in_group("players"):
		if player.stocks > 0:
			alive.append(player)

	if alive.size() == 1:
		print("Player %d wins!" % alive[0].player_number)
		
		# LATER: the round/UI system plugs in here
		# (show a win screen, a restart button, etc.)
