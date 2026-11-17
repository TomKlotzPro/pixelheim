extends Player
## A hero never built or stepped (PIX-499): what a test stands where the
## world's `player` is read, now that the type says `Player`. No sprite, no
## body's shape, no keys; a test sets what its subject reads and overrides
## what it calls. A stand-in extends it by its path:
## `class StubHero extends "res://test/bare_hero.gd"`.


func _ready() -> void:
	pass


func _physics_process(_delta: float) -> void:
	pass


func _unhandled_input(_event: InputEvent) -> void:
	pass
