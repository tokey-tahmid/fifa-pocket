extends Control

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

@onready var _phase_timer: Timer = $PhaseTimer
@onready var _announcement_timer: Timer = $AnnouncementTimer
@onready var _announcement_label: Label = $UI/HUD/PhaseAnnouncement
@onready var _player_score_label: Label = $UI/HUD/Scoreboard/PlayerScore
@onready var _opponent_score_label: Label = $UI/HUD/Scoreboard/OpponentScore
@onready var _round_label: Label = $UI/HUD/Scoreboard/RoundLabel
@onready var _summary_panel: Panel = $UI/HUD/SummaryPanel
@onready var _summary_label: RichTextLabel = $UI/HUD/SummaryPanel/SummaryLabel

var _current_phase: Phase = Phase.DRAW
var _current_round: int = 1
var _player_score: int = 0
var _opponent_score: int = 0
var _player_deck: Array = []
var _opponent_deck: Array = []
var _player_hand: Array = []
var _opponent_hand: Array = []
var _player_selected_card: Dictionary
var _opponent_selected_card: Dictionary
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()
    _phase_timer.timeout.connect(_on_phase_timer_timeout)
    _announcement_timer.timeout.connect(_on_announcement_timer_timeout)
    _prepare_default_decks()
    start_match()

func start_match() -> void:
    _current_phase = Phase.DRAW
    _current_round = 1
    _player_score = 0
    _opponent_score = 0
    _summary_panel.visible = false
    _summary_label.text = ""
    _update_scoreboard()
    _start_phase(Phase.DRAW)

func _prepare_default_decks() -> void:
    if _player_deck.is_empty():
        _player_deck = [
            {"name": "Clinical Striker", "attack": 88, "defense": 30, "pace": 86, "control": 80},
            {"name": "Box To Box", "attack": 78, "defense": 72, "pace": 79, "control": 82},
            {"name": "Creative Winger", "attack": 82, "defense": 40, "pace": 90, "control": 85},
            {"name": "Anchor Man", "attack": 65, "defense": 88, "pace": 68, "control": 74},
            {"name": "Sweeper Keeper", "attack": 50, "defense": 92, "pace": 60, "control": 77}
        ]
    if _opponent_deck.is_empty():
        _opponent_deck = [
            {"name": "Target Forward", "attack": 84, "defense": 36, "pace": 72, "control": 78},
            {"name": "Regista", "attack": 75, "defense": 70, "pace": 74, "control": 90},
            {"name": "Wing Back", "attack": 70, "defense": 76, "pace": 88, "control": 72},
            {"name": "Destroyer", "attack": 60, "defense": 91, "pace": 65, "control": 68},
            {"name": "Shot Stopper", "attack": 48, "defense": 94, "pace": 58, "control": 70}
        ]

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
    _draw_hands()
    _phase_timer.start(draw_duration)

func _begin_tactic_phase() -> void:
    _announce_phase("Tactic Selection")
    _player_selected_card = {}
    _opponent_selected_card = {}
    _phase_timer.start(tactic_duration)

func _begin_resolution_phase() -> void:
    _announce_phase("Resolution")
    var result := _calculate_round_result(_player_selected_card, _opponent_selected_card)
    _player_score += int(result["player_score"])
    _opponent_score += int(result["opponent_score"])
    _update_scoreboard()
    _summary_label.text = result["summary"]
    _summary_panel.visible = true
    _phase_timer.start(resolution_duration)

func _begin_cleanup_phase() -> void:
    _announce_phase("Cleanup Phase")
    _player_hand.clear()
    _opponent_hand.clear()
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

func player_choose_card(index: int) -> void:
    if _current_phase != Phase.TACTIC_SELECTION:
        return
    if index < 0 or index >= _player_hand.size():
        return

    _player_selected_card = _player_hand[index]
    _opponent_selected_card = _opponent_selected_card if !_opponent_selected_card.is_empty() else _select_ai_tactic()

    if auto_resolve_on_timeout:
        _phase_timer.stop()
        _advance_phase()

func _select_ai_tactic() -> Dictionary:
    if _opponent_hand.is_empty():
        return {}
    var best_card := _opponent_hand[0]
    var best_score := _score_card(best_card)
    for card in _opponent_hand:
        var value := _score_card(card)
        if value > best_score:
            best_score = value
            best_card = card
    return best_card

func _ensure_tactics_selected() -> void:
    if _player_selected_card.is_empty() and !_player_hand.is_empty():
        _player_selected_card = _player_hand[_rng.randi_range(0, _player_hand.size() - 1)]
    if _opponent_selected_card.is_empty():
        _opponent_selected_card = _select_ai_tactic()

func _calculate_round_result(player_card: Dictionary, opponent_card: Dictionary) -> Dictionary:
    var safe_player := player_card if !player_card.is_empty() else {"name": "No Play", "attack": 0, "defense": 0, "pace": 0, "control": 0}
    var safe_opponent := opponent_card if !opponent_card.is_empty() else {"name": "No Play", "attack": 0, "defense": 0, "pace": 0, "control": 0}

    var player_power := _score_card(safe_player)
    var opponent_power := _score_card(safe_opponent)
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

    var summary := "[center][b]%s[/b] vs [b]%s[/b][/center]\n" % [safe_player.get("name"), safe_opponent.get("name")]
    summary += "[center]Power %.1f - %.1f[/center]\n" % [player_power, opponent_power]
    summary += "[center]%s[/center]" % detail

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
    _player_score_label.text = "Player %d" % _player_score
    _opponent_score_label.text = "Opponent %d" % _opponent_score
    _round_label.text = "Round %d" % _current_round

func _announce_phase(text: String) -> void:
    _announcement_label.text = text
    _announcement_label.modulate = Color(1, 1, 1, 0)
    var fade_in := create_tween()
    fade_in.tween_property(_announcement_label, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
    _announcement_timer.start(1.5)

func _on_phase_timer_timeout() -> void:
    if _current_phase == Phase.COMPLETE:
        return
    if _current_phase == Phase.TACTIC_SELECTION:
        _ensure_tactics_selected()
    _advance_phase()

func _on_announcement_timer_timeout() -> void:
    var fade_out := create_tween()
    fade_out.tween_property(_announcement_label, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
