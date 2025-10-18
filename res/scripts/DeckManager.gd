extends RefCounted
class_name DeckManager

const CARD_REPOSITORY := preload("res://res/scripts/CardRepository.gd")
const PlayerProfile := preload("res://res/scripts/PlayerProfile.gd")

static var _repository: CardRepository = CARD_REPOSITORY.new()
static var _player_deck: Array[Dictionary] = []
static var _opponent_deck: Array[Dictionary] = []

static func set_selected_deck(deck: Array) -> void:
    _player_deck = _sanitize_deck(deck)
    var card_ids: Array = []
    for card in _player_deck:
        var card_id: String = String(card.get("id", card.get("name", "")))
        if card_id == "":
            continue
        card_ids.append(card_id)
    PlayerProfile.set_active_deck(card_ids)

static func get_player_deck() -> Array[Dictionary]:
    if _player_deck.is_empty():
        PlayerProfile.ensure_initialized()
        var stored: Array = PlayerProfile.get_active_deck_cards()
        if stored.is_empty():
            stored = _repository.load_default_player_deck()
        _player_deck = _sanitize_deck(stored)
    return _duplicate_deck(_player_deck)

static func get_default_player_deck() -> Array[Dictionary]:
    return _duplicate_deck(_repository.load_default_player_deck())

static func get_opponent_deck() -> Array[Dictionary]:
    if _opponent_deck.is_empty():
        _opponent_deck = _repository.load_default_opponent_deck()
    return _duplicate_deck(_opponent_deck)

static func set_opponent_deck(deck: Array) -> void:
    _opponent_deck = _sanitize_deck(deck)

static func clear_player_deck() -> void:
    _player_deck.clear()
    PlayerProfile.clear_active_deck()

static func is_valid_deck(deck: Array, required_size: int) -> bool:
    if deck.size() != required_size:
        return false
    var seen_ids: Dictionary = {}
    for card in deck:
        if !(card is Dictionary) or card.is_empty():
            return false
        var card_id: String = String(card.get("id", card.get("name", "")))
        if card_id == "":
            return false
        if seen_ids.has(card_id):
            return false
        seen_ids[card_id] = true
    return true

static func _sanitize_deck(deck: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for card in deck:
        if card is Dictionary and !card.is_empty():
            result.append(card.duplicate(true))
    return result

static func _duplicate_deck(deck: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for card in deck:
        if card is Dictionary:
            result.append(card.duplicate(true))
    return result
