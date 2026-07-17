# event_bus.gd
# ─────────────────────────────────────────────────────────────────────────────
# The EventBus is the communication backbone of the entire game.
# Instead of nodes talking directly to each other (which creates tight coupling),
# they broadcast signals through this central hub.
#
# HOW TO USE FROM ANY SCRIPT:
#   EventBus.player_died.emit()                   ← broadcast a signal
#   EventBus.player_died.connect(_on_player_died) ← listen for a signal
# ─────────────────────────────────────────────────────────────────────────────
extends Node


# ─── GAME STATE ──────────────────────────────────────────────────────────────
# Emitted when the overall game state changes (playing → paused, etc.)
signal game_state_changed(new_state: int)
signal game_paused()
signal game_unpaused()


# ─── PLAYER HEALTH ───────────────────────────────────────────────────────────
# Emitted whenever the player's HP changes — the HUD listens to this
# to update the heart/mask display without the player knowing the HUD exists
signal player_health_changed(current_hp: int, max_hp: int)
signal player_died()
signal player_respawned()


# ─── PLAYER SOUL ─────────────────────────────────────────────────────────────
# Soul fills when you hit enemies, empties when you heal
signal player_soul_changed(current_soul: int, max_soul: int)


# ─── PLAYER ACTIONS ──────────────────────────────────────────────────────────
# Broadcasted so VFX, audio, and other systems can react to player moves
signal player_damaged(amount: int, source_position: Vector2)
signal player_healed(amount: int)
signal player_dashed()
signal player_landed()


# ─── COMBAT ──────────────────────────────────────────────────────────────────
# Emitted when a hit connects — multiple systems react (damage numbers, VFX, audio)
signal hit_landed(target: Node, damage: int, hit_position: Vector2)
signal enemy_damaged(enemy: Node, amount: int)
signal enemy_died(enemy: Node, position: Vector2)


# ─── GEO (CURRENCY) ──────────────────────────────────────────────────────────
# Geo is the in-game currency (equivalent to Hollow Knight's geo)
signal geo_changed(new_total: int)
signal geo_collected(amount: int, from_position: Vector2)
signal geo_lost(amount: int)


# ─── CHECKPOINTS ─────────────────────────────────────────────────────────────
# checkpoint_id is a unique string per bench, e.g. "zone_01_bench_01"
signal checkpoint_activated(checkpoint_id: String)


# ─── ROOM / SCENE ────────────────────────────────────────────────────────────
signal room_transition_started(target_scene: String)
signal room_transition_finished()


# ─── UI ──────────────────────────────────────────────────────────────────────
signal dialogue_started(speaker_name: String)
signal dialogue_finished()
signal inventory_opened()
signal inventory_closed()
signal map_opened()
signal map_closed()


# ─── ITEMS ───────────────────────────────────────────────────────────────────
signal item_collected(item_id: String)
signal charm_equipped(charm_id: String)
signal charm_unequipped(charm_id: String)


# ─── AUDIO REQUESTS ──────────────────────────────────────────────────────────
# Any script can request audio without knowing AudioManager's address
signal play_sfx_requested(sfx_name: String)
signal play_music_requested(track_name: String)
signal stop_music_requested()


func _ready() -> void:
	# This prints to the Output panel when the game starts
	# It confirms the autoload loaded in the correct order
	print("[EventBus] Ready")
