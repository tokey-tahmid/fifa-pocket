extends PanelContainer

var card_data: Dictionary = {}

@onready var _name_label: Label = $HBoxContainer/Name
@onready var _meta_label: Label = $HBoxContainer/Meta

func set_card(data: Dictionary) -> void:
    card_data = data.duplicate(true)
    _name_label.text = card_data.get("name", "Unknown")
    var meta_parts: Array = []
    meta_parts.append(card_data.get("position", "--"))
    meta_parts.append(card_data.get("rarity", "Common"))
    var owned := int(card_data.get("owned_copies", 1))
    if owned > 1:
        meta_parts.append("x%d" % owned)
    _meta_label.text = " | ".join(meta_parts)

func _get_drag_data(_position: Vector2):
    if card_data.is_empty():
        return null
    set_drag_preview(_build_preview())
    return {
        "type": "card",
        "card": card_data.duplicate(true),
        "source": "library"
    }

func _build_preview() -> Control:
    var preview := VBoxContainer.new()
    preview.add_theme_constant_override("separation", 4)

    var name_label := Label.new()
    name_label.text = card_data.get("name", "")
    name_label.add_theme_color_override("font_color", Color.WHITE)
    preview.add_child(name_label)

    var stat_label := Label.new()
    stat_label.text = "ATK %d  DEF %d  PAC %d  CTRL %d" % [
        int(card_data.get("attack", 0)),
        int(card_data.get("defense", 0)),
        int(card_data.get("pace", 0)),
        int(card_data.get("control", 0))
    ]
    stat_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
    preview.add_child(stat_label)

    return preview
