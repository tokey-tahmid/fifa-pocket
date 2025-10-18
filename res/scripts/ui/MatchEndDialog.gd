extends AcceptDialog
class_name MatchEndDialog

@onready var _score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var _verdict_label: RichTextLabel = $MarginContainer/VBoxContainer/VerdictLabel
@onready var _rounds_label: Label = $MarginContainer/VBoxContainer/RoundsLabel
@onready var _player_rounds_value: Label = $MarginContainer/VBoxContainer/StatsGrid/PlayerRoundsValue
@onready var _opponent_rounds_value: Label = $MarginContainer/VBoxContainer/StatsGrid/OpponentRoundsValue
@onready var _player_cards_value: Label = $MarginContainer/VBoxContainer/StatsGrid/PlayerCardsValue
@onready var _opponent_cards_value: Label = $MarginContainer/VBoxContainer/StatsGrid/OpponentCardsValue
@onready var _player_tactics_value: Label = $MarginContainer/VBoxContainer/StatsGrid/PlayerTacticsValue
@onready var _opponent_tactics_value: Label = $MarginContainer/VBoxContainer/StatsGrid/OpponentTacticsValue
@onready var _player_energy_value: Label = $MarginContainer/VBoxContainer/StatsGrid/PlayerEnergyValue
@onready var _opponent_energy_value: Label = $MarginContainer/VBoxContainer/StatsGrid/OpponentEnergyValue
@onready var _rewards_label: Label = $MarginContainer/VBoxContainer/RewardsPanel/RewardsValue

func show_summary(data: Dictionary) -> void:
    var player_score := int(data.get("player_score", 0))
    var opponent_score := int(data.get("opponent_score", 0))
    var rounds_played := int(data.get("rounds_played", 0))
    _score_label.text = "Player %d - %d Opponent" % [player_score, opponent_score]
    var verdict_text := String(data.get("verdict", ""))
    _verdict_label.bbcode_text = verdict_text
    _rounds_label.text = "Rounds played: %d" % rounds_played
    _player_rounds_value.text = str(int(data.get("player_rounds_won", 0)))
    _opponent_rounds_value.text = str(int(data.get("opponent_rounds_won", 0)))
    _player_cards_value.text = str(int(data.get("player_cards_played", 0)))
    _opponent_cards_value.text = str(int(data.get("opponent_cards_played", 0)))
    _player_tactics_value.text = str(int(data.get("player_tactics_used", 0)))
    _opponent_tactics_value.text = str(int(data.get("opponent_tactics_used", 0)))
    _player_energy_value.text = "%.0f" % float(data.get("player_energy_spent", 0))
    _opponent_energy_value.text = "%.0f" % float(data.get("opponent_energy_spent", 0))
    _rewards_label.text = _format_rewards(data.get("rewards", {}))
    get_ok_button().text = "Close"
    popup_centered()

func _format_rewards(rewards: Dictionary) -> String:
    if rewards.is_empty():
        return "No rewards this time."
    var lines: Array = []
    for key in rewards.keys():
        var value: Variant = rewards[key]
        if value is Array:
            var names: Array[String] = []
            for entry in value:
                names.append(String(entry))
            lines.append("%s: %s" % [_beautify_label(String(key)), ", ".join(names)])
        else:
            lines.append("%s: %s" % [_beautify_label(String(key)), str(value)])
    lines.sort()
    return "\n".join(lines)

func _beautify_label(raw: String) -> String:
    var parts := raw.replace("_", " ").split(" ")
    for i in range(parts.size()):
        parts[i] = parts[i].capitalize()
    return " ".join(parts)
