extends Node
## IntegrationTest — Verifica el flujo completo de una partida Versus (temporal).
## Configura el modo, instancia VersusMatch y fuerza muertes para validar el
## bucle de rondas, el respawn con invulnerabilidad y el fin de partida.

var _vm: Node

func _ready() -> void:
	GameManager.mode = GameManager.Mode.VERSUS
	GameManager.p1_class = GameManager.CLASS_ARCHER
	GameManager.p2_class = GameManager.CLASS_WARRIOR
	GameManager.selected_arena_index = 0
	GameManager.reset_versus()
	_vm = (load("res://scenes/ui/VersusMatch.tscn") as PackedScene).instantiate()
	add_child(_vm)
	await _run()

func _run() -> void:
	var frames := 0
	while frames < 4000:
		await get_tree().physics_frame
		frames += 1
		if GameManager.p1_wins >= GameManager.rounds_to_win:
			print("=== INTEGRATION TEST RESULT ===")
			print("versus_round_flow: PASS (p1_wins=%d p2_wins=%d in %d frames)" % [GameManager.p1_wins, GameManager.p2_wins, frames])
			print("===============================")
			get_tree().quit(0)
			return
		var p2 = _vm.get("_p2")
		var active = _vm.get("_round_active")
		if active and p2 != null and is_instance_valid(p2) and not p2.is_dead and not p2.is_invulnerable():
			p2.die(self)
	print("=== INTEGRATION TEST RESULT ===")
	print("versus_round_flow: FAIL (timeout, p1_wins=%d p2_wins=%d)" % [GameManager.p1_wins, GameManager.p2_wins])
	print("===============================")
	get_tree().quit(1)
