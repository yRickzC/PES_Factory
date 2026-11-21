class_name ActorStateMachine
extends RefCounted
## One state and clock per actor, including single impacts and active attack windows.

signal impacted(action: EquipmentAction)
signal impact_window(action: EquipmentAction, from_time: float, to_time: float)

enum State { IDLE, WALK, ATTACK, WANDER, FORAGE, FLEE, DEAD, RUN }

var state := State.IDLE
var elapsed := 0.0
var action: EquipmentAction
var attack_direction := Vector3.ZERO
var _locomotion := State.IDLE
var _impact_emitted := false
var _cooldown := 0.0
var _hitstop_remaining := 0.0


func start_attack(next_action: EquipmentAction, direction := Vector3.ZERO) -> bool:
	if state == State.ATTACK or in_hitstop() or _cooldown > 0.0 or next_action == null or next_action.duration <= 0.0:
		return false
	action = next_action
	attack_direction = direction
	_cooldown = next_action.cooldown
	_impact_emitted = false
	transition_to(State.ATTACK)
	return true


func stop_for(seconds: float) -> void:
	_hitstop_remaining = maxf(_hitstop_remaining, seconds)


func in_hitstop() -> bool:
	return _hitstop_remaining > 0.0


func consume_hitstop(delta: float) -> bool:
	if not in_hitstop():
		return false
	_hitstop_remaining = maxf(0.0, _hitstop_remaining - delta)
	return true


func clear_hitstop() -> void:
	_hitstop_remaining = 0.0


func movement_scale() -> float:
	return action.movement_scale if action != null else 1.0


func advance(delta: float, moving: bool, sprinting := false) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_locomotion = State.IDLE
	if moving:
		_locomotion = State.RUN if sprinting else State.WALK
	if state != State.ATTACK:
		transition_to(_locomotion)
		if state == State.WALK or state == State.RUN:
			elapse(delta)
		return
	var active := action
	var previous := elapsed
	elapsed = minf(elapsed + delta, active.duration)
	if not _impact_emitted and elapsed >= active.impact_time():
		_impact_emitted = true
		impacted.emit(active)
	if state == State.ATTACK and action == active:
		var first := maxf(previous, active.impact_time())
		var last := minf(elapsed, active.impact_end_time())
		if last > first:
			impact_window.emit(active, first, last)
		if state == State.ATTACK and action == active and elapsed >= active.duration:
			cancel_attack()


func cancel_attack() -> void:
	if state == State.ATTACK:
		transition_to(_locomotion)


func elapse(delta: float) -> void:
	elapsed += delta


func transition_to(next_state: State, restart := false) -> void:
	if state != next_state or restart:
		if state == State.ATTACK and next_state != State.ATTACK:
			action = null
			attack_direction = Vector3.ZERO
		state = next_state
		elapsed = 0.0
