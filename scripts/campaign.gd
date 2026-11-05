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
	"pitva": {"name": "Pitva šediváka", "cost": 150, "days": 3.0, "needs": {"corpse": "grey"}, "branch": "bio", "icon": "race_grey",
		"desc": "Kde mají slabá místa? Všechny zbraně +15 % poškození proti vetřelcům."},
	"medicina": {"name": "Polní medicína", "cost": 250, "days": 4.0, "needs": {"research": "pitva"}, "branch": "bio", "icon": "medkit",
		"desc": "Co jsme se naučili na stole, pomůže i našim: lékárnička na 4 použití, padlý žoldák vykrvácí o 20 s později."},
	"pitva_levit": {"name": "Pitva Levita", "cost": 200, "days": 3.0, "needs": {"research": "pitva", "corpse": "levit"}, "branch": "bio", "icon": "race_levit",
		"desc": "Orgán, který ho nese, je jeho slabina. Levité dostávají o 20 % víc."},
	"pitva_ohar": {"name": "Pitva Ohaře", "cost": 200, "days": 3.0, "needs": {"research": "pitva", "corpse": "ohar"}, "branch": "bio", "icon": "race_ohar",
		"desc": "Pod pláty je tělo překvapivě měkké. Ohaři dostávají o 20 % víc."},
	"pitva_jestetan": {"name": "Pitva Ještěřana", "cost": 250, "days": 4.0, "needs": {"research": "pitva", "corpse": "jestetan"}, "branch": "bio", "icon": "race_jestetan",
		"desc": "Šupiny drží kulky, ale ne všude. Ještěřani dostávají o 20 % víc."},
	"pitva_lihnoun": {"name": "Pitva Líhavce", "cost": 300, "days": 4.0, "needs": {"research": "pitva_jestetan", "corpse": "lihnoun"}, "branch": "bio", "icon": "race_lihnoun",
		"desc": "Kde mezi pláty je měkko. Zbraně dávají Líhavcům a Nakaženým o 30 % víc. Ošetření nakaženého zabere polovinu času."},
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
	"batohy": {"name": "Výsadkové batohy", "cost": 250, "days": 4.0, "needs": {}, "branch": "material", "icon": "a_pack",
		"desc": "Větší batoh s rámem podle vzoru výsadkářů: místo šesti míst devět. Víc nábojů, víc lékárniček - jen to pořád váží."},
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
	"grey": ["Šedivák", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: ŠEDIVÁK. Klasifikace: mimozemská biologická jednotka. Stupeň ohrožení: KRITICKÝ. Status: nepřátelský - předvoj invazních sil.\n\nPOPIS HROZBY: První potvrzené jednotky mimozemského původu na území Země. Skutečné záměry neznámé; zpravodajské analýzy naznačují průzkumný předvoj rozsáhlé invaze, jejímž cílem je podrobení planety a zotročení lidí.\n\nFYZIOLOGIE A VÝBAVA: Mimořádná inteligence a rychlé vyhodnocování situací. Tělo je křehké, svalstvo nedostatečně vyvinuté - nahrazuje je biomechanická kombinéza, která několikanásobně zesiluje svaly i nervové reakce: nepřirozená rychlost, obratnost a reflexy. Hrudník chrání plát z neidentifikované slitiny.\n\nTAKTICKÉ HODNOCENÍ: Silné stránky - extrémní rychlost, inteligence, nadlidské reflexy, pokročilá technologie. Slabiny - křehká anatomie, závislost na kombinéze. Doporučení: vyřadit biomechanickou podporu (těžce zraněnému kombinéza vypoví - zpomalí a hůř míří). Vyhnout se boji na krátkou vzdálenost.\n\nZ BOJE: Plazmová pistole. Do očí se nestřílí: obejde tě a pálí do zad. Diskolly mu hlásí, kde stojíš. Padlé žoldáky odtahuje do tmy.\n\n\"Pokud jsou tyto bytosti skutečně jen průzkumníci, nechceme vědět, co přijde po nich.\" - Velitelství pozemních obranných sil, utajovaná zpráva"],
	"grey_velitel": ["Šedivák velitel", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: ŠEDIVÁK VELITEL. Klasifikace: mimozemská velitelská biologická jednotka. Stupeň ohrožení: KRITICKÝ+. Status: nepřátelský - velitelský článek invazních sil.\n\nPOPIS HROZBY: Vyšší vývojový nebo hodnostní stupeň Šediváků - taktický koordinátor, polní velitel a psionický operátor. Řídí pohyb podřízených, určuje cíle útoku a vyhodnocuje slabiny obrany. Pokud se běžní Šediváci jeví jako průzkumníci, Velitelé představují mozek celé operace.\n\nFYZIOLOGIE A VÝBAVA: Vyšší mentální kapacita, chladná inteligence, vypočítavost a schopnost manipulace. Tělo křehké jako u ostatních; velitelská kombinéza je robustnější, rychlejší a napojená i na nervový systém. Červená barva obleku označuje hodnost a vyšší energetickou kapacitu. Hrudník chrání zesílený plát z neidentifikované slitiny. Psionická čelenka zesiluje mentální schopnosti: narušuje vnímání, oslabuje morálku, možná přímo ovlivňuje nervovou soustavu.\n\nTAKTICKÉ HODNOCENÍ: Silné stránky - inteligence, velení, psionické útoky, extrémní rychlost, nadlidské reflexy. Slabiny - křehká anatomie, závislost na kombinéze a čelence, vysoká hodnota cíle: po jeho vyřazení podřízené jednotky ztrácejí koordinaci (hůř míří, nikdo je nežene vpřed). Doporučení: prioritní eliminace. Těžce zraněnému vypoví kombinéza i s čelenkou - zpomalí a psionika utichne. Vyhnout se přímému vizuálnímu kontaktu a boji zblízka bez psychické ochrany.\n\nZ BOJE: Vidí-li tě kterýkoli vetřelec, může ti vnutit paniku - nebo ti vnutí, že tvůj kamarád je jeden z nich. Když se ti obraz zbarví do fialova, nevěř ničemu, co vidíš. Živý zajatec je pro výzkum velká kořist.\n\n\"Běžný Šedivák je lovec. Šedivák Velitel je mysl, která lov řídí. Kde se objeví on, tam invaze nezačíná - tam už běží podle plánu.\" - Velitelství pozemních obranných sil, utajovaná zpráva"],
	"diskoll": ["Diskoll", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: DISKOLL. Klasifikace: mimozemská autonomní průzkumná jednotka. Stupeň ohrožení: VYSOKÝ. Status: nepřátelský - robotický zvěd invazních sil.\n\nPOPIS HROZBY: Pokročilá průzkumná jednotka, která doprovází Šediváky. Přes malé rozměry má mimořádně výkonné senzory: identifikuje cíle na velkou vzdálenost a okamžitě předává jejich přesnou polohu. Často ji přímo ovládá Šedivák Velitel, data ale dokáže rozeslat každé jednotce s kompatibilním přijímačem. Zásadní prvek jejich bojové koordinace.\n\nFYZIOLOGIE A VÝBAVA: Plně mechanická jednotka diskovitého tvaru, velikostí srovnatelná s pozemskými drony. Pohon umožňuje vysokou rychlost, prudké změny směru a stabilní vznášení bez viditelných pohyblivých částí. Centrální optický senzor identifikuje a sleduje cíle, komunikační anténa přenáší taktická data. Výzbroj: dvojice předních plazmových blasterů se zelenými projektily. Vnitřní systémy jsou mimořádně citlivé na energetické poškození.\n\nTAKTICKÉ HODNOCENÍ: Silné stránky - rychlost, okamžitá identifikace nepřítele, přesné zaměřování, přenos taktických informací, plazmová výzbroj, manévrovatelnost. Slabiny - nízká odolnost proti energetickým útokům (plazma a výbuchy ho trhají na kusy, kulky odráží), omezené pancéřování, zranitelná komunikace: když padne, Šediváci v okolí na chvíli ztratí obraz o bojišti. Doporučení: prioritně narušit komunikaci a vyřadit senzory; pokud to jde, zajistit nepoškozený exemplář.\n\nZ BOJE: Koho zaměří (zelený paprsek a pípnutí), o tom vědí všichni Šediváci v okolí. Nedá se omráčit.\n\n\"Největším nebezpečím Diskollu nejsou jeho zbraně. Je to skutečnost, že jakmile vás spatří, ví o vás celá nepřátelská armáda. Získání jediného funkčního exempláře by nám mohlo konečně odhalit, jak spolu ty zatracené věci komunikují.\" - Velitelství pozemních obranných sil, utajovaná zpráva"],
	"levit_velitel": ["Levit Mírotvůrce", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: LEVIT MÍROTVŮRCE. Klasifikace: Mimozemská biologicky modifikovaná velitelská jednotka. Stupeň ohrožení: EXTRÉMNÍ. Status: Nepřátelský - velitel teroristických jednotek invazních sil.\n\nPOPIS HROZBY: Levit Mírotvůrce představuje výrazně pokročilejší a nebezpečnější variantu standardních Levitů. Tato groteskně modifikovaná bytost zastává funkci velitele mimozemských teroristických jednotek, jejichž hlavním úkolem je šíření strachu, likvidace odporu a systematické zastrašování lidské populace.\nNa rozdíl od běžných Levitů vykazuje Mírotvůrce známky samostatného taktického uvažování, schopnosti vyhodnocovat nebezpečí a omezeného pudu sebezáchovy. Není proto neobvyklé, že se při vážném poškození stáhne z boje, aby se následně vrátil v částečně regenerovaném stavu.\nJeho přítomnost má navíc zásadní vliv na ostatní Levity. Dosud neobjasněným biologickým nebo neurologickým mechanismem dokáže stimulovat jejich agresivitu, potlačovat zbytky sebezáchovných instinktů a přivádět je do stavu nekontrolovatelného vražedného běsnění.\n\nFYZIOLOGIE A VÝBAVA: Tělo Mírotvůrce vykazuje známky rozsáhlých chirurgických zásahů, genetických úprav a implantace pokročilých biomechanických systémů. Obličej je násilně deformován kovovými háky a fixačními implantáty, zatímco vnitřní orgány jsou propojeny soustavou hadic, energetických vodičů a podpůrných zařízení.\nSpodní část těla tvoří mohutný zesílený antigravitační orgán, obklopený množstvím organických chapadel. Na rozdíl od běžných Levitů je tento orgán stabilizován dodatečnými mechanickými systémy a vyzařuje intenzivní fialovou záři.\nNejvýznamnější biologickou odlišností je schopnost částečné regenerace. Poškozené tkáně se dokážou postupně obnovovat, pokud má jednotka dostatek času a není vystavena dalším útokům. Regenerace pravděpodobně využívá energetické rezervy uložené v antigravitačním orgánu.\nJeho tělesná konstrukce je výrazně odolnější než u standardních Levitů a snese značné poškození.\nHlavní výzbroj tvoří těžká plazmová puška, schopná vypouštět vysoce energetické fialové projektily. Zbraň představuje vážné nebezpečí pro pěchotu i lehce obrněné cíle.\n\nTAKTICKÉ HODNOCENÍ:\n- Silné stránky: Vysoká odolnost, částečná regenerace, schopnost letu, taktická inteligence, těžká plazmová výzbroj, zesilování agresivity spojeneckých Levitů, psychologické zastrašování.\n- Slabiny: Regenerace vyžaduje čas, závislost na podpůrných biomechanických systémech, pravděpodobná zranitelnost energetických rozvodů a antigravitačního orgánu.\n- Doporučený postup: Absolutní priorita při střetu se skupinou Levitů. Eliminovat Mírotvůrce před zahájením boje s ostatními jednotkami. Nedovolit mu stáhnout se a regenerovat. Soustředit palbu na podpůrné systémy a antigravitační orgán. Vyhnout se dlouhotrvajícím střetům.\n\nZÁVĚREČNÉ UPOZORNĚNÍ: \"Mysleli jsme, že už jsme viděli všechno. Pak přišla ta větší věc. Fialová, obalená hadicemi, s obličejem roztrhaným železem. Ostatní Leviti začali vydávat příšerné zvuky a vrhli se na nás jako vzteklá zvířata. Ale ten velký jen visel ve vzduchu a díval se. Přísahám, že nás pozoroval. Když jsme ho konečně zasáhli, ustoupil. O deset minut později se vrátil. Rány, které jsme mu způsobili, byly pryč. Bože, co to s nimi udělali?\" - Poslední zaznamenané hlášení velitele 4. obranné čety, utajovaná zpráva Velitelství pozemních obranných sil"],
	"levit": ["Levit", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: LEVIT. Klasifikace: mimozemská biologicko-technologická jednotka. Stupeň ohrožení: VYSOKÝ. Status: nepřátelský - útočná a únosová jednotka invazních sil.\n\nPOPIS HROZBY: Létající mutant. Horní polovina připomíná člověka - lebeční tvář bez rtů plná zubů, rudé oči, kovové implantáty a hadice vedoucí do zádové nádrže. Spodní polovinu tvoří pulzující antigravitační orgán, ze kterého vyrůstají chapadla. Vyletí na střechu nebo do okna v patře, vystřelí a je jinde.\n\nFYZIOLOGIE A VÝBAVA: Antigravitační orgán drží tělo ve vzduchu a nese ho na tryskách. Laserová puška střílí rudé paprsky. Chapadly dokáže strhnout osamoceného vojáka ze země a odnést ho pryč - unesení se už nevracejí.\n\nTAKTICKÉ HODNOCENÍ: Silné stránky - pohyb ve třech rozměrech, rychlé přesuny, únosy. Slabiny - zranitelný antigravitační orgán a organická spodní část těla: zásah do spodní poloviny bolí víc. Plazma, lasery a výbuchy ho trhají. Doporučení: nechodit sám, dívat se nahoru. Když chapadla někoho zvednou, okamžitě střílet do Levita - jinak kamaráda odnese.\n\n\"Miller byl dva kroky za mnou. Pak zasyčely trysky, chapadla ho zvedla ze země a za vteřinu byl nad střechami. Ještě jsem slyšel, jak volá. Nikdy jsme ho nenašli.\" - přeživší voják, výpověď po misi"],
	"ohar": ["Ohař", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: OHAŘ. Klasifikace: Mimozemská biologicky modifikovaná lovecká jednotka. Stupeň ohrožení: VYSOKÝ. Status: Nepřátelský - doprovodná predátorská jednotka teroristických sil.\n\nPOPIS HROZBY: Ohař je specializovaná lovecká a pronásledovací jednotka nasazovaná především jako doprovod Levitů během jejich operací. Na první pohled vzdáleně připomíná šelmu, avšak jeho anatomie je zjevně výsledkem brutálních chirurgických zásahů, biomechanických úprav a neznámých experimentů.\nPrimární funkcí Ohaře je vyhledání, pronásledování a fyzická likvidace živých cílů v náročném terénu. Jednotka dává přednost přepadení ze zálohy, útoku ze stínu a brutálnímu boji na krátkou vzdálenost. Její bojový styl je založen na zastrašení, prudkém výpadu a co nejrychlejším roztrhání oběti.\nOhař není pouze útočná jednotka, ale i prostředek psychologického nátlaku. Jeho náhlý výpad a děsivý řev byly opakovaně popsány jako moment, při kterém dochází k panice, dezorientaci a dočasnému ochromení méně zkušeného personálu.\n\nFYZIOLOGIE A VÝBAVA: Tělo Ohaře nese výrazné známky chirurgických úprav. Kůže a svalovina jsou na mnoha místech narušeny, vyztuženy kovovými prvky, svorkami a implantáty. Navzdory těmto deformacím se pohybuje překvapivě tiše, rychle a koordinovaně.\nJeho protáhlý čenich je zakončen ostrou kostěnou nebo implantovanou čepelí, kterou používá k bodání, rozpárání měkkých cílů a prorážení ochranných prvků výstroje. Čelisti jsou uzpůsobeny k trhání tkání a spolu s drápy na končetinách z něj činí mimořádně nebezpečného predátora.\nPředpokládá se, že smyslové orgány Ohaře jsou přizpůsobeny lovu v šeru, mlze a zalesněném prostředí. Je schopen efektivně využívat terén, skrývat se, obcházet cíl a vyčkávat na ideální okamžik k útoku.\n\nTAKTICKÉ HODNOCENÍ:\n- Silné stránky: Vysoká rychlost, tichý pohyb, efektivní využití terénu, silný psychologický efekt, prudký útok ze zálohy, smrtící boj na krátkou vzdálenost, ostrá čepel na čenichu.\n- Slabiny: Omezené pancéřování, nutnost přiblížit se k cíli, pravděpodobná nižší efektivita na otevřeném prostranství bez krytu.\n- Doporučený postup: Vyvarovat se izolace jednotlivců a zajistit vzájemné krytí. Při kontaktu udržovat odstup a nenechat jednotku přiblížit se na dosah výpadu. Ve zalesněném a členitém terénu zvýšit ostražitost a kontrolovat slepé úhly.\n\nZÁVĚREČNÉ UPOZORNĚNÍ: \"Nejdřív jsme slyšeli jen šustění. Pak ticho. A potom ten řev. Nebyl to zvuk zvířete, byl to zvuk něčeho, co už dávno nemělo žít. Voják vedle mě se ani nestihl otočit. Ta věc na něj vyletěla ze tmy a během pár vteřin z něj zbyla jen krev a kusy výstroje. Jestli někdy uslyšíte Ohaře dřív, než ho uvidíte, už je téměř pozdě.\" - Záznam přeživšího člena lesní hlídky, utajovaná zpráva Velitelství pozemních obranných sil"],
	"jestetan": ["Ještěřan", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: JEŠTĚŘAN. Klasifikace: Mimozemská reptiloidní těžká pěchota. Stupeň ohrožení: KRITICKÝ. Status: Nepřátelský - těžká útočná jednotka invazních sil.\n\nPOPIS HROZBY: Ještěřan představuje jednu z nejodolnějších dosud identifikovaných biologických jednotek mimozemských invazních sil. Tito mohutní reptiloidní tvorové dosahují výšky přes dva a půl metru a disponují mimořádnou fyzickou silou, přirozeným pancéřováním a překvapivě vysokou přesností střelby.\nPrimárním úkolem Ještěřanů je přímý útok na opevněné pozice, likvidace nepřátelské pěchoty a prorážení obranných linií. Jejich pomalý pohyb kompenzuje extrémní odolnost, která jim umožňuje pokračovat v boji i po zásazích, jež by běžného člověka okamžitě vyřadily.\nZvláštní pozornost zasluhuje jejich schopnost operovat v nočních podmínkách. Pozorování z bojových střetů naznačují, že právě ve tmě dosahují nejvyšší bojové efektivity.\n\nFYZIOLOGIE A VÝBAVA: Ještěřani disponují mohutnou svalovou strukturou, silnými končetinami a pokožkou tvořenou mimořádně odolnými šupinami. Jejich přirozená ochrana je natolik účinná, že používají pouze lehké hrudní pancéřování, které chrání nejzranitelnější orgány.\nProtáhlá lebka je vybavena obrovskými čelistmi, jejichž stisk dokáže způsobit devastující poranění. Dlouhé drápy a masivní ocas představují další nebezpečí při boji na krátkou vzdálenost.\nHlavní výzbroj tvoří plazmové pušky mimozemské konstrukce, které Ještěřani ovládají s nečekanou přesností. Navzdory jejich těžkopádnému vzhledu vykazují mimořádně stabilní zaměřování, zejména v prostředí se sníženou viditelností.\nDosud není známo, zda jejich mimořádná odolnost vychází výhradně z přirozené anatomie, nebo zda byla dodatečně posílena neznámými biologickými úpravami.\n\nTAKTICKÉ HODNOCENÍ:\n- Silné stránky: Extrémní fyzická odolnost, přirozené pancéřování, vysoká síla, ničivé čelisti a drápy, přesná střelba, mimořádná efektivita při nočních operacích.\n- Slabiny: Nízká rychlost pohybu, omezená schopnost rychle měnit pozice. Další fyziologické slabiny zatím nebyly potvrzeny.\n- Doporučený postup: Vyvarovat se přímého střetu na krátkou vzdálenost. Využívat pohyblivé jednotky, krytí a koordinovanou palbu. Při nočních operacích počítat s vysokou přesností nepřátelské střelby. Vzhledem k jejich odolnosti se nedoporučuje podceňovat ani jednotlivé izolované exempláře.\n\nZÁVĚREČNÉ UPOZORNĚNÍ: \"Vypálili jsme do něj snad celý zásobník. Ani se nezastavil. Jen pomalu otočil tu svou zatracenou hlavu a zamířil. První ranou dostal našeho kulometčíka, druhou prostřelil kryt. Když jsme se pokusili ustoupit, prostě šel dál. Pomalu, beze spěchu, jako by přesně věděl, že mu nemáme čím ublížit. Nevím, co jsou zač, ale jestli jich sem pošlou stovky, máme zatraceně velký problém.\" - Výpověď přeživšího desátníka 12. mechanizované roty, utajovaná zpráva Velitelství pozemních obranných sil"],
	"jestetan_velitel": ["Ještěřan velitel", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: JEŠTĚŘAN VELITEL. Klasifikace: Mimozemská reptiloidní elitní pěchota / specializovaný lovec. Stupeň ohrožení: EXTRÉMNÍ. Status: Nepřátelský - velitelská a infiltrační jednotka invazních sil.\n\nPOPIS HROZBY: Ještěřan Velitel představuje výrazně nebezpečnější variantu standardní reptiloidní pěchoty. Kromě mimořádné fyzické odolnosti a síly disponuje pokročilou technologií maskování, která mu umožňuje stát se prakticky neviditelným pro lidské oko.\nNa rozdíl od běžných Ještěřanů vykazuje tento jedinec značnou inteligenci, trpělivost a schopnost samostatného taktického rozhodování. Jeho způsob boje připomíná spíše chování zkušeného predátora než standardního vojáka.\nNamísto přímého útoku se snaží nepřátelské jednotky rozdělovat, izolovat jednotlivce a následně je zneškodnit. Zvláštní pozornost zasluhuje skutečnost, že své oběti často neusmrcuje okamžitě, ale pokouší se je omráčit, znehybnit a odvléct z bojiště.\nÚčel těchto únosů zůstává neznámý. Dosud nebyl potvrzen návrat žádného z takto zajatých vojáků.\n\nFYZIOLOGIE A VÝBAVA: Ještěřan Velitel disponuje mohutným tělem pokrytým silnými šupinami, které poskytují značnou přirozenou ochranu. Na rozdíl od běžných příslušníků svého druhu používá kompletní bojovou zbroj z neidentifikované slitiny, která výrazně zvyšuje jeho odolnost vůči konvenčním zbraním.\nJeho výstroj zahrnuje pokročilý optický systém integrovaný do ochranných brýlí. Jejich přesná funkce není známa, ale velitelské jednotky byly pozorovány při efektivním vedení boje i za plného denního světla.\nNejnebezpečnějším prvkem jeho vybavení je aktivní maskovací zařízení, které dokáže téměř dokonale skrýt jeho tělo před vizuálním pozorováním. Zda technologie ovlivňuje také tepelné a radarové systémy, nebylo dosud potvrzeno.\nHlavní výzbroj tvoří pokročilá plazmová puška. Kromě střelných zbraní využívá své obrovské čelisti, drápy a fyzickou sílu k přemožení protivníků.\nJeho vysoká inteligence naznačuje, že se nejedná pouze o silnějšího vojáka, ale o specializovaného lovce schopného plánovat přepadení, využívat slabiny protivníka a koordinovat ostatní jednotky.\n\nTAKTICKÉ HODNOCENÍ:\n- Silné stránky: Extrémní fyzická odolnost, zesílené pancéřování, aktivní neviditelnost, vysoká inteligence, přesná střelba, schopnost přepadení, efektivní boj za denního světla, schopnost zneškodňovat a unášet živé cíle.\n- Slabiny: Nižší přirozená rychlost pohybu, závislost na maskovacím zařízení, možné krátkodobé narušení maskování při útoku nebo fyzickém kontaktu. Další slabiny nebyly potvrzeny.\n- Doporučený postup: Za žádných okolností nedovolit rozdělení družstva. Udržovat nepřetržitý vizuální kontakt mezi vojáky a pravidelně kontrolovat okolní prostor. Při podezření na přítomnost maskované jednotky využívat pohybové senzory a plošné průzkumné prostředky. Zmizení jediného člena družstva považovat za bezprostřední ohrožení celé jednotky.\n\nZÁVĚREČNÉ UPOZORNĚNÍ: \"Viděli jsme ho stát na kopci. Obrovský ještěr v pancíři. Pak prostě zmizel. Mysleli jsme, že se stáhl, jenže o pár minut později jsme ztratili spojení s naším zadním střelcem. Našli jsme jen jeho pušku. Potom zmizel další. Nikdo nic neslyšel. Teprve když jsme se stáhli na otevřené prostranství, zahlédl jsem v dálce, jak něco obrovského táhne našeho seržanta do lesa. Byl pořád naživu. Snažil se křičet, ale nemohl. Ta věc ho odnesla, jako by nic nevážil. A víte, co je nejhorší? Mám pocit, že nás ten parchant celou dobu jen zkoušel.\" - Výpověď jediného přeživšího člena průzkumného družstva Bravo-6, utajovaná zpráva Velitelství pozemních obranných sil"],
	"lihnoun": ["Líhavec", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: LÍHAVEC. Klasifikace: Mimozemská parazitická biologická útočná jednotka. Stupeň ohrožení: EXTRÉMNÍ. Status: Nepřátelský - teroristická a reprodukční jednotka invazních sil.\n\nPOPIS HROZBY: Líhavec představuje jednu z nejděsivějších forem mimozemské biologické agrese zaznamenané na území Země. Nejde pouze o útočnou jednotku, ale o živý nástroj šíření dalších nepřátelských organismů.\nPrimární funkcí Líhavce je napadnout živý cíl, znehybnit jej a implantovat do jeho těla vejce. Z nich se následně vyvíjí nové organismy, které se rodí přímo z útrob hostitele. Proces je extrémně brutální a ve všech známých případech končí smrtí napadeného jedince.\nLíhavec je zjevně stvořen k vyvolávání paniky a psychického zhroucení. Jeho samotná přítomnost na bojišti představuje nejen fyzické, ale i morální ohrožení. Vojáci, kteří vědí, co tato bytost dokáže, často reagují známkami silného stresu ještě před přímým kontaktem.\n\nFYZIOLOGIE A VÝBAVA: Tělo Líhavce je tvořeno odolnou, tmavou a slizkou tkání, která je na mnoha místech chráněna tvrdým chitinovým povrchem. Ten poskytuje vysokou ochranu proti běžným střelným zbraním a zároveň zachovává tvorovi značnou pohyblivost.\nJednotka je rychlá, obratná a navzdory své velikosti se pohybuje překvapivě plynule. Dlouhé končetiny zakončené drápy jí umožňují prudké výpady, uchopení kořisti a její následné znehybnění.\nNa zádech nese soustavu chapadlovitých orgánů, které pravděpodobně slouží jak k manipulaci s obětí, tak k procesu implantace. Tyto orgány jsou propojeny s vakovitými strukturami nesoucími reprodukční materiál.\nHlava je vybavena mohutnými čelistmi plnými ostrých zubů, které slouží k trhání tkání i k zastrašování. Celková anatomie naznačuje, že Líhavec není určen pro dlouhé přestřelky, ale pro rychlý útok, fyzické přemožení a biologickou kontaminaci cíle.\n\nTAKTICKÉ HODNOCENÍ:\n- Silné stránky: Vysoká odolnost, chitinová ochrana, značná rychlost, silný psychologický účinek, schopnost znehybnit cíl, parazitická reprodukce prostřednictvím hostitele.\n- Slabiny: Nutnost přímého kontaktu s cílem při implantaci, závislost na fyzickém přemožení oběti, pravděpodobná zranitelnost měkčích slizkých částí mezi chitinovými pláty.\n- Doporučený postup: Za žádných okolností nedovolit jednotce přiblížit se na dosah. Napadeného vojáka okamžitě izolovat a zabezpečit. V případě ztráty člena družstva předpokládat možnost implantace. Při střetu využívat soustředěnou palbu a nepodceňovat ani jednotlivý exemplář.\n\nZÁVĚREČNÉ UPOZORNĚNÍ: \"Nejdřív jsme si mysleli, že je to jen další bestie. Pak jsme našli Nováka. Ještě žil. Nemohl mluvit, jen se zmítal a snažil se něco dostat ze sebe ven. Když jsme rozřízli vestu, jeho břicho se pohnulo. Už jsme mu nemohli pomoct. Jestli někde uvidíte Líhavce, nestřílíte jen kvůli sobě. Střílíte kvůli všemu, co by mohlo přijít po něm.\" - Výpověď polního medika 3. obranného oddílu, utajovaná zpráva Velitelství pozemních obranných sil"],
	"zombie": ["Nakažený", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: NAKAŽENÝ. Klasifikace: Infikovaný lidský hostitel / přechodná biologická fáze. Stupeň ohrožení: VYSOKÝ. Status: Nepřátelský - biologicky kompromitovaný nosič mimozemského organismu.\n\nPOPIS HROZBY: Nakažený je lidský hostitel infikovaný reprodukčním zárodkem Líhavce. Nejde ještě o plně přeměněnou mimozemskou jednotku, ale o přechodné stádium mezi živým člověkem a biologickým inkubátorem.\nV této fázi hostitel postupně ztrácí kontrolu nad vlastním tělem i myslí. Ve většině zaznamenaných případů vykazuje známky extrémní bolesti, dezorientace, omezené komunikace a narůstající agresivity. Výsledné chování často připomíná primitivní \"živou mrtvolu\" - jedinec se pohybuje nekoordinovaně, působí otupěle, ale může být nečekaně nebezpečný při přiblížení.\nKonečné stadium infekce končí protržením těla hostitele a zrozením nového organismu. Tento proces je vždy smrtelný.\n\nFYZIOLOGIE A VÝBAVA: Tělo Nakaženého nese jasné známky postupující vnitřní invaze. V oblasti břicha se vytváří výrazná deformace způsobená růstem mimozemských vajec nebo zárodků. Hostitel bývá shrbený, pohybuje se trhavě a často si instinktivně chrání zasaženou oblast.\nPleť má nezdravý, zašedlý nebo našedle bledý odstín. Obličej bývá zkřivený bolestí, oči skelné nebo nepřítomné. V pozdějších fázích může dojít k výraznému úpadku motoriky i psychických funkcí.\nNakažený obvykle nenosí žádnou zvláštní výzbroj. Nebezpečí nepředstavuje jen fyzickým kontaktem, ale především tím, co v sobě ukrývá. Každý takový jedinec je v podstatě chodící inkubační schránkou pro vznik další nepřátelské entity.\n\nTAKTICKÉ HODNOCENÍ:\n- Silné stránky: Psychologický dopad na personál, nepředvídatelné chování, možnost napadnout nepřítele v zoufalém stavu, představuje biologickou hrozbu i po zneškodnění.\n- Slabiny: Omezená koordinace, výrazně snížená bojová efektivita, pomalejší reakce, vysoká fyzická zátěž způsobená infekcí.\n- Doporučený postup: Každého podezřelého jedince okamžitě izolovat. Zabránit přímému kontaktu bez ochranných prostředků. Pokud je potvrzena pokročilá fáze infekce, považovat hostitele za kritické biologické riziko. Manipulaci s tělem provádět pouze ve specializovaném režimu biologického ohrožení.\n\nZÁVĚREČNÉ UPOZORNĚNÍ: \"Pořád to byl člověk. Aspoň na chvíli. Dýchal, díval se na nás a pokoušel se něco říct. Ale v očích už nebyl on. Jen bolest. Břicho se mu hýbalo, jako by pod kůží něco žilo. Když jsme pochopili, co se děje, bylo pozdě. Jestli někdo vypadá jako přeživší, ještě to neznamená, že ho můžeme zachránit.\" - Záznam polního zdravotníka, biologicky kontaminovaná zóna, utajovaná zpráva Velitelství pozemních obranných sil"],
	"bijec": ["Bijec", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: BIJEC. Klasifikace: Mimozemská geneticky modifikovaná těžká útočná jednotka. Stupeň ohrožení: EXTRÉMNÍ. Status: Nepřátelský - elitní bojová jednotka invazních sil.\n\nPOPIS HROZBY: Bijec představuje jednu z nejnebezpečnějších dosud zaznamenaných pozemních jednotek mimozemských invazních sil. Na rozdíl od ostatních nepřátelských organismů, které často zastávají specializované role, byl Bijec zjevně vytvořen za jediným účelem - vyhledat nepřítele, překonat jeho obranu a zlikvidovat jej.\nTato geneticky modifikovaná bytost vzdáleně připomíná člověka, avšak její anatomie vykazuje extrémní svalový rozvoj, abnormální tělesné proporce a známky rozsáhlých biologických úprav.\nPřes svou mohutnou postavu vykazuje Bijec překvapivě vysokou inteligenci a schopnost taktického rozhodování. Dokáže vyhodnocovat bojovou situaci, využívat krytí, identifikovat prioritní cíle a přizpůsobovat své chování nepřátelskému odporu.\nNení to bezmyšlenkovité monstrum. Je to dokonale vycvičená a pravděpodobně geneticky naprogramovaná válečná mašina.\n\nFYZIOLOGIE A VÝBAVA: Bijec disponuje mimořádně vyvinutou svalovou strukturou, extrémní fyzickou silou a organismem schopným snášet značné poškození. Jeho tělo vykazuje výrazně vyšší odolnost než běžná lidská anatomie.\nCelý organismus je chráněn těžkou syntetickou zbrojí z dosud neidentifikovaného materiálu, která přesně kopíruje anatomii svého nositele. Zbroj pravděpodobně poskytuje nejen balistickou ochranu, ale také podporuje pohyb a fyzický výkon jednotky.\nNavzdory své mohutnosti se Bijec pohybuje překvapivě koordinovaně. Je schopen rychlých reakcí, přesného zaměřování a účinného boje na krátkou i střední vzdálenost.\nHlavní výzbroj tvoří výkonná energetická puška, která v kombinaci s jeho fyzickou silou představuje vážné nebezpečí pro pěchotu i opevněné pozice.\nPozorování naznačují, že Bijec nevykazuje strach ani běžné reakce na bolest. Přesto si zachovává dostatečnou inteligenci k tomu, aby se vyhnul zbytečnému riziku a pokračoval v boji s maximální efektivitou.\n\nTAKTICKÉ HODNOCENÍ:\n- Silné stránky: Extrémní fyzická odolnost, vysoká síla, těžké syntetické pancéřování, taktická inteligence, přesná střelba, vysoká bojová efektivita, schopnost samostatného rozhodování, minimální reakce na bolest.\n- Slabiny: Velká tělesná silueta, omezená pohyblivost ve stísněných prostorách, pravděpodobná závislost některých obranných systémů na funkčnosti syntetické zbroje. Další slabiny zatím nebyly potvrzeny.\n- Doporučený postup: Vyhnout se přímému střetu jednotlivých vojáků. Nasazovat koordinovanou palbu více jednotek a těžší výzbroj. Nepodceňovat schopnost Bijce takticky reagovat na změny situace. Prioritně zabránit jeho proniknutí do obranných pozic. V případě ztráty palebné převahy doporučen okamžitý organizovaný ústup.\n\nZÁVĚREČNÉ UPOZORNĚNÍ: \"Když se objevil, mysleli jsme, že je to nějaký jejich obrněný robot. Vypálili jsme na něj všechno, co jsme měli. Kulky se odrážely od pancíře a on šel dál. Pak se zastavil. Ne proto, že bychom ho zranili. Zastavil se, protože pochopil, odkud střílíme. Obešel naše postavení, dostal se nám do boku a během minuty zlikvidoval celé kulometné družstvo. Ten parchant přemýšlel. A co bylo horší, přemýšlel rychleji než my. Jestli tohle není jejich nejsilnější pěchota, tak nás Bůh ochraňuj.\" - Výpověď přeživšího poručíka 9. obranného praporu, utajovaná zpráva Velitelství pozemních obranných sil"],
	"bijec_velitel": ["Bijec velitel", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: BIJEC VELITEL. Klasifikace: Mimozemská geneticky modifikovaná elitní těžká útočná jednotka. Stupeň ohrožení: KATASTROFICKÝ. Status: Nepřátelský - velitelská bojová jednotka invazních sil.\n\nPOPIS HROZBY: Bijec Velitel představuje pokročilejší, silnější a výrazně nebezpečnější variantu standardního Bijce. Pokud je běžný Bijec považován za dokonalý nástroj přímé likvidace, tato velitelská verze je jeho ještě brutálnější evolucí - bojovým organismem navrženým nejen k ničení nepřítele, ale i k vedení ostatních útočných jednotek.\nNa bojišti působí jako živé beranidlo, morální opora invazních sil a mobilní centrum taktické koordinace. Zatímco běžný Bijec je schopen samostatného rozhodování, Bijec Velitel navíc vykazuje velitelské instinkty a schopnost ovlivňovat průběh střetu ve větším měřítku.\nJeho přítomnost výrazně zvyšuje agresivitu a bojovou výkonnost spojeneckých jednotek. Při střetu byl opakovaně zaznamenán jeho mohutný řev, který zjevně neslouží pouze k zastrašení nepřítele, ale zároveň funguje jako signál povzbuzující spojence k vyššímu nasazení.\nPokud není zlikvidován dostatečně rychle, dokáže navázat spojení s dalšími invazními silami a přivolat posily, čímž může původně zvládnutelný střet přerůst v katastrofální situaci.\n\nFYZIOLOGIE A VÝBAVA: Bijec Velitel má ještě robustnější tělesnou konstrukci než běžné varianty. Jeho svalová hmota, hustota kosterní struktury a celková odolnost byly zjevně dále posíleny genetickými i biomechanickými úpravami.\nJe chráněn zesílenou syntetickou zbrojí z neznámého materiálu, která poskytuje vyšší ochranu proti střelným i energetickým zbraním. Pancíř je silnější, lépe členěný a pravděpodobně vybaven pokročilejšími vnitřními podpůrnými systémy.\nNa předloktí nese integrovaný velitelský ovládací přístroj, jehož účel není zcela objasněn. Předpokládá se, že zařízení slouží ke koordinaci jednotek, přenosu taktických dat a vyvolání posil.\nHlavní výzbroj tvoří těžká energetická zbraň vysokého výkonu, vhodná k ničení pěchoty, krytých pozic i lehce obrněných cílů. V boji zblízka spoléhá na obrovskou sílu, pancéřovanou tělesnou konstrukci a bezohlednou brutalitu.\nNa rozdíl od běžných Bijců vykazuje nejen taktickou inteligenci, ale i schopnost vědomě řídit tempo boje a využívat psychologický tlak proti nepříteli.\n\nTAKTICKÉ HODNOCENÍ:\n- Silné stránky: Extrémní odolnost, zesílená syntetická zbroj, vysoká síla, velitelská inteligence, schopnost povzbuzovat spojence, těžká energetická výzbroj, vysoká bojová efektivita, možnost přivolání posil.\n- Slabiny: Velká silueta, omezená obratnost v úzkém prostoru, vysoká priorita cíle - po jeho eliminaci může dojít k poklesu koordinace nepřátelských sil, pravděpodobná závislost velitelských funkcí na integrovaném ovládacím zařízení.\n- Doporučený postup: Eliminace Bijce Velitele musí být absolutní prioritou. Nedovolit mu prodlužovat střet, vydávat velitelské povely ani přivolat podporu. Zaměřit palbu na ovládací modul na předloktí a spoje pancéřování. Při jeho přítomnosti počítat se zvýšenou agresivitou všech okolních nepřátelských jednotek.\n\nZÁVĚREČNÉ UPOZORNĚNÍ: \"Mysleli jsme, že už horší verze toho monstra neexistuje. Pak jsme uslyšeli ten řev. Nebyl to jen zvuk - bylo to jako rozkaz. Všechno kolem něj se dalo do pohybu, jako by najednou dostali novou sílu. Ten obrněný parchant šel přímo proti nám, zatímco ostatní nás obcházeli ze stran. Když jsme ho nedokázali složit hned, aktivoval něco na ruce. O sedm minut později se z lesa začaly valit další jednotky. V tu chvíli nám došlo, že jestli toho prevíta nezabiješ včas, nezabíjíš už jen jeho. Podepisuješ rozsudek smrti celé své jednotce.\" - Záznam přeživšího seržanta 14. obranné skupiny, utajovaná zpráva Velitelství pozemních obranných sil"],
	"nador": ["Nádor", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: NÁDOR. Klasifikace: Mimozemský autonomní biologický orgán. Stupeň ohrožení: KRITICKÝ. Status: Nepřátelský - regenerativní biologická útočná jednotka invazních sil.\n\nPOPIS HROZBY: Nádor představuje jednu z nejpodivnějších a nejnebezpečnějších biologických jednotek mimozemských invazních sil. Na rozdíl od ostatních známých organismů se nejedná o plnohodnotného živočicha v běžném slova smyslu, ale o samostatně fungující, levitující orgán, schopný aktivního pohybu, vyhledávání nepřátel a přímého útoku.\nJeho původ zůstává neznámý. Předpokládá se, že jde o uměle vypěstovanou biologickou zbraň, která ke svému fungování nepotřebuje žádné další tělesné orgány.\nNejznepokojivější vlastností Nádoru je jeho mimořádná schopnost obnovy. Zaznamenané případy naznačují, že i po zdánlivém usmrcení dokáže po určité době znovu obnovit životní funkce a pokračovat v útoku.\nStandardní střelné zbraně proto představují pouze dočasné řešení. Jednotka, která byla jednou zneškodněna, se může znovu objevit v nejméně očekávaném okamžiku.\n\nFYZIOLOGIE A VÝBAVA: Tělo Nádoru tvoří nepravidelná masa organické tkáně pokrytá množstvím vystouplých cév, pulzujících výrůstků a slizkých membrán. Jeho povrch neustále vykazuje drobné kontrakce, jako by celý organismus tvořil jediný obrovský sval.\nZe spodní části vyrůstají dlouhá chapadla, která pravděpodobně slouží k udržování rovnováhy a manipulaci s okolními předměty. Samotný mechanismus levitace zůstává neobjasněn.\nPrimární útočnou schopností je vystřikování vysoce koncentrované kyseliny, kterou organismus dokáže pod značným tlakem vypudit přímo na nepřátelský cíl.\nTato agresivní biologická sloučenina vykazuje mimořádné korozivní vlastnosti. Dokáže během krátké doby narušovat ochranné materiály, kovové konstrukce i organickou tkáň. Běžná pěchotní výstroj proti ní neposkytuje spolehlivou ochranu.\nNejvětší hrozbou je však regenerativní mechanismus, který umožňuje organismu obnovit životní funkce i po rozsáhlém poškození.\nDosavadní bojová pozorování naznačují, že definitivní likvidace je možná pouze úplným roztrháním biologické struktury prostřednictvím výbušnin nebo jiné explozivní zbraně.\n\nTAKTICKÉ HODNOCENÍ:\n- Silné stránky: Schopnost levitace, vysoce korozivní kyselinový útok, mimořádná regenerace, schopnost opětovného oživení po zdánlivé smrti, nezávislé biologické fungování.\n- Slabiny: Omezená pohyblivost ve stísněném prostředí, měkká organická struktura, kritická zranitelnost explozivním poškozením, které způsobí úplné roztrhání těla.\n- Doporučený postup: Udržovat dostatečnou vzdálenost a zabránit přímému zásahu kyselinou. Konvenční palbu považovat pouze za prostředek dočasného zneškodnění. Pro trvalou eliminaci používat výhradně výbušné nebo explozivní zbraně schopné roztrhat organismus na kusy. Zneškodněné exempláře nepovažovat za definitivně mrtvé, dokud nebyla jejich biologická struktura zcela zničena.\n\nZÁVĚREČNÉ UPOZORNĚNÍ: \"Zasáhli jsme tu věc snad dvacetkrát. Spadla na zem a přestala se hýbat. Mysleli jsme, že je po všem. Pak začala znovu pulzovat. Nejdřív pomalu, potom rychleji. Než jsme stačili zareagovat, vznesla se a vystříkla na nás tu svou kyselinu. Prožrala se pancířem našeho transportéru jako papírem. Nakonec ji dostal granátometčík. Roztrhal ji na kusy. Teprve potom zůstala ležet. Jestli mám něco říct těm, co půjdou po nás, tak jedině tohle: Dokud z té věci něco zbývá, pořád ještě žije.\" - Výpověď přeživšího člena 6. mechanizované hlídky, utajovaná zpráva Velitelství pozemních obranných sil"],
	"ohnivec": ["Ohnivec", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: OHNIVEC. Klasifikace: Mimozemská termobiologická destrukční jednotka. Stupeň ohrožení: EXTRÉMNÍ. Status: Nepřátelský - specializovaná demoliční a vyhledávací jednotka invazních sil.\n\nPOPIS HROZBY: Ohnivec představuje mimořádně nebezpečný biologický organismus, jehož primární funkcí je systematická likvidace opevněných pozic, obranných struktur a podzemních zařízení.\nNavzdory relativně malým rozměrům a extrémně pomalému pohybu disponuje ničivým potenciálem, který výrazně převyšuje většinu dosud zaznamenaných mimozemských pozemních jednotek.\nOhnivec není určen k pronásledování nepřítele ani k přímým střetům s pohyblivými cíli. Jeho účelem je postupovat vpřed a zničit vše, co mu stojí v cestě. Nezastaví jej beton, pancéřové dveře ani nejodolnější slitiny používané lidskou armádou.\nZvláštní pozornost zasluhuje jeho schopnost vyhledávat skryté podzemní objekty. Ohnivec je vybaven neznámým seismickým smyslem, díky němuž dokáže zaznamenávat vibrace hluboko pod zemským povrchem.\nPředpokládá se, že mimozemské síly tyto organismy využívají k odhalování utajených vojenských základen, bunkrů a dalších obranných zařízení, jejichž polohu nelze snadno zjistit běžným průzkumem.\n\nFYZIOLOGIE A VÝBAVA: Tělo Ohnivce tvoří kompaktní masa šedivé organické tkáně pokrytá silnými, tepelně odolnými membránami. Pod jejich povrchem je patrný intenzivní oranžovožlutý žár, který prostupuje celým organismem.\nVnitřní struktury pravděpodobně fungují jako biologická pec, v níž dochází k vytváření a udržování extrémních teplot. Ohnivec dokáže tuto energii soustředit a následně uvolnit v podobě vysoce koncentrovaného tepelného výboje, schopného propalovat i nejsilnější ochranné materiály.\nPovrch organismu je na několika místech vybaven tvrdými výrůstky, jejichž přesná funkce zůstává neznámá. Mohou sloužit k odvádění přebytečné energie nebo ke stabilizaci vnitřního žáru.\nOhnivec se pohybuje mimořádně pomalu a nevykazuje téměř žádnou snahu vyhýbat se překážkám. Namísto jejich obcházení je jednoduše ničí.\nNejzajímavější vlastností organismu je seismické vnímání. Dokáže zachytit a rozlišovat vibrace procházející horninami, půdou a pravděpodobně i rozsáhlými podzemními konstrukcemi. Tato schopnost z něj činí mimořádně nebezpečný nástroj při vyhledávání skrytých lidských základen.\n\nTAKTICKÉ HODNOCENÍ:\n- Silné stránky: Extrémní tepelný výkon, schopnost propalovat nejodolnější materiály, vysoká tepelná odolnost, seismické vyhledávání podzemních objektů, mimořádná účinnost proti opevněním, schopnost systematické destrukce infrastruktury.\n- Slabiny: Extrémně nízká rychlost pohybu, omezená schopnost pronásledovat pohyblivé cíle, výrazná tepelná stopa usnadňující detekci. Další fyziologické slabiny zatím nebyly potvrzeny.\n- Doporučený postup: Při identifikaci Ohnivce v blízkosti vojenského zařízení vyhlásit nejvyšší stupeň ohrožení. Zabránit jeho přiblížení k obranným strukturám a podzemním komplexům. Nepokoušet se jej zastavit pomocí běžných fyzických překážek. Prioritně využívat útoky z bezpečné vzdálenosti a vyhnout se přímému vystavení tepelnému výboji.\n\nZÁVĚREČNÉ UPOZORNĚNÍ: \"Byla to jen malá hromada masa. Sotva se to hýbalo. Smáli jsme se, že jim snad došli pořádní vojáci. Pak se ta věc zastavila nad naším bunkrem. Začala zářit. Nejdřív červeně, potom žlutě, až se na ni nedalo dívat. Beton pod ní se začal tavit. Ocelové výztuhy tekly jako vosk. Za necelou minutu se propálila stropem do podzemního skladu. Celý komplex zachvátil požár. Víte, co mě děsí nejvíc? Ta věc se vůbec nepokoušela hledat vchod. Prostě věděla, že jsme pod ní. A věděla přesně, kde má začít.\" - Výpověď přeživšího technika podzemního obranného komplexu Delta-9, utajovaná zpráva Velitelství pozemních obranných sil"],
	"myslodej": ["Mysloděj", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: MYSLODĚJ. Klasifikace: Mimozemská elitní psionická velitelská jednotka. Stupeň ohrožení: KATASTROFICKÝ. Status: Nepřátelský - vrchní koordinátor a strategický velitel invazních sil.\n\nPOPIS HROZBY: Mysloděj představuje dosud nejvyšší identifikovanou úroveň mimozemské velitelské hierarchie. Tyto záhadné, neustále levitující bytosti disponují psychickými schopnostmi, které dalece přesahují vše, s čím se lidské ozbrojené síly dosud setkaly.\nNa rozdíl od ostatních invazních jednotek, které se spoléhají na fyzickou sílu, technologickou převahu nebo početní výhodu, Mysloděj představuje absolutní nadvládu nad myslí protivníka.\nJeho hlavní funkcí je koordinace rozsáhlých mimozemských formací, řízení bojových operací a ovlivňování chování nepřátelských sil. Předpokládá se, že jediný Mysloděj dokáže současně ovládat nebo koordinovat stovky podřízených organismů.\nZvláště znepokojivá je jeho schopnost zasahovat přímo do lidského vědomí. Dokáže manipulovat s myšlenkami, vytvářet přesvědčivé iluze a přimět jednotlivce jednat proti vlastní vůli.\nPřítomnost Mysloděje na bojišti může znamenat, že mimozemská invaze přešla od lokálních útoků k rozsáhlé strategicky koordinované operaci.\n\nFYZIOLOGIE A VÝBAVA: Mysloděj má humanoidní postavu zahalenou v dlouhém tmavě fialovém rouchu, které zcela zakrývá jeho skutečnou anatomii. Pod kapucí není možné běžným pozorováním rozeznat obličej. Z temnoty vystupují pouze nepravidelné projevy fialové psionické energie.\nJeho ruce jsou neúměrně krátké, nedostatečně vyvinuté a téměř dokonale černé. Celková fyzická konstrukce působí křehce a nevhodně pro jakýkoliv přímý boj.\nTento nedostatek však zcela kompenzuje mimořádně rozvinutými psionickými schopnostmi.\nMysloděj dokáže pronikat do vědomí živých organismů, ovlivňovat jejich rozhodování, narušovat smyslové vnímání a vytvářet iluze, které oběť nedokáže snadno odlišit od reality.\nMezi jeho nejnebezpečnější schopnosti patří přímé mentální ovládnutí protivníka, při kterém může dočasně převzít kontrolu nad jeho jednáním. Takto ovlivnění vojáci mohou představovat bezprostřední nebezpečí pro vlastní jednotku.\nMysloděj rovněž disponuje schopností teleportace, která mu umožňuje okamžitě měnit pozici, uniknout z nebezpečí nebo se objevit na strategicky výhodném místě.\nJeho levitace a manipulace s okolními předměty naznačují rozsáhlé možnosti psychokinetického působení.\nNení známo, zda Mysloděj používá nějakou technologii zesilující jeho schopnosti, nebo zda všechny tyto jevy vycházejí přímo z jeho biologické podstaty.\n\nTAKTICKÉ HODNOCENÍ:\n- Silné stránky: Extrémní psionická síla, ovládání mysli, vytváření iluzí, narušování smyslového vnímání, teleportace, levitace, strategická inteligence, koordinace rozsáhlých invazních sil.\n- Slabiny: Křehká fyzická anatomie, pravděpodobně nízká odolnost vůči přímému fyzickému poškození. Další slabiny nebyly potvrzeny.\n- Doporučený postup: Přítomnost Mysloděje okamžitě hlásit vrchnímu velení. Nepovažovat vizuální ani zvukové informace za spolehlivé. Při podezření na mentální ovlivnění ověřovat identitu a rozkazy prostřednictvím nezávislých komunikačních kanálů. Zamezit přímému kontaktu a upřednostnit eliminaci z bezpečné vzdálenosti. Počítat s možností okamžité teleportace cíle.\n\nZÁVĚREČNÉ UPOZORNĚNÍ: \"Nikdy na nás nevystřelil. Ani jednou. Jen se vznášel nad zemí a díval se naším směrem. A pak začaly hlasy. Nejdřív jsem slyšel svou matku. Byla mrtvá už patnáct let. Volala mě domů. Vedle mě začal Harris plakat, protože prý viděl svou dceru. Náš kapitán najednou vytáhl pistoli a namířil na nás. Říkal, že jsme nepřátelé. Pak jsem toho tvora uviděl přímo před sebou. Byl tak blízko, že bych se ho mohl dotknout. Ale nemohl jsem se pohnout. A v hlavě se mi ozval hlas. Nebyl můj. Řekl jen: 'Vaše planeta už není vaše.' Potom zmizel. Když jsem se probral, všichni ostatní byli mrtví. Nevím, jestli je zabil on, nebo jsme se zabili navzájem.\" - Výpověď jediného přeživšího důstojníka operace Tiché nebe, přísně tajná zpráva Velitelství pozemních obranných sil"],
	"kolos": ["Kolos", "VOJENSKÁ DATABÁZE - NEZNÁMÉ ENTITY\nKrycí označení: KOLOS. Klasifikace: Mimozemská autonomní těžká mechanizovaná jednotka. Stupeň ohrožení: KATASTROFICKÝ. Status: Nepřátelský - těžký bojový stroj invazních sil.\n\nPOPIS HROZBY: Kolos představuje jeden z nejnebezpečnějších mechanických bojových prostředků mimozemských invazních sil. Jedná se o mohutnou, pavoukovitě konstruovanou válečnou mašinerii, jejíž jedinou známou funkcí je vyhledávání a likvidace nepřátelských jednotek.\nNa rozdíl od biologických organismů není Kolos řízen živou posádkou. Disponuje autonomní strojovou inteligencí, která mu umožňuje samostatně vyhodnocovat situaci, vybírat prioritní cíle a koordinovat vlastní pohyb i palbu.\nNavzdory obrovským rozměrům vykazuje překvapivou rychlost a obratnost. Nejznepokojivější vlastností je však téměř neslyšitelný pohyb. Kolos dokáže překonávat rozsáhlé vzdálenosti bez výrazných mechanických zvuků, což značně komplikuje jeho včasnou identifikaci.\nZaznamenány byly také případy, kdy se tyto stroje pohybovaly po svislých stěnách budov a jiných konstrukcích. Tato schopnost jim umožňuje obcházet obranné linie a útočit ze směrů, které lidské jednotky běžně nepovažují za přístupné těžké technice.\n\nFYZIOLOGIE A VÝBAVA: Kolos je tvořen rozsáhlou soustavou mechanických částí chráněných těžkým pancéřováním z dosud neidentifikované mimozemské slitiny.\nJeho konstrukce vzdáleně připomíná obrovského pavouka. Osm dlouhých mechanických končetin umožňuje rychlý pohyb v členitém terénu, překonávání překážek a stabilní vedení palby i na téměř svislých plochách.\nMechanismus, který umožňuje tak mohutnému stroji pohybovat se prakticky bezhlučně, zůstává neznámý. Předpokládá se využití pokročilých tlumicích systémů nebo technologie, která výrazně omezuje mechanické vibrace.\nHlavní výzbroj tvoří těžký plazmový kanón umístěný na horní části trupu, schopný zasahovat obrněná vozidla, opevněné pozice a rozsáhlejší cíle.\nSekundární výzbroj představuje dvojice rychlopalných plazmových kulometů, které slouží především k likvidaci pěchoty a potlačování nepřátelské palby.\nCentrální optický systém umožňuje nepřetržité sledování okolí a přesné zaměřování několika cílů současně.\nPřestože je Kolos plně mechanický, vykazuje mimořádně pokročilé taktické chování. Dokáže využívat terén, měnit útočné pozice a přizpůsobovat způsob boje aktuální situaci.\n\nTAKTICKÉ HODNOCENÍ:\n- Silné stránky: Extrémní pancéřování, vysoká rychlost, téměř neslyšitelný pohyb, schopnost šplhat po svislých plochách, autonomní strojová inteligence, těžký plazmový kanón, dvojice rychlopalných plazmových kulometů, vysoká přesnost střelby, schopnost útočit z nečekaných směrů.\n- Slabiny: Velká silueta, závislost na funkčnosti mechanických končetin a senzorových systémů, pravděpodobná zranitelnost pohyblivých spojů. Další konstrukční slabiny zatím nebyly potvrzeny.\n- Doporučený postup: Při identifikaci Kolosu okamžitě vyhlásit nejvyšší stupeň bojové pohotovosti. Nepovažovat výškové budovy ani vertikální překážky za bezpečné krytí. Využívat těžké protitankové zbraně a koordinovanou palbu. Prioritně se zaměřit na pohybové mechanismy a senzorové systémy. V případě nedostatečné palebné síly doporučen okamžitý ústup.\n\nZÁVĚREČNÉ UPOZORNĚNÍ: \"Slyšel jsem jen prasknutí betonu. Nic víc. Žádný motor, žádné kovové kroky, žádné hydraulické syčení. Prostě nic. Pak se nad námi něco pohnulo. Podíval jsem se nahoru a uviděl tu věc, jak visí na stěně osmipatrové budovy. Obrovský kovový pavouk. Ani nevím, jak se tam dostal. Jeho červené oko se otočilo přímo na nás. V tu chvíli jsem věděl, že nás má. Dvě spodní zbraně začaly střílet a naše obranná linie se během několika vteřin rozpadla. Když přijel tank, Kolos se prostě přesunul po fasádě, jako by gravitace vůbec neexistovala. Pak vypálil z horního kanónu. Tank zmizel v záblesku fialového světla. Nejhorší ale bylo, když střelba skončila. Ta věc se zase začala pohybovat. A znovu bylo úplné ticho.\" - Výpověď přeživšího velitele obranného stanoviště Echo-4, přísně tajná zpráva Velitelství pozemních obranných sil"],
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
## (0.50: everything costs about twice as much - credits are meant to matter)
const SHOP := {
	"rifle_clip": 80, "pistol_clip": 50, "shells": 60, "magnum_rounds": 70, "ac_clip": 160, "minigun_belt": 240,
	"rocket": 300, "grenade": 120, "smoke_grenade": 100, "mine": 180, "flare": 40, "medkit": 320,
	"laser_pistol": 600, "laser_rifle": 1200, "laser_cannon": 1800,
	"rifle": 500, "sniper": 900, "sniper_clip": 70, "shotgun": 500, "magnum": 440, "autocannon": 1200, "minigun": 1500, "rocket_launcher": 1300,
	"knife": 120, "stun_baton": 360, "scanner": 600, "radio": 80, "nvg": 700, "plasma_rifle": 1800, "plasma_cell": 180,
	"vesta": 600, "stit": 700, "pancir": 1800,
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
## Machines that blow up when they fall: what is left are scraps. After this many won missions
## with one shot down the workshop puts a whole one together (that counts as the body for research).
const WRECKS := {"diskoll": 3}

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

## The campaign's difficulty: chosen when it is founded, fixed until it ends.
func difficulty() -> String:
	return String(data.get("difficulty", Game.difficulty))

## How dear things are: prices of research, buildings, weapons, the Sokol (by difficulty).
func econ() -> float:
	return float({"easy": 1.0, "normal": 1.3, "veteran": 1.6}.get(difficulty(), 1.3))

## How long things take: research and construction (by difficulty).
func time_k() -> float:
	return float({"easy": 1.0, "normal": 1.25, "veteran": 1.5}.get(difficulty(), 1.25))

func research_cost(id: String) -> int:
	return int(round(float(RESEARCH[id]["cost"]) * econ() / 10.0) * 10)

func research_days(id: String) -> float:
	return float(RESEARCH[id]["days"]) * time_k()

func facility_cost(ft: String) -> int:
	return int(round(float(FACILITIES[ft]["cost"]) * econ() / 10.0) * 10)

func facility_days(ft: String) -> float:
	return ceilf(float(FACILITIES[ft]["days"]) * time_k())

func jet_price() -> int:
	return int(round(JET_PRICE * econ() / 10.0) * 10)

func new_campaign(diff := "") -> void:
	if diff == "":
		diff = Game.difficulty
	Game.difficulty = diff
	data = {
		"difficulty": diff, "mercs": {},
		"day": 0.0, "credits": {"easy": 1500, "normal": 1200, "veteran": 1000}.get(diff, 1200), "trust": 60, "month": 0,
		"research": {"done": [], "current": "", "progress": 0.0}, "bodies_v34": true,
		"armory": START_ARMORY.duplicate(), "orders": [], "missions": [], "next_mission": 0.15, "next_id": 1,
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
	if not data.is_empty():
		if not data.has("difficulty"):
			data["difficulty"] = Game.difficulty     # older saves: what was set when it was loaded
		if not data.has("mercs"):
			data["mercs"] = {}
		Game.difficulty = String(data["difficulty"])
	active = not data.is_empty()
	return active

## The host keeps every campaign mercenary (his own and the players'): name -> record.
## Returns the record to play with: the kept one when it is further along, else the given one (stored).
func keep_merc(m: Dictionary) -> Dictionary:
	if data.is_empty():
		return m
	var key := str(m.get("name", ""))
	if key == "":
		return m
	var mercs: Dictionary = data.get("mercs", {})
	var old: Dictionary = mercs.get(key, {})
	if not old.is_empty() and (int(old.get("missions", 0)) > int(m.get("missions", 0)) or (int(old.get("missions", 0)) == int(m.get("missions", 0)) and int(old.get("xp", 0)) > int(m.get("xp", 0)))):
		return old
	mercs[key] = m.duplicate(true)
	data["mercs"] = mercs
	save()
	return m

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
	_deliveries()
	# research
	var r: Dictionary = data["research"]
	if r["current"] != "":
		r["progress"] = float(r["progress"]) + days * (1.0 + 0.5 * (count("laborator") - 1))
		if float(r["progress"]) >= research_days(r["current"]):
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
			var lost_trust := int(round((15 if m["type"] == "terror" else 5) * (1.0 + war_stage())))     # (the later, the less patience)
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
				if String(f["kind"]) in ["supply", "battleship", "harvester"]:
					m["ufo"] = f["kind"]           # it lands as what flew
					m["size"] = UFO_SIZES[f["kind"]]
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
			data["next_raid"] = float(data["day"]) + rng.randf_range(lerpf(9.0, 4.0, war_stage()), lerpf(16.0, 8.0, war_stage()))
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
const UFO_NAMES := {"scout": "Průzkumník (malé)", "raider": "Nájezdník (střední)", "harvester": "Sklízeč (velké)",
	"supply": "Zásobovací loď (obří)", "battleship": "Bitevní loď (obří)"}
const UFO_ALIENS := {"scout": 0, "raider": 1, "harvester": 3, "supply": 4, "battleship": 6}
const UFO_SIZES := {"scout": "small", "raider": "medium", "harvester": "large", "supply": "huge", "battleship": "huge"}

func generate_flight() -> Dictionary:
	var lat := BASE_LAT + rng.randf_range(-12, 12)
	var lon := BASE_LON + rng.randf_range(-22, 22)
	if rng.randf() < 0.35:
		lat = rad_to_deg(asin(rng.randf_range(-0.8, 0.9)))
		lon = rng.randf_range(-180, 180)
	var kinds := ["scout", "scout", "raider", "raider", "harvester"]
	if float(data["day"]) < 4.0:
		kinds = ["scout", "scout", "raider"]
	elif int(data.get("month", 0)) >= 3:
		# late in the war the giants cross the sky too (0.56)
		kinds = ["scout", "raider", "raider", "harvester", "harvester", "supply", "battleship"]
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
	if jets() >= MAX_JETS or int(data["credits"]) < jet_price():
		return false
	data["credits"] = int(data["credits"]) - jet_price()
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
			m["size"] = UFO_SIZES[kind]
			m["ufo"] = kind            # the wreck is the ship you shot down
			m["extra_aliens"] = UFO_ALIENS[kind]
			m["reward"] = MTYPES["crash"]["reward"] + {"scout": 0, "raider": 200, "harvester": 450, "supply": 800, "battleship": 1100}[kind]
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
	p["allot"] = allot()
	p["nemesis"] = (data.get("nemesis", {}) as Dictionary).keys()
	p["armory"] = data["armory"].duplicate()
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
		data["base"][i2]["days"] = facility_days(ft) * 0.5
		txt += ", %s poničena (oprava %.0f dní)" % [FACILITIES[ft]["name"], facility_days(ft) * 0.5]
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
	var base: Dictionary = allot()
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

## Of what one merc lost, the pieces that were his own (the locker): the free allotment covers
## the first ones, his locker the next, the base's armory the rest.
func locker_part(kit: Array, lost: Dictionary, from_locker: Dictionary) -> Dictionary:
	var out := {}
	for it in lost:
		var n := int(lost[it])
		var had := kit.count(it)
		var free := mini(had, int(allot().get(it, 0)))
		var paid_lost := maxi(0, n - free)      # (what is lost counts against the free allotment first)
		var mine := mini(paid_lost, int(from_locker.get(it, 0)))
		if mine > 0:
			out[it] = mine
	return out

## The armory loses what the team took from it and did not bring back.
func _gear_lost(kits: Dictionary, lost: Dictionary, lockers: Dictionary) -> String:
	var gone := {}
	for peer in lost:
		var kit: Array = kits.get(peer, [])
		var mine := locker_part(kit, lost[peer], lockers.get(peer, {}))
		for it in lost[peer]:
			var n := int(lost[peer][it])
			var had := kit.count(it)
			var free := mini(had, int(allot().get(it, 0)))
			var paid_lost := maxi(0, n - free)
			var from_armory := paid_lost - int(mine.get(it, 0))
			if from_armory > 0:
				gone[it] = int(gone.get(it, 0)) + from_armory
	var l := []
	for it in gone:
		var have := int(data["armory"].get(it, 0))
		var g := mini(have, int(gone[it]))
		if g <= 0:
			continue
		data["armory"][it] = have - g
		if int(data["armory"][it]) <= 0:
			data["armory"].erase(it)
		l.append("%s %dx" % [Game.ITEMS[it]["short"] if Game.ITEMS.has(it) else it, g])
	return (" Ze skladu ubylo (spotřebováno nebo zůstalo venku): " + ", ".join(l) + ".") if not l.is_empty() else ""

func mission_done(id: int, success: bool, kills: int, captures: int, lost_mercs: int, civ_saved := 0, civ_dead := 0, races := [], loot := {}, wiped := false, kits := {}, q := 1.0, lost_gear := {}, lockers := {}) -> String:
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
	for r in WRECKS:
		var need := int(WRECKS[r])
		if int(found.get("trosky_" + r, 0)) >= need:
			found["trosky_" + r] = int(found["trosky_" + r]) - need
			found["corpse_" + r] = int(found.get("corpse_" + r, 0)) + 1
			got.append("%s 1x (seskládán z trosek)" % race_name(r))
			_log("Dílna seskládala z trosek celý kus: %s. Laboratoř ho může rozebrat." % race_name(r))
	data["found"] = found
	var gear_txt := _gear_lost(kits, lost_gear, lockers)
	_nemesis_tick()
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
	# the base's part of the reward (the mercenaries' pay goes to them, see the mission's end)
	var money := int(((int(int(m["reward"]) * 0.6) if success else 0) + kills * 40 + captures * 160 + civ_saved * 60) * q)
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
	var txt := "%s (%s): %s. Do rozpočtu základny +%d kr, důvěra %+d." % [info["name"], m["place"], "úspěch" if success else "neúspěch", money, dt]
	if lost_mercs > 0:
		txt += " Padlí: %d." % lost_mercs
	if civ_saved + civ_dead > 0:
		txt += " Civilisté: zachráněno %d, mrtvých %d." % [civ_saved, civ_dead]
	if not got.is_empty():
		txt += " Kořist: " + ", ".join(got) + "."
	if m["type"] == "base" and not success:
		txt += " " + _base_raided()
	elif wiped and not success:
		var kl := _kondor_lost({})
		txt += kl if transport() != "heli" else kl.replace("Kondoru", "Čápa").replace("Kondor", "Čáp")
	txt += gear_txt
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
		var cr := String(n["corpse"])
		if WRECKS.has(cr):
			var have := int(found.get("corpse_" + cr, 0)) > 0
			out.append(["trosky: %s (%d/%d)" % [race_name(cr), int(WRECKS[cr]) if have else int(found.get("trosky_" + cr, 0)), int(WRECKS[cr])], have])
		else:
			out.append(["tělo: " + race_name(cr), int(found.get("corpse_" + cr, 0)) > 0])
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
	if k.begins_with("trosky_"):
		return "trosky: " + race_name(k.substr(7))
	return String(LOOT_NAMES.get(k, k))

func start_research(id: String) -> bool:
	if not research_available(id) or data["research"]["current"] != "":
		return false
	var cost: int = research_cost(id)
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
	if cell["type"] != "" or int(data["credits"]) < facility_cost(ftype) or not can_build_at(index):
		return false
	data["credits"] = int(data["credits"]) - facility_cost(ftype)
	data["base"][index] = {"type": ftype, "days": facility_days(ftype)}
	_log("Stavba zahájena: " + f["name"])
	save()
	changed.emit()
	return true

func unlocked(item: String) -> bool:
	return not LOCKED_BY.has(item) or researched(LOCKED_BY[item])

func price(item: String) -> int:
	var p: float = float(SHOP[item]) * econ() * pow(0.85, count("dilna"))
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
	order(item)
	save()
	changed.emit()
	return true

## What every mercenary gets from the base for nothing (0.50: only the basics; the rest is bought,
## takes days to arrive, and whatever is not brought back from a mission is gone).
const ALLOT := {"pistol": 1, "pistol_clip": 2, "rifle": 1, "rifle_clip": 2, "knife": 1, "radio": 4, "flare": 2, "medkit": 1}
const ALLOT_VETERAN := {"pistol": 1, "pistol_clip": 1, "rifle": 1, "rifle_clip": 1, "knife": 1, "radio": 4, "flare": 1}
## The armory a new campaign starts with (bought by the council - lose it and it is gone).
const START_ARMORY := {"rifle_clip": 6, "pistol_clip": 4, "grenade": 4, "smoke_grenade": 2, "medkit": 2, "vesta": 2, "shotgun": 1, "shells": 3, "scanner": 1}
## What the black market pays for alien things (credits, before difficulty).
const LOOT_SELL := {"a_pistol": 500, "a_rifle": 800, "a_heavy": 1100, "slitiny": 30}

## 0 at the start of the war, 1 by about day 105 (the aliens grow bolder, the countries less patient).
func war_stage() -> float:
	return clampf((float(data.get("day", 0.0)) - 15.0) / 90.0, 0.0, 1.0)

## A merc who killed one of their commanders is marked: for the next missions they hunt him.
func mark_nemesis(names: Array) -> void:
	var nm: Dictionary = data.get("nemesis", {})
	for n in names:
		nm[n] = 4      # (this mission's end counts one off: three missions after it)
		_log("Vetřelci si zapamatovali jméno %s. Půjdou po něm." % n)
	data["nemesis"] = nm

func _nemesis_tick() -> void:
	var nm: Dictionary = data.get("nemesis", {})
	for k in nm.keys():
		nm[k] = int(nm[k]) - 1
		if int(nm[k]) <= 0:
			nm.erase(k)
	data["nemesis"] = nm

func allot() -> Dictionary:
	var base: Dictionary = ALLOT_VETERAN if difficulty() == "veteran" else ALLOT
	var out := {}
	for k in base:
		if unlocked(k):
			out[k] = int(base[k])
	return out

## Bought things are ordered, not conjured: they arrive after a while (alien tech is made in the workshop).
func delivery_days(item: String) -> float:
	var d := clampf(float(SHOP.get(item, 100)) / 500.0, 0.5, 3.0)
	if SHOP_MK.has(item):
		d += 2.0
	return d * time_k() * pow(0.85, count("dilna"))

func order(item: String) -> void:
	if not data.has("orders"):
		data["orders"] = []
	data["orders"].append({"item": item, "at": float(data["day"]) + delivery_days(item)})

func on_order(item: String) -> int:
	var n := 0
	for o in data.get("orders", []):
		if o["item"] == item:
			n += 1
	return n

func _deliveries() -> void:
	var left := []
	var got := {}
	for o in data.get("orders", []):
		if float(o["at"]) <= float(data["day"]):
			data["armory"][o["item"]] = int(data["armory"].get(o["item"], 0)) + 1
			got[o["item"]] = int(got.get(o["item"], 0)) + 1
		else:
			left.append(o)
	data["orders"] = left
	if not got.is_empty():
		var l := []
		for k in got:
			l.append("%s %dx" % [Game.ITEMS[k]["short"] if Game.ITEMS.has(k) else k, got[k]])
		_log("Dodávka do skladu: " + ", ".join(l) + ".")

func sell_price(item: String) -> int:
	return int(price(item) * 0.4)

## Sells one piece from the armory (40 % of the price).
func sell(item: String) -> bool:
	if int(data["armory"].get(item, 0)) <= 0:
		return false
	data["armory"][item] = int(data["armory"][item]) - 1
	if int(data["armory"][item]) <= 0:
		data["armory"].erase(item)
	data["credits"] = int(data["credits"]) + sell_price(item)
	save()
	changed.emit()
	return true

func loot_sell_price(k: String) -> int:
	return int(float(LOOT_SELL.get(k, 0)) * econ())

## Sells one piece of the loot (alien weapons, alloys) on the black market.
func sell_loot(k: String) -> bool:
	var found: Dictionary = data.get("found", {})
	if not LOOT_SELL.has(k) or int(found.get(k, 0)) <= 0:
		return false
	found[k] = int(found[k]) - 1
	data["credits"] = int(data["credits"]) + loot_sell_price(k)
	save()
	changed.emit()
	return true

## What one mercenary may take on a mission: the free allotment (minus what
## research has not unlocked yet) plus everything in the armory.
func stash() -> Dictionary:
	var base: Dictionary = allot()
	var out := {}
	for k in base:
		if unlocked(k):
			out[k] = int(base[k])
	for k in data.get("armory", {}):
		if unlocked(k):
			out[k] = int(out.get(k, 0)) + int(data["armory"][k])
	return out
