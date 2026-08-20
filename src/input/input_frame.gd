class_name InputFrame
extends RefCounted
## One frame of normalized player intent, produced by InputRouter.
## Gameplay code consumes this; it never reads touch widgets or Input directly.

var move: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO
var sprint_held: bool = false
var action_held: bool = false
var recenter_pressed: bool = false
var pause_pressed: bool = false
