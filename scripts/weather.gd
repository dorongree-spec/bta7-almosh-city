## Beer Sheva has two kinds of weather: hot, and hot with dust. Every few
## minutes a haze ("אובך") rolls in from the desert: the fog thickens, the
## sun dims to an orange disc, sand blows down the street and the heat
## climbs faster. Then it clears, and everybody washes their car again.
class_name Weather
extends Node3D

signal said(speaker: String, text: String)

const CLEAR_FOG := 0.0008
const HAZE_FOG := 0.011
const CLEAR_VOLUME := 0.0015
const HAZE_VOLUME := 0.016
const CALM_MIN := 240.0      # seconds of clear sky between hazes
const CALM_MAX := 420.0
const HAZE_MIN := 70.0       # seconds a haze lasts
const HAZE_MAX := 110.0
const RAMP := 14.0           # seconds to roll in or clear
const HEAT_BOOST := 1.8      # extra heat multiplier at full haze
const STORM_FOG := 2.2       # a sandstorm is this many times thicker than a haze
const WIND := Vector3(9.0, 0.0, 3.0)
const OPENERS := [
	"אובך. מישהו שוב השאיר את הנגב פתוח.",
	"סופת חול. הרכב שטפת אתמול, נכון?",
	"שרב. אפילו הגמלים נכנסו לקניון.",
]

## 0 = clear sky, 1 = full haze. Read by DayNight (light) and main (heat).
var haze := 0.0

var _env: Environment
var _focus: Callable
var _dust: GPUParticles3D
var _hazy := false
var _storm := false          # the current haze is a full sandstorm
var _timer := 0.0


func setup(env: Environment, focus: Callable) -> void:
	_env = env
	_focus = focus
	_timer = randf_range(CALM_MIN, CALM_MAX) * 0.5  # the first one comes sooner
	_dust = Puffs.make(Color(0.86, 0.72, 0.5, 0.35), 260, 4.0, Vector3(45.0, 3.0, 45.0), 0.0, 3.0)
	var motion := _dust.process_material as ParticleProcessMaterial
	motion.direction = WIND.normalized()
	motion.spread = 12.0
	motion.initial_velocity_min = WIND.length() * 0.7
	motion.initial_velocity_max = WIND.length() * 1.3
	add_child(_dust)


## Brings a sandstorm in now, for `seconds`: thicker than a haze and with
## more sand in the wind. The caller announces it.
func storm(seconds: float) -> void:
	_hazy = true
	_storm = true
	_timer = seconds


## True from the moment a storm or haze is called until it starts to clear.
func is_hazy() -> bool:
	return _hazy


## How much faster the player heats up right now (1 = normal).
func heat_factor() -> float:
	return 1.0 + HEAT_BOOST * haze


func _process(delta: float) -> void:
	if _env == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_hazy = not _hazy
		_timer = randf_range(HAZE_MIN, HAZE_MAX) if _hazy else randf_range(CALM_MIN, CALM_MAX)
		if _hazy:
			said.emit("חזאי", OPENERS.pick_random())
	haze = move_toward(haze, 1.0 if _hazy else 0.0, delta / RAMP)
	if haze <= 0.0:
		_storm = false   # kept until the sky is clear, so a storm thins out gradually

	var thick := STORM_FOG if _storm else 1.0
	_env.fog_density = lerpf(CLEAR_FOG, HAZE_FOG * thick, haze)
	_env.volumetric_fog_density = lerpf(CLEAR_VOLUME, HAZE_VOLUME * thick, haze)
	_dust.amount_ratio = 1.0 if _storm else 0.7
	_dust.emitting = haze > 0.15
	if _dust.emitting:
		# The dust cloud travels with the player, a little upwind.
		var centre: Vector3 = _focus.call()
		_dust.global_position = centre + Vector3(0, 2.5, 0) - WIND.normalized() * 15.0
