extends Control

const CARD_LIST_ITEM := preload("res://scenes/ui/CardListItem.tscn")
const DECK_SLOT_SCENE := preload("res://scenes/ui/DeckSlot.tscn")
const DeckManager := preload("res://scripts/DeckManager.gd")
const CardRepository := preload("res://scripts/CardRepository.gd")

@export var squad_size: int = 5

const ERROR_COLOR := Color(1, 0.3, 0.3)
const SUCCESS_COLOR := Color(0.4, 0.85, 0.5)

@onready var _card_list: VBoxContainer = $MainLayout/Content/CardLibrary/ScrollContainer/CardList
@onready var _deck_grid: GridContainer = $MainLayout/Content/DeckPanel/DeckGrid
@onready var _error_label: Label = $MainLayout/Content/DeckPanel/ErrorLabel
@onready var _save_button: Button = $MainLayout/Footer/SaveButton
@onready var _clear_button: Button = $MainLayout/Footer/ClearButton

var _repository := CardRepository.new()
var _deck_slots: Array = []
var _current_deck: Array = []

func _ready() -> void:
    _build_deck_grid()
    _populate_card_list()
    _load_existing_deck()
    _refresh_validation()
    _save_button.pressed.connect(_on_save_pressed)
    _clear_button.pressed.connect(_on_clear_pressed)

func _build_deck_grid() -> void:
    _deck_slots.clear()
    _deck_grid.columns = squad_size
    _current_deck.resize(squad_size)
    for i in range(squad_size):
        var slot := DECK_SLOT_SCENE.instantiate()
        slot.slot_index = i
        slot.drop_requested.connect(_on_slot_drop)
        slot.clear_requested.connect(_on_slot_clear)
        _deck_grid.add_child(slot)
        _deck_slots.append(slot)
        _current_deck[i] = {}

func _populate_card_list() -> void:
    for child in _card_list.get_children():
        child.queue_free()
    var cards := _repository.get_all_cards()
    cards.sort_custom(self, "_sort_cards")
    for card in cards:
        var item := CARD_LIST_ITEM.instantiate()
        item.set_card(card)
        _card_list.add_child(item)

func _load_existing_deck() -> void:
    var saved := DeckManager.get_player_deck()
    if saved.is_empty():
        saved = DeckManager.get_default_player_deck()
    for i in range(min(saved.size(), _deck_slots.size())):
        var slot := _deck_slots[i]
        var card := saved[i]
        slot.set_card(card)
        _current_deck[i] = card.duplicate(true)

func _on_slot_drop(slot_index: int, data: Dictionary) -> void:
    if data.get("type", "") != "card":
        return
    var card: Dictionary = data.get("card", {})
    if card.is_empty():
        return
    var source_slot := data.get("slot_index", -1)
    if source_slot != -1 and source_slot != slot_index and source_slot < _deck_slots.size():
        _clear_slot(source_slot)
    _assign_card(slot_index, card)

func _assign_card(slot_index: int, card: Dictionary) -> void:
    if slot_index < 0 or slot_index >= _deck_slots.size():
        return
    var slot := _deck_slots[slot_index]
    slot.set_card(card)
    _current_deck[slot_index] = card.duplicate(true)
    _refresh_validation()

func _clear_slot(slot_index: int) -> void:
    if slot_index < 0 or slot_index >= _deck_slots.size():
        return
    var slot := _deck_slots[slot_index]
    slot.clear_card()
    _current_deck[slot_index] = {}
    _refresh_validation()

func _on_slot_clear(slot_index: int) -> void:
    _clear_slot(slot_index)

func _refresh_validation() -> void:
    var filled := 0
    var duplicates := {}
    var duplicate_found := false
    for card in _current_deck:
        if card is Dictionary and !card.is_empty():
            filled += 1
            var card_id := card.get("id", card.get("name", ""))
            if card_id != "":
                if duplicates.has(card_id):
                    duplicate_found = true
                duplicates[card_id] = true
    var message := ""
    if duplicate_found:
        message = "Each card can only be used once."
    elif filled < squad_size:
        message = "Select %d more card(s) to complete the squad." % (squad_size - filled)

    _error_label.text = message
    _error_label.visible = message != ""
    if message != "":
        _error_label.modulate = ERROR_COLOR
    _save_button.disabled = message != "" or filled != squad_size

func _on_save_pressed() -> void:
    var sanitized := []
    for card in _current_deck:
        sanitized.append(card.duplicate(true) if card is Dictionary else {})
    DeckManager.set_selected_deck(sanitized)
    _error_label.text = "Deck saved."
    _error_label.visible = true
    _error_label.modulate = SUCCESS_COLOR

func _on_clear_pressed() -> void:
    for i in range(_deck_slots.size()):
        _clear_slot(i)
    DeckManager.clear_player_deck()

func _sort_cards(a: Dictionary, b: Dictionary) -> bool:
    return a.get("name", "") < b.get("name", "")
