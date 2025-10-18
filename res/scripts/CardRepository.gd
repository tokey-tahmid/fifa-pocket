extends RefCounted
class_name CardRepository

## Loads card definitions and helper metadata from a `.tres` resource.
## The repository keeps an in-memory cache and offers helper utilities to
## resolve default decks by id.

const DEFAULT_RESOURCE_PATH := "res://cards/CardData.tres"

var _resource_path: String
var _cards: Array = []
var _cards_by_id: Dictionary = {}
var _default_player_ids: Array = []
var _default_opponent_ids: Array = []

func _init(resource_path: String = DEFAULT_RESOURCE_PATH) -> void:
    _resource_path = resource_path

func get_all_cards() -> Array:
    _ensure_loaded()
    return _duplicate_cards(_cards)

func get_card_by_id(card_id: String) -> Dictionary:
    _ensure_loaded()
    if _cards_by_id.has(card_id):
        return _cards_by_id[card_id].duplicate(true)
    return {}

func get_cards_by_ids(ids: Array) -> Array:
    _ensure_loaded()
    var result: Array = []
    for id_value in ids:
        if _cards_by_id.has(id_value):
            result.append(_cards_by_id[id_value].duplicate(true))
    return result

func load_default_player_deck() -> Array:
    _ensure_loaded()
    return get_cards_by_ids(_default_player_ids)

func load_default_opponent_deck() -> Array:
    _ensure_loaded()
    return get_cards_by_ids(_default_opponent_ids)

func _ensure_loaded() -> void:
    if !_cards.is_empty():
        return

    var resource := ResourceLoader.load(_resource_path)
    if resource == null:
        push_error("CardRepository: Unable to load resource at %s" % _resource_path)
        return

    var raw_cards := resource.get("cards", [])
    if raw_cards is Array:
        for entry in raw_cards:
            if entry is Dictionary:
                var card := entry.duplicate(true)
                var card_id := card.get("id", "")
                if card_id == "":
                    card_id = card.get("name", "")
                if card_id == "":
                    continue
                _cards.append(card)
                _cards_by_id[card_id] = card
    else:
        push_warning("CardRepository: resource missing 'cards' array")

    var player_ids := resource.get("default_player_deck", [])
    if player_ids is Array:
        _default_player_ids = player_ids.duplicate(true)
    else:
        _default_player_ids = []

    var opponent_ids := resource.get("default_opponent_deck", [])
    if opponent_ids is Array:
        _default_opponent_ids = opponent_ids.duplicate(true)
    else:
        _default_opponent_ids = []

func _duplicate_cards(cards: Array) -> Array:
    var result: Array = []
    for card in cards:
        if card is Dictionary:
            result.append(card.duplicate(true))
    return result
