extends Node

signal dialogue_started
signal dialogue_ended
signal dialogue_advanced(step_index: int)

# Your tutorial dialogue lines
var tutorial_steps: Array[String] = [
	"Before you enter the ruins, practise moving and jumping in this hall.",
	"1 / 4 • Walk to the arrow",
	"Great job! Now try jumping over the obstacles.",
	"You're ready. Proceed to the exit!"
]

var current_step: int = 0
var is_active: bool = false

func start_dialogue() -> void:
	current_step = 0
	is_active = true
	GameManager.set_state(GameManager.State.DIALOGUE)
	dialogue_started.emit()
	dialogue_advanced.emit(current_step)

func next_step() -> void:
	current_step += 1
	if current_step >= tutorial_steps.size():
		end_dialogue()
	else:
		dialogue_advanced.emit(current_step)

func end_dialogue() -> void:
	is_active = false
	GameManager.set_state(GameManager.State.PLAYING)
	dialogue_ended.emit()
