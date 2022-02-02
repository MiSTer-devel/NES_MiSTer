Just in case it isn't obvious how these palette files are meant to be used:

* Kizul's Definitive NES Palette.pal
	For use with most games.
	    If your emulator of choice is NEStopia (either the original, or the
	"Undead Edition"), and you're attempting to play The Immortal, increase the
	Brightness setting (Options > Video... > Brightness slider) to 0.31. Elsewise,
	the game will be much too dark.

	(Sadly, the Linux versions of NEStopia "Undead Edition" don't seem to have an
	option for choosing a custom palette file.)

* Kizul's Definitive NES Palette - for Bee 52.pal
	For use primarily with Bee 52 (and other Camerica/Codemasters games).
	    This palette changes the brightness of a specific palette index ($1D) to be
	a little brighter than indices $xE and $xF, emulating the canon effect that Bee
	52 exploits and allowing various background details in the game to show up
	correctly.
	    The canon brightness for all blacks (except $0D) is slightly-lighter-than-
	pure-black (this palette uses RGB 20,20,20 for it); however, $0D is DARKER than
	all of the other blacks, so when a CRT screen is filled with $0D, the CRT TV
	will generally attempt to brighten the screen until the abundance of $0D matches
	the brightness that the other blacks are normally, thus changing $0D from RGB
	0,0,0 to RGB 20,20,20.
	    This has an exploited side-effect of ALSO brightening the other blacks to a
	shade of charcoal gray, though this trick is exploited exclusively (to the best
	of my knowledge) by Bee 52 and The Immortal (The Immortal's title screen, that
	is), and no other games.

* Kizul's Definitive NES Palette - for The Immortal with Color Emphasis disabled.pal
	For use exclusively with The Immortal, combined with the following Game Genie
	codes:
		GEOATSKV -- Color Emphasis (C.E.) disabled at Title screen, and
			    during narration.
		GPOEGSKN -- C.E. disabled in battles.
		GPVEASKN -- C.E. disabled on Items menu, password screen, and
			    conversations.
		GOUEYNKN -- C.E. disabled while walking around.