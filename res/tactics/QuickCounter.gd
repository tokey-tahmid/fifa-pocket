extends Tactic

func _init() -> void:
    tactic_name = "Quick Counter"
    description = "Sit back then explode forward using pace to catch defenders out."
    energy_cost = 4

func apply(self_card: Dictionary, opponent_card: Dictionary) -> Dictionary:
    var pace_bonus := clamp(int(self_card.get("pace", 0) / 7), 2, 7)
    var control_penalty := -2
    var opponent_rattled := opponent_card.get("defense", 0) < 80
    return {
        "self_modifiers": {
            "pace": pace_bonus + 5,
            "attack": 4,
            "control": control_penalty
        },
        "opponent_modifiers": opponent_rattled ? {"defense": -5, "control": -2} : {"defense": -2},
        "self_score_bonus": opponent_rattled ? 1 : 0,
        "opponent_score_bonus": 0,
        "summary": "Quick Counter unleashes explosive transitions to punish exposed defenses."
    }
