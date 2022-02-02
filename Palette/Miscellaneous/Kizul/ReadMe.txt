Just in case it isn't obvious how these palette files are meant to be used:

* Kizul's Definitive NTSC NES Master Palette (canonical off-blacks).pal
* Kizul's Definitive NTSC NES Master Palette (pure blacks).pal
	For use with most games.
	    If black seems to be washed out when using the "canonical off-blacks"
	version of this palette, use the "pure blacks" version.

* Kizul's Definitive NTSC NES Master Palette - for Bee 52 and The Immortal.pal
	For use primarily with Bee 52 (and other Camerica/Codemasters games).
	    This palette changes the brightness of the palette indices $1D, $xE, and $xF,
	emulating the effect that Bee 52 exploits and allowing various background details
	in the game to show up correctly.
	    The canon brightness for all blacks (except $0D) is slightly-lighter-than-
	pure-black (this palette uses RGB 16,16,16 for it). Bee 52 uses $0D -- which is
	effectively pure black -- for the outlines of sprites and for the main background
	color in night-time levels.
	On a CRT television, if most of the screen is filled with the $0D black, the TV
	will usually try to brighten the screen until $0D is off-black. This brightening
	causes the other colors -- the other off-blacks, in particular -- to become brighter
	than normal, resulting in an extra shade of gray.
	    This trick is exploited by Bee 52 and especially The Immortal. There may be
	other NES games that use this trick, but I don't know of any others.

* Kizul's Definitive NTSC NES Master Palette - for The Immortal (with Color Emphasis disabled).pal
	For use exclusively with The Immortal, combined with the following Game Genie
	codes:
		GEOATSKV -- Color Emphasis (C.E.) disabled at Title screen, and
			    during narration.
		GPOEGSKN -- C.E. disabled in battles.
		GPVEASKN -- C.E. disabled on Items menu, password screen, and
			    conversations.
		GOUEYNKN -- C.E. disabled while walking around.

	The Immortal uses a feature of the NES hardware called "Color Emphasis", which
	can be used to tint most of the palette -- specifically the range of $x0 to $xD,
	which includes the Whites, all of the colors, and the first column of blacks --
	by dimming out unwanted shades. (If you set the Red C.E. bit to On, and the others
	to be Off, the NES would output less Green and Blue in its video signal, making
	the palette appear to be tinted red.)
	    The Immortal, however, sets all three Color Emphasis bits to On, making the
	52 affected colors dimmer than usual.
	In addition, it also uses $0D (the darkest black) for the background color
	everywhere, and it appears on the screen in large amounts -- which, on a CRT TV's
	screen, makes $xE and $xF appear much brighter than usual.
	    $1D (which is usually the same brightness as $xE and $xF) is affected by this
	trick as well, but since it's also being affected by the Color Emphasis, it's
	only very slightly brighter than normal.

	You can also use the "~ for Bee 52" palette with The Immortal if your emulator
	has settings for controlling the brightness. I use NEStopia, and have found that
	increasing the brightness to 0.12 while using the "~ for Bee 52" palette is
	very close to reality.
	
	---
	
	https://procyon.com/~kizul/nes_files/screenshot_gallery/