extends Resource
class_name Tactic

@export var tactic_name: String = ""
@export var description: String = ""
@export var energy_cost: int = 0

## Returns a dictionary describing how this tactic modifies the match up.
## Keys:
##  - self_modifiers: Dictionary of stat deltas applied to the card using the tactic
##  - opponent_modifiers: Dictionary of stat deltas applied to the opposing card
##  - self_score_bonus: Integer bonus added to the tactic owner's score delta
##  - opponent_score_bonus: Integer bonus added to the opposing score delta
##  - summary: Optional string describing the effect for UI summaries
func apply(self_card: Dictionary, opponent_card: Dictionary) -> Dictionary:
    return {
        "self_modifiers": {},
        "opponent_modifiers": {},
        "self_score_bonus": 0,
        "opponent_score_bonus": 0,
        "summary": ""
    }
