extends Resource
class_name PlayerStats
## PlayerStats — Recurso de parámetros de movimiento del jugador.
## Editable desde el inspector para tunear el feel sin tocar código.
## Valores base según DOCUMENTO_MAESTRO.md §3.
## Autor: Claude Code · Versión: 0.4.0

@export var walk_speed: float = 160.0
@export var jump_velocity: float = -340.0
@export var gravity: float = 900.0
@export var max_fall_speed: float = 520.0

@export var wall_jump_push: float = 200.0       # horizontal, opuesto a la pared
@export var wall_jump_vertical: float = -360.0  # salto recto desde pared
@export var wall_slide_speed: float = 60.0      # caída máxima pegado a la pared
@export var wall_jump_lock: float = 0.15        # bloqueo de re-agarre tras wall jump

@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.12
@export var dash_cooldown: float = 0.6
@export var dash_invuln_frames: int = 6

@export var coyote_time: float = 0.08
@export var jump_buffer_time: float = 0.1

# V0.5 punto 5: rebote tras stomp (held = amplificado manteniendo salto)
@export var stomp_bounce: float = -180.0
@export var stomp_bounce_held: float = -254.0

# V0.5 punto 9: ledge grab — deslizamiento si no se mantiene la dirección
@export var ledge_slide_speed: float = 30.0
@export var ledge_max_slide: float = 20.0
