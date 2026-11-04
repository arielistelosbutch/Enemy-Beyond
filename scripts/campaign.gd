extends Node
## Enemy Beyond - the campaign: time on the globe, money, trust of the
## sponsors, research, the base and the missions the radar finds.
## Kept in user://campaign.cfg. In co-op the host's campaign is the one that counts.

signal changed
signal mission_found(m: Dictionary)
signal flight_found(f: Dictionary)
signal research_done(id: String)
signal report(text: String)
signal craft_arrived(c: Dictionary)
signal craft_ambushed(c: Dictionary)

const START_YEAR := 1999
const BASE_LAT := 49.6      # the base: somewhere in the Bohemian-Moravian highlands
const BASE_LON := 15.6

# ---- mission types -----------------------------------------------------------------------
const MTYPES := {
	"crash": {"name": "Havárie UFO", "reward": 450, "aliens": 0, "expire": 1.2, "trust": 4,
		"text": "Radar ztratil malé UFO. Spadlo do neobydlené krajiny. Posádka může být živá."},
	"landed": {"name": "Přistání UFO", "reward": 650, "aliens": 2, "expire": 0.6, "trust": 5,
		"text": "Neporušené UFO přistálo a posádka je venku. Neví, že o nich víme."},
	"abduction": {"name": "Únos", "reward": 550, "aliens": 1, "expire": 0.5, "trust": 6,
		"text": "Hlášení o světlech nad samotou a zmizelých lidech. Možná ještě není pozdě."},
	"mars": {"name": "Velín na Marsu", "reward": 0, "aliens": 4, "expire": 9999.0, "trust": 0,
		"text": "Orel je připravený. Odlet na Mars, do srdce jejich velení - k Velkému mozku. Zpátky se letí jen s vítězstvím."},
	"terror": {"name": "Teror", "reward": 900, "aliens": 3, "expire": 0.35, "trust": 10,
		"text": "Vetřelci vtrhli do městečka. Spojení s místní policií bylo přerušeno."},
	"rescue": {"name": "Záchrana", "reward": 750, "aliens": 1, "expire": 0.4, "trust": 8,
		"text": "Nouzový maják. Někdo, kdo o vetřelcích ví víc, než by měl, se schovává před jejich hlídkou. Najít, chránit, dostat do Kondoru."},
	"sabotage": {"name": "Sabotáž", "reward": 800, "aliens": 2, "expire": 0.5, "trust": 6,
		"text": "Vetřelci rozmístili v krajině tři majáky. Volají jimi posily. Položit nálože, zničit všechny tři a zmizet."},
	"alienbase": {"name": "Základna vetřelců", "reward": 1400, "aliens": 5, "expire": 9999.0, "trust": 14,
		"text": "Výslech prozradil, kde mají základnu. Jeskyně pod zemí, velitelské centrum s řídicím jádrem, v líhni zajatí lidé. Zničit jádro."},
	"base": {"name": "Útok na základnu", "reward": 600, "aliens": 3, "expire": 0.2, "trust": 6,
		"text": "Radar hlásí loď nad roklí. Míří na NÁS. Bránit základnu do posledního vetřelce."},
}

# ---- research: a tree - each project needs what came before it ---------------------------------
## needs: research (id or list), corpse (race: a body brought home), live (race, or "officer"),
## loot (alien item brought home), seen (race met), kills, captures.
## branch: the row band in the tree; icon: picture in the tree (assets/icons).
const BRANCHES := {"bio": "Biologie", "psi": "Výslechy a psionika", "zbrane": "Zbraně", "material": "Materiály a výbava", "lode": "Lodě a technika"}
const RESEARCH := {
	# biology: autopsies - each race on the table teaches where to hit it
	"pitva": {"name": "Pitva šeďáka", "cost": 150, "days": 3.0, "needs": {"corpse": "grey"}, "branch": "bio", "icon": "race_grey",
		"desc": "Kde mají slabá místa? Všechny zbraně +15 % poškození proti vetřelcům."},
	"medicina": {"name": "Polní medicína", "cost": 250, "days": 4.0, "needs": {"research": "pitva"}, "branch": "bio", "icon": "medkit",
		"desc": "Co jsme se naučili na stole, pomůže i našim: lékárnička na 4 použití, padlý žoldák vykrvácí o 20 s později."},
	"pitva_levit": {"name": "Pitva Levita", "cost": 200, "days": 3.0, "needs": {"research": "pitva", "corpse": "levit"}, "branch": "bio", "icon": "race_levit",
		"desc": "Orgán, který ho nese, je jeho slabina. Levité dostávají o 20 % víc."},
	"pitva_ohar": {"name": "Pitva Ohaře", "cost": 200, "days": 3.0, "needs": {"research": "pitva", "corpse": "ohar"}, "branch": "bio", "icon": "race_ohar",
		"desc": "Pod pláty je tělo překvapivě měkké. Ohaři dostávají o 20 % víc."},
	"pitva_jestetan": {"name": "Pitva Ještěřana", "cost": 250, "days": 4.0, "needs": {"research": "pitva", "corpse": "jestetan"}, "branch": "bio", "icon": "race_jestetan",
		"desc": "Šupiny drží kulky, ale ne všude. Ještěřani dostávají o 20 % víc."},
	"pitva_lihnoun": {"name": "Pitva Líhnouna", "cost": 300, "days": 4.0, "needs": {"research": "pitva_jestetan", "corpse": "lihnoun"}, "branch": "bio", "icon": "race_lihnoun",
		"desc": "Kde mezi pláty je měkko. Zbraně dávají Líhnounům a Nakaženým o 30 % víc. Ošetření nakaženého zabere polovinu času."},
	"pitva_bijec": {"name": "Pitva Bijce", "cost": 300, "days": 4.0, "needs": {"research": "pitva", "corpse": "bijec"}, "branch": "bio", "icon": "race_bijec",
		"desc": "Oblek k němu přirostl - ale švy zůstaly. Bijci dostávají o 20 % víc."},
	"pitva_nador": {"name": "Pitva Nádoru", "cost": 250, "days": 3.0, "needs": {"research": "pitva_bijec", "corpse": "nador"}, "branch": "bio", "icon": "race_nador",
		"desc": "Proč vstává z mrtvých. Nádory dostávají o 20 % víc."},
	"pitva_ohnivec": {"name": "Rozbor Ohnivce", "cost": 300, "days": 4.0, "needs": {"research": "pitva_bijec", "corpse": "ohnivec"}, "branch": "bio", "icon": "race_ohnivec",
		"desc": "Skála, která žije. Ohnivci dostávají o 20 % víc."},
	"pitva_myslodej": {"name": "Pitva Mysloděje", "cost": 400, "days": 5.0, "needs": {"research": "psi_clona", "corpse": "myslodej"}, "branch": "bio", "icon": "race_myslodej",
		"desc": "Skoro jen mozek. Myslodějové dostávají o 20 % víc a psionický útok slábne."},
	# interrogations and the mind
	"vyslech": {"name": "Výslech zajatce", "cost": 400, "days": 6.0, "needs": {"live": "any"}, "branch": "psi", "icon": "radio",
		"desc": "Co ví živý vetřelec? Odhalí, odkud přicházejí (připraví útok na jejich základnu)."},
	"psi_clona": {"name": "Psionická clona", "cost": 450, "days": 6.0, "needs": {"research": "vyslech", "seen": "grey_velitel"}, "branch": "psi", "icon": "race_grey_velitel",
		"desc": "Kovová síťka pod helmou a cvičení soustředění. Velitelé a Myslodějové se do mysli dostanou mnohem hůř."},
	"vyslech_velitel": {"name": "Výslech velitele", "cost": 600, "days": 7.0, "needs": {"research": "vyslech", "live": "officer"}, "branch": "psi", "icon": "race_bijec_velitel",
		"desc": "Velitel ví víc než voják. Vede k signálu z Marsu."},
	"signal": {"name": "Signál z Marsu", "cost": 600, "days": 6.0, "needs": {"research": "vyslech_velitel"}, "branch": "psi", "icon": "mars",
		"desc": "Zajatý velitel pořád opakuje jedno slovo a ukazuje do nebe. Radar zachytil úzký paprsek mířící na Mars. Tam je jejich velín - a v něm to, co je všechny řídí."},
	# weapons
	"zenijni": {"name": "Ženijní výbava", "cost": 150, "days": 2.0, "needs": {}, "branch": "zbrane", "icon": "mine",
		"desc": "Odemkne nášlapné miny a kouřové granáty ve zbrojnici."},
	"tezke": {"name": "Těžké zbraně", "cost": 300, "days": 4.0, "needs": {}, "branch": "zbrane", "icon": "autocannon",
		"desc": "Odemkne autokanón, minigun, raketomet a odstřelovací pušku."},
	"rozbor_plazma": {"name": "Plazmová zbraň vetřelců", "cost": 250, "days": 3.0, "needs": {"loot": "a_pistol"}, "branch": "zbrane", "icon": "a_pistol",
		"desc": "Rozebraná plazmová pistole. Ukořistěné zbraně vetřelců přestanou zlobit v rukou žoldáků a otevře se cesta k laseru."},
	"laser": {"name": "Laserové zbraně", "cost": 400, "days": 5.0, "needs": {"research": "rozbor_plazma"}, "branch": "zbrane", "icon": "laser_rifle",
		"desc": "Naše verze jejich energetického článku: laserová pistole a puška. Žádné zásobníky - článek se dobíjí sám."},
	"laser_tezky": {"name": "Laserový kanón", "cost": 600, "mk": 15, "days": 6.0, "needs": {"research": "laser", "loot": "a_heavy"}, "branch": "zbrane", "icon": "laser_cannon",
		"desc": "Těžký laser podle zbraně Bijců. Na obrněné cíle a stroje."},
	"plazma": {"name": "Plazmová puška", "cost": 700, "mk": 30, "days": 8.0, "needs": {"research": ["laser", "vyslech", "moskovium"], "loot": "a_rifle"}, "branch": "zbrane", "icon": "plasma_rifle",
		"desc": "Vlastní zbraň postavená podle zabavené plazmové pušky. Tou se dá udolat cokoli."},
	# materials and gear
	"vesta": {"name": "Balistická vesta a štít", "cost": 200, "days": 3.0, "needs": {}, "branch": "material", "icon": "vesta",
		"desc": "Keramické pláty v látkové vestě a ruční štít s průzorem. Vesta: o 20 % menší zranění. Štít v levé ruce zastaví většinu střel zepředu."},
	"vysilacky": {"name": "Helmové vysílačky", "cost": 200, "days": 3.0, "needs": {}, "branch": "material", "icon": "radio",
		"desc": "Vysílačka zabudovaná do helmy: mluvíš do éteru bez ruky na vysílačce. Odolnější proti rušení."},
	"slitiny": {"name": "Vetřelecké slitiny", "cost": 300, "mk": 20, "days": 5.0, "needs": {"loot": "slitiny"}, "branch": "material", "icon": "a_pack",
		"desc": "Pláty do vest z trupu UFO: +8 zdraví všem žoldákům."},
	"pancir": {"name": "Slitinový pancíř", "cost": 500, "mk": 25, "days": 6.0, "needs": {"research": ["slitiny", "vesta"]}, "branch": "material", "icon": "pancir",
		"desc": "Pláty z jejich slitiny přes celé tělo: o 38 % menší zranění. Je těžší, ale vidět je na každém žoldákovi."},
	"moskovium": {"name": "Moskovium 115", "cost": 350, "days": 5.0, "needs": {"loot": "moskovium"}, "branch": "material", "icon": "plasma_cell",
		"desc": "Prvek, který pohání jejich lodě i zbraně. Bez něj nepostavíme plazmu ani loď na Mars."},
	# craft and machines
	"rozbor_diskoll": {"name": "Rozbor Diskollu", "cost": 250, "days": 4.0, "needs": {"corpse": "diskoll"}, "branch": "lode", "icon": "race_diskoll",
		"desc": "Vrak létajícího disku. Diskolly dostávají o 20 % víc."},
	"detektor": {"name": "Citlivější detektor", "cost": 200, "days": 3.0, "needs": {"research": "rozbor_diskoll"}, "branch": "lode", "icon": "scanner",
		"desc": "Podle čidel Diskollu: detektor pohybu vidí na 35 m místo 25 m a méně se plete."},
	"rozbor_kolos": {"name": "Rozbor Kolosu", "cost": 450, "days": 5.0, "needs": {"research": "rozbor_diskoll", "corpse": "kolos"}, "branch": "lode", "icon": "race_kolos",
		"desc": "Trosky chodícího stroje. Kolosové dostávají o 20 % víc."},
	"kondor": {"name": "Transportér Kondor", "cost": 500, "days": 5.0, "needs": {"research": "slitiny"}, "branch": "lode", "icon": "dropship",
		"desc": "Místo pomalého vrtulníku Čáp rychlý transportér s krátkými křídly, slitinovým trupem a dvěma motory. Na misi doletí asi třikrát rychleji."},
	"orel": {"name": "Hvězdná loď Orel", "cost": 2500, "mk": 120, "days": 10.0, "needs": {"research": ["signal", "moskovium", "pancir", "kondor"]}, "branch": "lode", "icon": "dropship",
		"desc": "Kondor s motorem na Moskovium 115 a trupem z vetřeleckých slitin. Doletí na Mars a zpátky. Odemkne poslední misi."},
}

## Research that makes a race take more damage (an autopsy / a wreck taken apart).
const AUTOPSY_BONUS := {"levit": "pitva_levit", "ohar": "pitva_ohar", "jestetan": "pitva_jestetan", "bijec": "pitva_bijec",
	"nador": "pitva_nador", "ohnivec": "pitva_ohnivec", "myslodej": "pitva_myslodej", "diskoll": "rozbor_diskoll", "kolos": "rozbor_kolos"}

## The archive: what the mercenaries have learned about each kind (own texts).
const RACE_INFO := {
	"grey": ["Šeďák", "Drobný, fyzicky slabý, ale rychlý a chytrý. Plazmová pistole. Do očí se nestřílí: obejde tě a pálí do zad. Diskolly mu hlásí, kde stojíš. Padlé žoldáky odtahuje do tmy."],
	"grey_velitel": ["Šeďák velitel", "Šeďák v přiléhavé uniformě s vysokým límcem. Psionik: vidí-li tě kterýkoli vetřelec, může ti vnutit paniku - nebo ti vnutí, že tvůj kamarád je jeden z nich. Když se ti obraz zbarví do fialova, nevěř ničemu, co vidíš. Živý zajatec je pro výzkum velká kořist."],
	"diskoll": ["Diskoll", "Létající disk, doprovod Šeďáků. Rychlý, střílí krátké a nemilosrdně přesné dávky. Hlavně ale vidí: koho zaměří, o tom vědí všichni Šeďáci v okolí. Nedá se omráčit. Plazma a výbuchy ho trhají na kusy, kulky odráží."],
	"levit_velitel": ["Levit velitel", "Větší Levit s rudě žhnoucími tryskami. Ve vzduchu neuvěřitelně rychlý a obratný, nosí raketomet. Kde přistane, tam už za vteřinu není."],
	"levit": ["Levit", "Létající mutant, nahoře člověk, dole pulzující orgán, který ho drží ve vzduchu. Tvář bez rtů, plná zubů. Na tryskách vyletí na střechu nebo do okna v patře, vystřelí a už je jinde. Dívej se nahoru."],
	"ohar": ["Ohař", "Zmutovaný čtyřnohý vlk, z obličeje mu místo čenichu roste kostěná čepel, na plecích a hřbetu má pancéřové pláty. Loví sluchem: tiše se přikrade, a když je blízko, vyrazí šílenou rychlostí."],
	"jestetan": ["Ještěřan", "Vysoký ještěří lovec s dlouhým krkem a těžkým ocasem. Pomalý, ale velmi odolný a těžce vyzbrojený: kulomet, minigun nebo plazmové dělo, k tomu plazmové granáty. Na cestách nechává oslepující pasti. Starší kusy se umí skrýt v maskování - pak uvidíš jen dvě oči."],
	"jestetan_velitel": ["Ještěřan velitel", "Ještěřan v plné zbroji od helmy po holeně, vždy v maskování. Na pušku skoro nereaguje - na něj těžké zbraně. Rád se připlíží zezadu, omráčí tě úderem do týla a odnese do lodi. Nikdy nechoď sám."],
	"lihnoun": ["Líhnoun", "Téměř černý dravec. Číhá ve tmě, plíží se blíž a pak přiběhne po čtyřech rychleji, než utečeš. Zblízka zabíjí dvěma drápy. Do oběti vloží zárodek: civilista se za pár vteřin zvedne jako Nakažený, žoldák, který s ním vykrvácí, taky. Plazma ho pálí víc než kulky."],
	"zombie": ["Nakažený", "To, co zbylo z oběti Líhnouna. Pomalý, neúnavný. Když padne - nebo když uplyne čas - vyleze z něj nový Líhnoun."],
	"bijec": ["Bijec", "Vysoký mutant, celé tělo jen svaly v tmavě modrém biologickém obleku, který k němu přirostl jako druhá kůže. Nejlepší voják vetřelců: plazmová puška, kulomet, minigun nebo plazmové dělo a plazmové granáty. Postupuje od krytu ke krytu, dokud tě nenajde."],
	"bijec_velitel": ["Bijec velitel", "Bijec v krvavě rudém obleku. Strašně odolný, přesný, s těžkým plazmovým minigunem. Rány se mu hojí a jeho řev žene ostatní kupředu."],
	"nador": ["Nádor", "Vznášející se pulzující nádor plný žil a mrtvých očí. Plivá kyselinu obloukem. Když padne, NENÍ mrtvý: leží na zemi a za chvíli se znovu zvedne. Musíš ho rozstřílet podruhé."],
	"ohnivec": ["Ohnivec", "Plazící se hromada černé skály s žhavými spárami. Plivá roztavenou lávu, kdo stojí vedle něj, hoří, a když ho chvíli nikdo netrefí, žár mu rány zacelí. Kulky a plazma ho skoro neberou - na něj granát, raketa, autokanón."],
	"myslodej": ["Mysloděj", "Fialový rubáš, který se vznáší, jako by v něm nic nebylo. Ve skutečnosti velmi hubený tvor, který už nepotřebuje končetiny: plazmovou pistoli drží myslí ve vzduchu vedle sebe. Přímému boji se vyhýbá. Ovládá mysli: vnutí paniku, převezme ruce, způsobí bolest - a vlastní posílí, zahojí a vyburcuje. Zabij ho první."],
	"kolos": ["Kolos", "Chodící válečný stroj na třech nohách. Vepředu dvě plazmové hlavice, na střeše plazmové dělo. Přesný, rychlý a smrtící, ale je to jen stroj: jde rovnou za tím, co naposledy viděl. Při zničení exploduje."],
}

# ---- base facilities ---------------------------------------------------------------------------
const FACILITIES := {
	"velin": {"name": "Velín", "cost": 0, "days": 0, "desc": "Srdce základny."},
	"hangar": {"name": "Hangár", "cost": 0, "days": 0, "desc": "Domov Kondoru."},
	"ubikace": {"name": "Ubikace", "cost": 0, "days": 0, "desc": "Kde žoldáci spí (pokud vůbec)."},
	"laborator": {"name": "Laboratoř", "cost": 500, "days": 6.0, "desc": "Každá laboratoř zrychlí výzkum o polovinu."},
	"dilna": {"name": "Zbrojnice", "cost": 400, "days": 5.0, "desc": "Každá zbrojnice zlevní nákupy o 15 %."},
	"osetrovna": {"name": "Ošetřovna", "cost": 400, "days": 5.0, "desc": "Zranění se hojí dvakrát rychleji."},
	"radar": {"name": "Radar", "cost": 600, "days": 7.0, "desc": "Mise se objevují častěji a déle vydrží."},
	"cela": {"name": "Cela pro vetřelce", "cost": 450, "days": 5.0, "desc": "Prosklené kóje s poutacími křesly. Bez ní omráčený vetřelec cestu na základnu nepřežije - živé zajatce (a výslechy) jde mít jen s celou."},
	"strelnice": {"name": "Střelnice", "cost": 300, "days": 3.0, "desc": "Čtyři stanoviště, terče, bedna s municí. Na zkoušení zbraní mezi misemi."},
	"sklad": {"name": "Sklad", "cost": 250, "days": 3.0, "desc": "Regály a sudy. Každý sklad zlevní munici a granáty o 10 %."},
}
const GRID_W := 6
const GRID_H := 4

# ---- shop: permanent extra allotment for every mission ------------------------------------
const SHOP := {
	"rifle_clip": 40, "pistol_clip": 25, "shells": 30, "magnum_rounds": 35, "ac_clip": 80, "minigun_belt": 120,
	"rocket": 150, "grenade": 60, "smoke_grenade": 50, "mine": 90, "flare": 20, "medkit": 160,
	"laser_pistol": 300, "laser_rifle": 600, "laser_cannon": 900,
	"rifle": 250, "sniper": 450, "sniper_clip": 35, "shotgun": 250, "magnum": 220, "autocannon": 600, "minigun": 750, "rocket_launcher": 650,
	"knife": 60, "stun_baton": 180, "scanner": 300, "radio": 40, "plasma_rifle": 900, "plasma_cell": 90,
	"vesta": 300, "stit": 350, "pancir": 900,
}
const LOCKED_BY := {"mine": "zenijni", "smoke_grenade": "zenijni", "autocannon": "tezke", "ac_clip": "tezke",
	"minigun": "tezke", "minigun_belt": "tezke", "rocket_launcher": "tezke", "rocket": "tezke",
	"sniper": "tezke", "sniper_clip": "tezke",
	"plasma_rifle": "plazma", "plasma_cell": "plazma",
	"laser_pistol": "laser", "laser_rifle": "laser", "laser_cannon": "laser_tezky",
	"vesta": "vesta", "stit": "vesta", "pancir": "pancir"}
## Alien-tech items also cost Moskovium 115 (the element that powers their ships).
const SHOP_MK := {"plasma_rifle": 25, "plasma_cell": 3, "laser_cannon": 6, "pancir": 15}
## What the team brings home from a won mission (collected automatically).
const LOOT_NAMES := {"a_pistol": "Plazmová pistole vetřelců", "a_rifle": "Plazmová puška vetřelců", "a_heavy": "Těžká plazma vetřelců",
	"slitiny": "Vetřelecké slitiny", "moskovium": "Moskovium 115"}
const RACE_WEAPON := {"grey": "a_pistol", "grey_velitel": "a_pistol", "levit": "a_rifle", "levit_velitel": "a_rifle", "jestetan": "a_rifle", "jestetan_velitel": "a_rifle",
	"bijec": "a_heavy", "bijec_velitel": "a_heavy", "myslodej": "a_heavy"}

# ---- places (approximate, for mission names) --------------------------------------------------
const PLACES := [
	["Vysočina", 49.5, 15.6], ["Šumava", 49.0, 13.6], ["Krkonoše", 50.7, 15.6], ["Beskydy", 49.5, 18.4],
	["Bavorsko", 48.8, 11.5], ["Sasko", 51.0, 13.5], ["Polsko", 52.2, 19.0], ["Slovensko", 48.7, 19.7],
	["Rakousko", 47.5, 14.5], ["Maďarsko", 47.2, 19.4], ["Normandie", 49.0, 0.0], ["Bretaň", 48.2, -3.0],
	["Skotsko", 57.0, -4.2], ["Irsko", 53.2, -8.0], ["Skandinávie", 61.0, 10.0], ["Finsko", 63.0, 26.0],
	["Pobaltí", 56.8, 24.0], ["Ukrajina", 49.0, 31.0], ["Rumunsko", 45.8, 24.8], ["Balkán", 43.8, 20.5],
	["Itálie", 43.0, 12.5], ["Španělsko", 40.2, -3.7], ["Maroko", 32.0, -6.0], ["Egypt", 27.0, 30.0],
	["Sahara", 23.0, 10.0], ["Kongo", -2.0, 23.0], ["Keňa", 0.5, 37.5], ["Jižní Afrika", -29.0, 25.0],
	["Turecko", 39.0, 34.0], ["Írán", 32.5, 54.0], ["Ural", 58.0, 60.0], ["Sibiř", 61.0, 95.0],
	["Kazachstán", 48.0, 67.0], ["Mongolsko", 47.0, 103.0], ["Čína", 34.0, 108.0], ["Japonsko", 36.5, 138.5],
	["Indie", 22.0, 79.0], ["Indočína", 15.0, 103.0], ["Indonésie", -2.0, 115.0], ["Austrálie", -25.0, 134.0],
	["Nový Zéland", -42.0, 172.0], ["Aljaška", 64.0, -150.0], ["Kanada", 55.0, -100.0], ["Quebec", 50.0, -72.0],
	["Nová Anglie", 43.5, -71.5], ["Texas", 31.0, -99.0], ["Nevada", 38.5, -116.5], ["Kalifornie", 37.0, -120.0],
	["Velká jezera", 44.0, -85.0], ["Mexiko", 22.0, -102.0], ["Amazonie", -5.0, -62.0], ["Andy", -15.0, -72.0],
	["Pampa", -36.0, -63.0], ["Patagonie", -46.0, -69.0], ["Brazílie", -15.0, -48.0], ["Grónsko", 72.0, -40.0],
]

var data := {}
var active := false
var viewer := false        # a co-op client looking at the host's campaign (read-only copy)
var _land: Image
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func _land_img() -> Image:
	if _land == null:
		_land = (load("res://assets/textures/earth_land.png") as Texture2D).get_image()
	return _land

func is_land(lat: float, lon: float) -> bool:
	var img := _land_img()
	var x := int((lon + 180.0) / 360.0 * img.get_width()) % img.get_width()
	var y := clampi(int((90.0 - lat) / 180.0 * img.get_height()), 0, img.get_height() - 1)
	return img.get_pixel(x, y).r > 0.5

# ---- save / load ----------------------------------------------------------------------------------
func has_save() -> bool:
	return FileAccess.file_exists("user://campaign.cfg")

func new_campaign() -> void:
	data = {
		"day": 0.0, "credits": 1200, "trust": 60, "month": 0,
		"research": {"done": [], "current": "", "progress": 0.0}, "bodies_v34": true,
		"armory": {}, "missions": [], "next_mission": 0.15, "next_id": 1,
		"stats": {"kills": 0, "captures": 0, "missions": 0, "won": 0},
		"base": [], "log": ["Kampaň začala. Základna v rokli na Vysočině je v provozu."],
		"flights": [], "sokol_ready": 0.0,
		"lost": false, "cid": str(randi()), "transport": "heli", "crafts": [],
	}
	var b := []
	for i in GRID_W * GRID_H:
		b.append({"type": "", "days": 0.0})
	b[0] = {"type": "velin", "days": 0.0}
	b[1] = {"type": "hangar", "days": 0.0}
	b[GRID_W] = {"type": "ubikace", "days": 0.0}
	b[GRID_W + 1] = {"type": "laborator", "days": 0.0}
	data["base"] = b
	active = true
	save()

func load_campaign() -> bool:
	var cf := ConfigFile.new()
	if cf.load("user://campaign.cfg") != OK:
		return false
	data = cf.get_value("campaign", "data", {})
	if not data.is_empty() and not data.has("cid"):
		data["cid"] = str(randi())
	if not data.is_empty() and not data.has("bodies_v34"):
		# older saves did not keep bodies: count every race met (with kills) as one brought home
		data["bodies_v34"] = true
		data["legacy_caps"] = int(data.get("stats", {}).get("captures", 0)) > 0
		var found: Dictionary = data.get("found", {})
		if int(data.get("stats", {}).get("kills", 0)) > 0:
			for r in data.get("seen_races", []):
				found["corpse_" + String(r)] = maxi(1, int(found.get("corpse_" + String(r), 0)))
		data["found"] = found
	active = not data.is_empty()
	return active

func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("campaign", "data", data)
	cf.save("user://campaign.cfg")

# ---- time -----------------------------------------------------------------------------------------
func date_text() -> String:
	var d := int(data["day"])
	var months := ["listopadu", "prosince", "ledna", "února", "března", "dubna", "května", "června", "července", "srpna", "září", "října"]
	var mdays := [30, 31, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31]
	var m := 0
	var dd := d
	while dd >= mdays[m % 12]:
		dd -= mdays[m % 12]
		m += 1
	var year := START_YEAR + int((m + 10) / 12)
	var h := fmod(float(data["day"]) * 24.0, 24.0)
	return "%d. %s %d  %02d:%02d UTC" % [dd + 1, months[m % 12], year, int(h), int(fmod(h, 1.0) * 60)]

func utc_hours() -> float:
	return fmod(float(data["day"]) * 24.0, 24.0)

func local_hour(lon: float) -> float:
	return fposmod(utc_hours() + lon / 15.0, 24.0)

func is_night(lon: float) -> bool:
	var h := local_hour(lon)
	return h < 6.5 or h > 18.0

## Moves time forward (days). Returns true if something happened that should
## stop the clock (new mission, research done, monthly report).
func advance(days: float) -> bool:
	if data["lost"]:
		return true
	var stop := false
	data["day"] = float(data["day"]) + days
	# research
	var r: Dictionary = data["research"]
	if r["current"] != "":
		r["progress"] = float(r["progress"]) + days * (1.0 + 0.5 * (count("laborator") - 1))
		if float(r["progress"]) >= RESEARCH[r["current"]]["days"]:
			var done: String = r["current"]
			r["done"].append(done)
			r["current"] = ""
			r["progress"] = 0.0
			_log("Výzkum dokončen: " + RESEARCH[done]["name"])
			if done == "orel":
				_add_final()
			if done == "vyslech":
				_add_alien_base()
			if done == "kondor":
				data["transport"] = "kondor"
				_log("Kondor je v hangáru. Čáp jde do zálohy.")
			research_done.emit(done)
			stop = true
	# construction
	for cell in data["base"]:
		if float(cell["days"]) > 0:
			cell["days"] = max(0.0, float(cell["days"]) - days)
			if float(cell["days"]) <= 0:
				_log("Dostavěno: " + FACILITIES[cell["type"]]["name"])
				stop = true
	# missions expire
	for m in data["missions"].duplicate():
		if float(m["expires"]) < float(data["day"]):
			data["missions"].erase(m)
			if m["type"] == "base":
				_log(_base_raided())
				stop = true
				continue
			var lost_trust := 15 if m["type"] == "terror" else 5
			data["trust"] = int(data["trust"]) - lost_trust
			_log("%s (%s) zůstala bez odpovědi. Důvěra −%d." % [MTYPES[m["type"]]["name"], m["place"], lost_trust])
			stop = true
	# UFOs in flight move; some land, some leave
	if not data.has("flights"):
		data["flights"] = []
		data["sokol_ready"] = 0.0
	for f in data["flights"].duplicate():
		var hd := deg_to_rad(float(f["heading"]))
		f["lat"] = clampf(float(f["lat"]) + cos(hd) * float(f["speed"]) * days, -70.0, 75.0)
		f["lon"] = fposmod(float(f["lon"]) + sin(hd) * float(f["speed"]) * days / max(0.2, cos(deg_to_rad(float(f["lat"])))) + 180.0, 360.0) - 180.0
		if float(f["until"]) < float(data["day"]):
			data["flights"].erase(f)
			if rng.randf() < 0.5 and is_land(float(f["lat"]), float(f["lon"])):
				var m := generate_mission()
				m["type"] = "landed"
				m["lat"] = f["lat"]; m["lon"] = f["lon"]
				m["place"] = nearest_place(float(f["lat"]), float(f["lon"]))
				m["reward"] = MTYPES["landed"]["reward"]
				m["extra_aliens"] = UFO_ALIENS[f["kind"]] + 1
				data["missions"].append(m)
				_log("UFO, které nikdo nezastavil, přistálo: " + m["place"])
				mission_found.emit(m)
			else:
				_log("UFO opustilo dosah radaru.")
			stop = true
	if _move_crafts(days):
		stop = true
	# the radar finds something
	data["next_mission"] = float(data["next_mission"]) - days
	if float(data["next_mission"]) <= 0:
		var radars := count("radar")
		data["next_mission"] = rng.randf_range(0.6, 1.6) / (1.0 + 0.4 * radars)
		if rng.randf() < 0.5:
			var f := generate_flight()
			data["flights"].append(f)
			_log("Radar: UFO v letu nad oblastí " + nearest_place(float(f["lat"]), float(f["lon"])))
			flight_found.emit(f)
		else:
			var m := generate_mission()
			data["missions"].append(m)
			mission_found.emit(m)
		stop = true
	# from the third week on they know where we are: now and then they come for the base
	if float(data["day"]) > 18.0 and not data.get("won", false):
		data["next_raid"] = float(data.get("next_raid", float(data["day"]) + rng.randf_range(6.0, 12.0)))
		if float(data["day"]) >= float(data["next_raid"]):
			data["next_raid"] = float(data["day"]) + rng.randf_range(9.0, 16.0)
			var already := false
			for mm in data["missions"]:
				if mm["type"] == "base":
					already = true
			if not already:
				var bm := generate_mission()
				bm["type"] = "base"
				bm["lat"] = BASE_LAT; bm["lon"] = BASE_LON
				bm["place"] = "Základna - Vysočina"
				bm["biome"] = "base"
				bm["terrain"] = terrain_at(BASE_LAT, BASE_LON)
				bm["size"] = "medium"
				bm["reward"] = MTYPES["base"]["reward"]
				bm["extra_aliens"] = int(MTYPES["base"]["aliens"]) + int(float(data["day"]) / 15.0)
				bm["expires"] = float(data["day"]) + float(MTYPES["base"]["expire"])
				data["missions"].append(bm)
				_log("POPLACH: vetřelci míří na základnu!")
				mission_found.emit(bm)
				stop = true
	# monthly report
	var month := int(float(data["day"]) / 30.0)
	if month > int(data["month"]):
		data["month"] = month
		# the countries we protect pay by how much they trust us; the base costs money to run
		var trust := int(data["trust"])
		var funding := int(300 + trust * 10 + trust * trust * 0.08)
		var built := 0
		for c in data["base"]:
			if float(c.get("days", 0)) <= 0 and c.get("type", "") != "":
				built += 1
		var upkeep := 150 + built * 50 + jets() * 80 + (250 if trust < 30 else 0)
		data["credits"] = int(data["credits"]) + funding - upkeep
		var txt := "MĚSÍČNÍ HLÁŠENÍ\nStáty posílají %d kr (důvěra %d %%). Údržba základny %d kr. Rozpočet: %d kr." % [funding, trust, upkeep, int(data["credits"])]
		if trust < 30:
			txt += "\nNízká důvěra: státy ubírají peníze a provoz se prodražuje."
		if int(data["credits"]) < 0:
			data["debt_months"] = int(data.get("debt_months", 0)) + 1
			txt += "\nROZPOČET JE V MÍNUSU (%d. měsíc). Dva měsíce v mínusu = projekt zkrachuje. Přispějte z vlastních peněz!" % int(data["debt_months"])
			if int(data["debt_months"]) >= 2:
				data["lost"] = true
				txt = "KONEC\nProjekt zkrachoval. Základna se zavírá, žoldáci jdou domů."
		else:
			data["debt_months"] = 0
		_log(txt.replace("\n", " "))
		report.emit(txt)
		stop = true
	if int(data["trust"]) <= 0:
		data["lost"] = true
		report.emit("KONEC\nSponzoři stáhli peníze. Základna se zavírá.")
		stop = true
	changed.emit()
	return stop

func _log(s: String) -> void:
	data["log"].append("[%s] %s" % [date_text().split("  ")[0], s])
	if data["log"].size() > 40:
		data["log"].pop_front()

# ---- our craft on the globe: jets and the transport fly to the target in game time ---------------
## degrees of arc per game day (1 degree is about 111 km)
const CRAFT_SPEED := {"jet": 300.0, "heli": 60.0, "kondor": 160.0}
const CRAFT_NAMES := {"jet": "Sokol", "heli": "vrtulník Čáp", "kondor": "Kondor"}

## Older saves had the Kondor from the start.
func transport() -> String:
	return String(data.get("transport", "kondor"))

func crafts() -> Array:
	if not data.has("crafts"):
		data["crafts"] = []
	return data["crafts"]

static func unit(lat: float, lon: float) -> Vector3:
	var la := deg_to_rad(lat)
	var lo := deg_to_rad(lon)
	return Vector3(cos(la) * cos(lo), sin(la), cos(la) * sin(lo))

static func arc_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	return rad_to_deg(unit(lat1, lon1).angle_to(unit(lat2, lon2)))

## hours a craft needs from the base to a place
func eta_hours(kind: String, lat: float, lon: float) -> float:
	return arc_deg(BASE_LAT, BASE_LON, lat, lon) / float(CRAFT_SPEED[kind]) * 24.0

func transport_out() -> bool:
	for c in crafts():
		if c["kind"] != "jet":
			return true
	return false

func jets_out() -> int:
	var n := 0
	for c in crafts():
		if c["kind"] == "jet":
			n += int(c.get("n", 1))
		elif c.get("state", "") == "out":
			n += int(c.get("escort", 0))
	return n

func _target_of(c: Dictionary) -> Dictionary:
	var lst: Array = data.get("flights", []) if c["ttype"] == "flight" else data["missions"]
	for x in lst:
		if int(x["id"]) == int(c["target"]):
			return x
	return {}

## Sends a craft from the base. Returns it.
func launch_craft(kind: String, target: Dictionary, ttype: String, extra := {}) -> Dictionary:
	var c := {"id": int(data["next_id"]), "kind": kind, "lat": BASE_LAT, "lon": BASE_LON, "target": int(target["id"]),
		"ttype": ttype, "state": "out", "start": float(data["day"])}
	data["next_id"] = int(data["next_id"]) + 1
	for k in extra:
		c[k] = extra[k]
	# the way to a mission can be dangerous: once in a while small UFOs jump the transport
	if kind != "jet" and float(data["day"]) > 3.0 and rng.randf() < 0.22:
		c["ambush_at"] = rng.randf_range(0.3, 0.7)
		c["dist0"] = arc_deg(BASE_LAT, BASE_LON, float(target["lat"]), float(target["lon"]))
	crafts().append(c)
	_log("%s vzlétl k cíli: %s (asi %d h letu)." % [CRAFT_NAMES[kind].capitalize() if kind != "jet" else ("%d× Sokol" % int(extra.get("n", 1))), target.get("place", nearest_place(float(target["lat"]), float(target["lon"]))), maxi(1, roundi(eta_hours(kind, float(target["lat"]), float(target["lon"]))))])
	changed.emit()
	return c

## A craft comes home (after the fight, or when the target is gone).
func recall_craft(c: Dictionary, why := "") -> void:
	c["state"] = "back"
	c.erase("ambush_at")
	if why != "":
		_log(why)

## After the fight around the transport on the way. Returns the text for the globe.
func escort_done(craft_id: int, outcome: String, tr_hp: float, lost_jets: int) -> String:
	var c := craft_by_id(craft_id)
	var txt := ""
	for i in lost_jets:
		_repair_jet(5.0)
	if not c.is_empty():
		c["escort"] = maxi(0, int(c.get("escort", 0)) - lost_jets)
	if outcome == "transport_down":
		if not c.is_empty():
			crafts().erase(c)
		data["kondor_ready"] = float(data["day"]) + 1.0
		txt = "%s byl sestřelen cestou k cíli. Posádka nouzově přistála a tým se vrátil po zemi. Mise propadla, nový stroj bude v hangáru za 24 h." % CRAFT_NAMES.get(String(c.get("kind", transport())), "Transport").capitalize()
		data["trust"] = clampi(int(data["trust"]) - 2, 0, 100)
	else:
		if not c.is_empty():
			c["state"] = "out"
		txt = ("Útok na transport odražen." if outcome == "repelled" else "UFO útok vzdala.") + " Let k cíli pokračuje."
		if outcome == "repelled":
			data["credits"] = int(data["credits"]) + 100
			txt += " Za sestřelená UFO 100 kr."
		if tr_hp < 50.0:
			txt += " Transport je poškozený, ale letí."
	if lost_jets > 0:
		txt += " Ztraceno Sokolů: %d." % lost_jets
	_log(txt)
	save()
	changed.emit()
	return txt

func craft_by_id(id: int) -> Dictionary:
	for c in crafts():
		if int(c["id"]) == id:
			return c
	return {}

func _move_crafts(days: float) -> bool:
	var stop := false
	for c in crafts().duplicate():
		var tl: float = BASE_LAT
		var tn: float = BASE_LON
		if c["state"] == "out":
			var tg := _target_of(c)
			if tg.is_empty():
				recall_craft(c, "%s nedorazil včas - cíl zmizel. Vrací se na základnu." % CRAFT_NAMES[c["kind"]].capitalize())
				stop = true
				continue
			tl = float(tg["lat"])
			tn = float(tg["lon"])
		elif c["state"] != "back":
			continue        # waiting at the target (a fight or a mission is on)
		var a := unit(float(c["lat"]), float(c["lon"]))
		var b := unit(tl, tn)
		var ang := a.angle_to(b)
		var step := deg_to_rad(float(CRAFT_SPEED[c["kind"]]) * days)
		var p := b if step >= ang else a.slerp(b, step / maxf(ang, 0.0001)).normalized()
		c["lat"] = rad_to_deg(asin(clampf(p.y, -1.0, 1.0)))
		c["lon"] = rad_to_deg(atan2(p.z, p.x))
		var left := rad_to_deg(p.angle_to(b))
		if c["state"] == "back":
			if left < 0.3:
				crafts().erase(c)
				_log("%s je zpátky v hangáru." % CRAFT_NAMES[c["kind"]].capitalize())
			continue
		if c.has("ambush_at") and float(c.get("dist0", 0.0)) > 0.0 and 1.0 - left / float(c["dist0"]) >= float(c["ambush_at"]):
			c.erase("ambush_at")
			c["state"] = "ambush"
			craft_ambushed.emit(c)
			return true
		if left < 0.6:
			c["state"] = "arrived"
			craft_arrived.emit(c)
			return true
	return stop

# ---- UFOs in the air ---------------------------------------------------------------------------------
const UFO_NAMES := {"scout": "Průzkumník (malé)", "raider": "Nájezdník (střední)", "harvester": "Sklízeč (velké)"}
const UFO_ALIENS := {"scout": 0, "raider": 1, "harvester": 3}

func generate_flight() -> Dictionary:
	var lat := BASE_LAT + rng.randf_range(-12, 12)
	var lon := BASE_LON + rng.randf_range(-22, 22)
	if rng.randf() < 0.35:
		lat = rad_to_deg(asin(rng.randf_range(-0.8, 0.9)))
		lon = rng.randf_range(-180, 180)
	var kinds := ["scout", "scout", "raider", "raider", "harvester"]
	if float(data["day"]) < 4.0:
		kinds = ["scout", "scout", "raider"]
	var id := int(data["next_id"])
	data["next_id"] = id + 1
	return {"id": id, "kind": kinds[rng.randi() % kinds.size()], "lat": lat, "lon": lon,
		"heading": rng.randf_range(0, 360), "speed": rng.randf_range(15, 35),
		"until": float(data["day"]) + rng.randf_range(0.25, 0.5) * (1.0 + 0.3 * count("radar"))}

func sokol_ready() -> bool:
	return jets_ready() > 0

## Interceptors: the base starts with one Sokol, more can be bought (one per pilot in co-op).
const JET_PRICE := 1500
const MAX_JETS := 4
func jets() -> int:
	return int(data.get("jets", 1))

func jets_ready() -> int:
	var busy := 0
	for d in data.get("jet_repair", []):
		if float(d) > float(data["day"]):
			busy += 1
	if float(data.get("sokol_ready", 0.0)) > float(data["day"]):
		busy += 1        # older saves
	return maxi(0, jets() - busy - jets_out())

func buy_jet() -> bool:
	if jets() >= MAX_JETS or int(data["credits"]) < JET_PRICE:
		return false
	data["credits"] = int(data["credits"]) - JET_PRICE
	data["jets"] = jets() + 1
	_log("Do hangáru přibyla stíhačka Sokol (%d celkem)." % jets())
	save()
	changed.emit()
	return true

func _repair_jet(days: float) -> void:
	var r: Array = data.get("jet_repair", [])
	var now := float(data["day"])
	r = r.filter(func(d): return float(d) > now)
	r.append(now + days)
	data["jet_repair"] = r

func intercept_params(f: Dictionary) -> Dictionary:
	return {"intercept": true, "id": f["id"], "ufo": f["kind"], "lat": f["lat"], "lon": f["lon"]}

## After the air fight. Returns the text for the globe.
func intercept_done(id: int, outcome: String, kind: String, jet_hp: float, lost := -1, damaged := 0) -> String:
	var f := {}
	for ff in data["flights"]:
		if int(ff["id"]) == id:
			f = ff
	if not f.is_empty():
		data["flights"].erase(f)
	var lat: float = float(f.get("lat", BASE_LAT))
	var lon: float = float(f.get("lon", BASE_LON))
	var txt := ""
	data["day"] = float(data["day"]) + 0.05
	for c in crafts():
		if c["kind"] == "jet" and int(c["target"]) == id:
			c["state"] = "back"
			c["lat"] = lat
			c["lon"] = lon
	match outcome:
		"crashed":
			# where it fell: the nearest land along its path
			for i in 40:
				if is_land(lat, lon):
					break
				lat += rng.randf_range(-1.5, 1.5)
				lon += rng.randf_range(-1.5, 1.5)
			var m := generate_mission()
			m["type"] = "crash"
			m["lat"] = lat; m["lon"] = lon
			m["place"] = nearest_place(lat, lon)
			m["terrain"] = terrain_at(lat, lon)
			m["size"] = {"scout": "small", "raider": "medium", "harvester": "large"}[kind]
			m["extra_aliens"] = UFO_ALIENS[kind]
			m["reward"] = MTYPES["crash"]["reward"] + {"scout": 0, "raider": 200, "harvester": 450}[kind]
			m["expires"] = float(data["day"]) + 1.0
			data["missions"].append(m)
			data["trust"] = clampi(int(data["trust"]) + 3, 0, 100)
			txt = "%s sestřelen nad oblastí %s. Trosky s posádkou čekají na pozemní tým." % [UFO_NAMES[kind], m["place"]]
		"destroyed":
			data["credits"] = int(data["credits"]) + 150
			data["trust"] = clampi(int(data["trust"]) + 2, 0, 100)
			txt = "%s rozprášen ve vzduchu. Odměna 150 kr, žádná kořist." % UFO_NAMES[kind]
		"shot_down":
			data["trust"] = clampi(int(data["trust"]) - 2, 0, 100)
			txt = "Sokoly sestřeleny, piloti se katapultovali."
		"escaped", "fuel":
			txt = "UFO uniklo."
	# lost / damaged jets go to the workshop
	if lost < 0:
		lost = 1 if outcome == "shot_down" else 0
		damaged = 1 if jet_hp < 60 and outcome != "shot_down" else 0
	for c in crafts().duplicate():
		if c["kind"] == "jet" and int(c["target"]) == id:
			c["n"] = int(c.get("n", 1)) - lost
			if int(c["n"]) <= 0:
				crafts().erase(c)
	for i in lost:
		_repair_jet(5.0)
	for i in damaged:
		_repair_jet(1.5)
	if lost > 0:
		txt += " Ztraceno stíhaček: %d (nová za 5 dní)." % lost
	if damaged > 0:
		txt += " Poškozeno: %d (oprava 1,5 dne)." % damaged
	_log(txt)
	save()
	changed.emit()
	return txt

# ---- missions ---------------------------------------------------------------------------------------
func generate_mission() -> Dictionary:
	var lat := 0.0
	var lon := 0.0
	for tries in 200:
		# more often closer to home (the radar network is European)
		if rng.randf() < 0.55:
			lat = BASE_LAT + rng.randf_range(-14, 14)
			lon = BASE_LON + rng.randf_range(-25, 25)
		else:
			lat = rad_to_deg(asin(rng.randf_range(-0.85, 0.95)))
			lon = rng.randf_range(-180, 180)
		if is_land(lat, lon):
			break
	var types := ["crash", "crash", "landed", "abduction", "terror", "rescue", "sabotage"]
	if float(data["day"]) < 4.0:
		types = ["crash", "crash", "landed", "abduction", "rescue"]
	var t: String = types[rng.randi() % types.size()]
	var info: Dictionary = MTYPES[t]
	var terr0 := terrain_at(lat, lon)
	var biome := "farm"
	var roll := rng.randf()
	if t == "terror":
		biome = "town" if roll < 0.75 else "industrial"
	elif abs(lat) > 63:
		biome = "polar"
	elif terr0 == "snow" or abs(lat) > 55:
		biome = "mountain" if roll < 0.5 else "forest"
	elif roll < 0.22:
		biome = "forest"
	elif roll < 0.36:
		biome = "industrial"
	elif roll < 0.46:
		biome = "town"
	elif roll < 0.54:
		biome = "mountain"
	# map size: terror = the whole town (huge), a big landed ship = large
	var size := "medium"
	match t:
		"terror": size = "colossal" if float(data["day"]) > 30 and rng.randf() < 0.6 else "huge"
		"landed": size = "colossal" if float(data["day"]) > 45 and rng.randf() < 0.3 else ("large" if rng.randf() < 0.5 else "medium")
		"crash": size = "small" if rng.randf() < 0.4 else "medium"
		"abduction": size = "small" if rng.randf() < 0.5 else "medium"
		"rescue", "sabotage": size = "large" if rng.randf() < 0.6 else "medium"
	var terr := terrain_at(lat, lon)
	if biome == "polar":
		terr = "snow"
	if terr == "desert" and biome in ["farm", "forest", "mountain", "polar"]:
		biome = "desert"       # sand, rocks, ruins - not fields and cows
	var id := int(data["next_id"])
	data["next_id"] = id + 1
	var exp_days: float = float(info["expire"]) * (1.0 + 0.4 * count("radar")) * rng.randf_range(0.8, 1.3)
	return {
		"id": id, "type": t, "lat": lat, "lon": lon, "place": nearest_place(lat, lon),
		"expires": float(data["day"]) + exp_days, "biome": biome, "race": "grey", "size": size, "terrain": terr,
		"extra_aliens": int(info["aliens"]) + int(float(data["day"]) / 20.0),
		"reward": int(info["reward"]), "seed": rng.randi() % 1000000,
	}

## Ground by place and season (the campaign starts in November): snow in the north and
## the mountains, sand in the great deserts, otherwise the usual fields and woods.
func terrain_at(lat: float, lon: float) -> String:
	var desert := (lat > 15 and lat < 33 and lon > -15 and lon < 55) or (lat > -30 and lat < -19 and lon > 115 and lon < 145) \
		or (lat > 25 and lat < 37 and lon > -118 and lon < -105) or (lat > 36 and lat < 45 and lon > 55 and lon < 75)
	if desert:
		return "desert"
	var month := int(float(data.get("day", 0)) / 30.0) % 12      # 0 = November
	var winter := month <= 4
	if absf(lat) > 62 or (winter and lat > 50) or (winter and lat < -50):
		return "snow"
	return "temperate"

## The last mission appears on the globe at the base: the Orel takes off from there.
# ---- the aliens learn: what each mercenary keeps bringing, they learn to answer -------------------
const HABIT_GEAR := ["sniper", "shotgun", "magnum", "rocket_launcher", "autocannon", "minigun", "stun_baton", "stit",
	"pancir", "flare", "smoke_grenade", "mine", "grenade", "laser_rifle", "laser_cannon", "plasma_rifle"]
const HABIT_TEXT := {"sniper": "odstřelovačku - budou se k němu stahovat zblízka, krytem", "shotgun": "brokovnici - budou držet odstup",
	"magnum": "revolver - budou držet odstup", "rocket_launcher": "raketomet - nebudou se shlukovat", "autocannon": "autokanón - nebudou se shlukovat",
	"minigun": "minigun - budou se skrývat a chodit zezadu", "stun_baton": "obušek - nepustí ho k sobě", "stit": "štít - budou střílet z boku a zezadu",
	"pancir": "těžký pancíř - přinesou těžké zbraně a granáty", "flare": "světlice - budou se držet mimo světlo",
	"smoke_grenade": "kouř - budou čekat, až se rozplyne", "mine": "miny - budou chodit jinudy", "grenade": "granáty - nebudou se shlukovat",
	"laser_rifle": "laser - budou se víc krýt", "laser_cannon": "laserový kanón - nebudou se shlukovat", "plasma_rifle": "plazmu - budou se víc krýt"}

func _learn_habits(kits: Dictionary) -> void:
	var h: Dictionary = data.get("habits", {})
	for who in h:
		for it in h[who]:
			h[who][it] = float(h[who][it]) * 0.8          # they forget slowly
	for peer in kits:
		var who := String(Net.roster.get(peer, {}).get("name", "")) if Net.roster.has(peer) else String(Game.merc.get("name", ""))
		if who == "":
			continue
		if not h.has(who):
			h[who] = {}
		for it in kits[peer]:
			if it in HABIT_GEAR:
				h[who][it] = float(h[who].get(it, 0.0)) + 1.0
	data["habits"] = h

## Who carries what so often that the aliens have learned it: {merc name: [items]}.
func known_habits() -> Dictionary:
	var out := {}
	var h: Dictionary = data.get("habits", {})
	for who in h:
		var l := []
		for it in h[who]:
			if float(h[who][it]) >= 2.2:
				l.append(it)
		if not l.is_empty():
			out[who] = l
	return out

## The interrogation told us where they hide on Earth: a base underground (stays until destroyed).
func _add_alien_base() -> void:
	for mm in data["missions"]:
		if mm["type"] == "alienbase":
			return
	var m := generate_mission()
	m["type"] = "alienbase"
	m["size"] = "large"
	m["extra_aliens"] = int(MTYPES["alienbase"]["aliens"]) + int(float(data["day"]) / 15.0)
	m["reward"] = int(MTYPES["alienbase"]["reward"])
	m["expires"] = float(data["day"]) + 9999.0
	data["missions"].append(m)
	_log("Výslech prozradil polohu jejich základny: %s. Mise čeká na globu." % m["place"])

func _add_final() -> void:
	for mm in data["missions"]:
		if mm["type"] == "mars":
			return
	var id := int(data["next_id"])
	data["next_id"] = id + 1
	data["missions"].append({"id": id, "type": "mars", "lat": BASE_LAT, "lon": BASE_LON, "place": "Mars - rudá pláň",
		"expires": float(data["day"]) + 9999.0, "biome": "mars", "terrain": "mars", "size": "large", "race": "myslodej",
		"group": "myslodejove", "extra_aliens": 4, "reward": 0, "seed": rng.randi() % 1000000})
	_log("Orel je připravený na startovací rampě. Poslední mise: Mars.")

func won() -> bool:
	return bool(data.get("won", false))

func nearest_place(lat: float, lon: float) -> String:
	var best := ""
	var bd := 1e9
	for p in PLACES:
		var d: float = pow(p[1] - lat, 2) + pow(fposmod(p[2] - lon + 180.0, 360.0) - 180.0, 2) * cos(deg_to_rad(lat))
		if d < bd:
			bd = d
			best = p[0]
	return best

## Parameters handed to the mission scene (and to every client).
func mission_params(m: Dictionary) -> Dictionary:
	var p := m.duplicate()
	p["night"] = is_night(float(m["lon"]))
	p["hour"] = local_hour(float(m["lon"]))
	p["type_name"] = MTYPES[m["type"]]["name"]
	p["stash"] = stash()
	p["research"] = data["research"]["done"].duplicate()
	p["cid"] = str(data.get("cid", ""))
	p["day"] = float(data["day"])
	p["transport"] = transport()
	p["late"] = int(data.get("month", 0)) >= 3
	p["habits"] = known_habits()
	if String(m.get("type", "")) == "base":
		# the defence happens inside our own base
		p["base"] = data["base"].duplicate(true)
		p["grid_w"] = GRID_W
		p["grid_h"] = GRID_H
		p["attack"] = true
	return p

## The base fell to a raid (lost defence or nobody went): money, a facility and gear are gone.
func _base_raided() -> String:
	var lost_cr := int(int(data["credits"]) * 0.35)
	data["credits"] = int(data["credits"]) - lost_cr
	var txt := "Vetřelci vyplenili základnu: ztráta %d kr" % lost_cr
	var built := []
	for i in data["base"].size():
		var cell: Dictionary = data["base"][i]
		if cell.get("type", "") in ["laborator", "dilna", "radar", "osetrovna"] and float(cell.get("days", 0)) <= 0:
			built.append(i)
	if not built.is_empty():
		var i2: int = built[rng.randi() % built.size()]
		var ft: String = data["base"][i2]["type"]
		data["base"][i2]["days"] = float(FACILITIES[ft]["days"]) * 0.5
		txt += ", %s poničena (oprava %.0f dní)" % [FACILITIES[ft]["name"], float(FACILITIES[ft]["days"]) * 0.5]
	for k in data["armory"].keys():
		data["armory"][k] = int(int(data["armory"][k]) / 2)
	txt += ", polovina skladu zbraní je pryč."
	data["trust"] = int(data["trust"]) - 8
	return txt

## After the team comes back.
## True while the replacement Kondor is still on its way (after a lost team).
func kondor_ready() -> bool:
	return float(data["day"]) >= float(data.get("kondor_ready", 0.0))

func kondor_hours() -> int:
	return maxi(1, ceili((float(data.get("kondor_ready", 0.0)) - float(data["day"])) * 24.0))

## The whole team fell: the Kondor stays out there with everything in its hold.
## What the team carried beyond the free base allotment is gone from the armory;
## a replacement Kondor comes to the hangar a day later, so the war goes on.
func _kondor_lost(kits: Dictionary) -> String:
	var carried := {}
	for peer in kits:
		for it in kits[peer]:
			carried[it] = int(carried.get(it, 0)) + 1
	var base: Dictionary = Game.STASH_VETERAN if Game.difficulty == "veteran" else Game.STASH
	var crew := maxi(1, kits.size())
	var lost := []
	for it in carried:
		var have := int(data["armory"].get(it, 0))
		var gone := mini(have, maxi(0, int(carried[it]) - int(base.get(it, 0)) * crew))
		if gone > 0:
			data["armory"][it] = have - gone
			if int(data["armory"][it]) <= 0:
				data["armory"].erase(it)
			lost.append("%s %dx" % [Game.ITEMS[it]["short"] if Game.ITEMS.has(it) else it, gone])
	data["kondor_ready"] = float(data["day"]) + 1.0
	var txt := " Kondor se nevrátil - jeho náklad je ztracen"
	txt += (": " + ", ".join(lost) + ".") if not lost.is_empty() else "."
	txt += " Náhradní Kondor dorazí do hangáru za 24 hodin."
	return txt

func mission_done(id: int, success: bool, kills: int, captures: int, lost_mercs: int, civ_saved := 0, civ_dead := 0, races := [], loot := {}, wiped := false, kits := {}) -> String:
	# what the team brought home: research needs it, Moskovium pays for alien tech
	var found: Dictionary = data.get("found", {})
	var got := []
	if count("cela") == 0:
		# nowhere to keep them: the captives do not survive the trip
		for k in loot.keys():
			if String(k).begins_with("live_") and int(loot[k]) > 0:
				var ck := "corpse_" + String(k).substr(5)
				loot[ck] = int(loot.get(ck, 0)) + int(loot[k])
				loot[k] = 0
				_log("Zajatec cestu nepřežil - základna nemá celu pro vetřelce.")
	for k in loot:
		if int(loot[k]) <= 0:
			continue
		found[k] = int(found.get(k, 0)) + int(loot[k])
		if k == "moskovium":
			data["moskovium"] = moskovium() + int(loot[k])
		got.append("%s %d%s" % [loot_name(k), int(loot[k]), " g" if k == "moskovium" else "x"])
	data["found"] = found
	_learn_habits(kits)
	# the archive learns what the team has met
	var seen: Array = data.get("seen_races", [])
	for r in races:
		if not r in seen:
			seen.append(r)
	data["seen_races"] = seen
	var m := {}
	for mm in data["missions"]:
		if int(mm["id"]) == id:
			m = mm
	if m.is_empty():
		return ""
	data["missions"].erase(m)
	# the transport (and its escort) fly home - unless the whole team fell and it is lost out there
	for c in crafts().duplicate():
		if c["kind"] != "jet" and int(c["target"]) == id:
			if wiped and not success and m["type"] != "base":
				crafts().erase(c)
			else:
				c["state"] = "back"
	if m["type"] == "mars":
		if success:
			data["won"] = true
			_log("VÍTĚZSTVÍ. Velký mozek je mrtvý, velín na Marsu zničen.")
		else:
			data["missions"].append(m)       # the Orel can fly again
	var info: Dictionary = MTYPES[m["type"]]
	# the mercenaries take their share of the reward (paid to them after the mission)
	var money := (int(int(m["reward"]) * 0.6) if success else 0) + kills * 40 + captures * 160 + civ_saved * 60
	data["credits"] = int(data["credits"]) + money
	var dt: int = (int(info["trust"]) if success else -6) + civ_saved * 2 - civ_dead
	data["trust"] = clampi(int(data["trust"]) + dt, 0, 100)
	var st: Dictionary = data["stats"]
	st["kills"] = int(st["kills"]) + kills
	st["captures"] = int(st["captures"]) + captures
	st["missions"] = int(st["missions"]) + 1
	if success:
		st["won"] = int(st["won"]) + 1
	data["day"] = float(data["day"]) + 0.12   # flight home
	var txt := "%s (%s): %s. Odměna %d kr, důvěra %+d." % [info["name"], m["place"], "úspěch" if success else "neúspěch", money, dt]
	if lost_mercs > 0:
		txt += " Padlí: %d." % lost_mercs
	if civ_saved + civ_dead > 0:
		txt += " Civilisté: zachráněno %d, mrtvých %d." % [civ_saved, civ_dead]
	if not got.is_empty():
		txt += " Kořist: " + ", ".join(got) + "."
	if m["type"] == "base" and not success:
		txt += " " + _base_raided()
	elif wiped and not success:
		txt += _kondor_lost(kits) if transport() != "heli" else _kondor_lost(kits).replace("Kondoru", "Čápa").replace("Kondor", "Čáp")
	_log(txt)
	save()
	changed.emit()
	return txt

# ---- research, building, shop -----------------------------------------------------------------
func researched(id: String) -> bool:
	return (active or viewer) and id in data["research"]["done"]

func research_available(id: String) -> bool:
	if researched(id) or data["research"]["current"] == id:
		return false
	for c in needs_list(id):
		if not c[1]:
			return false
	return true

## Every condition of a project: [text, met].
func needs_list(id: String) -> Array:
	var n: Dictionary = RESEARCH[id]["needs"]
	var st: Dictionary = data.get("stats", {})
	var found: Dictionary = data.get("found", {})
	var out := []
	var reqs: Array = []
	if n.has("research"):
		reqs = n["research"] if n["research"] is Array else [n["research"]]
	for r in reqs:
		out.append(["výzkum: " + RESEARCH[r]["name"], researched(r)])
	if n.has("corpse"):
		out.append(["tělo: " + race_name(n["corpse"]), int(found.get("corpse_" + String(n["corpse"]), 0)) > 0])
	if n.has("live"):
		var lv := String(n["live"])
		var ok := false
		var what := "živý zajatec"
		if lv == "any":
			ok = int(st.get("captures", 0)) > 0 and data.get("legacy_caps", false)
			for k in found:
				if String(k).begins_with("live_") and int(found[k]) > 0:
					ok = true
		elif lv == "officer":
			what = "živý velitel (nebo Mysloděj)"
			for k in found:
				if String(k).begins_with("live_") and (String(k).ends_with("_velitel") or String(k) == "live_myslodej") and int(found[k]) > 0:
					ok = true
		else:
			what = "živý " + race_name(lv)
			ok = int(found.get("live_" + lv, 0)) > 0
		out.append([what, ok])
	if n.has("loot"):
		out.append(["kořist: " + loot_name(n["loot"]), int(found.get(n["loot"], 0)) > 0])
	if n.has("seen"):
		out.append(["setkání: " + race_name(n["seen"]), n["seen"] in data.get("seen_races", [])])
	if n.has("kills"):
		out.append(["zabitý vetřelec", int(st.get("kills", 0)) >= int(n["kills"])])
	if n.has("captures"):
		out.append(["živý zajatec", int(st.get("captures", 0)) >= int(n["captures"])])
	return out

func needs_text(id: String) -> String:
	var parts := []
	for c in needs_list(id):
		if not c[1]:
			parts.append(c[0])
	return "vyžaduje: " + ", ".join(parts) if not parts.is_empty() else ""

## What a project leads to (the ones that list it).
func leads_to(id: String) -> Array:
	var out := []
	for k in RESEARCH:
		var n: Dictionary = RESEARCH[k]["needs"]
		if n.has("research"):
			var reqs: Array = n["research"] if n["research"] is Array else [n["research"]]
			if id in reqs:
				out.append(k)
	return out

func race_name(r: String) -> String:
	return String(RACE_INFO[r][0]) if RACE_INFO.has(r) else r

func loot_name(k: String) -> String:
	if k.begins_with("corpse_"):
		return "tělo: " + race_name(k.substr(7))
	if k.begins_with("live_"):
		return "živý zajatec: " + race_name(k.substr(5))
	return String(LOOT_NAMES.get(k, k))

func start_research(id: String) -> bool:
	if not research_available(id) or data["research"]["current"] != "":
		return false
	var cost: int = RESEARCH[id]["cost"]
	var mk := int(RESEARCH[id].get("mk", 0))
	if int(data["credits"]) < cost or moskovium() < mk:
		return false
	data["credits"] = int(data["credits"]) - cost
	data["moskovium"] = moskovium() - mk
	data["research"]["current"] = id
	data["research"]["progress"] = 0.0
	_log("Zahájen výzkum: " + RESEARCH[id]["name"])
	save()
	changed.emit()
	return true

func count(ftype: String) -> int:
	var n := 0
	for c in data["base"]:
		if c["type"] == ftype and float(c["days"]) <= 0:
			n += 1
	return n

## A facility can only go next to a finished one (the corridor has to lead somewhere).
func can_build_at(index: int) -> bool:
	var b: Array = data["base"]
	if String(b[index]["type"]) != "":
		return true
	var x := index % GRID_W
	var z := index / GRID_W
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var nz: int = z + d.y
		if nx >= 0 and nz >= 0 and nx < GRID_W and nz < GRID_H and String(b[nz * GRID_W + nx]["type"]) != "":
			return true
	return false

func build(index: int, ftype: String) -> bool:
	var cell: Dictionary = data["base"][index]
	var f: Dictionary = FACILITIES[ftype]
	if cell["type"] != "" or int(data["credits"]) < int(f["cost"]) or not can_build_at(index):
		return false
	data["credits"] = int(data["credits"]) - int(f["cost"])
	data["base"][index] = {"type": ftype, "days": float(f["days"])}
	_log("Stavba zahájena: " + f["name"])
	save()
	changed.emit()
	return true

func unlocked(item: String) -> bool:
	return not LOCKED_BY.has(item) or researched(LOCKED_BY[item])

func price(item: String) -> int:
	var p: float = float(SHOP[item]) * pow(0.85, count("dilna"))
	if String(Game.ITEMS.get(item, {}).get("type", "")) in ["ammo", "grenade", "flare", "medkit"]:
		p *= pow(0.9, count("sklad"))
	return int(p)

func moskovium() -> int:
	return int(data.get("moskovium", 0))

func buy(item: String) -> bool:
	if not unlocked(item) or int(data["credits"]) < price(item) or moskovium() < int(SHOP_MK.get(item, 0)):
		return false
	data["credits"] = int(data["credits"]) - price(item)
	data["moskovium"] = moskovium() - int(SHOP_MK.get(item, 0))
	data["armory"][item] = int(data["armory"].get(item, 0)) + 1
	save()
	changed.emit()
	return true

## What one mercenary may take on a mission: the base allotment (minus what
## research has not unlocked yet) plus everything bought.
func stash() -> Dictionary:
	var vet := Game.difficulty == "veteran"
	var base: Dictionary = (Game.STASH_VETERAN if vet else Game.STASH).duplicate()
	var out := {}
	for k in base:
		if unlocked(k):
			out[k] = int(base[k])
	for k in data.get("armory", {}):
		if unlocked(k):
			out[k] = int(out.get(k, 0)) + int(data["armory"][k])
	return out
