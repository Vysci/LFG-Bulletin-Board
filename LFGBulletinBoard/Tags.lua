local TOCNAME,GBB=...

-- IMPORTANT, everything must be in low-case and with now space!

local function langSplit(source)
	local ret={}
	for lang,pat in pairs(source) do
		if pat~="-" then 
			ret[lang]=GBB.Tool.Split(pat," ")
		end
	end
	return ret
end

GBB.suffixTagsLoc=langSplit({
	enGB ="s group run runs",
	deDE ="gruppe",
	ruRU ="группран фарм фарма фармить", 
})

GBB.searchTagsLoc =langSplit({
	enGB = "group lfg lf lfm lftank lfheal lfhealer lfdps lfdd dd heal healer tank dps xdd xheal xhealer xtank druid hunter mage pala paladin priest rogue rouge shaman warlock warrior elite quest elitequest elitequests",				

	deDE = "gesucht suche suchen sucht such gruppe grp sfg sfm druide dudu jäger magier priester warri schurke rschami schamane hexer hexenmeister hm krieger heiler xheiler go run",

	ruRU = "лфг ищет ищу нид нужны лфм ищем пати похилю лф танк хил нужен дд рдд мдд",
})

GBB.badTagsLoc = langSplit({
	enGB = "layer",
	deDE = "fc",
	ruRU = "гильдию гильдия слой",

})



GBB.dungeonTagsLoc={
	enGB = langSplit({
		["RFC"] = 	"rfc ragefire chasm" ,
		["DM"]  = 	"deadmines vc vancleef dead mines mine" ,
		["WC"]  = 	"wc wailing caverns" ,	
		["SFK"] = 	"sfk shadowfang" ,
		["STK"] = 	"stk stock stockade stockades" ,
		["BFD"] = 	"bfd blackfathom fathom" ,
		["GNO"] =  	"gnomer gno gnomeregan gnomeragan gnome gnomregan gnomragan gnom gnomergan" ,
		["RFK"] = 	"rfk kraul" ,
		["SM2"] =	"sm scarlet monastery mona",
		["SMG"] = 	"smgy smg gy graveyard" ,
		["SML"] = 	"smlib sml lib library" ,
		["SMA"] = 	"smarm sma arm armory herod armoury arms" ,
		["SMC"] =  	"smcath smc cath cathedral",
		["RFD"] = 	"rfd downs" ,
		["ULD"] = 	"uld ulda uldaman ulduman uldman uldama udaman" ,
		["ZF"]  = 	"zf zul farrak zul'farrak zulfarrak zulfarak zul´farrak zul`farrak zulfa zulf" ,
		["MAR"] = 	"mar mara maraudon mauradon mauro maurodon princessrun maraudin maura marau mauraudon" ,
		["ST"]  = 	"st sunken atal temple" ,
		["BRD"] = 	"brd emperor emp arenarun angerforge blackrockdepth",
		["DM2"] =	"dire maul diremaul",
		["DME"] =  	"dme dmeast east puzilin jumprun",
		["DMN"] = 	"dmn dmnorth north tribute",
		["DMW"] = 	"dmw dmwest west",
		["STR"] = 	"stratlive live living stratUD undead ud baron stratholme stath stratholm strah strath strat starth",
		["SCH"] = 	"scholomance scholo sholo sholomance",
		["LBRS"] = 	"lower lbrs lrbs",
		["UBRS"] =	"upper ubrs urbs rend",
		["RAMPS"] = "ramparts rampart ramp ramps",
		["BF"] = "furnace furn bf",
		["SP"] = 	"slavepens pens sp",
		["UB"] = 	"underbog ub",
		["MT"] = 	"manatombs mana mt tomb tombs",
		["CRYPTS"] = "crypts crypt auchenai",
		["SETH"] = 	"sethekk seth sethek",
		["OHB"] = 	"ohb oh durnholde hillsbrad escape",
		["MECH"] = 	"mech mechanar",
		["BM"] = 	"morass bm",
		["MGT"] = 	"mgt mrt terrace magisters magister",
		["SH"] = 	"sh shattered shatered shaterred",
		["BOT"] = 	"botanica bot",
		["SL"] = 	"sl slab labyrinth lab",
		["SV"] = 	"sv steamvault steamvaults steam vault valts",
		["ARC"] = 	"arc arcatraz alcatraz",
		["KARA"] = 	"kara kz karazhan",
		["GL"] = 	"gl gruul gruuls gruul's",
		["MAG"] = 	"mag magtheridon magtheridon's magth",
		["SSC"] = 	"ssc serpentshrine serpentshine",
		["ZA"] = 	"za zulaman zul-aman zaman aman zul'aman",
		["EYE"] = 	"eye tk",
		["HYJAL"] = "hyjal hs hyj",
		["BT"] = 	"black bt",
		["SWP"] = 	"swp sunwell plateau plataeu sunwel",
		["ONY"] = 	"onyxia ony",
		["MC"]  = 	"molten core mc",
		["ZG"]  = 	"zg gurub zul'gurub zulgurub zul´gurub zul`gurub zulg",
		["AQ20"] = 	"ruins aq20",
		["BWL"] = 	"blackwing bwl",
		["AQ40"] = 	"aq40" ,
		["NAX"] = 	"naxxramas nax naxx",
		["WSG"] = 	"wsg warsong ws",
		["AB"]  = 	"basin",
		["AV"]  = 	"av valley",	
		["EOTS"] =  "storm eots",
		["TRADE"] = "buy buying sell selling wts wtb hitem henchant htrade enchanter", --hlink
	}),
	deDE =langSplit({
		["RFC"] = 	"rfa ragefireabgrund flammenschlund flamenschlund rf rfg" ,
		["DM"]  = 	"todesminen todesmine tm" ,
		["WC"]  = 	"hdw wehklagens" ,	
		["SFK"] = 	"burg bsf schattenfang" ,
		["STK"] = 	"verlies verließ verliess" ,
		["BFD"] = 	"bft blackfathomtiefen tiefschwarze grotte tsg" ,
		--["GNO"] =  	{} ,
		["RFK"] = 	"kral krall karl" ,
		["SMG"] = 	"friedhof hof fh freidhof" ,
		["SML"] = 	"bibli bibi bibliothek bib bücherei bibo biblio biblo bibl" ,
		["SM2"]	=	"kloster",
		["SMA"] = 	"wk waffenkammer arsenal" ,
		["SMC"] =  	"kathe kathedrale kath katha kahte",
		["RFD"] = 	"hügel huegel" ,
		["ULD"] = 	"uldamann" ,
		--["ZF"]  = 	{} ,
		["MAR"] = 	"prinzessinnenrun prinzessinenrun prinzessinrun prinzessrun" ,
		["ST"]  = 	"tempel" ,
		["BRD"] = 	"blackrocktiefen blackrock brt imperator imp",
		["DM2"] =	"düsterbruch duesterbruch db",
		["DME"] =  	"ost dbo dbost",
		["DMN"] = 	"tribut dbn nord dbnord",
		["DMW"] = 	"dbw dbwest",
		["STR"] = 	"lebend untot",
		--["SCH"] = 	{},
		--["LBRS"] = 	{},
		--["UBRS"] =	{},
		--["ONY"] = 	{},
		["MC"]  = 	"kern",
		--["ZG"]  = 	{},
		--["AQ20"] = 	{},
		--["BWL"] = 	{},
		--["AQ40"] = 	{} ,
		--["NAX"] = 	{},
		["WSG"] = 	"warsongschlucht schlucht",
		--["AB"]  = 	{},
		--["AV"]  = 	{},	
		["TRADE"] =	"kaufe verkauf kauf verkaufe ah vk tg trinkgeld trinkgold vz schneider verzauberer verzaubere schliesskassetten schließkassetten kassetten schlossknacken schloßknacken alchimie",
	}),	
	ruRU = langSplit({
		["AB"] = "низина арати",
		["AQ20"] = "руины ра20",
		["AQ40"] = "ан40",
		["AV"] = "ад альтеракская долина ",
		["BFD"] = "нп непроглядная пучина пучину",
		["BRD"] = "брд гчг глубины генерал арена ран кузня гнева глубины черной горы",
		["BWL"] = "логово крыла тьмы лкт",
		["DM"] = "мк мертвые копи ванклиф",
		["DM2"] = "дм забытый город",
		["DME"] = "восток вдм дмвосток джампран",
		["DMN"] = "дмн дмсевер север трибут трибьют",
		["DMW"] = "дмв запад дмзапад",
		["GNO"] = "гномреган гномер гномрег гномериган гномерган",
		["LBRS"] = "лбрс нвчг нпчг нижний низ",
		["MAR"] = "мар мара марадон мараудон мару мародон мароудон мродон",
		["MC"] = "недра",
		["NAX"] = "наксрамас накс",
		["ONY"] = "ониксия оня ониксию",
		["RFC"] = "оп огненная пропасть",
		["RFD"] = "ки курганы",
		["RFK"] = "ли лабиринты",
		["SCH"] = "шоло некроситет некр",
		["SFK"] = "ктк темного клыка",
		["SM2"] = "мао монастырь",
		["SMA"] = "оружейная армори арм оружейка",
		["SMC"] = "собор",
		["SMG"] = "кладбон кладбище",
		["SML"] = "библиотека библиотеку библу библа",
		["ST"] = "зх затанувший храм санкен сункен темпл",
		["STK"] = "тюрьма тюрьму тюрягу",
		["STR"] = "ст страт стратхольм",
		["TRADE"] = "куплю продам втс втб чантера чант энчантера",
		["UBRS"] = "убрс ввчг вчвчг впчг вчпчг верх верхний",
		["ULD"] = "ульд ульда ульдаман ульду ульдман улдаман",
		["WC"] = "пс стенаний пещеры",
		["WSG"] = "упв ущелье песни войны варсонг всг",
		["ZF"] = "зф фарак фаррак зул'фаррак зулфарак зулфаррак зульфарак",
		["ZG"] = "зг гуруб зул'гуруб  зулгуруб  зул´гуруб зул`гуруб",
	}),		
}

GBB.dungeonTagsLoc.enGB["DEADMINES"]={"dm"}

GBB.dungeonSecondTags = {
	["DEADMINES"] = {"DM","-DMW","-DME","-DMN"},
	["SM2"] = {"SMG","SML","SMA","SMC"},
	["DM2"] = {"DMW","DME","DMN","-DM"},
}
