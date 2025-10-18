extends Control

const DeckManager := preload("res://scripts/DeckManager.gd")
const AIBrain := preload("res://scripts/AIBrain.gd")
const HandCardScene := preload("res://scenes/ui/HandCard.tscn")

## Orchestrates the full life cycle of a match including the draw, tactic
## selection, resolution and cleanup phases. A simple state machine drives the
## timers and UI so the match can run in a deterministic loop without extra
## input wiring.

enum Phase {
    DRAW,
    TACTIC_SELECTION,
    RESOLUTION,
    CLEANUP,
    COMPLETE
}

@export var total_rounds: int = 5
@export var draw_duration: float = 1.5
@export var tactic_duration: float = 8.0
@export var resolution_duration: float = 2.5
@export var cleanup_duration: float = 1.0
@export var auto_resolve_on_timeout: bool = true
@export var player_energy_max: int = 6
@export var opponent_energy_max: int = 6
@export var energy_refresh_per_round: int = 3
@export var ai_debug_logging: bool = false

@onready var _phase_timer: Timer = $PhaseTimer
@onready var _announcement_timer: Timer = $AnnouncementTimer
@onready var _announcement_label: Label = $UI/PhaseAnnouncement
@onready var _phase_label: Label = $UI/HUD/MainVBox/TopBar/PhasePanel/PhaseLabel
@onready var _player_score_label: Label = $UI/HUD/MainVBox/TopBar/PlayerPanel/PlayerScore
@onready var _opponent_score_label: Label = $UI/HUD/MainVBox/TopBar/OpponentPanel/OpponentScore
@onready var _round_label: Label = $UI/HUD/MainVBox/TopBar/PhasePanel/RoundLabel
@onready var _player_energy_bar: ProgressBar = $UI/HUD/MainVBox/EnergyPanel/PlayerEnergyBox/PlayerEnergyBar
@onready var _player_energy_text: Label = $UI/HUD/MainVBox/EnergyPanel/PlayerEnergyBox/PlayerEnergyText
@onready var _opponent_energy_bar: ProgressBar = $UI/HUD/MainVBox/EnergyPanel/OpponentEnergyBox/OpponentEnergyBar
@onready var _opponent_energy_text: Label = $UI/HUD/MainVBox/EnergyPanel/OpponentEnergyBox/OpponentEnergyText
@onready var _player_hand_list: HBoxContainer = $UI/HUD/MainVBox/HandsContainer/PlayerHandPanel/PlayerHandScroll/PlayerHandList
@onready var _opponent_hand_list: VBoxContainer = $UI/HUD/MainVBox/HandsContainer/OpponentHandPanel/OpponentHandList
@onready var _summary_panel: Panel = $UI/HUD/MainVBox/SummaryPanel
@onready var _summary_label: RichTextLabel = $UI/HUD/MainVBox/SummaryPanel/SummaryLabel
@onready var _match_end_dialog: MatchEndDialog = $UI/MatchEndDialog

var _current_phase: Phase = Phase.DRAW
var _current_round: int = 1
var _player_score: int = 0
var _opponent_score: int = 0
var _player_deck: Array = []
var _opponent_deck: Array = []
var _player_hand: Array = []
var _opponent_hand: Array = []
var _player_selected_card: Dictionary = {}
var _opponent_selected_card: Dictionary = {}
var _player_selected_card_index: int = -1
var _opponent_selected_card_index: int = -1
var _player_selected_tactic: Tactic = null
var _opponent_selected_tactic: Tactic = null
var _player_energy: int = 0
var _opponent_energy: int = 0
var _available_tactics: Array = []
var _rng := RandomNumberGenerator.new()
var _ai_brain: AIBrain = null
var _player_rounds_won: int = 0
var _opponent_rounds_won: int = 0
var _player_cards_played: int = 0
var _opponent_cards_played: int = 0
var _player_tactics_used: int = 0
var _opponent_tactics_used: int = 0
var _player_energy_spent_total: float = 0.0
var _opponent_energy_spent_total: float = 0.0
var _rounds_played: int = 0

func _ready() -> void:
    _rng.randomize()
    AIBrain.register_project_settings()
    _ai_brain = AIBrain.new()
    if ai_debug_logging:
        _ai_brain.debug_enabled = true
    else:
        ai_debug_logging = _ai_brain.debug_enabled
    _phase_timer.timeout.connect(_on_phase_timer_timeout)
    _announcement_timer.timeout.connect(_on_announcement_timer_timeout)
    _load_tactics()
    _prepare_default_decks()
    start_match()

func start_match() -> void:
    _current_phase = Phase.DRAW
    _current_round = 1
    _player_score = 0
    _opponent_score = 0
    _player_energy = player_energy_max
    _opponent_energy = opponent_energy_max
    _player_rounds_won = 0
    _opponent_rounds_won = 0
    _player_cards_played = 0
    _opponent_cards_played = 0
    _player_tactics_used = 0
    _opponent_tactics_used = 0
    _player_energy_spent_total = 0
    _opponent_energy_spent_total = 0
    _rounds_played = 0
    _player_selected_card_index = -1
    _opponent_selected_card_index = -1
    _player_selected_tactic = null
    _opponent_selected_tactic = null
    _player_selected_card = {}
    _opponent_selected_card = {}
    _summary_panel.visible = false
    _summary_label.text = ""
    _clear_hand_ui()
    _update_scoreboard()
    _update_energy_display()
    _update_phase_label("Draw Phase")
    if _match_end_dialog:
        _match_end_dialog.hide()
    _start_phase(Phase.DRAW)

func _prepare_default_decks() -> void:
    if _player_deck.is_empty():
        _player_deck = DeckManager.get_player_deck()
    if _opponent_deck.is_empty():
        _opponent_deck = DeckManager.get_opponent_deck()

func _load_tactics() -> void:
    _available_tactics.clear()
    var dir := DirAccess.open("res://tactics")
    if dir:
        dir.list_dir_begin()
        var file_name := dir.get_next()
        while file_name != "":
            if !dir.current_is_dir() and file_name.to_lower().ends_with(".tres"):
                var path := "res://tactics/%s" % file_name
                var resource := ResourceLoader.load(path)
                if resource is Tactic:
                    _available_tactics.append(resource.duplicate(true))
            file_name = dir.get_next()
        dir.list_dir_end()
    _available_tactics.sort_custom(self, "_sort_tactics")

func _sort_tactics(a: Tactic, b: Tactic) -> bool:
    if a.energy_cost == b.energy_cost:
        return a.tactic_name < b.tactic_name
    return a.energy_cost < b.energy_cost

func _start_phase(phase: Phase) -> void:
    _current_phase = phase
    match phase:
        Phase.DRAW:
            _begin_draw_phase()
        Phase.TACTIC_SELECTION:
            _begin_tactic_phase()
        Phase.RESOLUTION:
            _begin_resolution_phase()
        Phase.CLEANUP:
            _begin_cleanup_phase()
        Phase.COMPLETE:
            _complete_match()

func _begin_draw_phase() -> void:
    _announce_phase("Draw Phase")
    _refresh_energy_pools()
    _player_selected_card = {}
    _opponent_selected_card = {}
    _player_selected_tactic = null
    _opponent_selected_tactic = null
    _player_selected_card_index = -1
    _opponent_selected_card_index = -1
    _clear_hand_ui()
    _draw_hands()
    _build_player_hand_ui()
    _build_opponent_hand_ui()
    _update_player_hand_ui()
    _update_opponent_hand_ui()
    _phase_timer.start(draw_duration)

func _begin_tactic_phase() -> void:
    _announce_phase("Tactic Selection")
    _phase_timer.start(tactic_duration)
    _select_ai_tactic()

func _begin_resolution_phase() -> void:
    _announce_phase("Resolution")
    var result := _calculate_round_result(
        _player_selected_card,
        _opponent_selected_card,
        _player_selected_tactic,
        _opponent_selected_tactic
    )
    _player_score += int(result["player_score"])
    _opponent_score += int(result["opponent_score"])
    _update_scoreboard()
    _summary_label.text = result["summary"]
    _summary_panel.visible = true
    _record_round_stats(result)
    _phase_timer.start(resolution_duration)

func _begin_cleanup_phase() -> void:
    _announce_phase("Cleanup Phase")
    _player_hand.clear()
    _opponent_hand.clear()
    _clear_hand_ui()
    _summary_panel.visible = false
    _phase_timer.start(cleanup_duration)

func _complete_match() -> void:
    _current_phase = Phase.COMPLETE
    _phase_timer.stop()
    var verdict := ""
    if _player_score > _opponent_score:
        verdict = "[color=green][b]Victory![/b][/color]"
    elif _player_score < _opponent_score:
        verdict = "[color=red][b]Defeat[/b][/color]"
    else:
        verdict = "[color=yellow][b]Draw[/b][/color]"

    var summary := "[center][b]Match Complete[/b][/center]\n"
    summary += "[center]Player %d - %d Opponent[/center]\n" % [_player_score, _opponent_score]
    summary += "[center]%s[/center]" % verdict
    _summary_label.text = summary
    _summary_panel.visible = true
    _announce_phase("Match Complete")
    _show_match_end_dialog(verdict)

func _advance_phase() -> void:
    match _current_phase:
        Phase.DRAW:
            _start_phase(Phase.TACTIC_SELECTION)
        Phase.TACTIC_SELECTION:
            _ensure_tactics_selected()
            _start_phase(Phase.RESOLUTION)
        Phase.RESOLUTION:
            _start_phase(Phase.CLEANUP)
        Phase.CLEANUP:
            _current_round += 1
            if _current_round > total_rounds:
                _start_phase(Phase.COMPLETE)
            else:
                _update_scoreboard()
                _start_phase(Phase.DRAW)
        Phase.COMPLETE:
            pass

func _draw_hands() -> void:
    _player_hand = _draw_cards_from_deck(_player_deck, 3)
    _opponent_hand = _draw_cards_from_deck(_opponent_deck, 3)

func _draw_cards_from_deck(deck: Array, count: int) -> Array:
    var cards: Array = []
    for _i in range(count):
        if deck.is_empty():
            break
        cards.append(deck[_rng.randi_range(0, deck.size() - 1)])
    return cards

func player_choose_card(index: int, tactic: Tactic = null) -> void:
    if _current_phase != Phase.TACTIC_SELECTION:
        return
    if index < 0 or index >= _player_hand.size():
        return
    if !_set_player_selection(index, tactic):
        return
    _select_ai_tactic()
    if auto_resolve_on_timeout:
        _phase_timer.stop()
        _advance_phase()

func _on_player_card_selected(index: int, tactic: Tactic) -> void:
    player_choose_card(index, tactic)

func _set_player_selection(index: int, tactic: Tactic) -> bool:
    if index < 0 or index >= _player_hand.size():
        return false
    var previous_cost := _player_selected_tactic.energy_cost if _player_selected_tactic else 0
    var available_energy := min(player_energy_max, _player_energy + previous_cost)
    if tactic and tactic.energy_cost > available_energy:
        return false
    _player_energy = available_energy - (tactic.energy_cost if tactic else 0)
    _player_selected_card = _player_hand[index]
    _player_selected_card_index = index
    _player_selected_tactic = tactic
    _update_player_hand_ui()
    _update_energy_display()
    return true

func _select_ai_tactic() -> Dictionary:
    if _ai_brain == null:
        return {}
    if _opponent_hand.is_empty():
        _opponent_selected_card = {}
        _opponent_selected_tactic = null
        _opponent_selected_card_index = -1
        return {}

    var previous_cost := _opponent_selected_tactic.energy_cost if _opponent_selected_tactic else 0
    var available_energy := min(opponent_energy_max, _opponent_energy + previous_cost)
    var had_previous := _opponent_selected_card_index >= 0
    var decision := _ai_brain.choose_play(
        _opponent_hand,
        available_energy,
        opponent_energy_max,
        _available_tactics,
        Callable(self, "_evaluate_option"),
        _player_selected_card,
        {
            "current_index": _opponent_selected_card_index,
            "previous_tactic": _opponent_selected_tactic,
            "round": _current_round,
            "phase": _current_phase,
            "player_selection": _player_selected_card
        }
    )
    _log_ai_decision(decision)

    var index := int(decision.get("index", -1))
    var tactic: Tactic = decision.get("tactic", null)

    if !_set_opponent_selection(index, tactic):
        if tactic and _set_opponent_selection(index, null):
            if ai_debug_logging:
                var card_name := _opponent_hand[index].get("name", "Opponent Card") if index >= 0 and index < _opponent_hand.size() else "Opponent Card"
                print("[AI] Fallback to balanced play for %s due to energy limits" % card_name)
        elif index >= 0 and index < _opponent_hand.size():
            if !_set_opponent_selection(index, null) and !had_previous:
                _clear_opponent_selection()
        elif !had_previous:
            _clear_opponent_selection()
    return _opponent_selected_card

func _clear_opponent_selection() -> void:
    _opponent_selected_card = {}
    _opponent_selected_tactic = null
    _opponent_selected_card_index = -1
    _update_opponent_hand_ui()
    _update_energy_display()

func _log_ai_decision(decision: Dictionary) -> void:
    if !ai_debug_logging or decision.is_empty():
        return
    var phase_names := Phase.keys()
    var phase_name := String(_current_phase)
    if _current_phase >= 0 and _current_phase < phase_names.size():
        phase_name = String(phase_names[_current_phase])
    var header := "[AI] Decision for round %d phase %s" % [_current_round, phase_name]
    print(header)
    var log_lines: Array = decision.get("log", [])
    for line in log_lines:
        print("[AI]   %s" % line)
    var chosen_index := int(decision.get("index", -1))
    if chosen_index >= 0 and chosen_index < _opponent_hand.size():
        var card := _opponent_hand[chosen_index]
        var tactic: Tactic = decision.get("tactic", null)
        var tactic_name := tactic.tactic_name if tactic else "Balanced Play"
        print("[AI] -> Selected %s with %s" % [card.get("name", "Opponent Card"), tactic_name])
    else:
        print("[AI] -> No valid selection")

func _set_opponent_selection(index: int, tactic: Tactic) -> bool:
    if index < 0 or index >= _opponent_hand.size():
        return false
    var previous_cost := _opponent_selected_tactic.energy_cost if _opponent_selected_tactic else 0
    var available_energy := min(opponent_energy_max, _opponent_energy + previous_cost)
    if tactic and tactic.energy_cost > available_energy:
        return false
    _opponent_energy = available_energy - (tactic.energy_cost if tactic else 0)
    _opponent_selected_card = _opponent_hand[index]
    _opponent_selected_card_index = index
    _opponent_selected_tactic = tactic
    _update_opponent_hand_ui()
    _update_energy_display()
    return true

func _ensure_tactics_selected() -> void:
    if (_player_selected_card.is_empty() or _player_selected_card_index < 0) and !_player_hand.is_empty():
        _auto_select_player_option()
    _select_ai_tactic()

func _auto_select_player_option() -> void:
    if _player_hand.is_empty():
        return
    var available_energy := min(player_energy_max, _player_energy + (_player_selected_tactic.energy_cost if _player_selected_tactic else 0))
    var best_index := 0
    var best_tactic: Tactic = null
    var best_score := -INF

    for i in range(_player_hand.size()):
        var card := _player_hand[i]
        var baseline := _evaluate_option(card, null, _opponent_selected_card)
        if baseline > best_score:
            best_score = baseline
            best_index = i
            best_tactic = null
        for tactic in _available_tactics:
            if tactic.energy_cost > available_energy:
                continue
            var value := _evaluate_option(card, tactic, _opponent_selected_card)
            if value > best_score:
                best_score = value
                best_index = i
                best_tactic = tactic
    _set_player_selection(best_index, best_tactic)
    _select_ai_tactic()

func _calculate_round_result(player_card: Dictionary, opponent_card: Dictionary, player_tactic: Tactic, opponent_tactic: Tactic) -> Dictionary:
    var safe_player := player_card if !player_card.is_empty() else _empty_card("No Play")
    var safe_opponent := opponent_card if !opponent_card.is_empty() else _empty_card("No Play")

    var player_effect := _resolve_tactic_effect(player_tactic, safe_player, safe_opponent)
    var opponent_effect := _resolve_tactic_effect(opponent_tactic, safe_opponent, safe_player)

    var player_modified := _apply_card_modifiers(safe_player, player_effect.get("self_modifiers", {}))
    player_modified = _apply_card_modifiers(player_modified, opponent_effect.get("opponent_modifiers", {}))

    var opponent_modified := _apply_card_modifiers(safe_opponent, opponent_effect.get("self_modifiers", {}))
    opponent_modified = _apply_card_modifiers(opponent_modified, player_effect.get("opponent_modifiers", {}))

    var player_power := _score_card(player_modified)
    var opponent_power := _score_card(opponent_modified)
    var player_delta := 0
    var opponent_delta := 0
    var detail := ""

    var diff := player_power - opponent_power
    if diff > 8:
        player_delta = 3
        detail = "%s overwhelms %s" % [safe_player.get("name"), safe_opponent.get("name")]
    elif diff > 3:
        player_delta = 2
        opponent_delta = 0
        detail = "%s edges %s" % [safe_player.get("name"), safe_opponent.get("name")]
    elif diff < -8:
        opponent_delta = 3
        detail = "%s shuts down %s" % [safe_opponent.get("name"), safe_player.get("name")]
    elif diff < -3:
        opponent_delta = 2
        detail = "%s outplays %s" % [safe_opponent.get("name"), safe_player.get("name")]
    else:
        player_delta = 1
        opponent_delta = 1
        detail = "%s battles %s to a draw" % [safe_player.get("name"), safe_opponent.get("name")]

    player_delta += int(player_effect.get("self_score_bonus", 0))
    player_delta += int(opponent_effect.get("opponent_score_bonus", 0))
    opponent_delta += int(opponent_effect.get("self_score_bonus", 0))
    opponent_delta += int(player_effect.get("opponent_score_bonus", 0))

    player_delta = max(player_delta, 0)
    opponent_delta = max(opponent_delta, 0)

    var summary := "[center][b]%s[/b] vs [b]%s[/b][/center]\n" % [safe_player.get("name"), safe_opponent.get("name")]
    summary += "[center]Power %.1f - %.1f[/center]\n" % [player_power, opponent_power]
    summary += "[center]%s[/center]" % detail

    var tactic_lines: Array[String] = []
    if player_tactic:
        var player_text := "Player uses %s" % player_tactic.tactic_name
        var player_detail := String(player_effect.get("summary", ""))
        if player_detail != "":
            player_text += ": %s" % player_detail
        tactic_lines.append("[color=#6cc070]%s[/color]" % player_text)
    elif String(player_effect.get("summary", "")) != "":
        tactic_lines.append("[color=#6cc070]%s[/color]" % player_effect.get("summary"))

    if opponent_tactic:
        var opponent_text := "Opponent uses %s" % opponent_tactic.tactic_name
        var opponent_detail := String(opponent_effect.get("summary", ""))
        if opponent_detail != "":
            opponent_text += ": %s" % opponent_detail
        tactic_lines.append("[color=#ff7b6b]%s[/color]" % opponent_text)
    elif String(opponent_effect.get("summary", "")) != "":
        tactic_lines.append("[color=#ff7b6b]%s[/color]" % opponent_effect.get("summary"))

    if !tactic_lines.is_empty():
        summary += "\n"
        for line in tactic_lines:
            summary += "[center]%s[/center]\n" % line
        summary = summary.rstrip("\n")

    return {
        "player_score": player_delta,
        "opponent_score": opponent_delta,
        "summary": summary
    }

func _score_card(card: Dictionary) -> float:
    if card.is_empty():
        return 0.0
    var attack := float(card.get("attack", 0))
    var defense := float(card.get("defense", 0))
    var pace := float(card.get("pace", 0))
    var control := float(card.get("control", 0))
    return attack * 1.1 + defense * 0.9 + pace * 0.7 + control * 0.5

func _update_scoreboard() -> void:
    _player_score_label.text = str(_player_score)
    _opponent_score_label.text = str(_opponent_score)
    _round_label.text = "Round %d / %d" % [_current_round, total_rounds]

func _update_energy_display() -> void:
    _player_energy_bar.max_value = player_energy_max
    _player_energy_bar.value = _player_energy
    _player_energy_text.text = "%d/%d" % [_player_energy, player_energy_max]
    _opponent_energy_bar.max_value = opponent_energy_max
    _opponent_energy_bar.value = _opponent_energy
    _opponent_energy_text.text = "%d/%d" % [_opponent_energy, opponent_energy_max]

func _refresh_energy_pools() -> void:
    if _current_round == 1:
        _player_energy = player_energy_max
        _opponent_energy = opponent_energy_max
    else:
        _player_energy = min(player_energy_max, _player_energy + energy_refresh_per_round)
        _opponent_energy = min(opponent_energy_max, _opponent_energy + energy_refresh_per_round)
    _update_energy_display()

func _build_player_hand_ui() -> void:
    _clear_container(_player_hand_list)
    for i in range(_player_hand.size()):
        var card := _player_hand[i]
        var hand_card: Control = HandCardScene.instantiate()
        var options := _available_tactics.duplicate()
        options.insert(0, null)
        hand_card.set_card(i, card, options, _player_energy)
        hand_card.card_selected.connect(_on_player_card_selected)
        hand_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        _player_hand_list.add_child(hand_card)

func _build_opponent_hand_ui() -> void:
    _clear_container(_opponent_hand_list)
    for card in _opponent_hand:
        var label := Label.new()
        var base_text := card.get("name", "Opponent Card")
        label.text = base_text
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.set_meta("base_text", base_text)
        label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.85))
        _opponent_hand_list.add_child(label)

func _clear_hand_ui() -> void:
    _clear_container(_player_hand_list)
    _clear_container(_opponent_hand_list)

func _clear_container(container: Node) -> void:
    for child in container.get_children():
        child.queue_free()

func _update_player_hand_ui() -> void:
    for child in _player_hand_list.get_children():
        if child.has_method("get_card_index"):
            var is_selected := child.get_card_index() == _player_selected_card_index
            if child.has_method("set_selected"):
                child.set_selected(is_selected)
            if child.has_method("update_energy"):
                child.update_energy(_player_energy)

func _update_opponent_hand_ui() -> void:
    var children := _opponent_hand_list.get_children()
    for i in range(children.size()):
        var label := children[i]
        if !(label is Label):
            continue
        var base_text := label.get_meta("base_text", label.text)
        if i == _opponent_selected_card_index:
            var tactic_name := _opponent_selected_tactic.tactic_name if _opponent_selected_tactic else "Balanced Play"
            label.text = "%s\n[%s]" % [base_text, tactic_name]
            label.self_modulate = Color(1, 0.85, 0.85, 1)
        else:
            label.text = base_text
            label.self_modulate = Color(0.9, 0.85, 0.85, 1)

func _resolve_tactic_effect(tactic: Tactic, self_card: Dictionary, opponent_card: Dictionary) -> Dictionary:
    if tactic == null:
        return {
            "self_modifiers": {},
            "opponent_modifiers": {},
            "self_score_bonus": 0,
            "opponent_score_bonus": 0,
            "summary": ""
        }
    var effect := tactic.apply(self_card, opponent_card)
    if effect == null:
        effect = {}
    if !effect.has("self_modifiers"):
        effect["self_modifiers"] = {}
    if !effect.has("opponent_modifiers"):
        effect["opponent_modifiers"] = {}
    if !effect.has("self_score_bonus"):
        effect["self_score_bonus"] = 0
    if !effect.has("opponent_score_bonus"):
        effect["opponent_score_bonus"] = 0
    if !effect.has("summary"):
        effect["summary"] = ""
    return effect

func _apply_card_modifiers(card: Dictionary, modifiers: Dictionary) -> Dictionary:
    if modifiers.is_empty():
        return card
    var result := card.duplicate(true)
    var stat_keys := ["attack", "defense", "pace", "control"]
    for key in stat_keys:
        if modifiers.has(key):
            var base_value := float(result.get(key, 0))
            var delta := float(modifiers.get(key, 0))
            result[key] = max(0, base_value + delta)
    return result

func _evaluate_option(card: Dictionary, tactic: Tactic, opposing_card: Dictionary) -> float:
    var safe_self := card if !card.is_empty() else _empty_card("No Play")
    var safe_opponent := opposing_card if !opposing_card.is_empty() else _empty_card("No Play")
    var effect := _resolve_tactic_effect(tactic, safe_self, safe_opponent)
    var modified_self := _apply_card_modifiers(safe_self, effect.get("self_modifiers", {}))
    var modified_opponent := _apply_card_modifiers(safe_opponent, effect.get("opponent_modifiers", {}))
    var advantage := _score_card(modified_self) - _score_card(modified_opponent)
    advantage += float(effect.get("self_score_bonus", 0)) - float(effect.get("opponent_score_bonus", 0))
    return advantage

func _empty_card(name: String) -> Dictionary:
    return {
        "name": name,
        "attack": 0,
        "defense": 0,
        "pace": 0,
        "control": 0
    }

func _announce_phase(text: String) -> void:
    _announcement_label.text = text
    _announcement_label.modulate = Color(1, 1, 1, 0)
    var fade_in := create_tween()
    fade_in.tween_property(_announcement_label, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
    _announcement_timer.start(1.5)
    _update_phase_label(text)

func _update_phase_label(text: String) -> void:
    _phase_label.text = text

func _on_phase_timer_timeout() -> void:
    if _current_phase == Phase.COMPLETE:
        return
    if _current_phase == Phase.TACTIC_SELECTION:
        _ensure_tactics_selected()
    _advance_phase()

func _on_announcement_timer_timeout() -> void:
    var fade_out := create_tween()
    fade_out.tween_property(_announcement_label, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)

func _record_round_stats(result: Dictionary) -> void:
    _rounds_played += 1
    var player_delta := int(result.get("player_score", 0))
    var opponent_delta := int(result.get("opponent_score", 0))
    if player_delta > opponent_delta:
        _player_rounds_won += 1
    elif opponent_delta > player_delta:
        _opponent_rounds_won += 1
    if !_player_selected_card.is_empty():
        _player_cards_played += 1
    if !_opponent_selected_card.is_empty():
        _opponent_cards_played += 1
    if _player_selected_tactic:
        _player_tactics_used += 1
        _player_energy_spent_total += _player_selected_tactic.energy_cost
    if _opponent_selected_tactic:
        _opponent_tactics_used += 1
        _opponent_energy_spent_total += _opponent_selected_tactic.energy_cost

func _show_match_end_dialog(verdict: String) -> void:
    if _match_end_dialog == null:
        return
    var rewards := _calculate_rewards()
    _match_end_dialog.show_summary({
        "player_score": _player_score,
        "opponent_score": _opponent_score,
        "rounds_played": _rounds_played,
        "player_rounds_won": _player_rounds_won,
        "opponent_rounds_won": _opponent_rounds_won,
        "player_cards_played": _player_cards_played,
        "opponent_cards_played": _opponent_cards_played,
        "player_tactics_used": _player_tactics_used,
        "opponent_tactics_used": _opponent_tactics_used,
        "player_energy_spent": _player_energy_spent_total,
        "opponent_energy_spent": _opponent_energy_spent_total,
        "verdict": verdict,
        "rewards": rewards
    })

func _calculate_rewards() -> Dictionary:
    var rewards := {}
    var base_coins := max(0, _player_score - _opponent_score) * 25 + _player_rounds_won * 10
    if base_coins > 0:
        rewards["coins"] = base_coins
    var majority := int((total_rounds + 1) / 2)
    if _player_score > _opponent_score and _player_rounds_won >= majority:
        rewards["card_packs"] = 1
    return rewards
