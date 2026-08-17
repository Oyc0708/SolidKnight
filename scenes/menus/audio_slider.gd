extends HSlider

@export var audio_bus_name: String


func _ready() -> void:
	var bus_index := AudioServer.get_bus_index(audio_bus_name)

	if bus_index == -1:
		push_warning("Audio bus not found: " + audio_bus_name)
		return

	value = db_to_linear(AudioServer.get_bus_volume_db(bus_index))

	value_changed.connect(_on_value_changed)


func _on_value_changed(new_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(audio_bus_name)

	if bus_index == -1:
		return

	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(new_value)
	)
