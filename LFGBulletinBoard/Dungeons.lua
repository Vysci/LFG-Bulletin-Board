local TOCNAME,GBB=...

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
		["EYE"] = 	"The Eye",
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
		["MISC"] = 	"Miscellaneous",
		["TRADE"] =	"Trade",
		["DEBUG"] = "DEBUG INFO",
		["BAD"] =	"DEBUG BAD WORDS - REJECTED",
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
			["SMG"] = 	"Monastère écarlate: Graveyard",
			["SML"] = 	"Monastère écarlate: Library",
			["SMA"] = 	"Monastère écarlate: Armory",
			["SMC"] = 	"Monastère écarlate: Cathedral",
			["RFD"] = 	"Souilles de Tranchebauge",
			["ULD"] = 	"Uldaman",
			["ZF"] = 	"Zul'Farrak",
			["MAR"] = 	"Maraudon",
			["ST"] = 	"Le temple d'Atal'Hakkar",
			["BRD"] = 	"Profondeurs de Blackrock",
			["DM2"] = 	"Hache-tripes",
			["DME"] = 	"Hache-tripes: East",
			["DMN"] = 	"Hache-tripes: North",
			["DMW"] = 	"Hache-tripes: West",
			["STR"] = 	"Stratholme",
			["SCH"] = 	"Scholomance",
			["LBRS"] = 	"Pic Blackrock",
			["UBRS"] = 	"Pic Blackrock (10)",
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
			["ONY"] = 	"Repaire d'Onyxia (40)",
			["MC"] = 	"Cœur du Magma (40)",
			["ZG"] = 	"Zul'Gurub (20)",
			["AQ20"] = 	"Ruines d'Ahn'Qiraj (20)",
			["BWL"] = 	"Repaire de l'Aile noire (40)",
			["AQ40"] = 	"Ahn'Qiraj (40)",
			["NAX"] = 	"Naxxramas (40)",
		
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
			["EOTS"] =  "Eye of the Storm (PvP)",
			["ZF"] = "Зул'Фаррак",
			["ZG"] = "Зул'Гуруб (20)",
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

function Union ( a, b )
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
	["UBRS"] = 	{58,60}, ["ONY"] = 	{60,60}, ["MC"] = 	{60,60}, ["ZG"] = 	{60,60}, ["AQ20"]= 	{60,60}, ["BWL"] = {60,60},
	["AQ40"] = 	{60,60}, ["NAX"] = 	{60,60}, ["WSG"] = 	{10,70}, ["AB"] = 	{20,70}, ["AV"] = 	{51,70}, ["MISC"]= {0,100},  
	["DEBUG"] = {0,100}, ["BAD"] =	{0,100}, ["TRADE"]=	{0,100}, ["SM2"] =  {28,42}, ["DM2"] =	{58,60}, ["DEADMINES"]={18,23},
}

GBB.PostTbcDungeonLevels = {
	["RFC"] = 	{13,20}, ["DM"] = 	{16,24}, ["WC"] = 	{16,24}, ["SFK"] = 	{17,25}, ["STK"] = 	{21,29}, ["BFD"] = 	{20,28},
	["GNO"] = 	{24,40}, ["RFK"] = 	{23,31}, ["SMG"] = 	{28,34}, ["SML"] = 	{30,38}, ["SMA"] = 	{32,42}, ["SMC"] = 	{35,44},
	["RFD"] = 	{33,41}, ["ULD"] = 	{36,44}, ["ZF"] = 	{42,50}, ["MAR"] = 	{40,52}, ["ST"] = 	{45,54}, ["BRD"] = 	{48,60},
	["LBRS"] = 	{54,60}, ["DME"] = 	{54,61}, ["DMN"] = 	{54,61}, ["DMW"] = 	{54,61}, ["STR"] = 	{56,61}, ["SCH"] = 	{56,61},
	["UBRS"] = 	{53,61}, ["ONY"] = 	{60,60}, ["MC"] = 	{60,60}, ["ZG"] = 	{60,60}, ["AQ20"]= 	{60,60}, ["BWL"] = {60,60},
	["AQ40"] = 	{60,60}, ["NAX"] = 	{60,60}, ["WSG"] = 	{10,70}, ["AB"] = 	{20,70}, ["AV"] = 	{51,70}, ["MISC"]= {0,100},  
	["DEBUG"] = {0,100}, ["BAD"] =	{0,100}, ["TRADE"]=	{0,100}, ["SM2"] =  {28,42}, ["DM2"] =	{58,60}, ["DEADMINES"]={16,24},
}

GBB.TbcDungeonLevels = { 
	["RAMPS"] =  {60,62}, 	["BF"] = 	 {61,63},     ["SP"] = 	 {62,64},    ["UB"] = 	 {63,65},     ["MT"] = 	 {64,66},     ["CRYPTS"] = {65,67},
	["SETH"] =   {67,69},  	["OHB"] = 	 {66,68},     ["MECH"] =   {69,70},    ["BM"] =      {69,70},    ["MGT"] =	 {70,70},    ["SH"] =	 {70,70}, 
	["BOT"] =    {70,70},    ["SL"] = 	 {70,70},    ["SV"] =     {70,70},   ["ARC"] = 	 {70,70},    ["KARA"] = 	 {70,70},    ["GL"] = 	 {70,70}, 
	["MAG"] =    {70,70},    ["SSC"] =    {70,70}, 	["EYE"] =    {70,70},   ["ZA"] = 	 {70,70},    ["HYJAL"] =  {70,70}, 	["BT"] =     {70,70}, 
	["SWP"] =    {70,70}, 	["EOTS"] =   {15,70},    	
}	

GBB.TbcDungeonNames = { 
	"RAMPS", "BF", "SP", "UB", "MT", "CRYPTS",
	"SETH", "OHB", "MECH", "BM", "MGT", "SH", 
	"BOT", "SL", "SV", "ARC", "KARA", "GL", 
	"MAG", "SSC", "EYE", "ZA", "HYJAL", "BT", 
	"SWP",   	
}	

GBB.VanillDungeonNames  = { 
	"RFC", "WC" , "DM" , "SFK", "STK", "BFD", "GNO",
    "RFK", "SMG", "SML", "SMA", "SMC", "RFD", "ULD", 
    "ZF", "MAR", "ST" , "BRD", "LBRS", "DME", "DMN", 
    "DMW", "STR", "SCH", "UBRS", "ONY", "MC", "ZG", 
    "AQ20", "BWL", "AQ40", "NAX",
}	


GBB.PvpNames = {
	"WSG", "AB", "AV", "EOTS"
}

GBB.Misc = {"MISC", "TRADE",}

GBB.DebugNames = {
	"DEBUG", "BAD", "NIL",
}

-- Needed because Lua sucks, Blizzard switch to Python please
-- Takes in a list of dungeon lists, it will then concatenate the lists into a single list
-- it will put the dungeons in an order and give them a value incremental value that can be used for sorting later 
-- ie one list "Foo" which contains "Bar" and "FooBar" and a second list "BarFoo" which contains "BarBar"
-- the output would be single list with "Bar" = 1, "FooBar" = 2, "BarFoo" = 3, "BarBar" = 4
function ConcatenateLists(Names) 
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
	local dungeonOrder = {GBB.VanillDungeonNames, GBB.TbcDungeonNames, GBB.PvpNames, GBB.Misc, GBB.DebugNames}
	local vanillaDungeonSize = 0

	-- Why does Lua not having a fucking size function
	for _, _ in pairs(GBB.VanillDungeonNames) do 
		vanillaDungeonSize = vanillaDungeonSize + 1
	end

	local debugSize = 0
	for _, _ in pairs(GBB.DebugNames) do
		debugSize = debugSize+1
	end
	
	GBB.TBCDUNGEONSTART = vanillaDungeonSize + 1
	GBB.MAXDUNGEON = vanillaDungeonSize

	local tmp_dsort, concatenatedSize = ConcatenateLists(dungeonOrder)
	local dungeonSort = {}
	
	GBB.TBCMAXDUNGEON = concatenatedSize - debugSize - 1
	
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
	
function DetermineVanillDungeonRange() 
	if GBB.GameType == "TBC" then
		return GBB.PostTbcDungeonLevels
	end

	return GBB.VanillaDungeonLevels
end

GBB.dungeonLevel = Union(DetermineVanillDungeonRange(), GBB.TbcDungeonLevels)
