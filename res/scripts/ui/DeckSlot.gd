extends PanelContainer

signal drop_requested(slot_index, data)
signal clear_requested(slot_index)

@export var slot_index: int = 0

var card_data: Dictionary = {}

@onready var _card_widget: CardWidget = $VBoxContainer/CardDisplay
@onready var _hint_label: Label = $VBoxContainer/Hint

func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    if _card_widget:
        _card_widget.set_interactive(false)
    set_card(card_data)

func set_card(data: Dictionary) -> void:
    card_data = data.duplicate(true)
    if _card_widget:
        _card_widget.set_card(card_data)
    if _hint_label:
        if card_data.is_empty():
            _hint_label.text = "Drag a card here"
        else:
            _hint_label.text = "Double click to flip • Right click to clear"

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
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        clear_requested.emit(slot_index)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
        if _card_widget:
            _card_widget.flip()

func _on_mouse_entered() -> void:
    if _card_widget:
        _card_widget.trigger_hover(true)

func _on_mouse_exited() -> void:
    if _card_widget:
        _card_widget.trigger_hover(false)
