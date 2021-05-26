Group Bulletin Board

GBB verschafft Überblick zu den endlosen Anfragen in den chat channels. Es erkennt alle Anfragen zu den klassischen Instanzen, sortiert sie und stellt sie übersichtlich da. Zahlreiche Filtermöglichkeiten reduziert die gigantische Anzahl auf genau die Instanzen, die dich interessieren. Und falls das nicht reicht, informiert GBB dich über jede neue Anfrage mittels eines Sounds oder Chat-Benachrichtigung. Und abschließend kann GBB deine Anfrage wiederholt veröffentlichen.
Aktuell wird Englisch, Deutsch und Russisch unterstützt, aber man kann GBB an jede Sprache einfach anpassen.

Benutzung:
GBB durchsucht im Hintergrund die Chat-Nachrichten nach Instanz-Anfragen. Um eine Person anzuflüstern, einfach den Eintrag mit links anklicken. Für ein "/who" genügt ein Shift + links klick. Die Instanz-Liste lässt sich in den Einstellungen filtern. Zudem kann man mit einen Linksklick auf den Instanz-Namen diesen falten.
Alte Einträge werden nach 150 Sekunden rausgefiltert.

Befehle:
<value> kann true,1,enable,false,0,disable sein. Wird <value> weggelassen, schaltet der aktuelle Status um.
/gbb notify chat <value> - Bei neuer Anfrage eine Nachricht senden
/gbb notify sound <value> - Bei neuer Anfrage ein Geräusch abspielen
/gbb debug <value> - Debug-Informationen anzeigen
/gbb reset - Hauptfenster zurücksetzen
/gbb config/setup/options - Konfiguration öffnen
/gbb about - 'Über' öffnen
/gbb help - Hilfe anzeigen
/gbb - Hauptfenster öffnen

Credits:
Hubbotu und kavarus für die russische Übersetzung
Baudzilla für die Grafiken/Idee des resize-code

Changelog
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
