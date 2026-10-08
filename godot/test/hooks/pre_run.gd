extends GutHookScript
## Every test reads English (PIX-195): the game follows the system's
## language, and a French machine would otherwise translate what the tests
## compare word for word.


func run() -> void:
	Text.apply("en")
