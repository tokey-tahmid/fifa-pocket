extends Tactic

func _init() -> void:
    tactic_name = "High Press"
    description = "Sacrifice defensive shape to overwhelm with relentless pressure."
    energy_cost = 3

func apply(self_card: Dictionary, opponent_card: Dictionary) -> Dictionary:
    var pressure_bonus := clamp(int(self_card.get("pace", 0) / 8), 1, 6)
    var fatigue_penalty := 2
    return {
        "self_modifiers": {
            "attack": pressure_bonus + 6,
            "defense": -fatigue_penalty,
            "control": 2
        },
        "opponent_modifiers": {
            "defense": -3
        },
        "self_score_bonus": 0,
        "opponent_score_bonus": 0,
        "summary": "High Press increases attacking threat at the cost of backline stability."
    }
