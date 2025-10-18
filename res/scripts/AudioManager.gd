class_name AudioManager
extends Node

@export var music_bus: StringName = &"Music"
@export var sfx_bus: StringName = &"SFX"
@export var max_simultaneous_sfx: int = 8
@export var default_bgm: StringName = &"match"
@export var bgm_streams := {
    "match": null,
}
@export var sfx_streams := {
    "card_play": null,
    "goal_cheer": null,
    "ui_transition": null,
}

var _bgm_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
    _ensure_buses_exist()
    _create_bgm_player()
    _create_sfx_pool()

func play_bgm(name: StringName = &"match", restart: bool = false) -> void:
    var stream := _get_bgm_stream(name)
    if stream == null:
        return
    if _bgm_player == null:
        _create_bgm_player()
    if _bgm_player == null:
        return
    if _bgm_player.stream != stream or restart:
        _bgm_player.stream = stream
        _bgm_player.play()
    elif !_bgm_player.playing:
        _bgm_player.play()

func stop_bgm(fade_time: float = 0.25) -> void:
    if _bgm_player == null:
        return
    if fade_time <= 0.0:
        _bgm_player.stop()
        return
    var tween := create_tween()
    tween.tween_property(_bgm_player, "volume_db", -60.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_callback(Callable(_bgm_player, "stop"))
    tween.tween_property(_bgm_player, "volume_db", 0.0, 0.01)

func play_sfx(name: StringName) -> void:
    var stream := _get_sfx_stream(name)
    if stream == null:
        return
    var player := _get_available_sfx_player()
    if player == null:
        return
    player.stream = stream
    player.volume_db = 0.0
    player.play()

func set_music_volume_db(volume_db: float) -> void:
    if _bgm_player:
        _bgm_player.volume_db = volume_db

func set_sfx_volume_db(volume_db: float) -> void:
    for player in _sfx_players:
        player.volume_db = volume_db

func _create_bgm_player() -> void:
    if _bgm_player:
        return
    _bgm_player = AudioStreamPlayer.new()
    _bgm_player.bus = music_bus
    _bgm_player.autoplay = false
    var default_stream := _get_bgm_stream(default_bgm)
    if default_stream:
        _bgm_player.stream = default_stream
    _bgm_player.volume_db = 0.0
    add_child(_bgm_player)

func _create_sfx_pool() -> void:
    if !_sfx_players.is_empty():
        return
    for i in range(max(1, max_simultaneous_sfx)):
        var player := AudioStreamPlayer.new()
        player.bus = sfx_bus
        player.autoplay = false
        add_child(player)
        _sfx_players.append(player)

func _get_available_sfx_player() -> AudioStreamPlayer:
    for player in _sfx_players:
        if !player.playing:
            return player
    if _sfx_players.size() < max(1, max_simultaneous_sfx):
        var extra := AudioStreamPlayer.new()
        extra.bus = sfx_bus
        add_child(extra)
        _sfx_players.append(extra)
        return extra
    return null

func _get_bgm_stream(name: StringName) -> AudioStream:
    return _resolve_stream(bgm_streams.get(name))

func _get_sfx_stream(name: StringName) -> AudioStream:
    return _resolve_stream(sfx_streams.get(name))

func _resolve_stream(source) -> AudioStream:
    if source is AudioStream:
        return source
    if source is String or source is StringName:
        var path := String(source)
        if ResourceLoader.exists(path):
            var loaded := ResourceLoader.load(path)
            if loaded is AudioStream:
                return loaded
    return null

func _ensure_buses_exist() -> void:
    var audio_server := AudioServer
    if !audio_server.has_bus(music_bus):
        audio_server.add_bus(audio_server.get_bus_count())
        audio_server.set_bus_name(audio_server.get_bus_count() - 1, music_bus)
    if !audio_server.has_bus(sfx_bus):
        audio_server.add_bus(audio_server.get_bus_count())
        audio_server.set_bus_name(audio_server.get_bus_count() - 1, sfx_bus)
