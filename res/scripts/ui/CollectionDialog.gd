extends AcceptDialog
class_name CollectionDialog

const CardListItemScene := preload("res://scenes/ui/CardListItem.tscn")
const PlayerProfile := preload("res://res/scripts/PlayerProfile.gd")

@onready var _rarity_filter: OptionButton = $MarginContainer/VBoxContainer/Controls/RarityFilter
@onready var _total_label: Label = $MarginContainer/VBoxContainer/Controls/TotalLabel
@onready var _card_list: VBoxContainer = $MarginContainer/VBoxContainer/Scroll/CardListContainer/CardList
@onready var _empty_label: Label = $MarginContainer/VBoxContainer/Scroll/CardListContainer/EmptyLabel

var _cards: Array[Dictionary] = []

func _ready() -> void:
    window_title = "Card Collection"
    if has_method("get_ok_button"):
        get_ok_button().text = "Close"
    _rarity_filter.item_selected.connect(_on_filter_changed)
    refresh()

func refresh() -> void:
    PlayerProfile.ensure_initialized()
    _cards = PlayerProfile.get_owned_cards()
    _cards.sort_custom(Callable(self, "_sort_cards"))
    _build_rarity_filter()
    _refresh_list()

func _sort_cards(a: Dictionary, b: Dictionary) -> bool:
    var rarity_a := String(a.get("rarity", "")).to_lower()
    var rarity_b := String(b.get("rarity", "")).to_lower()
    if rarity_a == rarity_b:
        return String(a.get("name", "")) < String(b.get("name", ""))
    return rarity_a < rarity_b

func _build_rarity_filter() -> void:
    var rarity_set := {}
    for card in _cards:
        var rarity := String(card.get("rarity", "")).to_lower()
        if rarity != "":
            rarity_set[rarity] = true
    var rarities := rarity_set.keys()
    rarities.sort()
    var previous := _get_selected_rarity()
    _rarity_filter.clear()
    _rarity_filter.add_item("All Rarities")
    _rarity_filter.set_item_metadata(0, "")
    var index := 1
    for rarity in rarities:
        var display := rarity.capitalize()
        _rarity_filter.add_item(display)
        _rarity_filter.set_item_metadata(index, rarity)
        index += 1
    if previous != "" and rarities.has(previous):
        for i in range(_rarity_filter.item_count):
            if _rarity_filter.get_item_metadata(i) == previous:
                _rarity_filter.select(i)
                return
    _rarity_filter.select(0)

func _refresh_list() -> void:
    for child in _card_list.get_children():
        child.queue_free()
    var filter := _get_selected_rarity()
    var filtered: Array = []
    var total_owned := 0
    for card in _cards:
        var rarity := String(card.get("rarity", "")).to_lower()
        if filter != "" and rarity != filter:
            continue
        filtered.append(card)
        total_owned += int(card.get("owned_copies", 1))
    _empty_label.visible = filtered.is_empty()
    for card in filtered:
        var item := CardListItemScene.instantiate()
        item.set_card(card)
        _card_list.add_child(item)
    var label_text := "Total cards: %d" % total_owned
    if !filtered.is_empty():
        label_text += " | Unique: %d" % filtered.size()
    _total_label.text = label_text

func _on_filter_changed(_index: int) -> void:
    _refresh_list()

func _get_selected_rarity() -> String:
    if _rarity_filter.item_count == 0:
        return ""
    var selected := _rarity_filter.get_selected_id()
    if selected < 0 or selected >= _rarity_filter.item_count:
        selected = 0
    var metadata := _rarity_filter.get_item_metadata(selected)
    if metadata == null:
        return ""
    return String(metadata)
