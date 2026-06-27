extends Node
## FWaveTest — Verifica el sistema de portales y mini-oleadas (V0.8.2 Bloque F):
##  F-1) Al iniciar no hay monstruos; aparece el portal y el monstruo emerge ~1s después.
##  F-2) La oleada solo avanza cuando todos los monstruos de TODAS las mini-oleadas mueren.
##       Recorre las 3 oleadas del Nivel 1 matando a cada monstruo y espera on_level_cleared.

var _cleared := false

func _ready() -> void:
	await _run()

func _run() -> void:
	var lvl := (load("res://scenes/levels/Level_01_Forest.tscn") as PackedScene).instantiate() as LevelBase
	add_child(lvl)
	lvl.on_level_cleared.connect(func() -> void: _cleared = true)
	await get_tree().physics_frame
	lvl.start_waves()

	# --- F-1: a los ~0.5s (antes del PORTAL_LEAD de 1s) NO debe haber monstruos ---
	for i in 30:
		await get_tree().physics_frame
	var monsters_at_half_s := get_tree().get_nodes_in_group("monster").size()
	var f1_ok := monsters_at_half_s == 0

	# --- F-1b: pasado 1s desde el inicio ya deben haber emergido los 2 Slimes ---
	for i in 50:
		await get_tree().physics_frame
	var spawned_after_1s := get_tree().get_nodes_in_group("monster").size()
	var f1b_ok := spawned_after_1s >= 1   # al menos un monstruo ha emergido del portal

	# --- F-2: recorrer todas las oleadas matando cada monstruo que aparezca ---
	var seen := {}
	var frames := 0
	while not _cleared and frames < 7000:
		await get_tree().physics_frame
		frames += 1
		for m in get_tree().get_nodes_in_group("monster"):
			if m is MonsterBase and not m.is_dead:
				seen[m.get_instance_id()] = true
				m.die(self)
	var total_spawned := seen.size()
	# Nivel 1: W1=3, W2=5, W3=5 → 13 monstruos en total.
	var f2_ok := _cleared and total_spawned == 13

	print("=== FWAVE TEST RESULT ===")
	print("no_monsters_before_portal (F-1): ", "PASS" if f1_ok else "FAIL", " (count=", monsters_at_half_s, ")")
	print("monster_emerges_after_portal (F-1): ", "PASS" if f1b_ok else "FAIL", " (count=", spawned_after_1s, ")")
	print("all_waves_cleared (F-2): ", "PASS" if f2_ok else "FAIL", " (cleared=", _cleared, " total=", total_spawned, " frames=", frames, ")")
	print("=========================")
	get_tree().quit(0 if (f1_ok and f1b_ok and f2_ok) else 1)
