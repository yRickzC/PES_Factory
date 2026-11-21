class_name HitFeedback
extends RefCounted
## The actor applies this response to accepted damage through its normal collider.

var _impulse := Vector3.ZERO
var _duration := 0.0
var _remaining := 0.0


func receive(profile: HitFeedbackProfile, machine: ActorStateMachine, direction: Vector3) -> void:
	machine.stop_for(profile.hitstop_seconds)
	var planar := Vector3(direction.x, 0.0, direction.z)
	if not planar.is_zero_approx() and profile.knockback_speed > 0.0 and profile.knockback_seconds > 0.0:
		_impulse = planar.normalized() * profile.knockback_speed
		_duration = profile.knockback_seconds
		_remaining = _duration


func step_knockback(delta: float) -> Vector3:
	if _remaining <= 0.0 or delta <= 0.0:
		return Vector3.ZERO
	# Average the decay over the portion of this physics tick covered by the impulse.
	var active_delta := minf(delta, _remaining)
	var weight := (_remaining - active_delta * 0.5) / _duration * (active_delta / delta)
	_remaining -= active_delta
	return _impulse * weight


static func confirm(profile: HitFeedbackProfile, machine: ActorStateMachine) -> void:
	machine.stop_for(profile.hitstop_seconds)
