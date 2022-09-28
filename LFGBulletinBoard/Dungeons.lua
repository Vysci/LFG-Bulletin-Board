local TOCNAME,GBB=...

local function getSeasonalDungeons()
    local events = {}

    for eventName, eventData in pairs(GBB.Seasonal) do
		table.insert(events, eventName)
        if GBB.Tool.InDateRange(eventData.startDate, eventData.endDate) then
			GBB.SeasonalActiveEvents[eventName] = true
        end
    end
	return events
end

function GBB.GetDungeonNames()
	local DefaultEnGB={
		["RFC"] = 	"Ragefire Chasm",
		["DM"] = 	"The Deadmines",
		["WC"] = 	"Wailing Caverns",	
		["SFK"] = 	"Shadowfang Keep",
		["STK"] = 	"The Stockade",
		["BFD"] = 	"Blackfathom Deeps",
		["GNO"] = 	"Gnomeregan",
		["RFK"] = 	"Razorfen Kraul",
		["SM2"] =	"Scarlet Monastery",
		["SMG"] = 	"Scarlet Monastery: Graveyard",
		["SML"] = 	"Scarlet Monastery: Library",
		["SMA"] = 	"Scarlet Monastery: Armory",
		["SMC"] = 	"Scarlet Monastery: Cathedral",
		["RFD"] = 	"Razorfen Downs",
		["ULD"] = 	"Uldaman",
		["ZF"] = 	"Zul'Farrak",
		["MAR"] = 	"Maraudon",
		["ST"] = 	"The Sunken Temple",
		["BRD"] = 	"Blackrock Depths",
		["DM2"] = 	"Dire Maul",
		["DME"] = 	"Dire Maul: East",
		["DMN"] = 	"Dire Maul: North",
		["DMW"] = 	"Dire Maul: West",
		["STR"] = 	"Stratholme",
		["SCH"] = 	"Scholomance",
		["LBRS"] = 	"Lower Blackrock Spire",
		["UBRS"] = 	"Upper Blackrock Spire (10)",
		["RAMPS"] = "Hellfire Citadel: Ramparts",
		["BF"] = 	"Hellfire Citadel: Blood Furnace",
		["SP"] = 	"Coilfang Reservoir: Slave Pens",
		["UB"] = 	"Coilfang Reservoir: Underbog",
		["MT"] = 	"Auchindoun: Mana Tombs",
		["CRYPTS"] = "Auchindoun: Auchenai Crypts",
		["SETH"] = 	"Auchindoun: Sethekk Halls",
		["OHB"] = 	"Caverns of Time: Old Hillsbrad",
		["MECH"] = 	"Tempest Keep: The Mechanar",
		["BM"] = 	"Caverns of Time: Black Morass",
		["MGT"] = 	"Magisters' Terrace",
		["SH"] = 	"Hellfire Citadel: Shattered Halls",
		["BOT"] = 	"Tempest Keep: Botanica",
		["SL"] = 	"Auchindoun: Shadow Labyrinth",
		["SV"] = 	"Coilfang Reservoir: Steamvault",
		["ARC"] = 	"Tempest Keep: The Arcatraz",
		["KARA"] = 	"Karazhan",
		["GL"] = 	"Gruul's Lair",
		["MAG"] = 	"Hellfire Citadel: Magtheridon's Lair",
		["SSC"] = 	"Coilfang Reservoir: Serpentshrine Cavern",

		["UK"] = 	"Utgarde Keep",
		["NEX"] = 	"The Nexus",
		["AZN"] = 	"Azjol-Nerub",
		["ANK"] = 	"Ahn’kahet: The Old Kingdom",
		["DTK"] = 	"Drak’Tharon Keep",
		["VH"] = 	"Violet Hold",
		["GD"] = 	"Gundrak",
		["HOS"] = 	"Halls of Stone",
		["HOL"] = 	"Halls of Lightning",
		["COS"] = 	"The Culling of Stratholme",
		["OCC"] = 	"The Oculus",
		["UP"] = 	"Utgarde Pinnacle",
		["FOS"] = 	"Forge of Souls",
		["POS"] = 	"Pit of Saron",
		["HOR"] = 	"Halls of Reflection",
		["CHAMP"] = "Trial of the Champion",
		["NAXX"] = 	"Naxxramas",

		["OS"]   =  "Obsidian Sanctum",
		["VOA"] = 	"Vault of Archavon",
		["EOE"] = 	"Eye of Eternity",
		["ULDAR"] =   "Ulduar",
		["TOTC"] = 	"Trial of the Crusader",
		["RS"] = 	"Ruby Sanctum",
		["ICC"] = 	"Icecrown Citadel",

		["EYE"] = 	"Tempest Keep: The Eye",
		["ZA"] = 	"Zul-Aman",
		["HYJAL"] = "The Battle For Mount Hyjal",
		["BT"] = 	"Black Temple",
		["SWP"] = 	"Sunwell Plateau",
		["ONY"] = 	"Onyxia's Lair (40)",
		["MC"] = 	"Molten Core (40)",
		["ZG"] = 	"Zul'Gurub (20)",
		["AQ20"] = 	"Ruins of Ahn'Qiraj (20)",
		["BWL"] = 	"Blackwing Lair (40)",
		["AQ40"] = 	"Temple of Ahn'Qiraj (40)",
		["NAX"] = 	"Naxxramas (40)",
		["WSG"] = 	"Warsong Gulch (PvP)",
		["AB"] = 	"Arathi Basin (PvP)",
		["AV"] = 	"Alterac Valley (PvP)",
		["EOTS"] =  "Eye of the Storm (PvP)",
		["SOTA"] =   "Stand of the Ancients (PvP)",
		["WG"]  =   "Wintergrasp (PvP)",
		["ARENA"] = "Arena (PvP)",
		["MISC"] = 	"Miscellaneous",
		["TRADE"] =	"Trade",
		["DEBUG"] = "DEBUG INFO",
		["BAD"] =	"DEBUG BAD WORDS - REJECTED",
		["BREW"] =  "Brewfest - Coren Direbrew",
		["HOLLOW"] =  "Hallow's End - Headless Horseman",
		}
		
	local dungeonNamesLocales={ 
		deDE ={
			["RFC"] = 	"Flammenschlund",
			["DM"] = 	"Die Todesminen",
			["WC"] = 	"Die Höhlen des Wehklagens",		
			["SFK"] = 	"Burg Schattenfang",
			["STK"] = 	"Das Verlies",
			["BFD"] = 	"Die Tiefschwarze Grotte",
			["GNO"] = 	"Gnomeregan",
			["RFK"] = 	"Kral der Klingenhauer",
			["SM2"] =	"Scharlachrotes Kloster",
			["SMG"] = 	"Scharlachrotes Kloster: Friedhof",
			["SML"] = 	"Scharlachrotes Kloster: Bibliothek",
			["SMA"] = 	"Scharlachrotes Kloster: Waffenkammer",
			["SMC"] = 	"Scharlachrotes Kloster: Kathedrale",
			["RFD"] = 	"Hügel der Klingenhauer",
			["ULD"] = 	"Uldaman",
			["ZF"] = 	"Zul'Farrak",
			["MAR"] = 	"Maraudon",
			["ST"] = 	"Der Tempel von Atal'Hakkar",
			["BRD"] = 	"Die Schwarzfels-Tiefen",
			["DM2"] = 	"Düsterbruch",
			["DME"] = 	"Düsterbruch: Ost",
			["DMN"] = 	"Düsterbruch: Nord",
			["DMW"] = 	"Düsterbruch: West",
			["STR"] = 	"Stratholme",
			["SCH"] = 	"Scholomance",
			["LBRS"] = 	"Die Untere Schwarzfelsspitze",
			["UBRS"] = 	"Obere Schwarzfelsspitze (10)",
			["RAMPS"] = "Höllenfeuerzitadelle: Höllenfeuerbollwerk",
			["BF"] = 	"Höllenfeuerzitadelle: Der Blutkessel",
			["SP"] = 	"Echsenkessel: Die Sklavenunterkünfte",
			["UB"] = 	"Echsenkessel: Der Tiefensumpf",
			["MT"] = 	"Auchindoun: Die Managruft",
			["CRYPTS"] = "Auchindoun: Die Auchenaikrypta",
			["SETH"] = 	"Auchindoun: Sethekkhallen",
			["OHB"] = 	"Höhlen der Zeit: Flucht von Durnholde",
			["MECH"] = 	"Festung der Stürme: Die Mechanar",
			["BM"] = 	"Höhlen der Zeit: Der Schwarze Morast",
			["MGT"] = 	"Die Terrasse der Magister",
			["SH"] = 	"Höllenfeuerzitadelle: Die Zerschmetterten Hallen",
			["BOT"] = 	"Festung der Stürme: Botanica",
			["SL"] = 	"Auchindoun: Schattenlabyrinth",
			["SV"] = 	"Echsenkessel: Die Dampfkammer",
			["ARC"] = 	"Festung der Stürme: Die Arcatraz",
			["KARA"] = 	"Karazhan",
			["GL"] = 	"Gruuls Unterschlupf",
			["MAG"] = 	"Höllenfeuerzitadelle: Magtheridons Kammer",
			["SSC"] = 	"Echsenkessel: Höhle des Schlangenschreins",
			["EYE"] = 	"Das Auge des Sturms",
			["ZA"] = 	"Zul-Aman",
			["HYJAL"] = "Schlacht um den Berg Hyjal",
			["BT"] = 	"Der Schwarze Tempel",
			["SWP"] = 	"Sonnenbrunnenplateau",
			["ONY"] = 	"Onyxias Hort (40)",
			["MC"] = 	"Geschmolzener Kern (40)",
			["ZG"] = 	"Zul'Gurub (20)",
			["AQ20"] = 	"Ruinen von Ahn'Qiraj (20)",
			["BWL"] = 	"Pechschwingenhort (40)",
			["AQ40"] = 	"Tempel von Ahn'Qiraj (40)",
			["NAX"] = 	"Naxxramas (40)",
			["WSG"] = 	"Warsongschlucht (PVP)",
			["AV"] = 	"Alteractal (PVP)",
			["AB"] = 	"Arathibecken (PVP)",
			["EOTS"] =  "Auge des Sturms (PvP)",
			["ARENA"] = "Arena (PvP)",
			["MISC"] = 	"Verschiedenes",
			["TRADE"] =	"Handel",
 
		},
		frFR ={
			["RFC"] = 	"Gouffre de Ragefeu",
			["DM"] = 	"Les Mortemines",
			["WC"] = 	"Cavernes des lamentations",	
			["SFK"] = 	"Donjon d'Ombrecroc",
			["STK"] = 	"La Prison",
			["BFD"] = 	"Profondeurs de Brassenoire",
			["GNO"] = 	"Gnomeregan",
			["RFK"] = 	"Kraal de Tranchebauge",
			["SM2"] =	"Monastère écarlate",
			["SMG"] = 	"Monastère écarlate: Cimetière",
			["SML"] = 	"Monastère écarlate: Bibliothèque",
			["SMA"] = 	"Monastère écarlate: Armurerie",
			["SMC"] = 	"Monastère écarlate: Cathédrale",
			["RFD"] = 	"Souilles de Tranchebauge",
			["ULD"] = 	"Uldaman",
			["ZF"] = 	"Zul'Farrak",
			["MAR"] = 	"Maraudon",
			["ST"] = 	"Le temple d'Atal'Hakkar",
			["BRD"] = 	"Profondeurs de Blackrock",
			["DM2"] = 	"Hache-tripes",
			["DME"] = 	"Hache-tripes: Est",
			["DMN"] = 	"Hache-tripes: Nord",
			["DMW"] = 	"Hache-tripes: Ouest",
			["STR"] = 	"Stratholme",
			["SCH"] = 	"Scholomance",
			["LBRS"] = 	"Pic Blackrock",
			["UBRS"] = 	"Pic Blackrock (10)",
			["RAMPS"] = "Citadelle des Flammes Infernales: Remparts des Flammes infernales",
			["BF"] = 	"Citadelle des Flammes Infernales: La Fournaise du sang",
			["SP"] = 	"Réservoir de Glissecroc : Les enclos aux esclaves",
			["UB"] = 	"Réservoir de Glissecroc : La Basse-tourbière",
			["MT"] = 	"Auchindoun: Tombes-mana",
			["CRYPTS"] = "Auchindoun: Cryptes Auchenaï",
			["SETH"] = 	"Auchindoun: Les salles des Sethekk",
			["OHB"] = 	"Grottes du Temps: Contreforts de Hautebrande d'antan",
			["MECH"] = 	"Donjon de la Tempête: Le Méchanar",
			["BM"] = 	"Grottes du Temps: Le Noir Marécage",
			["MGT"] = 	"Terrasse des Magistères",
			["SH"] = 	"Citadelle des Flammes Infernales: Les Salles brisées",
			["BOT"] = 	"Donjon de la Tempête: Botanica",
			["SL"] = 	"Auchindoun: Labyrinthe des ombres",
			["SV"] = 	"Réservoir de Glissecroc : Le Caveau de la vapeur",
			["ARC"] = 	"Donjon de la Tempête: L'Arcatraz",
			["KARA"] = 	"Karazhan",
			["GL"] = 	"Repaire de Gruul",
			["MAG"] = 	"Citadelle des Flammes Infernales: Le repaire de Magtheridon",
			["SSC"] = 	"Réservoir de Glissecroc : Caverne du sanctuaire du Serpent",
			["EYE"] = 	"L'Œil du cyclone",
			["ZA"] = 	"Zul-Aman",
			["HYJAL"] = "Sommet d'Hyjal",
			["BT"] = 	"Temple noir",
			["SWP"] = 	"Plateau du Puits de soleil",
			["ONY"] = 	"Repaire d'Onyxia (40)",
			["MC"] = 	"Cœur du Magma (40)",
			["ZG"] = 	"Zul'Gurub (20)",
			["AQ20"] = 	"Ruines d'Ahn'Qiraj (20)",
			["BWL"] = 	"Repaire de l'Aile noire (40)",
			["AQ40"] = 	"Ahn'Qiraj (40)",
			["NAX"] = 	"Naxxramas (40)",
			["ARENA"] = "Arena (PvP)",
		},
		esMX ={
			["RFC"] = 	"Sima Ígnea",
			["DM"] = 	"Las Minas de la Muerte",
			["WC"] = 	"Cuevas de los Lamentos",		
			["SFK"] = 	"Castillo de Colmillo Oscuro",
			["STK"] = 	"Las Mazmorras",
			["BFD"] = 	"Cavernas de Brazanegra",
			["GNO"] = 	"Gnomeregan",
			["RFK"] = 	"Horado Rajacieno",
			["SM2"] =	"Monasterio Escarlata",
			["SMG"] = 	"Monasterio Escarlata: Friedhof",
			["SML"] = 	"Monasterio Escarlata: Bibliothek",
			["SMA"] = 	"Monasterio Escarlata: Waffenkammer",
			["SMC"] = 	"Monasterio Escarlata: Kathedrale",
			["RFD"] = 	"Zahúrda Rojocieno",
			["ULD"] = 	"Uldaman",
			["ZF"] = 	"Zul'Farrak",
			["MAR"] = 	"Maraudon",
			["ST"] = 	"El Templo de Atal'Hakkar",
			["BRD"] = 	"Profundidades de Roca Negra	",
			["DM2"] = 	"La Masacre",
			["DME"] = 	"La Masacre: Ost",
			["DMN"] = 	"La Masacre: Nord",
			["DMW"] = 	"La Masacre: West",
			["STR"] = 	"Stratholme",
			["SCH"] = 	"Scholomance",
			["LBRS"] = 	"Cumbre de Roca Negra",
			["UBRS"] = 	"Cumbre de Roca Negra (10)",
			["RAMPS"] = "Hellfire Citadel: Ramparts",
			["BF"] = 	"Hellfire Citadel: Blood Furnace",
			["SP"] = 	"Coilfang Reservoir: Slave Pens",
			["UB"] = 	"Coilfang Reservoir: Underbog",
			["MT"] = 	"Auchindoun: Mana Tombs",
			["CRYPTS"] = "Auchindoun: Auchenai Crypts",
			["SETH"] = 	"Auchindoun: Sethekk Halls",
			["OHB"] = 	"Caverns of Time: Old Hillsbrad",
			["MECH"] = 	"Tempest Keep: The Mechanar",
			["BM"] = 	"Caverns of Time: Black Morass",
			["MGT"] = 	"Magisters' Terrace",
			["SH"] = 	"Hellfire Citadel: Shattered Halls",
			["BOT"] = 	"Tempest Keep: Botanica",
			["SL"] = 	"Auchindoun: Shadow Labyrinth",
			["SV"] = 	"Coilfang Reservoir: Steamvault",
			["ARC"] = 	"Tempest Keep: The Arcatraz",
			["KARA"] = 	"Karazhan",
			["GL"] = 	"Gruul's Lair",
			["MAG"] = 	"Hellfire Citadel: Magtheridon's Lair",
			["SSC"] = 	"Coilfang Reservoir: Serpentshrine Cavern",
			["EYE"] = 	"The Eye",
			["ZA"] = 	"Zul-Aman",
			["HYJAL"] = "The Battle For Mount Hyjal",
			["BT"] = 	"Black Temple",
			["SWP"] = 	"Sunwell Plateau",
			["ONY"] = 	"Guarida de Onyxia (40)",
			["MC"] = 	"Núcleo de Magma (40)",
			["ZG"] = 	"Zul'Gurub (20)",
			["AQ20"] = 	"Ruinas de Ahn'Qiraj (20)",
			["BWL"] = 	"Guarida Alanegra (40)",
			["AQ40"] = 	"Ahn'Qiraj (40)",
			["NAX"] = 	"Naxxramas (40)",
			["ARENA"] = "Arena (PvP)",

		},
		ruRU = {
			["AB"] = "Низина Арати (PvP)",
			["AQ20"] = "Руины Ан'Киража (20)",
			["AQ40"] = "Ан'Кираж (40)",
			["AV"] = "Альтеракская Долина (PvP)",
			["BAD"] = "ОТЛАДКА ПЛОХИЕ СЛОВА - ОТКЛОНЕН",
			["BFD"] = "Непроглядная Пучина",
			["BRD"] = "Глубины Черной горы",
			["BWL"] = "Логово Крыла Тьмы (40)",
			["DEBUG"] = "ИНФОРМАЦИЯ О ОТЛАДКАХ",
			["DM"] = "Мертвые копи",
			["DM2"] = "Забытый Город",
			["DME"] = "Забытый Город: Восток",
			["DMN"] = "Забытый Город: Север",
			["DMW"] = "Забытый Город: Запад",
			["GNO"] = "Гномреган",
			["LBRS"] = "Низ Вершины Черной горы",
			["MAR"] = "Мародон",
			["MC"] = "Огненные Недра (40)",
			["MISC"] = "Прочее",
			["NAX"] = "Наксрамас (40)",
			["RAMPS"] = "Цитадель Адского Пламени: Бастионы",
			["BF"] = 	"Цитадель Адского Пламени: Кузня Крови",
			["SP"] = 	"Резервуар Кривого Клыка: Узилище",
			["UB"] = 	"Резервуар Кривого Клыка: Нижетопь",
			["MT"] = 	"Аукиндон: Гробницы Маны",
			["CRYPTS"] = "Аукиндон: Аукенайские гробницы",
			["SETH"] = 	"Аукиндон: Сетеккские залы",
			["OHB"] = 	"Пещеры Времени: Старые предгорья Хилсбрада",
			["MECH"] = 	"Крепость Бурь: Механар",
			["BM"] = 	"Пещеры Времени: Черные топи",
			["MGT"] = 	"Терраса магистров",
			["SH"] = 	"Цитадель Адского Пламени: Разрушенные залы",
			["BOT"] = 	"Крепость Бурь: Ботаника",
			["SL"] = 	"Аукиндон: Темный лабиринт",
			["SV"] = 	"Резервуар Кривого Клыка: Паровое подземелье",
			["ARC"] = 	"Крепость Бурь: Аркатрац",
			["KARA"] = 	"Каражан",
			["GL"] = 	"Логово Груула",
			["MAG"] = 	"Цитадель Адского Пламени: Логово Магтеридона",
			["SSC"] = 	"Резервуар Кривого Клыка: Змеиное святилище",
			["EYE"] = 	"Крепость Бурь: Око",
			["ZA"] = 	"Зул'Аман",
			["HYJAL"] = "Пещеры Времени: Вершина Хиджала",
			["BT"] = 	"Черный Храм",
			["SWP"] = 	"Плато Солнечного Колодца",
			["ONY"] = "Логово Ониксии (40)",
			["RFC"] = "Огненная пропасть",
			["RFD"] = "Курганы Иглошкурых",
			["RFK"] = "Лабиринты Иглошкурых",
			["SCH"] = "Некроситет",
			["SFK"] = "Крепость Темного Клыка",
			["SM2"] = "Монастырь Алого ордена",
			["SMA"] = "Монастырь Алого ордена: Оружейная",
			["SMC"] = "Монастырь Алого ордена: Собор",
			["SMG"] = "Монастырь Алого ордена: Кладбище",
			["SML"] = "Монастырь Алого ордена: Библиотека",
			["ST"] = "Затонувший Храм",
			["STK"] = "Тюрьма",
			["STR"] = "Стратхольм",
			["TRADE"] = "Торговля",
			["UBRS"] = "Верх Вершины Черной горы (10)",
			["ULD"] = "Ульдаман",
			["WC"] = "Пещеры Стенаний",
			["WSG"] = "Ущелье Песни Войны (PvP)",
			["EOTS"] =  "Око Бури (PvP)",
			["ARENA"] = "Arena (PvP)",
			["ZF"] = "Зул'Фаррак",
			["ZG"] = "Зул'Гуруб (20)",
		},
		zhTW ={
			["RFC"] = 	"怒焰裂谷",
			["DM"] = 	"死亡礦坑",
			["WC"] = 	"哀嚎洞穴",	
			["SFK"] = 	"影牙城堡",
			["STK"] = 	"監獄",
			["BFD"] = 	"黑暗深淵",
			["GNO"] = 	"諾姆瑞根",
			["RFK"] = 	"剃刀沼澤",
			["SM2"] =	"血色修道院",
			["SMG"] = 	"血色修道院: 墓地",
			["SML"] = 	"血色修道院: 圖書館",
			["SMA"] = 	"血色修道院: 軍械庫",
			["SMC"] = 	"血色修道院: 大教堂",
			["RFD"] = 	"剃刀高地",
			["ULD"] = 	"奧達曼",
			["ZF"] = 	"祖爾法拉克",
			["MAR"] = 	"瑪拉頓",
			["ST"] = 	"阿塔哈卡神廟",
			["BRD"] = 	"黑石深淵",
			["DM2"] = 	"厄運之槌",
			["DME"] = 	"厄運之槌: 東",
			["DMN"] = 	"厄運之槌: 北",
			["DMW"] = 	"厄運之槌: 西",
			["STR"] = 	"斯坦索姆",
			["SCH"] = 	"通靈學院",
			["LBRS"] = 	"黑石塔下層",
			["UBRS"] = 	"黑石塔上層 (10)",
			["RAMPS"] = 	"地獄火壁壘",
			["BF"] = 	"血熔爐",
			["SP"] = 	"奴隸監獄",
			["UB"] = 	"深幽泥沼",
			["MT"] = 	"法力墓地",
			["CRYPTS"] = 	"奧奇奈地穴",
			["SETH"] = 	"塞司克大廳",
			["OHB"] = 	"希爾斯布萊德丘陵舊址",
			["MECH"] = 	"麥克納爾",
			["BM"] = 	"黑色沼澤",
			["MGT"] = 	"博學者殿堂",
			["SH"] = 	"破碎大廳",
			["BOT"] = 	"波塔尼卡",
			["SL"] = 	"暗影迷宮",
			["SV"] = 	"蒸氣洞穴",
			["ARC"] = 	"亞克崔茲",
			["KARA"] = 	"卡拉贊 (10)",
			["GL"] = 	"戈魯爾之巢 (25)",
			["MAG"] = 	"瑪瑟里頓的巢穴 (25)",
			["SSC"] = 	"毒蛇神殿洞穴 (25)",
			["EYE"] = 	"風暴要塞 (25)",
			["ZA"] = 	"祖阿曼 (10)",
			["HYJAL"] = 	"海加爾山 (25)",
			["BT"] = 	"黑暗神廟 (25)",
			["SWP"] = 	"太陽之井高地 (25)",
			["ONY"] = 	"奧妮克希亞的巢穴 (40)",
			["MC"] = 	"熔火之心 (40)",
			["ZG"] = 	"祖爾格拉布 (20)",
			["AQ20"] = 	"安其拉廢墟 (20)",
			["BWL"] = 	"黑翼之巢 (40)",
			["AQ40"] = 	"安其拉 (40)",
			["NAX"] = 	"納克薩瑪斯 (40)",
			["WSG"] = 	"戰歌峽谷 (PvP)",
			["AB"] = 	"阿拉希盆地 (PvP)",
			["AV"] = 	"奧特蘭克山谷 (PvP)",
			["EOTS"] = 	"暴風之眼 (PvP)",
			["MISC"] = 	"未分類",
			["TRADE"] =	"交易",
		},
	}

	
	
	local dungeonNames = dungeonNamesLocales[GetLocale()] or {}
	
	if GroupBulletinBoardDB and GroupBulletinBoardDB.CustomLocalesDungeon and type(GroupBulletinBoardDB.CustomLocalesDungeon) == "table" then
		for key,value in pairs(GroupBulletinBoardDB.CustomLocalesDungeon) do
			if value~=nil and value ~="" then
				dungeonNames[key.."_org"]=dungeonNames[key] or DefaultEnGB[key]
				dungeonNames[key]=value				
			end
		end
	end
	
	
	setmetatable(dungeonNames, {__index = DefaultEnGB})
	
	dungeonNames["DEADMINES"]=dungeonNames["DM"]
	
	return dungeonNames
end

local function Union ( a, b )
    local result = {}
    for k,v in pairs ( a ) do
        result[k] = v
    end
    for k,v in pairs ( b ) do
		result[k] = v
    end
    return result
end

GBB.VanillaDungeonLevels ={
	["RFC"] = 	{13,18}, ["DM"] = 	{18,23}, ["WC"] = 	{15,25}, ["SFK"] = 	{22,30}, ["STK"] = 	{22,30}, ["BFD"] = 	{24,32},
	["GNO"] = 	{29,38}, ["RFK"] = 	{30,40}, ["SMG"] = 	{28,38}, ["SML"] = 	{29,39}, ["SMA"] = 	{32,42}, ["SMC"] = 	{35,45},
	["RFD"] = 	{40,50}, ["ULD"] = 	{42,52}, ["ZF"] = 	{44,54}, ["MAR"] = 	{46,55}, ["ST"] = 	{50,60}, ["BRD"] = 	{52,60},
	["LBRS"] = 	{55,60}, ["DME"] = 	{58,60}, ["DMN"] = 	{58,60}, ["DMW"] = 	{58,60}, ["STR"] = 	{58,60}, ["SCH"] = 	{58,60},
	["UBRS"] = 	{58,60}, ["MC"] = 	{60,60}, ["ZG"] = 	{60,60}, ["AQ20"]= 	{60,60}, ["BWL"] = {60,60},
	["AQ40"] = 	{60,60}, ["NAX"] = 	{60,60}, 
	["MISC"]= {0,100},  
	["DEBUG"] = {0,100}, ["BAD"] =	{0,100}, ["TRADE"]=	{0,100}, ["SM2"] =  {28,42}, ["DM2"] =	{58,60}, ["DEADMINES"]={18,23},
}

GBB.PostTbcDungeonLevels = {
	["RFC"] = 	{13,20}, ["DM"] = 	{16,24}, ["WC"] = 	{16,24}, ["SFK"] = 	{17,25}, ["STK"] = 	{21,29}, ["BFD"] = 	{20,28},
	["GNO"] = 	{24,40}, ["RFK"] = 	{23,31}, ["SMG"] = 	{28,34}, ["SML"] = 	{30,38}, ["SMA"] = 	{32,42}, ["SMC"] = 	{35,44},
	["RFD"] = 	{33,41}, ["ULD"] = 	{36,44}, ["ZF"] = 	{42,50}, ["MAR"] = 	{40,52}, ["ST"] = 	{45,54}, ["BRD"] = 	{48,60},
	["LBRS"] = 	{54,60}, ["DME"] = 	{54,61}, ["DMN"] = 	{54,61}, ["DMW"] = 	{54,61}, ["STR"] = 	{56,61}, ["SCH"] = 	{56,61},
	["UBRS"] = 	{53,61}, ["MC"] = 	{60,60}, ["ZG"] = 	{60,60}, ["AQ20"]= 	{60,60}, ["BWL"] = {60,60},
	["AQ40"] = 	{60,60}, ["NAX"] = 	{60,60}, 
	["MISC"]= {0,100},  
	["DEBUG"] = {0,100}, ["BAD"] =	{0,100}, ["TRADE"]=	{0,100}, ["SM2"] =  {28,42}, ["DM2"] =	{58,60}, ["DEADMINES"]={16,24},
}


GBB.TbcDungeonLevels = { 
	["RAMPS"] =  {60,62}, 	["BF"] = 	 {61,63},     ["SP"] = 	 {62,64},    ["UB"] = 	 {63,65},     ["MT"] = 	 {64,66},     ["CRYPTS"] = {65,67},
	["SETH"] =   {67,69},  	["OHB"] = 	 {66,68},     ["MECH"] =   {69,70},    ["BM"] =      {69,70},    ["MGT"] =	 {70,70},    ["SH"] =	 {70,70}, 
	["BOT"] =    {70,70},    ["SL"] = 	 {70,70},    ["SV"] =     {70,70},   ["ARC"] = 	 {70,70},    ["KARA"] = 	 {70,70},    ["GL"] = 	 {70,70}, 
	["MAG"] =    {70,70},    ["SSC"] =    {70,70}, 	["EYE"] =    {70,70},   ["ZA"] = 	 {70,70},    ["HYJAL"] =  {70,70}, 	["BT"] =     {70,70}, 
	["SWP"] =    {70,70},
}

GBB.PvpLevels = {
	["WSG"] = 	{10,70}, ["AB"] = 	{20,70}, ["AV"] = 	{51,70},   ["WG"] = {80,80}, ["SOTA"] = {80,80},  ["EOTS"] =   {15,70},   ["ARENA"] = {70,80},
}

GBB.WotlkDungeonLevels = {
	["UK"] =    {68,80},    ["NEX"] =    {69,80},    ["AZN"] =    {70,80},    ["ANK"] =    {71,80},    ["DTK"] =    {72,80},    ["VH"] =    {73,80},    
	["GD"] =    {74,80},    ["HOS"] =    {75,80},    ["HOL"] =    {76,80},    ["COS"] =    {78,80},    ["OCC"] =    {77,80},    ["UP"] =    {77,80},    
	["FOS"] =    {80,80},   ["POS"] =    {80,80},    ["HOR"] =    {80,80},    ["CHAMP"] =  {78,80},    ["OS"] =    {80,80},    ["VOA"] =    {80,80},    
	["EOE"] =    {80,80},   ["ULDAR"] =  {80,80},    ["TOTC"] =     {80,80},    ["RS"] =     {80,80},    ["ICC"] =    {80,80},    ["ONY"] =    {80,80},    
	["NAXX"] =   {80,80},   ["BREW"] = {65,70},      ["HOLLOW"] = {65,70},
}

GBB.WotlkDungeonNames = {
	"UK", "NEX", "AZN", "ANK", "DTK", "VH", "GD", "HOS", "HOL", "COS", 
	"OCC", "UP", "FOS", "POS", "HOR", "CHAMP", "OS", "VOA", "EOE", "ULDAR", 
	"TOTC", "RS", "ICC", "ONY", "NAXX"
}

GBB.TbcDungeonNames = { 
	"RAMPS", "BF", "SH", "MAG", "SP", "UB", "SV", "SSC", "MT", "CRYPTS",
	"SETH", "SL", "OHB", "BM", "MECH", "BOT", "ARC", "EYE", "MGT", "KARA",
	"GL", "ZA", "HYJAL", "BT", "SWP",
}

GBB.VanillDungeonNames  = { 
	"RFC", "WC" , "DM" , "SFK", "STK", "BFD", "GNO",
    "RFK", "SMG", "SML", "SMA", "SMC", "RFD", "ULD", 
    "ZF", "MAR", "ST" , "BRD", "LBRS", "DME", "DMN", 
    "DMW", "STR", "SCH", "UBRS", "MC", "ZG", 
    "AQ20", "BWL", "AQ40", "NAX",
}	


GBB.PvpNames = {
	"WSG", "AB", "AV", "EOTS", "WG", "SOTA", "ARENA",
}

GBB.Misc = {"MISC", "TRADE",}

GBB.DebugNames = {
	"DEBUG", "BAD", "NIL",
}

GBB.Raids = {
	"ONY", "MC", "ZG", "AQ20", "BWL", "AQ40", "NAX", 
	"KARA", "GL", "MAG", "SSC", "EYE", "ZA", "HYJAL", 
	"BT", "SWP", "ARENA", "WSG", "AV", "AB", "EOTS",
	"WG", "SOTA", "BREW", "HOLLOW", "OS", "VOA", "EOE", 
	"ULDAR", "TOTC", "RS", "ICC", "NAXX",
}

GBB.Seasonal = {
    ["BREW"] = { startDate = "9/20", endDate = "10/06"},
	["HOLLOW"] = { startDate = "10/18", endDate = "11/01"}
}

GBB.SeasonalActiveEvents = {}
GBB.Events = getSeasonalDungeons()

function GBB.GetRaids()
	local arr = {}
	for _, v in pairs (GBB.Raids) do
		arr[v] = 1
	end
	return arr
end

-- Needed because Lua sucks, Blizzard switch to Python please
-- Takes in a list of dungeon lists, it will then concatenate the lists into a single list
-- it will put the dungeons in an order and give them a value incremental value that can be used for sorting later 
-- ie one list "Foo" which contains "Bar" and "FooBar" and a second list "BarFoo" which contains "BarBar"
-- the output would be single list with "Bar" = 1, "FooBar" = 2, "BarFoo" = 3, "BarBar" = 4
local function ConcatenateLists(Names) 
	local result = {}
	local index = 1
	for k, nameLists in pairs (Names) do 
		for _, v in pairs(nameLists) do 
			result[v] = index
			index = index + 1
		end
	end
	return result, index
end

function GBB.GetDungeonSort()
	for eventName, eventData in pairs(GBB.Seasonal) do
        if GBB.Tool.InDateRange(eventData.startDate, eventData.endDate) then
			table.insert(GBB.WotlkDungeonNames, 1, eventName)
		else
			table.insert(GBB.DebugNames, 1, eventName)
		end
    end
	
	local dungeonOrder = { GBB.VanillDungeonNames, GBB.TbcDungeonNames, GBB.WotlkDungeonNames, GBB.PvpNames, GBB.Misc, GBB.DebugNames}

	-- Why does Lua not having a fucking size function
	 local vanillaDungeonSize = 0
	 for _, _ in pairs(GBB.VanillDungeonNames) do
		vanillaDungeonSize = vanillaDungeonSize + 1
	 end

	 local tbcDungeonSize = 0
	 for _, _ in pairs(GBB.TbcDungeonNames) do
		tbcDungeonSize = tbcDungeonSize + 1
	 end

	local debugSize = 0
	for _, _ in pairs(GBB.DebugNames) do
		debugSize = debugSize+1
	end
	

	local tmp_dsort, concatenatedSize = ConcatenateLists(dungeonOrder)
	local dungeonSort = {}
	
	GBB.TBCDUNGEONSTART = vanillaDungeonSize + 1
	GBB.MAXDUNGEON = vanillaDungeonSize
	GBB.TBCMAXDUNGEON = vanillaDungeonSize  + tbcDungeonSize
	GBB.WOTLKDUNGEONSTART = GBB.TBCMAXDUNGEON + 1
	GBB.WOTLKMAXDUNGEON = concatenatedSize - debugSize - 1
	
	for dungeon,nb in pairs(tmp_dsort) do
		dungeonSort[nb]=dungeon
		dungeonSort[dungeon]=nb
	end

	-- Need to do this because I don't know I am too lazy to debug the use of SM2, DM2, and DEADMINES
	dungeonSort["SM2"] = 10.5
	dungeonSort["DM2"] = 19.5
	dungeonSort["DEADMINES"] = 99 
	
	return dungeonSort
end
	
local function DetermineVanillDungeonRange() 

	return GBB.PostTbcDungeonLevels

end

GBB.dungeonLevel = Union(Union(Union(DetermineVanillDungeonRange(), GBB.TbcDungeonLevels), GBB.WotlkDungeonLevels), GBB.PvpLevels)