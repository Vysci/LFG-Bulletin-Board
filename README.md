# LFG Bulletin Board

Dungeon and group request filtering

## About
LFG Bulletin Board provides an overview of the endless group requests from chat channels.
The addon collects "looking for group" advertisements as posts on a bulletin board; posts are then grouped and sorted by their associated dungeon/category.

LFG Bulletin Board has pre-set categories for all classic dungeons up to cataclysm (including Season of Discovery), with support for user defined custom categories as well ("Additional Filters" in addon settings).

![Imgur](https://i.imgur.com/MauwkSt.png)

## Features (see in-game addon settings)
- Filtering options reduce help reduce bulletin board clutter to exactly the dungeons/raids that interest you.
- Sound or chat notifications for any newly added request to filtered dungeons.
- Quickly request to join a group from the bulletin board using a templated message. (see click actions below)
- Support for browsing requests from the Blizzard Group Finder.
- Create custom filter categories for grouping messages by keyword. Useful for limited time events or niche activities.

### Category/Dungeon Header Click Actions
- `Left-Click` - Folds/Expands to hide or show the associated requests for that category.

### Request Entry Clicks Actions
- `Left-Click` - Starts a whisper message to the post author.
- `Shift + Left-Click` - Sends a "/who" request to query the author's player info.
- `Ctrl + Left-Click` - Sends a group invite to the author.
- `Alt + Left-Click` - Sends a templated message requesting to join the post author's group.

### Window Settings
_Accessed via the settings button on the main bulletin board window._
- **Lock/Unlock Window** - Allows you to move the window around by dragging the header/footer/tabs on the bulletin board.
- **Make Non-Interactive** - Enables a limited* click-through mode for the bulletin board.
  - \* Request and category names will still be interactive.
- **Opacity** - Changes the opacity of the bulletin board.
- **Tab Position** - Change the position of the tabs between the top and bottom of the main window.
  - _Accessed via a right-click tooltip menu on the tabs themselves._

### Slash Commands

**Note**: `value` can be one of - `true`, `1`, `enable`, `false`, `0`, `disable`.

(if `value` is omitted, the current status switches for any toggle like setting)

- `/gbb notify chat <value>` - On new request make a chat notification
- `/gbb notify sound <value>` - On new request make a sound notification
- `/gbb debug <value>` - Show debug information
- `/gbb reset` - Reset main window position
- `/gbb config/setup/options` - Open configuration
- `/gbb about` - open about
- `/gbb help` - Print help
- `/gbb chat organize/clean` - Creates a new chat tab if one doesn't already exist, named "LFG" with all channels subscribed. Removes LFG heavy spam channels from default chat tab
- `/gbb` - open main window

## FAQ
**How do custom language "Search Patterns" patterns work**?

![image](https://github.com/user-attachments/assets/5d3e4e45-3edf-422e-aae8-5c259d146043)
- There is a bit of confusion on how it works which leads people to believe there is a bug. However the following rules apply:
    1. **Only 1 language selected** - Will use that languages default values and ignore any custom patterns entered
    2. **Only `Custom` selected** - Will override any defaults with the custom values entered. If fields were left blank then that dungeon will have no associated patterns
    3. **Multiple languages selected** - Any colliding search patterns will be overridden by the first language selected. Enabled the "show debug information" option in the main settings to see what patterns are being prioritized.
    4.  **Languages + `Custom` selected** - this will result in using all of the languages default values AND anything that has been entered manually

## Images
Classic Era Dungeon & Raid Filters

![classic_dungeon_filters](https://i.imgur.com/kcEIY3D.png)

Additional Filters

![additional_filters](https://i.imgur.com/wCmyaw5.png)

"Request to Join" Templated Message

![request_message](https://i.imgur.com/z1JFZpN.png)
![request_message_replacements](https://i.imgur.com/dIgRxaT.png)

Window Settings

![settings_button_menu](https://i.imgur.com/0qhThzj.png)
![tab_button_menu](https://i.imgur.com/0hVTv5o.png)

## Additional Language Support

While the addon supports localization of dungeon names and other settings related labels for all game client languages, it does not have native support for the chat parsing/categorizing features.

Community contributions of default "Search Patterns" are required to really enable the chat parsing for non-english languages.

To better the support for your language please consider contributing by opening an issue at our [Github Repository](https://github.com/Vysci/LFG-Bulletin-Board/issues) with your suggested keywords.
Or considering opening a PR with the changes outright.

## Credits

Original Addon (2019-2020): https://legacy.curseforge.com/wow/addons/group-bulletin-board
