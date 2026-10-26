# Patient Z · Piso 1

Proyecto de Godot 4.7 (Forward+). Abrir con **Importar** y elegir `project.godot`.

## Flujo
`MainMenu.tscn` (escena principal) → **Play** → `main.tscn` → `scenes/levels/laboratorio_piso1.tscn`

## Archivos que tú pones
| Archivo | Para qué |
|---|---|
| `assets/img/menu.jpg` | Fondo del menú |
| `assets/audio/Horror Game Menu Music 1 Redone.mp3` | Música del menú |
| `assets/player/Walking.fbx` | Modelo y animación del jugador (ya incluido) |
| `assets/audio/alarm.mp3` (opcional) | Sonido de la alarma. Si no está, suena una sirena generada por código |

Si cambias los nombres, edita las constantes de `scripts/ui/main_menu.gd` y `scripts/systems/alarm_system.gd`.

## Controles
W A S D mover · Shift correr · C agacharse · E hablar · F interactuar · Clic disparar · R recargar ·
1-2 armas · 3 venda · L linterna · H ocultar UI · Esc soltar ratón (Esc + M = volver al menú)

## Dónde cambiar cosas
- Mapa: `MAPA` en `scripts/levels/laboratorio_piso1.gd`
- Nº de infectados: `objetivo_bajas` en `scripts/systems/level_config.gd` (debe coincidir con las `Z` del mapa)
- Diálogos: `scripts/systems/dialogue_db.gd`
- Duración/volumen de la alarma: `scripts/systems/alarm_system.gd`
- Modelo del jugador: `MODEL_PATH` en `scripts/player/player_model.gd`
- Carteles 3D (STAIRS, SECURITY GUARD ROOM): `scripts/environment/stairs_sign.gd`
- Sangre (Decals): `scripts/environment/blood_spawner.gd` · solo se ve con el renderer Forward+ o Mobile
