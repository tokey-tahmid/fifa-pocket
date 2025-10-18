extends RefCounted
class_name AIBrain

## Provides opponent decision making by evaluating available cards, tactics and
## energy. The brain reads tunable difficulty parameters from project settings
## so designers can tweak aggressiveness and randomness without touching code.

const SETTINGS_PREFIX := "fifa-pocket/ai"
const SETTING_AGGRESSIVENESS := "%s/aggressiveness" % SETTINGS_PREFIX
const SETTING_RANDOMNESS := "%s/randomness" % SETTINGS_PREFIX
const SETTING_DEBUG := "%s/debug_logging" % SETTINGS_PREFIX

const DEFAULT_AGGRESSIVENESS := 0.65
const DEFAULT_RANDOMNESS := 0.2

var aggressiveness: float = DEFAULT_AGGRESSIVENESS
var randomness: float = DEFAULT_RANDOMNESS
var debug_enabled: bool = false

var _rng := RandomNumberGenerator.new()

static func register_project_settings() -> void:
    _ensure_setting(SETTING_AGGRESSIVENESS, DEFAULT_AGGRESSIVENESS, {
        "name": SETTING_AGGRESSIVENESS,
        "type": TYPE_FLOAT,
        "hint": PROPERTY_HINT_RANGE,
        "hint_string": "0.0,1.0,0.01",
        "usage": PROPERTY_USAGE_DEFAULT
    })
    _ensure_setting(SETTING_RANDOMNESS, DEFAULT_RANDOMNESS, {
        "name": SETTING_RANDOMNESS,
        "type": TYPE_FLOAT,
        "hint": PROPERTY_HINT_RANGE,
        "hint_string": "0.0,1.0,0.01",
        "usage": PROPERTY_USAGE_DEFAULT
    })
    _ensure_setting(SETTING_DEBUG, false, {
        "name": SETTING_DEBUG,
        "type": TYPE_BOOL,
        "hint": PROPERTY_HINT_NONE,
        "usage": PROPERTY_USAGE_DEFAULT
    })

static func _ensure_setting(path: String, default_value: Variant, property_info: Dictionary) -> void:
    if !ProjectSettings.has_setting(path):
        ProjectSettings.set_setting(path, default_value)
    if property_info:
        ProjectSettings.add_property_info(property_info)

func _init() -> void:
    _rng.randomize()
    refresh_settings()

func refresh_settings() -> void:
    aggressiveness = clamp(float(_get_setting(SETTING_AGGRESSIVENESS, DEFAULT_AGGRESSIVENESS)), 0.0, 1.0)
    randomness = clamp(float(_get_setting(SETTING_RANDOMNESS, DEFAULT_RANDOMNESS)), 0.0, 1.0)
    debug_enabled = bool(_get_setting(SETTING_DEBUG, false))

func _get_setting(path: String, fallback: Variant) -> Variant:
    if ProjectSettings.has_setting(path):
        return ProjectSettings.get_setting(path)
    return fallback

func choose_play(
        hand: Array,
        available_energy: int,
        max_energy: int,
        tactics: Array,
        evaluate_callable: Callable,
        opponent_card: Dictionary,
        context: Dictionary = {}
    ) -> Dictionary:
    refresh_settings()

    var log: Array[String] = []
    var safe_energy := max(available_energy, 0)
    log.append("Energy pool %d/%d" % [safe_energy, max_energy])
    if !opponent_card.is_empty():
        log.append("Opponent shows %s" % opponent_card.get("name", "Unknown"))
    else:
        log.append("Opponent has not revealed a card")
    if context.has("round"):
        log.append("Context: round %s" % String(context.get("round")))
    if context.has("phase"):
        log.append("Context: phase %s" % String(context.get("phase")))

    if hand.is_empty():
        log.append("No cards available to play")
        return {"index": -1, "tactic": null, "log": log}

    var candidates: Array = []
    var best_candidate: Dictionary = {}

    for i in range(hand.size()):
        var card := hand[i]
        var base_score := float(evaluate_callable.call(card, null, opponent_card))
        var candidate := _build_candidate(i, card, null, 0, base_score, safe_energy, max_energy)
        log.append(_format_candidate_log(candidate))
        candidates.append(candidate)
        best_candidate = _better_candidate(best_candidate, candidate)

        for tactic in tactics:
            if tactic == null:
                continue
            var energy_cost := int(tactic.energy_cost)
            if energy_cost > safe_energy:
                log.append("  Skip %s with %s (cost %d > energy %d)" % [card.get("name", "Card"), tactic.tactic_name, energy_cost, safe_energy])
                continue
            var tactic_score := float(evaluate_callable.call(card, tactic, opponent_card))
            var tactic_candidate := _build_candidate(i, card, tactic, energy_cost, tactic_score, safe_energy, max_energy)
            log.append(_format_candidate_log(tactic_candidate))
            candidates.append(tactic_candidate)
            best_candidate = _better_candidate(best_candidate, tactic_candidate)

    if candidates.is_empty():
        log.append("No valid candidates found")
        return {"index": -1, "tactic": null, "log": log}

    var final_candidate := _apply_randomness(candidates, best_candidate, log)
    log.append("Chosen index %d score %.2f" % [final_candidate.get("index", -1), final_candidate.get("score", 0.0)])

    return {
        "index": final_candidate.get("index", -1),
        "tactic": final_candidate.get("tactic", null),
        "score": final_candidate.get("score", -INF),
        "log": log
    }

func _build_candidate(
        index: int,
        card: Dictionary,
        tactic: Tactic,
        energy_cost: int,
        base_score: float,
        available_energy: int,
        max_energy: int
    ) -> Dictionary:
    var adjusted_score := base_score
    var attack := float(card.get("attack", 0))
    var defense := float(card.get("defense", 0))
    var pace := float(card.get("pace", 0))
    var control := float(card.get("control", 0))
    var offense_bias := ((attack + pace * 0.5) - (defense + control * 0.5)) / 100.0
    var offense_bonus := offense_bias * aggressiveness
    adjusted_score += offense_bonus

    var energy_bonus := 0.0
    if max_energy > 0:
        energy_bonus = (float(energy_cost) / float(max_energy)) * aggressiveness * 2.0
        adjusted_score += energy_bonus

    var conserve_bonus := 0.0
    if available_energy > 0:
        var remaining_ratio := float(available_energy - energy_cost) / float(max(available_energy, 1))
        conserve_bonus = remaining_ratio * (1.0 - aggressiveness) * 0.5
        adjusted_score += conserve_bonus

    return {
        "index": index,
        "card": card,
        "tactic": tactic,
        "energy_cost": energy_cost,
        "base_score": base_score,
        "score": adjusted_score,
        "offense_bonus": offense_bonus,
        "energy_bonus": energy_bonus,
        "conserve_bonus": conserve_bonus
    }

func _format_candidate_log(candidate: Dictionary) -> String:
    var card := candidate.get("card", {})
    var tactic: Tactic = candidate.get("tactic", null)
    var tactic_name := tactic.tactic_name if tactic else "Balanced Play"
    return "  %s with %s -> base %.2f adj %.2f (off %.2f, energy %.2f, conserve %.2f)" % [
        card.get("name", "Card"),
        tactic_name,
        candidate.get("base_score", 0.0),
        candidate.get("score", 0.0),
        candidate.get("offense_bonus", 0.0),
        candidate.get("energy_bonus", 0.0),
        candidate.get("conserve_bonus", 0.0)
    ]

func _better_candidate(current: Dictionary, candidate: Dictionary) -> Dictionary:
    if current.is_empty():
        return candidate
    if candidate.get("score", -INF) > current.get("score", -INF):
        return candidate
    return current

func _apply_randomness(candidates: Array, best_candidate: Dictionary, log: Array) -> Dictionary:
    if randomness <= 0.0 or candidates.size() <= 1:
        log.append("Randomness disabled; using optimal choice")
        return best_candidate

    var sorted := candidates.duplicate()
    sorted.sort_custom(self, "_sort_candidates")
    var roll := _rng.randf()
    if roll >= randomness:
        log.append("Random roll %.2f kept optimal choice" % roll)
        return best_candidate

    var limit := min(3, sorted.size())
    var pick_index := _rng.randi_range(0, limit - 1)
    var chosen := sorted[pick_index]
    log.append("Random roll %.2f selected alternative #%d (score %.2f)" % [roll, pick_index + 1, chosen.get("score", 0.0)])
    return chosen

func _sort_candidates(a: Dictionary, b: Dictionary) -> bool:
    return a.get("score", -INF) > b.get("score", -INF)
