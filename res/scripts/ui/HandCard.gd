extends PanelContainer

signal card_selected(card_index: int, tactic: Tactic)

var _card_index: int = -1
var _card_data: Dictionary = {}
var _tactics: Array = []
var _current_energy: int = 0
var _is_selected: bool = false
var _scale_tween: Tween = null

@onready var _card_widget: CardWidget = $HBoxContainer/CardDisplay
@onready var _tactic_selector: OptionButton = $HBoxContainer/ControlPanel/TacticSelector
@onready var _status_label: Label = $HBoxContainer/ControlPanel/StatusLabel
@onready var _play_button: Button = $HBoxContainer/ControlPanel/PlayButton
@onready var _energy_hint: Label = $HBoxContainer/ControlPanel/EnergyHint
@onready var _selection_particles: GPUParticles2D = $SelectionBurst

func set_card(card_index: int, card_data: Dictionary, tactics: Array, current_energy: int) -> void:
    _card_index = card_index
    _card_data = card_data.duplicate(true)
    _tactics = tactics.duplicate()
    if _tactics.is_empty():
        _tactics.append(null)
    _card_widget.set_card(_card_data)
    _populate_tactics()
    set_selected(false)
    update_energy(current_energy)

func update_energy(current_energy: int) -> void:
    _current_energy = current_energy
    _energy_hint.text = "Available energy: %d" % _current_energy
    _update_play_state()

func set_selected(selected: bool) -> void:
    var changed := _is_selected != selected
    _is_selected = selected
    self_modulate = selected ? Color(0.85, 1.0, 0.9, 1.0) : Color(1, 1, 1, 1)
    _card_widget.set_selected(selected)
    if changed:
        _animate_selection(selected)
    if selected and _status_label.text == "":
        _status_label.text = "Selected"

func _populate_tactics() -> void:
    _tactic_selector.clear()
    for i in range(_tactics.size()):
        var tactic: Tactic = _tactics[i]
        var label := "Balanced Play (0 EN)"
        var tooltip := "Stick to the player's natural strengths."
        if tactic:
            label = "%s (%d EN)" % [tactic.tactic_name, tactic.energy_cost]
            tooltip = tactic.description
        _tactic_selector.add_item(label, i)
        _tactic_selector.set_item_tooltip(i, tooltip)
    _tactic_selector.select(0)
    _status_label.text = ""

func _get_selected_tactic() -> Tactic:
    if _tactics.is_empty():
        return null
    var selected := _tactic_selector.get_selected_id()
    if selected < 0 or selected >= _tactics.size():
        selected = 0
    return _tactics[selected]

func _on_PlayButton_pressed() -> void:
    var tactic := _get_selected_tactic()
    if tactic and tactic.energy_cost > _current_energy:
        _status_label.text = "Need %d EN" % tactic.energy_cost
        return
    emit_signal("card_selected", _card_index, tactic)

func _on_TacticSelector_item_selected(_index: int) -> void:
    _update_play_state()

func _update_play_state() -> void:
    var tactic := _get_selected_tactic()
    var cost := tactic.energy_cost if tactic else 0
    var affordable := cost <= _current_energy
    _play_button.disabled = !affordable
    if affordable:
        _status_label.text = _is_selected ? "Selected" : ""
    else:
        _status_label.text = "Need %d EN" % cost

func get_card_index() -> int:
    return _card_index

func play_selection_feedback() -> void:
    _animate_selection(true)
    if _selection_particles:
        _selection_particles.restart()
        _selection_particles.emitting = true

func _animate_selection(selected: bool) -> void:
    if _scale_tween and _scale_tween.is_running():
        _scale_tween.kill()
    var target_scale := selected ? Vector2(1.04, 1.04) : Vector2.ONE
    _scale_tween = create_tween()
    _scale_tween.set_trans(Tween.TRANS_QUAD)
    _scale_tween.set_ease(selected ? Tween.EASE_OUT : Tween.EASE_IN)
    _scale_tween.tween_property(self, "scale", target_scale, selected ? 0.25 : 0.2)
    if selected:
        _scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
