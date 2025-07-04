local TOCNAME, 
	---@class Addon_Tags: Addon_DungeonData
	GBB = ...;

local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local isSoD = isClassicEra and (C_Seasons.GetActiveSeason() == Enum.SeasonID.SeasonOfDiscovery)
-- IMPORTANT, everything must be in low-case and with now space!
---@param source table<string, string>
---@return table<string, string[]>
local function langSplit(source)
	local ret={}
	for lang,pat in pairs(source) do
		if pat~="-" then
			ret[lang]=GBB.Tool.Split(pat," ")
		end
	end
	return ret
end

--------------------------------------------------------------------------------
-- Preset Search Patterns/Tags
--------------------------------------------------------------------------------
-- note the string values are referred to as `tagString`s
-- these strings are space delimited `tags`, which are split in a table usually called a `tagList`
-- the individual tags in themselves cant contain spaces (otherwise it would get split into multiple tags)
-- these tags are all defaults/Preset and can be modified in-game via the options.

--- Suffix Tags:
local suffixTags = {
	enGB = "s group run runs", 
	deDE = "gruppe",
	ruRU = "группран фарм фарма фармить",
	frFR = "groupe",
	zhTW = "",
	zhCN = "",
	esES = "",
	ptBR = ""
}

--- Search Tags: usually prepended to an looking for group chat message, ie the "lfg" in "lfg wailing caverns"
local searchTags = {
	enGB = "group lfg lf lfm lftank lfheal lfhealer lfdps lfdd dd heal healer tank dps xdd xheal xhealer xtank druid hunter mage pala paladin priest rogue rouge shaman warlock warrior elite quest elitequest elitequests",

	deDE = "gesucht suche suchen sucht such gruppe grp sfg sfm druide dudu jäger magier priester warri schurke rschami schamane hexer hexenmeister hm krieger heiler xheiler go run",

	ruRU = "лфг ищет ищу нид нужны лфм лф2м ищем пати похилю лф танк хил нужен дд рдд мдд ршам рога вар прист армс пал",
	frFR = "groupe cherche chasseur druide mage paladin pretre voleur chaman quete",

	zhTW = "缺 來 找 徵 坦 補 DD 輸出 戰 聖 薩 獵 德 賊 法 牧 術",
	zhCN = "= 缺 来 找 德 T N ND DZ FS SS SM",
	esES = "buscando grupo bm bdg bg",
	ptBR = "procurando grupo pm pg"
}

--- Bad Tags: for messages to ignore which may have matched a searchTag, like
-- spammed "lf layer" messages durring server launches.
local badTags = {
	enGB = "layer",
	deDE = "fc",
	ruRU = "гильдию гильдия слой",
	frFR = "",
	zhTW = "影布 回流",
	zhCN = "影布 回流",
	esES = "",
	ptBR = ""
}

--- Heroic Tags: for identifying dungeon/raid difficulties
local heroicTags = {
	enGB = "h hc heroic",
	deDE = "h hc heroic",
	ruRU = "гер героик",
	frFR = "h hc heroic hm hero heroique",
	zhTW = "h 英雄",
	zhCN = "h H 英雄",
	esES = "h hc heroico heroica",
	ptBR = "h hc heroico",
}

--- Dungeon Tags: for identifying dungeons related to messages.
local dungeonTags = {
	AQ20 = { -- Ahn'Qiraj Ruins
		enGB = "ruins aq20 aqr",
		deDE = nil,
		ruRU = "руины ра20 ак20 аку20",
		frFR = nil,
		zhTW = "RAQ AQ20 廢墟",
		zhCN = "FX 废墟",
		esES = "",
		ptBR = ""
	},
	AQ40 = { -- Ahn'Qiraj Temple
		enGB = "aq40 aqt",
		deDE = nil,
		ruRU = "ан40 ак40 аку40",
		frFR = nil,
		zhTW = "TAQ AQ40 安琪拉 安其拉",
		zhCN = "TAQ 安其拉", 
	},
	ANK = { -- Ahn'kahet: The Old Kingdom
		enGB = "ank old ako ok kingdom",
		deDE = nil,
		ruRU = "анкахет акнахет анк кахет",
		frFR = "ank ahn",
		zhTW = nil,
		zhCN = "安卡赫特：古代王国 王国",
	},
	CRYPTS = { -- Auchenai Crypts
		enGB = "crypts crypt auchenai ac acrypts acrypt",
		deDE = "krypta auchenaikrypta auchen",
		ruRU = "аукенайские аг аукенские аукинайские аук аукен",
		frFR = "crypte cryptes crypts crypt auchenaï auchenai",
		zhTW = "地穴",
		zhCN = "地穴",
	},
	AZGS = { -- Azuregos
		enGB = "azu azuregos azregos",
	},
	KAZK = { -- Lord Kazzak
		enGB = "kazzak kaz",
	},
	AZN = { -- Azjol-Nerub
		enGB = "azn an nerub",
		deDE = nil,
		ruRU = "азжол ажзол азжолнеруб ажзолнеруб",
		frFR = "azjol nerub az azol azjob",
		zhTW = nil,
		zhCN = "艾卓",
	},
	BH = { -- Baradin Hold
		enGB = "bh baradin",
		ruRU = nil,  
		frFR = nil,  
		zhTW = nil,
		zhCN = nil,
	},
	BT = { -- Black Temple
		enGB = "bt",
		deDE = "tempel bt black blacktempel blacktemple temple",
		ruRU = "бт иллидан илидан",
		frFR = nil,
		zhTW = "黑暗神廟 黑廟",
		zhCN = "黑暗神庙 黑庙", 
	},
	BFD = { -- Blackfathom Deeps
		enGB = "bfd blackfathom fathom",
		deDE = "bft blackfathomtiefen tiefschwarze grotte tsg",
		ruRU = "нп непроглядная пучина пучину",
		frFR = "brassenoire",
		zhTW = "黑暗深淵",
		zhCN = "黑暗深渊",
	},
	BRC = { -- Blackrock Caverns
		enGB = "brc",
		ruRU = nil,  
		frFR = nil,  
		zhTW = nil,
		zhCN = nil,
	},

	-- all these can get redirected to the pre-cata "BRD" for the time being.
	-- these did not exists colloquially as wings pre-cata,
	NULL = { -- Blackrock Depths - Detention Block

	},
	NULL = { -- Blackrock Depths - Upper City

	},

	BWD = { -- Blackwing Descent
		enGB = "bwd descent bwd10 bwd25",
		deDE = nil,
		ruRU = "ткт",
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	BWL = { -- Blackwing Lair
		enGB = "blackwing bwl",
		deDE = nil,
		ruRU = "логово крыла тьмы лкт",
		frFR = nil,
		zhTW = "BWL 黑翼",
		zhCN = "BWL 黑翼",
	},
	BF = { -- Blood Furnace
		enGB = "furnace furn bf",
		deDE = "bk kessel blutkessel",
		ruRU = "крови кк",
		frFR = "fournaise",
		zhTW = "血熔爐 熔爐 融爐 血熔盧 熔盧 融盧",
		zhCN = "熔炉",
	},
	BREW = { -- Coren Direbrew (Brewfest)
		enGB = "brewfest brew coren dire direbrew beerfest",
		deDE = nil,
		ruRU = "хмельной фестиваль корен худовар",
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	DM = { -- Deadmines
		enGB = "deadmines vc vancleef dead mines mine",
		deDE = "todesminen todesmine tm",
		ruRU = "мк мертвые копи ванклиф",
		frFR = "mm mortemines mine mortemine",
		zhTW = "死亡礦坑 死況 死礦",
		zhCN = "死亡矿坑 死矿",
	},
	-- When changing tag strings for diremaul dungeons make sure to consider
	-- other versions of the game since the wings might be referred to differently. 
	DMW = { -- Dire Maul - Capital Gardens (DMW pre-cata)
		enGB = "dmw dmwest west",
		deDE = "dbw dbwest",
		ruRU = "дмв запад дмзапад",
		frFR = "ouest",
		zhTW = "厄西 惡西 噩西",
		zhCN = "厄运西",
	},
	DMN = { -- Dire Maul - Gordok Commons (DMN pre-cata)
		enGB = "dmn dmnorth north tribute dmt",
		deDE = "tribut dbn nord dbnord",
		ruRU = "дмн дмсевер север трибут трибьют",
		frFR = "tribut nord",
		zhTW = "厄北 惡北 噩北 完美厄運 完美惡運 完美噩運",
		zhCN = "厄运北 完美厄运",
	},
	DME = { -- Dire Maul - Warpwood Quarter (DME pre-cata)
		enGB = "dme dmeast east puzilin jumprun",
		deDE = "ost dbo dbost",
		ruRU = "восток вдм дмвосток джампран",
		frFR = "htest",
		zhTW = "厄東 惡東 噩東",
		zhCN = "厄运东",
	},
	DS = { -- Dragon Soul
		enGB = "ds deathwing",
	},
	DTK = { -- Drak'Tharon Keep
		enGB = "dtk drak draktharon drak'tharon",
		deDE = nil,
		ruRU = "драк'тарон драктарон",
		frFR = "dtk drak draktharon drak'tharon drak",
		zhTW = nil,
		zhCN = "达克萨隆要塞 达克萨隆",
	},
	NULL = { -- End Time

	},
	NULL = { -- Fall of Deathwing

	},
	FL = { -- Firelands
		enGB = "firelands fl ragnaros"
	},
	GNO = { -- Gnomeregan
		enGB = "gnomer gno gnomeregan gnomeragan gnome gnomregan gnomragan gnom gnomergan",
		deDE = nil,
		ruRU = "гномреган гномер гномрег гномериган гномерган",
		frFR = nil,
		zhTW = "諾姆瑞根",
		zhCN = "诺莫瑞根",
	},
	GB = { -- Grim Batol
		enGB = "gb grim batol",
		deDE = nil,
		ruRU = nil,
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	GL = { -- Gruul's Lair
		enGB = "gl gruul gruuls gruul's",
		deDE = "grull grul gruul",
		ruRU = "грул груула",
		frFR = nil,
		zhTW = "戈魯 魯爾 戈乳 哥魯 哥乳",
		zhCN = "格鲁尔",
	},
	GD = { -- Gundrak
		enGB = "gd gundrak",
		deDE = nil,
		ruRU = "гундрак гуднрак гун драк",
		frFR = "gd gundrak",
		zhTW = nil,
		zhCN = "古达克",
	},
	HOL = { -- Halls of Lightning
		enGB = "hol lightning",
		deDE = nil,
		ruRU = "молний чм",
		frFR = "sdf",
		zhTW = nil,
		zhCN = "闪电大厅",
	},
	HOO = { -- Halls of Origination
		enGB = "hoo origination halls",
		deDE = nil,
		ruRU = nil,
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	HOR = { -- Halls of Reflection
		enGB = "hor reflection",
		deDE = nil,
		ruRU = "залы отражений кяз",
		frFR = nil,
		zhTW = nil,
		zhCN = "映像大厅",
	},
	HOS = { -- Halls of Stone
		enGB = "hos stone",
		deDE = nil,
		ruRU = "камня чк",
		frFR = "sdp",
		zhTW = nil,
		zhCN = "岩石大厅",
	},
	RAMPS = { -- Hellfire Ramparts
		enGB = "ramparts rampart ramp ramps",
		deDE = "bm bollwerk höllenfeuerbollwerk bw",
		ruRU = "бастионы адского пламени цап бастион бап рампы",
		frFR = "remparts rempart renpart ranpart renparts rampart ramparts",
		zhTW = "堡壘 壁壘 火堡 火壘 火堡壘 火壁壘",
		zhCN = "碉堡",
	},
	NULL = { -- Hour of Twilight

	},
	HYJAL = { -- Hyjal Past
		enGB = "hyjal hs hyj",
		deDE = "hdz3 mount hyjal mounthyjal ",
		ruRU = "хиджал",
		frFR = nil,
		zhTW = "海珊 海山 海加爾",
		zhCN = "海山 海加尔",
	},
	ICC = { -- Icecrown Citadel
		enGB = "icc icecrown citadel",
		deDE = nil,
		ruRU = "цлк",
		frFR = "icc icecrown citadel icc10 icc25",
		zhTW = nil,
		zhCN = "冰冠碉堡",
	},

	KARA = { -- Karazhan
		enGB = "kara kz karazhan",
		deDE = "kara karazahn",
		ruRU = "каражан кара караджан кару",
		frFR = nil,
		zhTW = "卡拉 卡啦",
		zhCN = "KLZ 卡拉赞",
	},
	TOLVIR = { -- Lost City of the Tol'vir
		enGB = "tol'vir tolvir",
		deDE = nil,
		ruRU = nil,
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	LBRS = { -- Lower Blackrock Spire
		enGB = "lower lbrs lrbs",
		deDE = nil,
		ruRU = "лбрс нвчг нпчг нижний низ",
		frFR = nil,
		zhTW = "黑下 黑石塔下",
		zhCN = "黑下 黑石塔下",
	},
	MGT = { -- Magisters' Terrace
		enGB = "mgt mrt terrace magisters magister",
		deDE = "tdm terasse",
		ruRU = "тераса терраса магистров тм",
		frFR = nil,
		zhTW = "博學",
		zhCN = "博学",
	},
	MAG = { -- Magtheridon's Lair
		enGB = "mag magtheridon magtheridon's magth",
		deDE = "maggi magi magtheridons magtheridon",
		ruRU = "мага магтеридон",
		frFR = nil,
		zhTW = "馬肥 瑪色 馬瑟 瑪瑟",
		zhCN = "马肥 玛瑟里顿",
	},
	MT = { -- Mana-Tombs
		enGB = "manatombs mana mt tomb tombs",
		deDE = "mg gruft managruft manatomb tomb mana",
		ruRU = "маны гм манатомбс манатомбы томбы мана томбс манатобс манатомб манатомс ману",
		frFR = "tombe mana tm manatomb",
		zhTW = "法力 墓地 法墓",
		zhCN = "法力 陵墓 法墓",
	},

	-- all these can get redirected the "MARA" catchall for the time being.
	-- these did not exists as wings pre-cata, just entrances (princess, orange, purple)
	-- Maraudon - Earth Song Falls
	NULL = {},	
	-- Maraudon - Foulspore Cavern
	NULL = {},  
	-- Maraudon - The Wicked Grotto
	NULL = {},	
	
	MC = { -- Molten Core
		enGB = "molten core mc",
		deDE = "kern",
		ruRU = "недра",
		frFR = nil,
		zhTW = "MC 熔火 螺絲",
		zhCN = "MC 熔火",
	},    
	NAXX = { -- Naxxramas
		enGB = "naxxramas nax naxx nax10 naxx10 nax25 naxx25",
		deDE = nil,
		ruRU = "наксрамас накс наксарамас",
		frFR = "naxxramas nax naxx nax10 naxx10 nax25 naxx25",
		zhTW = "naxx 老克 納克",
		zhCN = "naxx 纳克萨玛斯",
	},	
	ONY = { -- Onyxia's Lair
		enGB = "onyxia ony",
		deDE = nil,
		ruRU = "ониксия оня ониксию",
		frFR = nil,
		zhTW = "黑妹 龍妹 奧妮 ONYX",
		zhCN = "黑龙 奧妮克希亞",
	},  
	BM = { --- Opening of the Dark Portal (aka the Black Morass)
		enGB = "morass bm black",
		deDE = "hdz2 morast",
		ruRU = "черные топи",
		frFR = "gt2",
		zhTW = "18波 黑色沼澤 黑沼 沼澤",
		zhCN = "18波 黑色沼澤 黑沼 沼澤",
	},
	POS = { -- Pit of Saron
		enGB = "pos pit saron",
		deDE = nil,
		ruRU = "яма яму сарона кяз",
		frFR = nil,
		zhTW = nil,
		zhCN = "萨隆深渊",
	},
	RFC = { -- Ragefire Chasm
		enGB = "rfc ragefire chasm",
		deDE = "rfa ragefireabgrund flammenschlund flamenschlund rf rfg",
		ruRU = "оп огненная пропасть",
		frFR = "rfc ragefeu",
		zhTW = "怒焰裂谷 怒驗 怒焰",
		zhCN = "怒焰峡谷 怒焰",
	},    
	RFD = { -- Razorfen Downs
		enGB = "rfd downs",
		deDE = "hügel huegel",
		ruRU = "ки курганы",
		frFR = "souille souilles",
		zhTW = "剃刀高地",
		zhCN = "剃刀高地",
	},   
	RFK = { -- Razorfen Kraul
		enGB = "rfk kraul",
		deDE = "kral krall karl",
		ruRU = "ли лабиринты",
		frFR = "kraal",
		zhTW = "剃刀沼澤",
		zhCN = "剃刀沼泽",
	},   
	RS = { -- Ruby Sanctum
		enGB = "rs ruby sanctum hal hal10 hal25",
		deDE = nil,
		ruRU = "рубиновое святилище рс",
		frFR = nil,
		zhTW = nil,
		zhCN = "红玉圣殿",
	},	
	SMA = { -- Scarlet Monastery - Armory
		enGB = "smarm sma arm armory herod armoury arms",
		deDE = "wk waffenkammer arsenal",
		ruRU = "оружейная армори арм оружейка",
		frFR = "armu armurerie",
		zhTW = "軍械",
		zhCN = "武器库",
	},	
	SMC = { -- Scarlet Monastery - Cathedral
		enGB = "smcath smc cath cathedral",
		deDE = "kathe kathedrale kath katha kahte",
		ruRU = "собор",
		frFR = "cathé cathe",
		zhTW = "教堂",
		zhCN = "教堂",
	},	
	SMG = { -- Scarlet Monastery - Graveyard
		enGB = "smgy smg gy graveyard",
		deDE = "friedhof hof fh freidhof",
		ruRU = "кладбон кладбище",
		frFR = "cimetière cimetiere cim",
		zhTW = "血色墓地",
		zhCN = "血色墓地",
	},   
	SML = { -- Scarlet Monastery - Library
		enGB = "smlib sml lib library",
		deDE = "bibli bibi bibliothek bib bücherei bibo biblio biblo bibl",
		ruRU = "библиотека библиотеку библу библа",
		frFR = "bibli bibliothèque bibliotheque librairie",
		zhTW = "血色圖書館",
		zhCN = "血色图书馆",
	},	
	SCH = { -- Scholomance
		enGB = "scholomance scholo sholo sholomance",
		deDE = nil,
		ruRU = "шоло некроситет некр",
		frFR = nil,
		zhTW = "通靈",
		zhCN = "通灵",
	},    
	SSC = { -- Serpentshrine Cavern
		enGB = "ssc serpentshrine serpentshine",
		deDE = "ssc vashi schlangenschrein",
		ruRU = "резервуар Кривого Клыка змеиное святилище зс",
		frFR = nil,
		zhTW = "毒蛇",
		zhCN = "毒蛇",
	},	
	SETH = { -- Sethekk Halls
		enGB = "sethekk seth sethek",
		deDE = "sh sethekhallen seth sethek",
		ruRU = "сетеккские залы сз сетеки сеттек сетекские сетеков сетеккскиезалы сеттекские",
		frFR = "sethekk seth sethek setthek settek",
		zhTW = "鳥廳 塞斯克 塞司克 賽司克 賽斯克 鳥聽 烏鴉",
		zhCN = "鸟厅",
	},	
	SL = { -- Shadow Labyrinth
		enGB = "sl slab labyrinth lab",
		deDE = "sl schlabby schattenlab shadow schattenlaby shadowlab",
		ruRU = "темный тёмный  лаберинт лабиринт шл лаба",
		frFR = "labyrinth lab laby shadowlab",
		zhTW = "迷宮 暗影 暗宮",
		zhCN = "迷宮",
	},	
	SFK = { -- Shadowfang Keep
		enGB = "sfk shadowfang",
		deDE = "burg bsf schattenfang",
		ruRU = "ктк темного клыка",
		frFR = "ombrecroc",
		zhTW = "影牙城堡 影牙",
		zhCN = "影牙城堡 影牙",
	},    
	SH = { -- Shattered Halls
		enGB = "sh shattered shatered shaterred",
		deDE = "zh zerschmetterte hallen",
		ruRU = "разрушенные рз разрушенных разрушеные",
		frFR = "salles salle brisées brisees brise brisés brisé sb brisée halls",
		zhTW = "破碎",
		zhCN = "破碎",
	},	
	SP = { -- Slave Pens
		enGB = "slavepens pens sp",
		deDE = "sp sklaven sklavenunterkünfte",
		ruRU = "узилище узилише улилище узилища узилеще узлще",
		frFR = "enclos enclo",
		zhTW = "奴隸 監獄 奴監",
		zhCN = "围栏",
	},	
	STK = { -- Stormwind Stockade
		enGB = "stk stock stockade stockades",
		deDE = "verlies verließ verliess",
		ruRU = "тюрьма тюрьму тюрягу",
		frFR = "prison",
		zhTW = nil,
		zhCN = nil,
	},

	-- all these can get redirected to the pre-cata "STRAT" for the time being.
	NULL = { -- Stratholme - Main Gate

	},  
	NULL = { -- Stratholme - Service Entrance

	},

	ST = { -- Sunken Temple
		enGB = "st sunken atal temple",
		deDE = "tempel",
		ruRU = "зх затанувший храм санкен сункен темпл",
		frFR = "st sunken englouti atal",
		zhTW = "神廟 阿塔哈卡",
		zhCN = "神庙",
	},    
	EYE = { -- Tempest Keep (The Eye)
		enGB = "eye tk",
		deDE = "auge tk fds",
		ruRU = "бурь фениксом",
		frFR = nil,
		zhTW = "風暴 要塞 鳳凰",
		zhCN = "风暴 要塞",
	},	
	ARC = { -- The Arcatraz
		enGB = "arc arcatraz alcatraz",
		deDE = "arca arka arkatraz arcatraz",
		ruRU = "аркатрац кба алькатрац аркатрас алькатрас алькатраз арка аркатраз",
		frFR = "arca",
		zhTW = "亞克",
		zhCN = "禁魔监狱",
	},	
	BOT2 = { -- The Bastion of Twilight
		enGB = "bot bastion bot10 bot25",
		deDE = nil,
		ruRU = "сб",
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	BFG = { -- The Battle for Gilneas
		enGB = "bfg tbfg gilneas",
		deDE = nil,
		ruRU = nil,
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	BOT = { -- The Botanica
		enGB = "botanica bot",
		deDE = "bota botanika botanica",
		ruRU = "ботаника кбб ботанику бот боту",
		frFR = "botanica bota",
		zhTW = "波塔 波卡",
		zhCN = "生态船",
	},	
	LOVE = { -- The Crown Chemical Co. (Love is in the Air)

	},	
	COS = { -- The Culling of Stratholme
		enGB = "culling cos",
		deDE = nil,
		ruRU = "очищение страт стратхольм",
		frFR = "gt4",
		zhTW = nil,
		zhCN = "净化斯坦索姆 stsm STSM",
	},	
	OHB = { -- The Escape From Durnholde (Old Hillsbrad Foothills)
		enGB = "ohb oh ohf durnholde hillsbrad escape",
		deDE = "hdz1 hillsbrad",
		ruRU = "cтарые предгорья хилсбрада спх старый хилсбрад хилсбард побег дарнхольд",
		frFR = "gt1",
		zhTW = "索爾 丘陵",
		zhCN = "索尔",
	},	
	EOE = { -- The Eye of Eternity
		enGB = "eoe maly eternity",
		deDE = nil,
		ruRU = "око вечности малигос малигоса",
		frFR = "maly malygos may",
		zhTW = nil,
		zhCN = "永恒之眼 蓝龙",
	},	
	FOS = { -- The Forge of Souls
		enGB = "fos forge soul",
		deDE = nil,
		ruRU = "кузня душ кузню кяз",
		frFR = nil,
		zhTW = nil,
		zhCN = "灵魂洪炉",
	},	
	SUMMER = { -- The Frost Lord Ahune (Midsummer)
		enGB = "ahune",
	},	
	HOLLOW = { -- The Headless Horseman
		enGB = "headless horseman hollow",
		deDE = nil,
		ruRU = "всадник",
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},	
	MECH = { -- The Mechanar
		enGB = "mech mechanar",
		deDE = "mecha mechanar mech",
		ruRU = "механар кбм механар мех меха меху",
		frFR = "méca mech mechanar méchanar",
		zhTW = "麥克",
		zhCN = "能源舰",
	},	
	NEX = { -- The Nexus
		enGB = "nexus nex",
		deDE = nil,
		ruRU = "нексус",
		frFR = "nexus nex",
		zhTW = nil,
		zhCN = "魔枢",
	},	
	OS = { -- The Obsidian Sanctum
		enGB = "sarth obsidian sanctum",
		deDE = nil,
		ruRU = "ос обсидиановое святилище сарт сартарион сартариона",
		frFR = "sarth sart sanctum sartha sartha10 sartha25 sarta10 sarta25",
		zhTW = nil,
		zhCN = "黑曜石圣殿 红龙",
	},	
	OCC = { -- The Oculus
		enGB = "occ oculus",
		deDE = nil,
		ruRU = "окулус",
		frFR = "occulus oculus",
		zhTW = nil,
		zhCN = "魔环",
	},	
	NULL = { -- The Siege of Wyrmrest Temple

	},	
	SV = { -- The Steamvault
		enGB = "sv steamvault steamvaults steam vault valts",
		deDE = "dk dampfkammer",
		ruRU = "резервуар паровое паравое паровые пп парового",
		frFR = "steam vault réservoir reservoir caveau caveaux",
		zhTW = "蒸氣 蒸汽",
		zhCN = "蒸汽 地窖",
	},	
	TSC = { -- The Stonecore
		enGB = "stonecore sc",
		deDE = nil,
		ruRU = nil,
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},	
	SWP = { -- The Sunwell
		enGB = "swp sunwell plateau plataeu sunwel",
		deDE = nil,
		ruRU = "плато свп санвел санвэл",
		frFR = nil,
		zhTW = "太陽",
		zhCN = "太阳井",
	},	
	VP = { -- The Vortex Pinnacle
		enGB = "VP vortex pinnacle",
		deDE = nil,
		ruRU = nil,
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	TOFW = { -- Throne of the Four Winds
		enGB = "totfw toftw tofw four winds tofw10 tofw25 tot4w to4w t4w",
		deDE = "td4w t4w",
		ruRU = "тчв",
		frFR = "t4v t4w",
		zhTW = nil,
		zhCN = nil,
	},	
	TOTT = { -- Throne of the Tides
		enGB = "tott tides",
		deDE = nil,
		ruRU = nil,
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	TB = { -- Tol Barad
		enGB = "tb bftb barad",
		deDE = nil,
		ruRU = nil,
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	CHAMP = { -- Trial of the Champion
		enGB = "champ toc champion",
		deDE = nil,
		ruRU = "чемпиона ич",
		frFR = "champ toc champion",
		zhTW = nil,
		zhCN = "冠军的试炼",
	},
	TOTC = { -- Trial of the Crusader/Trial of the Grand Crusader
		enGB = "tc totc totc10 totc25 toc10 toc25 togc",
		deDE = nil,
		ruRU = "крестоносца ик",
		frFR = "tc totc totc10 totc25 toc10 toc25 togc",
		zhTW = nil,
		zhCN = "十字军的试炼",
	},
	TP = { -- Twin Peaks
		enGB = "tp peaks",
		deDE = nil,
		ruRU = nil,
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	ULD = { -- Uldaman
		enGB = "uld ulda uldaman ulduman uldman uldama udaman",
		deDE = "uldamann",
		ruRU = "ульда ульдаман ульдман улдаман ульдуман",
		frFR = nil,
		zhTW = "奧達曼",
		zhCN = "奥达曼",
	},
	ULDAR = { -- Ulduar
		enGB = "uld ulduar",
		deDE = nil,
		ruRU = "ульдуар ульд ульда йог",
		frFR = "uldu uld uldu10 uldu25 ulduar ulduar10 ulduar25",
		zhTW = nil,
		zhCN = "奥杜尔",
	},
	UB = { -- Underbog
		enGB = "underbog ub",
		deDE = "ts sumpf tiefensumpf tiefen",
		ruRU = "нижетопь нт нежитопь нижнетопь",
		frFR = "bt basse tourbière tourbiere",
		zhTW = "深幽 泥沼",
		zhCN = "幽暗 泥沼",
	},
	UBRS = { -- Upper Blackrock Spire
		enGB = "upper ubrs urbs rend",
		deDE = nil,
		ruRU = "убрс ввчг вчвчг впчг вчпчг верх верхний",
		frFR = nil,
		zhTW = "黑上 黑石塔上",
		zhCN = "黑上 黑石塔上",
	},
	UK = { -- Utgarde Keep
		enGB = "uk utk utgarde",
		deDE = nil,
		ruRU = "крепость",
		frFR = nil,
		zhTW = nil,
		zhCN = "乌特加德城堡 乌堡",
	},
	UP = { -- Utgarde Pinnacle
		enGB = "up pinnacle",
		deDE = nil,
		ruRU = "вершина верх",
		frFR = "cime",
		zhTW = nil,
		zhCN = "乌特加德之巅 乌巅",
	},
	VOA = { -- Vault of Archavon
		enGB = "voa vault archavon",
		deDE = nil,
		ruRU = "склеп аркавона аркавон",
		frFR = "archa acha archavon",
		zhTW = nil,
		zhCN = "阿尔卡冯的宝库 宝库 色球",
	},
	VH = { -- Violet Hold
		enGB = "vh violet hold",
		deDE = nil,
		ruRU = "аметистовая амк",
		frFR = "fp fort",
		zhTW = nil,
		zhCN = "紫罗兰监狱 监狱",
	},
	WC = { -- Wailing Caverns
		enGB = "wc wailing caverns",
		deDE = "hdw wehklagens",
		ruRU = "пс стенаний пещеры",
		frFR = "lams lam lamentations",
		zhTW = "哀嚎洞穴 哀號 哀嚎",
		zhCN = "哀嚎洞穴 哀嚎",
	},
	NULL = { -- Well of Eternity

	},
	ZA = { -- Zul'Aman
		enGB = "za zulaman zul-aman zaman aman zul'aman",
		deDE = "za zulaman aman zul",
		ruRU = "зул'аман зуламан ЗА",
		frFR = nil,
		zhTW = "ZA 阿曼",
		zhCN = "ZA 祖阿曼",
	},
	ZF = { -- Zul'Farrak
		enGB = "zf zul farrak zul'farrak zulfarrak zulfarak zul´farrak zul`farrak zulfa zulf",
		deDE = nil,
		ruRU = "зф фарак фаррак зул'фаррак зулфарак зулфаррак зульфарак",
		frFR = nil,
		zhTW = "ZF 組爾法 祖爾法",
		zhCN = "ZLF 祖尔法拉克",
	},
	ZG = { -- Zul'Gurub 
		enGB = "zg gurub zul'gurub zulgurub zul´gurub zul`gurub zulg",
		deDE = nil,
		ruRU = "зг гуруб зул'гуруб  зулгуруб  зул?гуруб зул`гуруб зул'гуруба",
		frFR = nil,
		zhTW = "ZG 祖爾格 組爾格 龍虎",
		zhCN = "ZG 祖格",
	},

	-- Misc. Dungeons
	SM2 = { -- Base Scarlet Monastery catch-all for all wings
		enGB = "sm scarlet monastery mona",
		deDE = "kloster",
		ruRU = "мао монастырь",
		frFR = nil,
		zhTW = "血色",
		zhCN = "血色",
	},
	DM2 = { -- Base Dire Maul catch-all for all wings
		enGB = "dire maul diremaul",
		deDE = "düsterbruch duesterbruch db",
		ruRU = "дм забытый город",
		frFR = "ht hache-tripes hachetripes hache tripe tripes",
		zhTW = "厄運 惡運 噩運",
		zhCN = "厄运",
	},
	BRD = { -- Blackrock Depths (Pre Cata, no wings)
		enGB = "brd emperor emp arenarun angerforge blackrockdepth",
		deDE = "blackrocktiefen blackrock brt imperator imp",
		ruRU = "брд гчг глубины генерал ран глубины черной горы",
		frFR = "brd profondeur profondeurs",
		zhTW = "黑深 深淵",
		zhCN = "黑石深渊",
	},	
	STR = { -- Stratholme (Pre Cata, no wings)
		enGB = "stratlive live living stratUD undead ud baron stratholme stath stratholm strah strath strat starth",
		deDE = "lebend untot",
		ruRU = "ст",
		frFR = nil,
		zhTW = "斯坦",
		zhCN = "stsm 斯坦索姆",
	},
	MAR = { -- Maraudon (Pre Cata, no wings)
		enGB = "mar mara maraudon mauradon mauro maurodon princessrun maraudin maura marau mauraudon",
		deDE = "prinzessinnenrun prinzessinenrun prinzessinrun prinzessrun",
		ruRU = "мар мара марадон мараудон мару мародон мароудон мродон мородон",
		frFR = nil,
		zhTW = "馬拉 瑪拉",
		zhCN = "玛拉顿",
	},

	-- Cata pre-patch dungeon bosses
	NULL = { -- Crown Princess Theradras
	},
	NULL = { -- Grand Ambassador Flamelash
	},
	NULL = { -- Kai'ju Gahz'rilla
	},
	NULL = { -- Prince Sarsarun
	},

	-- Mists of Pandaria specific dungeons/raids
	MSV = { -- "Mogu'shan Vaults"
		enGB = "msv vaults",
    },
    NIUZAO_TEMPLE = { -- "Siege of Niuzao Temple"
		enGB = "niu niuzao temple nt",
    },
    SETTING_SUN = { -- "Gate of the Setting Sun"
		enGB = "goss gate",
    },
	SCARLET_HALLS = { -- "Scarlet Halls"
		enGB = "scarlet halls sh",
    },
    TOT = { -- "Throne of Thunder"
		enGB = "tot tot10 tot25",
    },
    MSP = { -- "Mogu'shan Palace"
		enGB = "palace msp",
    },
    TOTJS = { -- "Temple of the Jade Serpent"
		enGB = "jade serpent totjs",
    },
    SPM = { -- "Shado-Pan Monastery"
		enGB = "monastery spm",
    },
    BREWERY = { -- "Stormstout Brewery"
		enGB = "brewery stormstout sb brew",
    },
    TERRACE = { -- "Terrace of Endless Spring"
		enGB = "terrace tes toes",
    },
    HEART_OF_FEAR = { -- "Heart of Fear"
		enGB = "heart hof",
    },

	-- PvP
	RBG = { -- 10v10 Rated Battleground
		enGB = "rbgs rbg rated",
		deDE = nil, 
		ruRU = nil,  
		frFR = nil,  
		zhTW = nil,
		zhCN = nil,
	},
	ARENA = { -- 2v2 3v3 5v5 Arena
		enGB = "2s 3s 5s 3v3 5v5 2v2 2vs2 3vs3 5vs5",
		deDE = "2s 3s 5s 3v3 5v5 2v2 2vs2 3vs3 5vs5",
		ruRU = "2s 3s 5s 2с 3с 5с 2x2 3x3 5x5 2х2 3х3 5х5 2на2 3на3 5на5 кап",
		frFR = "2s 3s 5s 3v3 5v5 2v2 2vs2 3vs3 5vs5",
		zhTW = "競技 22 33 3v3 5v5 2v2 2vs2 3vs3 5vs5",
		zhCN = "竞技 22 33 3v3 5v5 2v2 2vs2 3vs3 5vs5",
    },
	AV = { -- Alterac Valley
		enGB = "av valley",
		deDE = nil,
		ruRU = "ад альтеракская долина ",
		frFR = "alterac",
		zhTW = "奧山 奧特蘭",
		zhCN = "奧山 奥特兰",
	},	
	AB = { -- Arathi Basin
		enGB = "basin ab",
		deDE = nil,
		ruRU = "низина арати",
		frFR = "arathi",
		zhTW = "阿拉溪 阿拉希 阿拉西",
		zhCN = "阿拉希",
	},	
	EOTS = { -- Eye of the Storm
		enGB = "storm eots",
		deDE = "ads",
		ruRU = "бури",
		frFR = nil,
		zhTW = "暴風眼 暴風之眼",
		zhCN = "风暴之眼",
	},	
	IOC = { -- Isle of Conquest
		enGB = "ioc",
		deDE = nil,
		ruRU = nil,
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},	
	SOTA = { -- Strand of the Ancients
		enGB = "sota strand ancient",
		deDE = nil,
		ruRU = "берег древних",
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},	
	WSG = { -- Warsong Gulch
		enGB = "wsg warsong ws",
		deDE = "warsongschlucht schlucht",
		ruRU = "упв ущелье песни войны варсонг всг",
		frFR = nil,
		zhTW = "戰哥 戰歌",
		zhCN = "战歌",
	},
	WG = { -- Wintergrasp
		enGB = "wg wintergrasp",
		deDE = nil,
		ruRU = "оло озеро",
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	SSM = { -- Silvershard Mines
		enGB = "ssm silvershard",
		deDE = nil,
		ruRU = nil,
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
	KOTMOGU = { -- Temple of Kotmogu
		enGB = "kotmogu",
		deDE = nil,
		ruRU = nil,
		frFR = nil,
		zhTW = nil,
		zhCN = nil,
	},
}
if isSoD then
	local sodSpecificTags = { -- appended to associated dungeonTags
		KARA = { -- Karazhan Crypts
			enGB = "kc crypts",
		},
		AQ20 = { -- Ruins of Ahn'Qiraj
			enGB = "aq10",
		},
		CRY = { -- Crystal vale (Thunderaan)
			enGB = "crystal vale thunderan thunderaan",
		},
		NMG = { -- Nightmare Grove (Emerald Dragons)
			enGB = "grove nmg dragons",
		},
		DFC = { -- Demonfall Canyon
			enGB = "demonfall dfc demon fall canyon",
		},
		ENCLAVE = { -- Scarlet Enclave
			enGB = "enclave scarlet se",
		}
	}
	for key, tagsByLoc in pairs(sodSpecificTags) do
		if not dungeonTags[key] then
			dungeonTags[key] = tagsByLoc
		else for locale, tag in pairs(tagsByLoc) do
			if not dungeonTags[key][locale] then
				dungeonTags[key][locale] = tag
			else
				dungeonTags[key][locale] = strjoin(" ", dungeonTags[key][locale], tag)
			end
		end end
	end
end
dungeonTags["DEADMINES"] = { enGB = "dm" } -- should normalize "DM" to "DEADMINES" at somepoint.

--- Misc. categeories tags (these are core to the addon) 
-- see `CustomCategories.lua` for additional user-editable categories/tags
local miscTags = {
	TRADE = { -- Trade Services
	  enGB = "buy buying sell selling wts wtb hitem henchant htrade enchanter wtt",
	  deDE = "kaufe verkauf kauf verkaufe ah vk tg trinkgeld trinkgold vz schneider verzauberer verzaubere schliesskassetten schließkassetten kassetten schlossknacken schloßknacken alchimie",
	  ruRU = "куплю продам втс втб чантера чант энчантера скрафчу сделаю чарю чары",
	  frFR = "achete vends enchanteur vend",
	  zhTW = "買 賣 售 收 代工 出售 附魔 COD",
	  zhCN = "买 卖 收 代工 出售 附魔",
	},
	TRAVEL = { -- Travel Services
	  enGB = "sum summ summon summons summoning port portal travel",
	  deDE = nil,
	  ruRU = nil,
	  frFR = nil,
	  zhTW = nil,
	  zhCN = nil,
	},
	MISC = { --[[Misc messages, no defined tags. see getRequestDungeons in RequestList.lua]]},
}

--- Secondary Dungeon Tags: used for groupable categories such as Scarlet Monastery
--- note: DEADMINES entry used for an edge case in categorizing between Dire Maul and Deadmines
local dungeonSecondTags = {
	["DEADMINES"] = { "DM", "-DMW", "-DME", "-DMN" },
	["SM2"] = { "SMG", "SML", "SMA", "SMC" },
	["DM2"] = { "DMW", "DME", "DMN", "-DM" },
}

--------------------------------------------------------------------------------
-- Public table references
--------------------------------------------------------------------------------
-- Comaptibility reformatting of data back to original shape.
-- [locale] => [dungeonKey]=> Array<tag>
local dungeonTagsLoc = {}
for _, categoryTags in pairs({dungeonTags, miscTags}) do
	for dungeonKey, tagsByLocale in pairs(categoryTags) do
		tagsByLocale = langSplit(tagsByLocale)
		for locale, tags in pairs(tagsByLocale) do
			if not dungeonTagsLoc[locale] then
				dungeonTagsLoc[locale] = {}
			end
			dungeonTagsLoc[locale][dungeonKey] = tags
		end
	end
end

GBB.dungeonSecondTags = dungeonSecondTags
GBB.suffixTagsLoc = langSplit(suffixTags)
GBB.searchTagsLoc = langSplit(searchTags)
GBB.badTagsLoc = langSplit(badTags)
GBB.heroicTagsLoc = langSplit(heroicTags)
GBB.Misc = (function() local t = {}; for k, _ in pairs(miscTags) do table.insert(t,k); end return t; end)()

GBB.dungeonTagsLoc = dungeonTagsLoc

-- todo: this is a hack to only use this system for Cata+ clients
if WOW_PROJECT_ID >= WOW_PROJECT_CATACLYSM_CLASSIC then
	GBB.Dungeons.ProcessActivityInfo()
end

-- Remove any unused dungeon tags based on game version
local clientDungeonKeys = GBB.GetSortedDungeonKeys() -- includes raids/bgs/dungeons for all valid expansions.
assert(next(clientDungeonKeys), "No client dungeons found. Was `ProcessActivityInfo()` called?")

clientDungeonKeys = (function() ---@type table<string, boolean> convert to map
	local t = {}; for _, key in ipairs(clientDungeonKeys) do t[key] = true; end return t;
end)()
-- iterate over all locales and `nil` out any entries for dungeons not in current client
for locale, dungeonTags in pairs(GBB.dungeonTagsLoc) do
	for dungeonKey, _ in pairs(dungeonTags) do
		if not (clientDungeonKeys[dungeonKey]
			or dungeonSecondTags[dungeonKey]
			or miscTags[dungeonKey])
		then
			GBB.dungeonTagsLoc[locale][dungeonKey] = nil
		end
	end
end
