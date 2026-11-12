extends GutHookScript
## Every test reads English (PIX-195): the game follows the system's
## language, and a French machine would otherwise translate what the tests
## compare word for word. And every test has the game's keys bound, as
## world.gd binds them when the game starts (PIX-454): a screen's keys are
## actions (`interact`, `menu`) that exist only once Controls.apply made
## them, so a file pressing E passed in the suite only after another file
## had bound them, and failed run alone.


func run() -> void:
	Text.apply("en")
	Controls.apply({})
