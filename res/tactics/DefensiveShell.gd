extends Tactic

func _init() -> void:
    tactic_name = "Defensive Shell"
    description = "Pull everyone behind the ball to absorb pressure and strike carefully."
    energy_cost = 2

func apply(self_card: Dictionary, opponent_card: Dictionary) -> Dictionary:
    var structure_bonus := clamp(int(self_card.get("defense", 0) / 10), 1, 5)
    return {
        "self_modifiers": {
            "defense": structure_bonus + 6,
            "control": 3
        },
        "opponent_modifiers": {
            "attack": -4
        },
        "self_score_bonus": 1,
        "opponent_score_bonus": 0,
        "summary": "Defensive Shell bolsters the back line and frustrates opposing attacks."
    }
