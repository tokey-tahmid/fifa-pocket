extends Tactic

func _init() -> void:
    tactic_name = "Quick Counter"
    description = "Sit back then explode forward using pace to catch defenders out."
    energy_cost = 4

func apply(self_card: Dictionary, opponent_card: Dictionary) -> Dictionary:
    var pace_bonus: int = clampi(int(self_card.get("pace", 0) / 7), 2, 7)
    var control_penalty: int = -2
    var opponent_rattled: bool = opponent_card.get("defense", 0) < 80
    return {
        "self_modifiers": {
            "pace": pace_bonus + 5,
            "attack": 4,
            "control": control_penalty
        },
        "opponent_modifiers": {"defense": -5, "control": -2} if opponent_rattled else {"defense": -2},
        "self_score_bonus": 1 if opponent_rattled else 0,
        "opponent_score_bonus": 0,
        "summary": "Quick Counter unleashes explosive transitions to punish exposed defenses."
    }
