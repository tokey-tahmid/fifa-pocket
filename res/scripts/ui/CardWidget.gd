extends PanelContainer
class_name CardWidget

signal card_flipped(is_front: bool)

@export var interactive: bool = true
@export var hover_scale: float = 1.05
@export var hover_duration: float = 0.15
@export var flip_duration: float = 0.24
@export var selected_tint: Color = Color(0.85, 1.0, 0.85)
@export var deselected_tint: Color = Color(1, 1, 1)

var _card_data: Dictionary = {}
var _is_front: bool = true
var _hover_tween: Tween
var _flip_tween: Tween
var _selection_tween: Tween
var _is_selected: bool = false

@onready var _front_panel: Panel = $MarginContainer/CardStack/FrontPanel
@onready var _back_panel: Panel = $MarginContainer/CardStack/BackPanel
@onready var _name_label: Label = $MarginContainer/CardStack/FrontPanel/VBoxContainer/NameLabel
@onready var _position_label: Label = $MarginContainer/CardStack/FrontPanel/VBoxContainer/MetaRow/PositionLabel
@onready var _rarity_label: Label = $MarginContainer/CardStack/FrontPanel/VBoxContainer/MetaRow/RarityLabel
@onready var _stat_attack: Label = $MarginContainer/CardStack/FrontPanel/VBoxContainer/StatsGrid/AttackValue
@onready var _stat_defense: Label = $MarginContainer/CardStack/FrontPanel/VBoxContainer/StatsGrid/DefenseValue
@onready var _stat_pace: Label = $MarginContainer/CardStack/FrontPanel/VBoxContainer/StatsGrid/PaceValue
@onready var _stat_control: Label = $MarginContainer/CardStack/FrontPanel/VBoxContainer/StatsGrid/ControlValue
@onready var _footer_label: Label = $MarginContainer/CardStack/FrontPanel/VBoxContainer/FooterLabel
@onready var _back_summary: RichTextLabel = $MarginContainer/CardStack/BackPanel/MarginContainer/BackSummary

func _ready() -> void:
    set_card({})
    _update_interactive_state()
    pivot_offset = size * 0.5
    resized.connect(_on_size_changed)

func set_card(card_data: Dictionary) -> void:
    _card_data = card_data.duplicate(true)
    if _card_data.is_empty():
        _apply_empty_state()
    else:
        _apply_card_state()
    show_front(true, true)

func get_card() -> Dictionary:
    return _card_data.duplicate(true)

func show_front(front: bool, instant: bool = false) -> void:
    if front == _is_front and !instant:
        return
    _is_front = front
    if instant:
        scale = Vector2.ONE
        _front_panel.visible = _is_front
        _back_panel.visible = !_is_front
        card_flipped.emit(_is_front)
        return
    _play_flip_animation()

func flip() -> void:
    show_front(!_is_front)

func trigger_hover(active: bool) -> void:
    if !_can_animate():
        return
    if _hover_tween and _hover_tween.is_running():
        _hover_tween.kill()
    var target := Vector2.ONE
    if active:
        target = Vector2(hover_scale, hover_scale)
    _hover_tween = create_tween()
    _hover_tween.tween_property(self, "scale", target, hover_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func set_selected(selected: bool) -> void:
    _is_selected = selected
    var target_color := selected_tint if selected else deselected_tint
    if _selection_tween and _selection_tween.is_running():
        _selection_tween.kill()
    _selection_tween = create_tween()
    _selection_tween.tween_property(self, "self_modulate", target_color, 0.12)

func set_interactive(value: bool) -> void:
    interactive = value
    _update_interactive_state()

func _update_interactive_state() -> void:
    if interactive:
        mouse_filter = Control.MOUSE_FILTER_STOP
        if !mouse_entered.is_connected(_on_mouse_entered):
            mouse_entered.connect(_on_mouse_entered)
        if !mouse_exited.is_connected(_on_mouse_exited):
            mouse_exited.connect(_on_mouse_exited)
    else:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        if mouse_entered.is_connected(_on_mouse_entered):
            mouse_entered.disconnect(_on_mouse_entered)
        if mouse_exited.is_connected(_on_mouse_exited):
            mouse_exited.disconnect(_on_mouse_exited)

func _apply_empty_state() -> void:
    _name_label.text = "Empty Slot"
    _position_label.text = "--"
    _rarity_label.text = ""
    _stat_attack.text = "-"
    _stat_defense.text = "-"
    _stat_pace.text = "-"
    _stat_control.text = "-"
    _footer_label.text = "Drag a card to assign"
    _back_summary.text = "[center]No card information available.[/center]"

func _apply_card_state() -> void:
    var name := String(_card_data.get("name", "Unknown"))
    var position := String(_card_data.get("position", "--"))
    var rarity := String(_card_data.get("rarity", "Common"))
    var club := String(_card_data.get("club", ""))
    var nation := String(_card_data.get("nation", ""))
    _name_label.text = name
    _position_label.text = position
    _rarity_label.text = rarity
    _stat_attack.text = str(int(_card_data.get("attack", 0)))
    _stat_defense.text = str(int(_card_data.get("defense", 0)))
    _stat_pace.text = str(int(_card_data.get("pace", 0)))
    _stat_control.text = str(int(_card_data.get("control", 0)))
    var rating := _estimate_power_rating(_card_data)
    var footer_parts := []
    if club != "":
        footer_parts.append(club)
    if nation != "":
        footer_parts.append(nation)
    footer_parts.append("Power %.1f" % rating)
    _footer_label.text = " • ".join(footer_parts)
    var details := "[center][b]%s[/b][/center]" % name
    var meta_line := _build_meta_line(position, rarity)
    if meta_line != "":
        details += "\n[center]%s[/center]" % meta_line
    if club != "" or nation != "":
        var origin_parts := []
        if club != "":
            origin_parts.append("Club: %s" % club)
        if nation != "":
            origin_parts.append("Nation: %s" % nation)
        details += "\n[center]%s[/center]" % " • ".join(origin_parts)
    details += "\n\nPower Rating: %.1f" % _estimate_power_rating(_card_data)
    _back_summary.text = details

func _estimate_power_rating(card: Dictionary) -> float:
    var attack := float(card.get("attack", 0))
    var defense := float(card.get("defense", 0))
    var pace := float(card.get("pace", 0))
    var control := float(card.get("control", 0))
    return attack * 1.1 + defense * 0.9 + pace * 0.7 + control * 0.5

func _build_meta_line(position: String, rarity: String) -> String:
    var meta_parts := []
    if position != "":
        meta_parts.append(position)
    if rarity != "":
        meta_parts.append(rarity)
    if meta_parts.is_empty():
        return ""
    return " • ".join(meta_parts)

func _play_flip_animation() -> void:
    if !_can_animate():
        _front_panel.visible = _is_front
        _back_panel.visible = !_is_front
        card_flipped.emit(_is_front)
        return
    if _flip_tween and _flip_tween.is_running():
        _flip_tween.kill()
    var first_half := flip_duration * 0.5
    _flip_tween = create_tween()
    _flip_tween.set_trans(Tween.TRANS_CUBIC)
    _flip_tween.set_ease(Tween.EASE_IN_OUT)
    _flip_tween.tween_property(self, "scale", Vector2(0.0, 1.0), first_half)
    _flip_tween.tween_callback(_toggle_face)
    _flip_tween.tween_property(self, "scale", Vector2.ONE, first_half)

func _toggle_face() -> void:
    _front_panel.visible = _is_front
    _back_panel.visible = !_is_front
    card_flipped.emit(_is_front)

func _can_animate() -> bool:
    return is_inside_tree()

func _gui_input(event: InputEvent) -> void:
    if !interactive:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
        flip()

func _on_mouse_entered() -> void:
    trigger_hover(true)

func _on_mouse_exited() -> void:
    trigger_hover(false)

func _on_size_changed() -> void:
    pivot_offset = size * 0.5
    if !_can_animate():
        scale = Vector2.ONE
