Group Bulletin Board

GBB provides an overview of the endless requests in the chat channels. It detects all requests to the classic dungeons, sorts them and presents them clearly way. Numerous filtering options reduce the gigantic number to exactly the dungeons that interest you. And if that's not enough, GBB will let you know about any new request via a sound or chat notification. And finally, GBB can post your request repeatedly.
Currently, English, German and Russian dungeons are recognized natively. But it is easily possible to adapt GBB to any language.

Usage
GBB searches the chat messages for dungeon requests in the background. To whisper a person, simply click on the entry with the left mouse button. For a "/who" a shift + left click is enough. The dungeon list can be filtered in the settings. You can also fold this by left-clicking on the dungeon name.
Old entries are filtered out after 150 seconds.

Slash Commands
<value> can be true, 1, enable, false, 0, disable. If <value> is omitted, the current status switches.
/gbb notify chat <value> - On new request make a chat notification
/gbb notify sound <value> - On new request make a sound notification
/gbb debug <value> - Show debug information
/gbb reset -  Reset main window position
/gbb config/setup/options - Open configuration
/gbb about - open about
/gbb help - Print help
/gbb - open main window

Credits
Hubbotu and kavarus for the russian translation
Baudzilla for the graphics/idea of the resize-code

Changelog

2.45
- Fixed a bug that was causing some issues with SM and DM 

2.44
- Added support for TBC
- New panel for classic dungeons
- TBC Dungeons are now the default panel
- Refactor code
- Lua sucks
- No support for TBC localization
- Renamed project

2.00	
- Channel-Filter
- repair priest-icon
- option "Show a fixed number of requests"
- option "Chat Style"
- About-Panel

1.90 	
- Split Filter/Settings
- Filter - (un)select all - button
- Rightclick on a filter - unselect all others
- Option "lock minimap-button position"
- Option "Minimize minimap button distance"
- Option "Guess the player level based on the dungeon request"
- Search-Engine-Optimization
- many context-menus with right click

1.83 
- dm is now default dire maul. 
- Level-Guess-System - store the level of players by recommand level of the dungeons
- improved tags 

1.82 
- dm:e should now be detected

1.81 
- fix a possible lfg-join-bug

1.8 
- compact mode for small windows
- update russian language
- improved dire maul / deathmines / dm detection
- foldable dungeon categories
- new resize method, just grab any border (graphics/idea by Baudzilla)
- show Level after /who

1.7 
- Clickabel Name-Link for the chat notification
- russian tags and dungeon names by kavarus
- redesign search-patterns / localization option pages

1.6	
- Optional show class symbols
- Support for databrocker
- move option "Debug information" to "/gbb debug"
- "/gbb reset" - reset the window-position
- redesign shout-box
- new "Dungeon" Trade
- princess run should be now in maraudon-list
- when you start a request in chat (or by announcment-tool), this dungeons will be forced to show
- Connect messages posted within 10 seconds
- tooltip redesign
- inbuild localization

1.5	
- colorize name by class
- intelligent ToolTip
- BugFixes

1.41
- possible fix for an empty scroll list
	
1.4	
- option for Replace Raid symbols, for example {rt1}
- Automatic Announcment Feature (disabled by default)
	Select the Channel, type your message and then click on "announce" - GBB will announce your message every (timeout-time) seconds
- minimum timeout for removing/announce is now 60 seconds

1.3	
- ESC-Key now close the main window
- Debug-Section does now only appear with activated option
- change method when joining lfg-channel
- new lib: Lib_GPI.Options for handling the options panel
- new lib: LIB_GPI.MinimapButton for handling the minmapbutton
- Sourcecode optimation

1.2
- optimization and new search-engine
- Add dungeon level (from https://classic.wowhead.com/guides/classic-dungeons-overview )
- Add Option "Filter on recommended level ranges"
- Add Option "Highligh dungeons on recommended level"
- Add Search-patterns-Selection (english, german, custom - multiply choice!)
- Add Options for custom search pattern (simple list, seperated by any space punctuation character)

1.1
- fix bug with badTags.

1.0 
-Inital realease
