extends PanelContainer

signal drop_requested(slot_index, data)
signal clear_requested(slot_index)

@export var slot_index: int = 0

var card_data: Dictionary = {}

@onready var _name_label: Label = $VBoxContainer/CardName
@onready var _stat_label: Label = $VBoxContainer/CardStats

func _ready() -> void:
    set_card(card_data)

func set_card(data: Dictionary) -> void:
    card_data = data.duplicate(true)
    if card_data.is_empty():
        _name_label.text = "Empty Slot"
        _stat_label.text = "Drag a card here"
    else:
        _name_label.text = card_data.get("name", "Unknown")
        _stat_label.text = "ATK %d  DEF %d  PAC %d  CTRL %d" % [
            int(card_data.get("attack", 0)),
            int(card_data.get("defense", 0)),
            int(card_data.get("pace", 0)),
            int(card_data.get("control", 0))
        ]

func clear_card() -> void:
    set_card({})

func _can_drop_data(_position: Vector2, data) -> bool:
    return data is Dictionary and data.get("type", "") == "card"

func _drop_data(_position: Vector2, data) -> void:
    drop_requested.emit(slot_index, data)

func _get_drag_data(_position: Vector2):
    if card_data.is_empty():
        return null
    var preview := Label.new()
    preview.text = card_data.get("name", "")
    set_drag_preview(preview)
    return {
        "type": "card",
        "card": card_data.duplicate(true),
        "source": "slot",
        "slot_index": slot_index
    }

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MouseButton.RIGHT and event.pressed:
        clear_requested.emit(slot_index)
