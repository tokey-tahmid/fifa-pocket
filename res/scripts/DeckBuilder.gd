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
@onready var _search_line: LineEdit = $MainLayout/ControlsBar/SearchLine
@onready var _position_filter: OptionButton = $MainLayout/ControlsBar/PositionFilter
@onready var _rarity_filter: OptionButton = $MainLayout/ControlsBar/RarityFilter
@onready var _reset_filters_button: Button = $MainLayout/ControlsBar/ResetFilters
@onready var _library_count: Label = $MainLayout/Content/CardLibrary/LibraryHeader/LibraryCount
@onready var _overview_count: Label = $MainLayout/Content/DeckPanel/OverviewPanel/OverviewVBox/OverviewGrid/CountValue
@onready var _overview_attack: Label = $MainLayout/Content/DeckPanel/OverviewPanel/OverviewVBox/OverviewGrid/AttackValue
@onready var _overview_defense: Label = $MainLayout/Content/DeckPanel/OverviewPanel/OverviewVBox/OverviewGrid/DefenseValue
@onready var _overview_pace: Label = $MainLayout/Content/DeckPanel/OverviewPanel/OverviewVBox/OverviewGrid/PaceValue
@onready var _overview_control: Label = $MainLayout/Content/DeckPanel/OverviewPanel/OverviewVBox/OverviewGrid/ControlValue
@onready var _overview_rarity: Label = $MainLayout/Content/DeckPanel/OverviewPanel/OverviewVBox/OverviewGrid/RarityValue

var _repository := CardRepository.new()
var _deck_slots: Array = []
var _current_deck: Array = []
var _all_cards: Array = []

const FILTER_ALL := "__all__"

func _ready() -> void:
    _build_deck_grid()
    _populate_card_list()
    _load_existing_deck()
    _refresh_validation()
    _save_button.pressed.connect(_on_save_pressed)
    _clear_button.pressed.connect(_on_clear_pressed)
    _search_line.text_changed.connect(_on_search_changed)
    _position_filter.item_selected.connect(_on_filter_changed)
    _rarity_filter.item_selected.connect(_on_filter_changed)
    _reset_filters_button.pressed.connect(_on_reset_filters)

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
    _all_cards = _repository.get_all_cards()
    _all_cards.sort_custom(self, "_sort_cards")
    _build_filter_options()
    for card in _filter_cards():
        var item := CARD_LIST_ITEM.instantiate()
        item.set_card(card)
        _card_list.add_child(item)
    _update_library_count()

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
    _update_squad_overview()

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

func _on_search_changed(_text: String) -> void:
    _refresh_filtered_cards()

func _on_filter_changed(_index: int) -> void:
    _refresh_filtered_cards()

func _on_reset_filters() -> void:
    _search_line.text = ""
    if _position_filter.item_count > 0:
        _position_filter.select(0)
    if _rarity_filter.item_count > 0:
        _rarity_filter.select(0)
    _refresh_filtered_cards()

func _refresh_filtered_cards() -> void:
    for child in _card_list.get_children():
        child.queue_free()
    for card in _filter_cards():
        var item := CARD_LIST_ITEM.instantiate()
        item.set_card(card)
        _card_list.add_child(item)
    _update_library_count()

func _build_filter_options() -> void:
    var position_set := {}
    var rarity_set := {}
    for card in _all_cards:
        var pos := String(card.get("position", ""))
        if pos != "":
            position_set[pos] = true
        var rarity := String(card.get("rarity", ""))
        if rarity != "":
            rarity_set[rarity] = true
    var positions := position_set.keys()
    positions.sort()
    var rarities := rarity_set.keys()
    rarities.sort()
    _position_filter.clear()
    _rarity_filter.clear()
    _position_filter.add_item("All Positions")
    _position_filter.set_item_metadata(0, FILTER_ALL)
    var index := 1
    for pos in positions:
        if pos == "":
            continue
        _position_filter.add_item(pos)
        _position_filter.set_item_metadata(index, pos)
        index += 1
    _position_filter.select(0)

    _rarity_filter.add_item("All Rarities")
    _rarity_filter.set_item_metadata(0, FILTER_ALL)
    index = 1
    for rarity in rarities:
        if rarity == "":
            continue
        _rarity_filter.add_item(rarity)
        _rarity_filter.set_item_metadata(index, rarity)
        index += 1
    _rarity_filter.select(0)

func _filter_cards() -> Array:
    if _all_cards.is_empty():
        return []
    var result: Array = []
    var search_text := _search_line.text.strip_edges().to_lower()
    var position_filter := _get_selected_filter(_position_filter)
    var rarity_filter := _get_selected_filter(_rarity_filter)
    for card in _all_cards:
        if position_filter != FILTER_ALL and String(card.get("position", "")).to_lower() != position_filter.to_lower():
            continue
        if rarity_filter != FILTER_ALL and String(card.get("rarity", "")).to_lower() != rarity_filter.to_lower():
            continue
        if search_text != "" and !_matches_search(card, search_text):
            continue
        result.append(card)
    return result

func _get_selected_filter(option_button: OptionButton) -> String:
    if option_button.item_count == 0:
        return FILTER_ALL
    var selected := option_button.get_selected_id()
    if selected < 0 or selected >= option_button.item_count:
        selected = 0
    var metadata := option_button.get_item_metadata(selected)
    if metadata == null or metadata == "":
        return FILTER_ALL
    return String(metadata)

func _matches_search(card: Dictionary, query: String) -> bool:
    var haystacks := [
        String(card.get("name", "")),
        String(card.get("club", "")),
        String(card.get("nation", "")),
        String(card.get("position", "")),
        String(card.get("rarity", ""))
    ]
    for hay in haystacks:
        if hay.to_lower().find(query) != -1:
            return true
    return false

func _update_library_count() -> void:
    var count := _card_list.get_child_count()
    _library_count.text = "%d result%s" % [count, count == 1 ? "" : "s"]

func _update_squad_overview() -> void:
    var filled := 0
    var totals := {
        "attack": 0,
        "defense": 0,
        "pace": 0,
        "control": 0
    }
    var rarity_counts := {}
    for card in _current_deck:
        if !(card is Dictionary) or card.is_empty():
            continue
        filled += 1
        for key in totals.keys():
            totals[key] += int(card.get(key, 0))
        var rarity := String(card.get("rarity", ""))
        if rarity == "":
            rarity = "Unknown"
        rarity_counts[rarity] = int(rarity_counts.get(rarity, 0)) + 1

    _overview_count.text = "%d/%d" % [filled, squad_size]
    _overview_attack.text = _format_average(totals["attack"], filled)
    _overview_defense.text = _format_average(totals["defense"], filled)
    _overview_pace.text = _format_average(totals["pace"], filled)
    _overview_control.text = _format_average(totals["control"], filled)
    if rarity_counts.is_empty():
        _overview_rarity.text = "--"
    else:
        var rarity_strings: Array = []
        var rarity_array: Array = rarity_counts.keys()
        rarity_array.sort_custom(func(a, b):
            var count_a := int(rarity_counts[a])
            var count_b := int(rarity_counts[b])
            if count_a == count_b:
                return String(a) < String(b)
            return count_a > count_b
        )
        for rarity in rarity_array:
            rarity_strings.append("%s x%d" % [rarity, int(rarity_counts[rarity])])
        _overview_rarity.text = ", ".join(rarity_strings)

func _format_average(total: int, count: int) -> String:
    if count <= 0:
        return "--"
    return "%.1f" % (float(total) / float(count))
