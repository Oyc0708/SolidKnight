extends Node2D
## All visuals and UI are saved Godot nodes. This script connects them.
@export_group("Your Words")
@export var heading := "The Proving Grounds"
@export_multiline var welcome := "Before you enter the ruins, practise four moves in this hall. Watch the small knight, then follow the arrow."
@export_multiline var walk_task := "Hold D or Right to walk to the arrow. A or Left moves you back."
@export_multiline var jump_task := "Walk close to the first block, then hold D and Space (or W). Land on the marked ledge."
@export_multiline var double_task := "Start near the middle-right of this ledge. Hold jump briefly, release, then jump again while rising. Keep moving right onto the higher block."
@export_multiline var dash_task := "Hold A or Left and press Shift to dash. Return to the arrow on the ground."
@export_multiline var final_text := "Well done! You completed walking, jumping, double jumping and dashing. Your adventure is ready."
@export_file("*.tscn") var game_scene_path := "res://scenes/main/game.tscn"

@onready var player: CharacterBody2D = $Player
@onready var progress_label: Label = $UI/Progress
@onready var dialogue: Label = $UI/DialogueBox/Margin/VBox/Dialogue
@onready var next_button: Button = $UI/DialogueBox/Margin/VBox/Buttons/Next
@onready var replay_button: Button = $UI/DialogueBox/Margin/VBox/Buttons/Replay
@onready var retry_button: Button = $UI/DialogueBox/Margin/VBox/Buttons/Retry
@onready var menu_button: Button = $UI/DialogueBox/Margin/VBox/Buttons/Menu
@onready var goals: Array[Area2D] = [
	$Goals/WalkGoal, $Goals/JumpGoal, $Goals/DoubleGoal, $Goals/DashGoal
]
@onready var starts: Array[Marker2D] = [
	$StartPoints/WalkStart, $StartPoints/JumpStart,
	$StartPoints/DoubleStart, $StartPoints/DashStart
]
@onready var arrow: Node2D = $Arrow
@onready var demo_motion: AnimationPlayer = $UI/DemoBox/AnimationPlayer
@onready var demo_caption: Label = $UI/DemoBox/DemoCaption

# 0 = welcome, 1..4 = practice, 5 = finished.
var step := 0
var used_double_jump := false
var used_dash := false
var changing_scene := false

func _ready() -> void:
	GameManager.unpause_game()
	EventBus.play_music_requested.emit("room")
	next_button.pressed.connect(_next)
	replay_button.pressed.connect(_replay)
	retry_button.pressed.connect(_retry_step)
	menu_button.pressed.connect(_main_menu)
	_show_step()

func _show_step() -> void:
	var practising := step >= 1 and step <= 4
	_lock_player(not practising)
	next_button.visible = not practising
	replay_button.visible = step == 5
	retry_button.visible = practising
	arrow.visible = practising
	for index in range(goals.size()):
		# Areas stay active. Only the current goal gets a visible floor marker.
		goals[index].get_node("Marker").visible = practising and index == step - 1
	var words: Array[String] = [welcome, walk_task, jump_task, double_task, dash_task, final_text]
	dialogue.text = words[step]
	var animations := ["idle_demo", "walk_demo", "jump_demo", "double_demo", "dash_demo", "idle_demo"]
	var captions := ["WATCH THE KNIGHT", "A / D  -  WALK", "SPACE / W  -  JUMP", "JUMP TWICE", "SHIFT  -  DASH", "READY TO EXPLORE"]
	demo_motion.play(animations[step])
	demo_caption.text = captions[step]
	progress_label.text = heading
	if practising:
		arrow.global_position = goals[step - 1].global_position
		progress_label.text = "%s   |   %d / 4" % [heading, step]
	elif step == 5:
		progress_label.text = "All four challenges complete"
	next_button.text = "Begin Adventure" if step == 5 else "Start practice"
	if next_button.visible:
		next_button.grab_focus()

func _physics_process(_delta: float) -> void:
	if step < 1 or step > 4 or changing_scene:
		return
	# Read the real player's actions. No changes to your friend's movement code.
	if step == 3:
		used_double_jump = used_double_jump or player.get_double_jump_flash_timer() > 0
	if step == 4:
		used_dash = used_dash or player.is_dashing()
	if not goals[step - 1].overlaps_body(player) or not player.is_on_floor():
		return
	if step == 3 and not used_double_jump:
		return
	if step == 4 and not used_dash:
		return
	step += 1
	EventBus.play_sfx_requested.emit("button_click")
	_show_step()

func _next() -> void:
	if changing_scene:
		return
	EventBus.play_sfx_requested.emit("button_click")
	if step == 0:
		step = 1
		_show_step()
	elif step == 5:
		_open_scene(game_scene_path)

func _lock_player(lock: bool) -> void:
	# Player uses GameManager, not a can_move variable.
	GameManager.set_state(GameManager.State.DIALOGUE if lock else GameManager.State.PLAYING)
	player.velocity = Vector2.ZERO

func _retry_step() -> void:
	if step < 1 or step > 4:
		return
	player.reset_after_death()
	player.global_position = starts[step - 1].global_position
	used_double_jump = false
	used_dash = false
	_show_step()

func _replay() -> void:
	_open_scene(scene_file_path)

func _main_menu() -> void:
	_open_scene("res://scenes/menus/main_menu.tscn")

func _open_scene(path: String) -> void:
	if changing_scene:
		return
	changing_scene = true
	_lock_player(false)
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		changing_scene = false
		_show_step()
		dialogue.text = "Could not open the scene. Check its path in the Inspector."

func _input(event: InputEvent) -> void:
	# This scene has a Main menu button instead of the game's pause menu.
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
