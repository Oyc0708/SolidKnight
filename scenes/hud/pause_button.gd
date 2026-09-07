extends TextureButton

@onready var icon = $PauseIcon
@export var settings_panel: Panel

var normal_modulate = Color.WHITE
var hover_modulate = Color(1.15, 1.15, 1.15, 1.0)
var pressed_modulate = Color(0.8, 0.8, 0.8, 1.0)

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_mouse_entered():
	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "modulate", hover_modulate, 0.1)
	tween.tween_property(icon, "modulate", hover_modulate, 0.1)
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(icon, "scale", Vector2(1.05, 1.05), 0.1)

func _on_mouse_exited():
	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "modulate", normal_modulate, 0.1)
	tween.tween_property(icon, "modulate", normal_modulate, 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.1)

func _on_button_down():
	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "modulate", pressed_modulate, 0.05)
	tween.tween_property(icon, "modulate", pressed_modulate, 0.05)
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(icon, "scale", Vector2(0.95, 0.95), 0.05)

func _on_button_up():
	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "modulate", hover_modulate, 0.05)
	tween.tween_property(icon, "modulate", hover_modulate, 0.05)
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.05)
	tween.tween_property(icon, "scale", Vector2(1.05, 1.05), 0.05)
