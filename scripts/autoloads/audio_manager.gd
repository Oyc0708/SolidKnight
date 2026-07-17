# audio_manager.gd
# ─────────────────────────────────────────────────────────────────────────────
# Central controller for all game audio.
# Any script can request a sound without knowing this node's location.
# Audio buses (Master/Music/SFX) are configured in Phase 11 — for now,
# sounds will play through the default Master bus.
#
# HOW TO USE FROM ANY SCRIPT:
#   AudioManager.play_sfx("player_jump")
#   AudioManager.play_music("zone_01_theme")
#   AudioManager.stop_music()
#
#   OR via EventBus (preferred for decoupled systems):
#   EventBus.play_sfx_requested.emit("player_jump")
# ─────────────────────────────────────────────────────────────────────────────
extends Node


# ─── CONSTANTS ───────────────────────────────────────────────────────────────
const SFX_BASE_PATH: String = "res://assets/audio/sfx/"
const MUSIC_BASE_PATH: String = "res://assets/audio/music/"


# ─── NODES ───────────────────────────────────────────────────────────────────
# We create these nodes in code because AudioManager is a script-based autoload,
# not a scene. We cannot use @onready here.
var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

# Track current music so we don't restart a track that's already playing
var _current_music: String = ""


# ─── BUILT-IN FUNCTIONS ──────────────────────────────────────────────────────
func _ready() -> void:
	# Create an AudioStreamPlayer for background music
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)          # Must add to scene tree to function
	
	# Create a separate AudioStreamPlayer for sound effects
	# Using a separate player means music and SFX have independent volume control
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFXPlayer"
	add_child(_sfx_player)
	
	# Connect to EventBus so any script can request audio via signals
	EventBus.play_sfx_requested.connect(play_sfx)
	EventBus.play_music_requested.connect(play_music)
	EventBus.stop_music_requested.connect(stop_music)
	
	print("[AudioManager] Ready")


# ─── PUBLIC FUNCTIONS ─────────────────────────────────────────────────────────
## Play a sound effect by filename (without extension)
## Example: play_sfx("player_jump") plays res://assets/audio/sfx/player_jump.wav
func play_sfx(sfx_name: String) -> void:
	var path := SFX_BASE_PATH + sfx_name + ".wav"
	
	# Check if file exists before loading — missing audio causes crashes
	if not ResourceLoader.exists(path):
		# push_warning prints to Output but does NOT crash the game
		# Use this for "nice to have" checks that shouldn't stop gameplay
		push_warning("[AudioManager] SFX not found: " + path)
		return
	
	_sfx_player.stream = load(path)
	_sfx_player.play()


## Play a music track by filename (without extension)
## Example: play_music("zone_01_theme") plays res://assets/audio/music/zone_01_theme.ogg
func play_music(track_name: String) -> void:
	# Don't restart a track that's already playing
	if _current_music == track_name and _music_player.playing:
		return
	
	var path := MUSIC_BASE_PATH + track_name + ".ogg"
	
	if not ResourceLoader.exists(path):
		push_warning("[AudioManager] Music not found: " + path)
		return
	
	_music_player.stream = load(path)
	_music_player.play()
	_current_music = track_name


## Stop the currently playing music track
func stop_music() -> void:
	_music_player.stop()
	_current_music = ""


## Adjust the volume of music (0.0 = silent, 1.0 = full)
## Phase 11 will replace this with bus-based volume control
func set_music_volume(volume: float) -> void:
	# AudioStreamPlayer.volume_db takes decibels — we convert from 0-1 range
	_music_player.volume_db = linear_to_db(volume)


## Adjust the volume of sound effects
func set_sfx_volume(volume: float) -> void:
	_sfx_player.volume_db = linear_to_db(volume)
