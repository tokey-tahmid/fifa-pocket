extends RefCounted
class_name PlayerProfile

## Manages the persistent player profile including currency, inventory and
## tutorial flags. Data is serialized to a ConfigFile stored in the user://
## folder so progress survives between sessions.

const SAVE_PATH := "user://player_profile.cfg"
const SECTION_CORE := "core"
const SECTION_INVENTORY := "inventory"
const SECTION_DECKS := "decks"
const SECTION_TUTORIALS := "tutorials"
const CURRENT_VERSION := 1

const DEFAULT_TUTORIAL_FLAGS := {
    "deck_builder": true,
    "match_flow": true
}

const RARITY_WEIGHTS := {
    "legendary": 5,
    "epic": 10,
    "rare": 20,
    "uncommon": 30,
    "common": 40
}

const CardRepository := preload("res://res/scripts/CardRepository.gd")

static var _profile: Dictionary = {}
static var _repository: CardRepository = CardRepository.new()
static var _rng := RandomNumberGenerator.new()
static var _loaded := false

static func ensure_initialized() -> void:
    if _loaded:
        return
    _rng.randomize()
    _profile = _load_or_create_profile()
    _loaded = true

static func get_coin_balance() -> int:
    ensure_initialized()
    var core: Dictionary = _profile.get(SECTION_CORE, {})
    return int(core.get("coins", 0))

static func add_coins(amount: int) -> int:
    ensure_initialized()
    if amount <= 0:
        return get_coin_balance()
    var core: Dictionary = _profile.get(SECTION_CORE, {})
    var coins := int(core.get("coins", 0)) + amount
    core["coins"] = coins
    _profile[SECTION_CORE] = core
    _save_profile()
    return coins

static func get_owned_cards() -> Array[Dictionary]:
    ensure_initialized()
    var inventory: Dictionary = _profile.get(SECTION_INVENTORY, {})
    if inventory.is_empty():
        return []
    var ids := inventory.keys()
    var cards := _repository.get_cards_by_ids(ids)
    var cards_by_id: Dictionary = {}
    for card in cards:
        var card_id := _get_card_id(card)
        cards_by_id[card_id] = card
    var result: Array[Dictionary] = []
    for card_id in ids:
        if !cards_by_id.has(card_id):
            continue
        var card: Dictionary = cards_by_id[card_id].duplicate(true)
        card["owned_copies"] = int(inventory.get(card_id, 0))
        result.append(card)
    result.sort_custom(func(a, b):
        var rarity_a := String(a.get("rarity", "")).to_lower()
        var rarity_b := String(b.get("rarity", "")).to_lower()
        if rarity_a == rarity_b:
            return String(a.get("name", "")) < String(b.get("name", ""))
        return rarity_a < rarity_b
    )
    return result

static func get_card_count(card_id: String) -> int:
    ensure_initialized()
    return int(_profile.get(SECTION_INVENTORY, {}).get(card_id, 0))

static func grant_cards(card_ids: Array) -> Array[Dictionary]:
    ensure_initialized()
    var added_cards: Array[Dictionary] = []
    if card_ids.is_empty():
        return added_cards
    var inventory: Dictionary = _profile.get(SECTION_INVENTORY, {}).duplicate(true)
    for raw_id in card_ids:
        var card_id := String(raw_id)
        if card_id == "":
            continue
        inventory[card_id] = int(inventory.get(card_id, 0)) + 1
        var card: Dictionary = _repository.get_card_by_id(card_id)
        if !card.is_empty():
            card["owned_copies"] = int(inventory[card_id])
            added_cards.append(card)
    _profile[SECTION_INVENTORY] = inventory
    _save_profile()
    return added_cards

static func get_active_deck_cards() -> Array[Dictionary]:
    ensure_initialized()
    var deck_ids: Array = _profile.get(SECTION_DECKS, {}).get("active", [])
    if deck_ids.is_empty():
        return _ensure_default_deck()
    return _repository.get_cards_by_ids(deck_ids)

static func set_active_deck(card_ids: Array) -> void:
    ensure_initialized()
    var sanitized: Array[String] = []
    for raw_id in card_ids:
        var card_id := String(raw_id)
        if card_id == "":
            continue
        sanitized.append(card_id)
    if sanitized.is_empty():
        _ensure_default_deck()
    else:
        var decks: Dictionary = _profile.get(SECTION_DECKS, {})
        decks["active"] = sanitized
        _profile[SECTION_DECKS] = decks
        _save_profile()

static func clear_active_deck() -> void:
    ensure_initialized()
    var decks: Dictionary = _profile.get(SECTION_DECKS, {})
    decks.erase("active")
    _profile[SECTION_DECKS] = decks
    _save_profile()
    _ensure_default_deck()

static func apply_match_rewards(base_rewards: Dictionary) -> Dictionary:
    ensure_initialized()
    if base_rewards.is_empty():
        return {}
    var summary: Dictionary = {}
    var coins := int(base_rewards.get("coins", 0))
    if coins > 0:
        add_coins(coins)
        summary["coins"] = coins
    var packs := int(base_rewards.get("card_packs", 0))
    if packs > 0:
        summary["card_packs"] = packs
        var acquired: Array[String] = []
        for _i in range(packs):
            var card := _draw_random_card()
            if card.is_empty():
                continue
            var card_id := _get_card_id(card)
            if card_id == "":
                continue
            grant_cards([card_id])
            acquired.append(card.get("name", card_id))
        if !acquired.is_empty():
            summary["cards"] = acquired
    if !summary.is_empty():
        _save_profile()
    return summary

static func consume_tutorial(flag: String) -> bool:
    ensure_initialized()
    var tutorials: Dictionary = _profile.get(SECTION_TUTORIALS, {})
    if !tutorials.has(flag):
        return false
    if tutorials[flag] == false:
        return false
    tutorials[flag] = false
    _profile[SECTION_TUTORIALS] = tutorials
    _save_profile()
    return true

static func should_show_tutorial(flag: String) -> bool:
    ensure_initialized()
    return bool(_profile.get(SECTION_TUTORIALS, {}).get(flag, false))

static func _load_or_create_profile() -> Dictionary:
    var config := ConfigFile.new()
    var error := config.load(SAVE_PATH)
    if error != OK:
        return _build_default_profile()
    return _deserialize_profile(config)

static func _build_default_profile() -> Dictionary:
    var inventory: Dictionary = {}
    var starter_deck: Array[String] = []
    var default_cards := _repository.load_default_player_deck()
    for card in default_cards:
        var card_id := _get_card_id(card)
        if card_id == "":
            continue
        inventory[card_id] = int(inventory.get(card_id, 0)) + 1
        starter_deck.append(card_id)
    return {
        SECTION_CORE: {
            "version": CURRENT_VERSION,
            "coins": 0
        },
        SECTION_INVENTORY: inventory,
        SECTION_DECKS: {
            "active": starter_deck
        },
        SECTION_TUTORIALS: DEFAULT_TUTORIAL_FLAGS.duplicate(true)
    }

static func _deserialize_profile(config: ConfigFile) -> Dictionary:
    var core := {
        "version": int(config.get_value(SECTION_CORE, "version", CURRENT_VERSION)),
        "coins": int(config.get_value(SECTION_CORE, "coins", 0))
    }
    var inventory := {}
    if config.has_section(SECTION_INVENTORY):
        for key in config.get_section_keys(SECTION_INVENTORY):
            inventory[String(key)] = int(config.get_value(SECTION_INVENTORY, key, 0))
    var decks := {
        "active": config.get_value(SECTION_DECKS, "active", [])
    }
    var tutorials := DEFAULT_TUTORIAL_FLAGS.duplicate(true)
    if config.has_section(SECTION_TUTORIALS):
        for key in config.get_section_keys(SECTION_TUTORIALS):
            tutorials[String(key)] = bool(config.get_value(SECTION_TUTORIALS, key, true))
    return {
        SECTION_CORE: core,
        SECTION_INVENTORY: inventory,
        SECTION_DECKS: decks,
        SECTION_TUTORIALS: tutorials
    }

static func _save_profile() -> void:
    ensure_initialized()
    var config := ConfigFile.new()
    var core := _profile.get(SECTION_CORE, {})
    config.set_value(SECTION_CORE, "version", int(core.get("version", CURRENT_VERSION)))
    config.set_value(SECTION_CORE, "coins", int(core.get("coins", 0)))
    var inventory: Dictionary = _profile.get(SECTION_INVENTORY, {})
    for key in inventory.keys():
        config.set_value(SECTION_INVENTORY, key, int(inventory[key]))
    var decks: Dictionary = _profile.get(SECTION_DECKS, {})
    if decks.has("active"):
        config.set_value(SECTION_DECKS, "active", decks["active"])
    var tutorials: Dictionary = _profile.get(SECTION_TUTORIALS, {})
    for key in tutorials.keys():
        config.set_value(SECTION_TUTORIALS, key, bool(tutorials[key]))
    var err := config.save(SAVE_PATH)
    if err != OK:
        push_warning("PlayerProfile: Unable to save profile (%s)" % err)

static func _ensure_default_deck() -> Array:
    var decks: Dictionary = _profile.get(SECTION_DECKS, {})
    var active: Array = decks.get("active", [])
    if !active.is_empty():
        return _repository.get_cards_by_ids(active)
    var defaults := _repository.load_default_player_deck()
    var deck_ids: Array[String] = []
    for card in defaults:
        var card_id := _get_card_id(card)
        if card_id == "":
            continue
        deck_ids.append(card_id)
    decks["active"] = deck_ids
    _profile[SECTION_DECKS] = decks
    _save_profile()
    return defaults

static func _draw_random_card() -> Dictionary:
    var all_cards := _repository.get_all_cards()
    if all_cards.is_empty():
        return {}
    var weighted: Array[Dictionary] = []
    var total_weight := 0
    for card in all_cards:
        var rarity := String(card.get("rarity", "common")).to_lower()
        var weight := int(RARITY_WEIGHTS.get(rarity, 20))
        total_weight += max(weight, 1)
        weighted.append({
            "card": card,
            "cumulative": total_weight
        })
    if total_weight <= 0:
        return weighted[0]["card"].duplicate(true)
    var roll := _rng.randi_range(1, total_weight)
    for entry in weighted:
        if roll <= int(entry.get("cumulative", 0)):
            return entry.get("card", {}).duplicate(true)
    return weighted.back().get("card", {}).duplicate(true)

static func _get_card_id(card: Dictionary) -> String:
    if card.is_empty():
        return ""
    var card_id := String(card.get("id", ""))
    if card_id != "":
        return card_id
    return String(card.get("name", ""))
