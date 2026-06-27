extends Resource
class_name ProjectileStats
## ProjectileStats — Parámetros de un tipo de proyectil, editables desde el inspector.
## V0.2 punto 5: velocidad inicial y gravedad de las flechas ajustables sin tocar código.
## Autor: Claude Code · Versión: 0.5.0

@export var initial_speed: float = 500.0   # velocidad de disparo recto (A1)
@export var cone_speed: float = 650.0       # velocidad del disparo en cono (A2)
@export var proj_gravity: float = 250.0     # gravedad del proyectil (parábola más tendida)
