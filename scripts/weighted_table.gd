class_name WeightedTable
extends RefCounted
# Wraps a weighted random table with pseudo-random compensation.
# Items that appear less often than their target probability get a boost;
# items that appear too often get a penalty. This smooths variance within a session.

var _entries: Array[Dictionary] = []   # [{key, scene, target_weight}]
var _counts: Dictionary = {}           # {key: int}
var _total_count: int = 0
var _compensation_strength: float = 0.5


func init(table: Array[Dictionary], key_func: Callable, compensation_strength: float = 0.5) -> void:
    _compensation_strength = compensation_strength
    _entries.clear()
    _counts.clear()
    _total_count = 0
    for entry in table:
        var key: String = key_func.call(entry.scene)
        var e := {
            "key": key,
            "scene": entry.scene,
            "target_weight": entry.weight,
        }
        _entries.append(e)
        _counts[key] = 0


func pick_and_record() -> PackedScene:
    var scene: PackedScene = _pick()
    _record(_key_for(scene))
    return scene


func reset() -> void:
    for key in _counts:
        _counts[key] = 0
    _total_count = 0


func _key_for(scene: PackedScene) -> String:
    for e in _entries:
        if e.scene == scene:
            return e.key
    return ""


func _pick() -> PackedScene:
    # Compute sum of target weights.
    var target_total := 0.0
    for e in _entries:
        target_total += e.target_weight
    if target_total <= 0.0:
        return _entries[0].scene

    # Compute adjusted weight for each entry.
    var n := _entries.size()
    var adjusted: Array[float] = []
    var adj_total := 0.0
    for i in n:
        var entry := _entries[i]
        var expected: float = entry.target_weight / target_total
        var actual: float = expected
        if _total_count > 0:
            actual = float(_counts[entry.key]) / float(_total_count)
        var deviation: float = expected - actual
        var adj: float = entry.target_weight * (1.0 + deviation * _compensation_strength)
        adj = clampf(adj, 0.01, target_total)
        adjusted.append(adj)
        adj_total += adj

    # Roll and select.
    var roll := randf() * adj_total
    var acc := 0.0
    for i in n:
        acc += adjusted[i]
        if roll <= acc:
            return _entries[i].scene
    return _entries[-1].scene


func _record(key: String) -> void:
    if _counts.has(key):
        _counts[key] += 1
        _total_count += 1
