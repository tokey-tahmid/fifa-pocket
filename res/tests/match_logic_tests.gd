extends Node

const MatchController := preload("res://scripts/MatchController.gd")
const Tactic := preload("res://tactics/BaseTactic.gd")

class MockTactic extends Tactic:
    var _self_modifiers: Dictionary
    var _opponent_modifiers: Dictionary
    var _self_bonus: int
    var _opponent_bonus: int
    var _summary: String

    func _init(name: String, modifiers_self: Dictionary, modifiers_opponent: Dictionary, self_bonus: int = 0, opponent_bonus: int = 0, summary: String = "") -> void:
        tactic_name = name
        _self_modifiers = modifiers_self.duplicate(true)
        _opponent_modifiers = modifiers_opponent.duplicate(true)
        _self_bonus = self_bonus
        _opponent_bonus = opponent_bonus
        _summary = summary

    func apply(self_card: Dictionary, opponent_card: Dictionary) -> Dictionary:
        return {
            "self_modifiers": _self_modifiers,
            "opponent_modifiers": _opponent_modifiers,
            "self_score_bonus": _self_bonus,
            "opponent_score_bonus": _opponent_bonus,
            "summary": _summary
        }

func _create_card(name: String, attack: int, defense: int, pace: int, control: int) -> Dictionary:
    return {
        "name": name,
        "attack": attack,
        "defense": defense,
        "pace": pace,
        "control": control
    }

func test_stronger_card_scores_three_points() -> void:
    var controller := MatchController.new()
    var striker := _create_card("Star Striker", 90, 82, 88, 76)
    var defender := _create_card("Reserve Defender", 40, 35, 30, 28)
    var result := controller._calculate_round_result(striker, defender, null, null)
    assert(result.get("player_score", 0) == 3)
    assert(result.get("opponent_score", 0) == 0)

func test_tactic_modifiers_shift_advantage() -> void:
    var controller := MatchController.new()
    var balanced := _create_card("Balanced Mid", 70, 70, 70, 70)
    var disruptor := _create_card("Disruptor", 72, 68, 72, 68)
    var counter_tactic := MockTactic.new("High Press", {"attack": 5, "pace": 4}, {"control": -6})
    var stall_tactic := MockTactic.new("Time Waste", {}, {"pace": -10}, 0, 1)
    var result := controller._calculate_round_result(balanced, disruptor, counter_tactic, stall_tactic)
    assert(result.get("player_score", 0) > result.get("opponent_score", 0))

func test_score_card_accounts_for_modifiers() -> void:
    var controller := MatchController.new()
    var base_card := _create_card("Playmaker", 60, 65, 62, 80)
    var modified := controller._apply_card_modifiers(base_card, {"attack": 10, "defense": -5, "control": 5})
    var base_score := controller._score_card(base_card)
    var modified_score := controller._score_card(modified)
    assert(modified_score > base_score)
