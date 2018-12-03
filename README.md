# NES for [MiSTer](https://github.com/MiSTer-devel/Main_MiSTer/wiki) 

### This is an FPGA implementation of the NES/Famicom based on [FPGANES](https://github.com/strigeus/fpganes) by Ludvig Strigeus and ported to MiSTer.

## Features
 * Supports saves for most ROM games (FDS saves not currently supported)
 * FDS Support
 * Multiple Palette options
 * Supports expansion audio from FDS and special mappers
 * Supports many popular mappers including VRC6-7, MMC0-5, and UNROM 512

## Installation
Copy the NES_\*.rbf file to the root of the SD card. Create a **NES** folder on the root of the card, and place NES roms (\*.NES) inside this folder. The ROMs must have an iNES or NES2.0 header, which most already do. NES2.0 headers are prefered for the best accuracy. To have a game ROM load automatically upon starting the core, rename it **boot.rom** and place it in the **NES** folder.

### Famicom Disk System Usage
Before loading \*.FDS files, first you must load the official, unpatched FDS BIOS. The BIOS file you obtain may be named with a \*.NES extension, in which case you must rename it to have a \*.BIN extension before being able to use it. After loading the bios you may select an FDS image. By default, the NES core will swap disk sides for you automatically. To suppress this behavior, hold the SELECT button on the player 1 controller. Currently, saves are not supported for FDS games.

## Saving and Loading
The battery backed RAM (Save RAM) for the NES does not write to disk automatically. When loading a game, you must select **Load Backup RAM** from the OSD menu. After saving in your game, you must then write the RAM to the SD card by selecting **Save Backup RAM** from the menu. If you do not save your RAM to disk, the contents will be lost next time you restart the core or switch games.

## Supported Mappers

|#||||||||||||||||
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|**0**|**1**|**2**|**3**|**4**|**5**||**7**||**9**|**10**|**11**|~~12~~|**13**||**15**|
|**16**||**18**|**19**|**FDS**|~~21~~|~~22~~|~~23~~|**24**|~~25~~|**26**||**28**||**30**||
|**32**|**33**|**34**||~~36~~|**37**|**38**||~~40~~|**41**|**42**|~~43~~|~~44~~|~~45~~|~~46~~|**47**|
|**48**|~~49~~|~~50~~|~~51~~|~~52~~|~~53~~|~~54~~|~~55~~|~~56~~|~~57~~|~~58~~|~~59~~|~~60~~|~~61~~|~~62~~|~~63~~|
|**64**|~~65~~|**66**|~~67~~|**68**|**69**|**70**|**71**|~~72~~|~~73~~|~~74~~|**75**|**76**|~~77~~|**78**|**79**|
|**80**|~~81~~|**82**|~~83~~|~~84~~|**85**|~~86~~|**87**|**88**|**89**|~~90~~|~~91~~|~~92~~|**93**|~~94~~|**95**|
|~~96~~|~~97~~||~~99~~|~~100~~|**101**|||~~104~~|**105**||~~107~~|~~108~~|~~109~~|~~110~~|~~111~~|
|~~112~~|**113**|~~114~~|~~115~~|~~116~~|~~117~~|**118**|**119**|~~120~~||~~122~~|~~123~~||~~125~~|~~126~~|~~127~~|
|~~128~~|~~129~~|~~130~~|~~131~~|~~132~~|~~133~~|~~134~~|~~135~~||~~137~~|~~138~~|~~139~~|**140**|~~141~~|~~142~~|~~143~~|
|~~144~~|~~145~~|~~146~~|~~147~~|~~148~~|~~149~~|~~150~~|~~151~~|**152**|~~153~~|**154**|~~155~~|~~156~~|~~157~~|**158**|~~159~~|
|~~160~~|~~161~~|~~162~~|~~163~~|~~164~~|**165**|~~166~~|~~167~~|~~168~~|~~169~~|||||||
|||||~~180~~|~~181~~|~~182~~|~~183~~|**184**|~~185~~|~~186~~|~~187~~|~~188~~|~~189~~|~~190~~|~~191~~|
|~~192~~|~~193~~|~~194~~||~~196~~||~~198~~|~~199~~|~~200~~|~~201~~|~~202~~|~~203~~|~~204~~|~~205~~|**206**|**207**|
|~~208~~|~~209~~|~~210~~|~~211~~|~~212~~|~~213~~|~~214~~|~~215~~|~~216~~|~~217~~|||||~~222~~||
|~~224~~|~~225~~|~~226~~|~~227~~|**228**|~~229~~|~~230~~|~~231~~|**232**|~~233~~|**234**|~~235~~|~~236~~|~~237~~|||
|~~240~~|~~241~~|~~242~~|~~243~~|~~244~~|~~245~~|~~246~~||~~248~~|~~249~~|~~250~~|~~251~~|~~252~~||~~254~~|~~255~~|

Key: **Supported**, ~~Not Supported~~. Mappers that are not existent or not useful are blank.

