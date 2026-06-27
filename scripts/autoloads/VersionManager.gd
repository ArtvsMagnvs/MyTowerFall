extends Node
## VersionManager — Autoload
## Mantiene el número de versión del juego y datos de build.
## Autor: Claude Code · Versión: 0.4.0

const VERSION: String = "0.8.7"
const GAME_TITLE: String = "NIIDE"
const GAME_SUBTITLE: String = "El Círculo Dárico"
const BUILD_DATE: String = "2026-06-26"

func get_version_string() -> String:
	return "v%s" % VERSION

func get_full_string() -> String:
	return "%s: %s %s (%s)" % [GAME_TITLE, GAME_SUBTITLE, get_version_string(), BUILD_DATE]
