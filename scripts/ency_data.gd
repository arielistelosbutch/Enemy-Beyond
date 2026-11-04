class_name EncyData
## The encyclopedia's entries (own texts). Each one opens when the team has met / brought home /
## researched what it is about. Fields: cat, title, text, model, view (stand / table / item / craft),
## unlock: "start" | "seen:<race>" | "res:<research>" | "loot:<item>" | "missions:<n>" | "item:<id>".

const CATS := ["Vetřelci", "Pitvy a výslechy", "Stroje a lodě vetřelců", "Zbraně a výbava", "Naše letadla", "Objevy"]

const AUTOPSY := {
	"grey": ["pitva", "Tělo je lehké, kosti duté jako u ptáka. Trávicí soustava skoro chybí - šedivák se živí roztokem, který vstřebává kůží. Mozek a oči jsou naopak nepřiměřeně velké a propojené hustou sítí nervů. Rozmnožovací orgány nenašel nikdo. Vypadá to na tvora vypěstovaného, ne zrozeného. Nejzranitelnější je hrudník: tenká stěna, pod ní srdce velikosti pěsti."],
	"levit": ["pitva_levit", "Spodní polovina těla byla chirurgicky odstraněna a nahrazena pulzujícím vakem, který tvora nadnáší a zároveň dýchá, tráví a čistí krev místo něj. Horní polovina je svalnatý predátor se zuby žraloka. Pokud vak prorazíš, tvor se zřítí a udusí. Na zádech pahýly trysek srostlé s páteří."],
	"ohar": ["pitva_ohar", "Kostěná čepel na čele roste přímo z lebky a je ostřejší než chirurgický skalpel. Oči zakrnělé, zato ušní dutiny obrovské - ohař slyší tlukot srdce na desítky metrů. Pancéřové pláty na plecích jsou kost, ne kov, a mezi nimi je kůže tenká jako u psa. Mířit na boky."],
	"jestetan": ["pitva_jestetan", "Šupiny jsou tvrdé jako keramika a odvádějí teplo - proto je infračervená optika skoro nevidí. V hrdle orgán, který mění barvu kůže; u starších kusů je propojený s implantátem maskování. Samice nosí v těle desítky vajec, ze kterých se líhnou Líhavci. Nejslabší místo: hrdlo pod čelistí."],
	"lihnoun": ["pitva_lihnoun", "Chitinový krunýř drží kulky, ale ne žár - plazma ho propálí snadno. Dvě dlouhé drápové končetiny jsou duté a nesou zárodek, který tvor vpraví do oběti. Zárodek přebírá nervovou soustavu hostitele během několika vteřin. Srdce má tři a mozek rozdělený do uzlin podél páteře, proto běží ještě chvíli po zásahu do hlavy."],
	"bijec": ["pitva_bijec", "Oblek není oblek: je to živá tkáň, srostlá s kůží, a slouží jako pancíř i chladič. Pod ní svaly s implantovanými vlákny, které násobí sílu. Bijci nemají rozmnožovací orgány ani bolestivé receptory - jsou to vypěstovaní vojáci. Švy obleku na bocích a v podpaží jsou místa, kde kulka projde."],
	"nador": ["pitva_nador", "Uvnitř není nic, co by připomínalo orgány. Jen žíly, tekutina a desítky očí bez víček. Každá buňka si nese kopii celého tvora, proto se po zásahu znovu zformuje. Zastavit ho jde jen tak, že ho rozstřílíš na kusy, dokud leží."],
	"ohnivec": ["pitva_ohnivec", "Kámen, který žije. Vnější vrstva je čedič, uvnitř proudí roztavená hmota. Kulky se odrážejí, plazma ho skoro nepálí. Výbuch ale rozštípne krunýř a vnitřní žár pak vyteče. Když ho nikdo nezasahuje, žár praskliny zacelí."],
	"myslodej": ["pitva_myslodej", "Pod rubášem jen tenká kostra a mozek třikrát větší než lidský. Končetiny zakrnělé - zbraň drží myslí. Mozková kůra vysílá vlny, které naše přístroje zachytí jako šum v rádiu. Po pitvě víme, na jaké frekvenci ruší, a clona to tlumí ještě víc."],
	"diskoll": ["rozbor_diskoll", "Stroj, ne tvor. Disk drží ve vzduchu malý gravitační motor na Moskovium. Okraj je posetý čidly, která vidí teplo, pohyb i rádiový šum, a všechno, co vidí, vysílá ostatním. Pancíř odráží kulky, ale chladič uprostřed spodní strany je zranitelný."],
	"kolos": ["rozbor_kolos", "Chodící válečný stroj na třech nohách. Pohání ho reaktor na Moskovium uprostřed trupu - při zničení vybuchne. Řízení je jednoduché: jde za posledním cílem, který viděl. Mezi nohama je trup otevřený a tam pancíř chybí."],
}

const INTERROGATION := "Velitel mluví jen v obrazech, které nám vnutí do mysli. Opakuje se jedno místo: rudá planeta, pod povrchem obrovský sál a v něm něco, co myslí za všechny. Vojáci poslouchají velitele, velitelé poslouchají TO. Pokud to zničíme, celá invaze ztratí hlavu."

const UFO := {
	"ufo_scout": ["Průzkumník", "Malý disk s posádkou několika šediváků nebo jejich spojenců. Létá nízko, mapuje krajinu, unáší dobytek. Často havaruje - jeho motor je rychlý, ale křehký. Uvnitř jediný sál a pohonná jednotka.", "missions:0"],
	"ufo_raider": ["Nájezdník", "Střední loď pro přepady a únosy. Dva sály, silnější motor, pancéřovaný trup. Posádka bývá větší a mívá s sebou šelmy nebo stroje.", "missions:3"],
	"ufo_harvester": ["Sklízeč", "Velká loď, která sklízí - lidi, zvířata, suroviny. Na palubě vždy velitel a těžká výzbroj. Když přistane, není to průzkum, je to žeň.", "missions:6"],
}

const ITEM_TEXT := {
	"pistol": "Služební pistole. Spolehlivá, lehká, slabá. Poslední záchrana, když dojde všechno ostatní.",
	"rifle": "Útočná puška, páteř každého týmu. Dávka nebo jednotlivé rány, slušný dosah.",
	"shotgun": "Brokovnice na krátkou vzdálenost. V domě, ve sklepě, v lodi - tam není co řešit.",
	"magnum": "Revolver s municí, která zastaví i velké zvíře. Šest ran, pomalé nabíjení.",
	"sniper": "Odstřelovací puška. Jeden výstřel, jeden zásah - a záblesk, který prozradí, kde ležíš.",
	"autocannon": "Autokanón. Těžký, hlučný, rozbije zeď i pancíř.",
	"minigun": "Rotační kulomet. Pás na sto padesát ran a dost hluku na vzbuzení celé vesnice.",
	"rocket_launcher": "Raketomet. Na stroje, Ohnivce a cokoli, co se schovává za zdí.",
	"stun_baton": "Elektrický obušek. Tři pořádné rány a vetřelec padne živý - laboratoř si ho vezme.",
	"knife": "Bojový nůž. Tichý. Do zad funguje líp.",
	"grenade": "Útočný granát. Hodit, schovat se, počítat do tří.",
	"smoke_grenade": "Kouřový granát. Kouř zastaví oči, ne kulky.",
	"mine": "Nášlapná mina. Na cesty, kudy chodí.",
	"flare": "Světlice. Hoří minutu a ukáže, co je ve tmě. Taky ukáže tebe.",
	"medkit": "Lékárnička: obvazy, morfin, zastavení krvácení. Padlého kamaráda postaví na nohy.",
	"scanner": "Detektor pohybu. Pípá, když se něco hýbe. Neřekne co.",
	"radio": "Vysílačka. Bez ní je tým jen pár lidí ve tmě.",
	"nvg": "Noktovizor PVS-7, armádní kus z osmdesátých let. Stačí ho mít u sebe: L ho sklopí před oči. Ve tmě vidíš do dálky, jen zeleně a zrnitě. Do svítilny, ohně nebo plazmy se nedívej - oslepí tě.",
	"vesta": "VOJENSKÁ DATABÁZE - PROJEKT X\nOznačení: STANDARDNÍ BOJOVÁ VÝSTROJ UAI. Klasifikace: Osobní ochranná výstroj pozemních jednotek. Typ: Lehká modulární bojová zbroj. Výrobce: Vojenský vývojový program Projekt X. Status: Standardní výbava operativců UAI.\n\nPOPIS VÝSTROJE: Standardní bojová výstroj UAI představuje základní ochranný systém vojáků nasazovaných v rámci Projektu X. Byla navržena s důrazem na pohyblivost, modularitu a ochranu proti konvenčním i mimozemským zbraním.\nZákladem je odolná vojenská kombinéza doplněná soustavou lehkých pancéřových plátů, které chrání nejdůležitější části těla, aniž by výrazně omezovaly pohyb vojáka.\nAčkoliv poskytuje spolehlivou ochranu proti střepinám a části běžných balistických hrozeb, její účinnost proti pokročilým mimozemským energetickým zbraním zůstává omezená.\n\nKONSTRUKCE A OCHRANA:\n- Hrudní pancíř: Kompozitní ochranný plát určený k ochraně životně důležitých orgánů. Integrovaný identifikační světelný prvek umožňuje rozpoznání spojeneckých jednotek.\n- Bojová přilba: Lehká balistická přilba s komunikační soupravou a možností připojení dodatečných senzorů nebo nočního vidění.\n- Ochrana končetin: Samostatné pancéřové segmenty chránící ramena, kolena a předloktí. Konstrukce upřednostňuje pohyblivost před maximálním pancéřováním.\n- Taktický batoh: Modulární úložný systém označený symbolem X, určený k přepravě munice, zdravotnického materiálu a specializovaného vybavení.\n- Identifikace UAI: Charakteristická nášivka na rameni označující příslušnost k mezinárodním obranným silám Projektu X.\n\nSTANDARDNÍ VÝBAVA:\n- Osobní zbraň: Standardní útočná puška dle bojového zařazení vojáka.\n- Komunikace: Šifrované rádiové spojení s velitelstvím a ostatními členy družstva.\n- Zdravotnická výbava: Individuální lékárnička pro základní ošetření v bojových podmínkách.\n- Taktické prostředky: Granáty, dodatečná munice a specializované vybavení podle charakteru mise.\n- Polní systém: Základní navigační a identifikační zařízení pro koordinaci pohybu jednotek.\n\nTAKTICKÉ HODNOCENÍ:\n- Výhody: Nízká hmotnost, dobrá pohyblivost, modulární konstrukce, snadná údržba, možnost budoucích technologických vylepšení.\n- Nevýhody: Omezená ochrana proti plazmovým a energetickým zbraním, nedostatečná odolnost vůči mimozemským biologickým útokům, absence aktivních obranných systémů.\n- Doporučené použití: Standardní pěchotní operace, průzkum, zajišťování objektů a boj proti lehkým mimozemským jednotkám.\n\nZÁVĚREČNÉ HODNOCENÍ: \"Tohle je to nejlepší, co v současnosti dokážeme našim vojákům nabídnout. Je to lehké, spolehlivé a umožňuje jim bojovat bez zbytečného omezení pohybu. Ale nedělejme si iluze. Proti zbraním, které ti zatracení cizáci používají, je to pořád jen kus pancíře. Potřebujeme jejich technologie. Potřebujeme pochopit jejich materiály. A hlavně potřebujeme čas, abychom z našich vojáků přestali dělat snadné cíle. Do té doby jim nezbývá nic jiného než dobrý výcvik, spolehlivá puška a trochu štěstí.\" - Vedoucí výzbrojního oddělení Projektu X, interní zpráva UAI\n\n",
	"stit": "Ruční balistický štít s průzorem. Zastaví většinu střel zepředu.",
	"pancir": "Pancíř ze slitin z trupu UFO. Těžký, ale plazmu vydrží.",
	"laser_pistol": "Laserová pistole. Článek se dobíjí sám, žádné zásobníky.",
	"laser_rifle": "Laserová puška. Přesná, tichá, bez zpětného rázu.",
	"laser_cannon": "Laserový kanón. Na obrněné cíle a stroje.",
	"plasma_rifle": "Naše plazmová puška podle jejich vzoru. Konečně stejné zbraně.",
	"a_pistol": "Plazmová pistole vetřelců. Bez výzkumu v lidských rukou zlobí: dlouho se nabíjí a střílí, kam chce.",
	"a_rifle": "Plazmová puška vetřelců. Dávky žhavé plazmy. Neprozkoumaná je to loterie.",
	"a_heavy": "Těžká plazma Bijců. Výbuch při dopadu rozbije i zeď.",
}

## What each weapon is good and bad at (for choosing what to carry).
const PROS_CONS := {
	"pistol": ["lehká, rychle se tasí, slušně přesná", "slabá, na velké vetřelce málo"],
	"rifle": ["dobrý dosah, dávka i jednotlivé rány, univerzální", "hlučná, těžší než pistole"],
	"shotgun": ["zblízka smrtící, jedna rána zastaví i Ohaře", "na dálku broky rozprší, pomalé nabíjení po jednom"],
	"magnum": ["obrovská rána do jedné ruky", "jen 6 ran, silný zpětný ráz, pomalé nabíjení"],
	"sniper": ["přesná na velkou dálku, jedna rána často stačí", "od boku nepoužitelná, hlučná, pomalá kadence"],
	"autocannon": ["prorazí zeď i pancíř, výbuch kolem zásahu", "velmi těžký a hlučný, malý zásobník, ze stoje nepřesný"],
	"minigun": ["déšť olova, 150 ran v pásu", "musí se roztočit, nejtěžší zbraň, budí celou mapu"],
	"rocket_launcher": ["zničí stroje, Ohnivce i úkryt za zdí", "jedna raketa, dlouhé nabíjení, nebezpečná zblízka i pro vás"],
	"laser_pistol": ["žádné zásobníky, článek se dobíjí sám, tichá", "když ho vystřílíš do dna, nevystřelí, dokud se nenabije doplna"],
	"laser_rifle": ["přesná, tichá, bez zpětného rázu, nekonečná munice", "vystřílený článek se musí nabít doplna, než zase střílí"],
	"laser_cannon": ["silný na obrněné cíle a stroje", "těžký, krátký článek, chce oporu; vybitý se musí nabít doplna"],
	"plasma_rifle": ["silná, přesná a tichá", "drahá: Moskovium a články"],
	"knife": ["tichý, zezadu zabíjí", "musíš až k nim"],
	"stun_baton": ["vetřelce omráčí živého pro výzkum", "skoro nezraní, musíš až k nim"],
	"a_pistol": ["silná plazma", "bez výzkumu zlobí: dlouho se nabíjí a rozptyluje"],
	"a_rifle": ["silná dávka plazmy", "bez výzkumu nepřesná a pomalá"],
	"a_heavy": ["výbuch při dopadu rozbije i zeď", "těžká, bez výzkumu sotva ovladatelná"],
	"vesta": ["o pětinu menší zranění", "4 kg navíc"],
	"pancir": ["o 38 % menší zranění, plazmu vydrží", "7 kg navíc"],
	"stit": ["zastaví většinu střel zepředu", "zabere ruku, 6 kg"],
}

static func _rate_word(v: float, steps: Array, words: Array) -> String:
	for i in steps.size():
		if v <= float(steps[i]):
			return words[i]
	return words[-1]

## The numbers under a weapon's (or armour's) text: what it does, how often, how much, how loud.
static func card(id: String) -> String:
	var r: Dictionary = Game.ITEMS.get(id, {})
	var t := String(r.get("type", ""))
	var lines := []
	if t == "weapon":
		var dmg := "%d" % int(r.get("damage", 0))
		if r.has("pellets"):
			dmg = "%d × %d broků" % [int(r["pellets"]), int(r["damage"])]
		if r.has("splash"):
			dmg += " + výbuch %.1f m" % float(r["splash"])
		lines.append("Poškození: " + dmg)
		lines.append("Kadence: %d ran/min%s" % [int(60.0 / maxf(float(r.get("rate", 1.0)), 0.01)), " (dávka)" if r.get("auto", false) else ""])
		if r.get("laser", false):
			lines.append("Článek: %d ran, dobije se za %.1f s" % [int(r.get("cap", 0)), float(r.get("recharge", 0.0))])
		elif r.has("cap") and r.get("alien", false):
			lines.append("Náboje: %d, pak se dlouho nabíjí" % int(r["cap"]))
		elif r.has("cap"):
			lines.append("Náboje: %d (nabíjí se po jednom)" % int(r["cap"]))
		elif String(r.get("ammo", "")) != "" and Game.ITEMS.has(r["ammo"]):
			lines.append("Zásobník: %d ran (%s)" % [int(Game.ITEMS[r["ammo"]].get("rounds", 0)), Game.ITEMS[r["ammo"]]["short"]])
		lines.append("Přesnost: " + _rate_word(float(r.get("spread", 2.0)), [0.5, 1.0, 1.5, 2.2, 3.0], ["vynikající", "vysoká", "dobrá", "střední", "nízká", "velmi nízká"]))
		lines.append("Hluk: " + _rate_word(float(r.get("noise", 50.0)), [30.0, 45.0, 60.0, 75.0], ["tichá", "slyšet v okolí", "hlučná", "velmi hlučná", "slyší ji celá mapa"]))
		lines.append("Váha: %d kg%s%s" % [int(r.get("weight", 0)), ", obouruční" if r.get("two", false) else ", do jedné ruky", ", chce oporu (ležet, opřít)" if r.get("brace", false) else ""])
	elif t == "melee":
		lines.append("Poškození: %d%s" % [int(r.get("damage", 0)), ("  zezadu ×%.0f" % float(r["backstab"])) if r.has("backstab") else ""])
		if r.has("stun"):
			lines.append("Omráčení: %d za ránu" % int(r["stun"]))
		lines.append("Dosah: %.1f m   Váha: %d kg" % [float(r.get("reach", 0.0)), int(r.get("weight", 0))])
	elif t == "armor":
		lines.append("Zranění: −%d %%   Váha: %d kg" % [int(round((1.0 - float(r.get("protect", 1.0))) * 100.0)), int(r.get("weight", 0))])
	elif t == "shield":
		lines.append("Váha: %d kg" % int(r.get("weight", 0)))
	if PROS_CONS.has(id):
		lines.append("+ " + String(PROS_CONS[id][0]))
		lines.append("− " + String(PROS_CONS[id][1]))
	if lines.is_empty():
		return ""
	return "\n\n" + "\n".join(lines)

const CRAFT := {
	"heli": ["Čáp", "Starý dopravní vrtulník. Pomalý a hlučný, ale doveze tým kamkoli. Rampa vzadu, místo pro celý tým a jejich výbavu.", "start"],
	"dropship": ["Kondor", "Transportér s krátkými křídly a slitinovým trupem. Startuje svisle, letí třikrát rychleji než Čáp.", "res:kondor"],
	"sokol": ["Sokol", "Stíhačka pro záchyt UFO. Kanón a rakety. Sestřelené UFO spadne do krajiny a posádka zůstane uvnitř - pro tým.", "start"],
	"orel": ["Orel", "Kondor s motorem na Moskovium 115 a trupem ze slitin. Jediná lidská loď, která doletí na Mars a zpátky.", "res:orel"],
}

const LORE := {
	"moskovium": ["Moskovium 115", "Prvek, který u nás v přírodě není. Vetřelci ho používají jako palivo i jako zdroj energie zbraní. V malém množství září zeleně a hřeje na dotek. Bez něj nepostavíme plazmu ani loď, která doletí na Mars.", "", "plasma_cell"],
	"slitiny": ["Vetřelecké slitiny", "Kov z trupu UFO je lehčí než hliník a pevnější než ocel. Nedá se svařit, jen tvarovat při velmi vysoké teplotě. Pláty z něj chrání žoldáky i naše letadla.", "", "a_pack"],
	"vyslech": ["Výslech zajatce", "Živý vetřelec nemluví, ale jeho mysl prosakuje do přístrojů. Z toho, co jsme zachytili, víme, odkud přilétají a že mají někde na Zemi i vlastní základny.", "", "grey"],
	"psi_clona": ["Psionická clona", "Velitelé šediváků a Myslodějové útočí přímo na mysl: strach, panika, iluze, převzetí rukou. Kovová síťka pod helmou a cvičení soustředění ten útok tlumí. Když se obraz zbarví do fialova, něco je špatně - věř tomu, co víš, ne tomu, co vidíš.", "", "grey_velitel"],
	"signal": ["Signál z Marsu", "Úzký paprsek z rudé planety. Opakuje se každých jedenáct minut. Je to rozkaz - a odpověď. Tam je jejich velín.", "", "mars_hq"],
	"rozbor_plazma": ["Plazmová zbraň vetřelců", "Uvnitř zbraně je článek, který drží plazmu v magnetickém poli. Spoušť ho na zlomek vteřiny otevře. Pochopili jsme, jak se nabíjí - ukořistěné zbraně teď slouží i nám a otevřela se cesta k laseru.", "", "a_pistol"],
}

## All entries, in order: [{id, cat, title, text, model, view, unlock}].
static func entries() -> Array:
	var out := []
	for r in Campaign.RACE_INFO:
		var model: String = r
		out.append({"id": "race_" + r, "cat": "Vetřelci", "title": Campaign.RACE_INFO[r][0], "text": Campaign.RACE_INFO[r][1],
			"model": model, "view": "stand", "unlock": "seen:" + r, "icon": "race_" + r})
	for r in AUTOPSY:
		var a: Array = AUTOPSY[r]
		var machine: bool = r in ["diskoll", "kolos"]
		out.append({"id": "autopsy_" + r, "cat": "Pitvy a výslechy", "title": ("Rozbor: " if machine else "Pitva: ") + Campaign.race_name(r), "text": a[1],
			"model": r, "view": "table", "unlock": "res:" + a[0], "icon": "race_" + r})
	out.append({"id": "vyslech_velitel", "cat": "Pitvy a výslechy", "title": "Výslech velitele", "text": INTERROGATION,
		"model": "grey_velitel", "view": "stand", "unlock": "res:vyslech_velitel", "icon": "race_grey_velitel"})
	for u in UFO:
		out.append({"id": u, "cat": "Stroje a lodě vetřelců", "title": UFO[u][0], "text": UFO[u][1], "model": u, "view": "craft", "unlock": UFO[u][2], "icon": u})
	for it in ITEM_TEXT:
		var unlock: String = "loot:" + it if it.begins_with("a_") else ("res:" + Campaign.LOCKED_BY[it] if Campaign.LOCKED_BY.has(it) else "start")
		out.append({"id": "item_" + it, "cat": "Zbraně a výbava", "title": Game.ITEMS[it]["name"], "text": ITEM_TEXT[it] + card(it), "model": it, "view": "item", "unlock": unlock, "icon": it})
	for c in CRAFT:
		out.append({"id": "craft_" + c, "cat": "Naše letadla", "title": CRAFT[c][0], "text": CRAFT[c][1], "model": c if c != "orel" else "dropship", "view": "craft", "unlock": CRAFT[c][2], "icon": c if c != "orel" else "dropship"})
	for k in LORE:
		var l: Array = LORE[k]
		out.append({"id": "lore_" + k, "cat": "Objevy", "title": l[0], "text": l[1], "model": l[3], "view": "item" if l[3] in ["plasma_cell", "a_pack", "a_pistol"] else "stand",
			"unlock": "res:" + k, "icon": ""})
	return out

## Is an entry open to the team?
static func unlocked(e: Dictionary) -> bool:
	if not Campaign.active and not Campaign.viewer:
		return true            # outside a campaign (menu): everything
	var u := String(e["unlock"])
	if u == "start":
		return true
	var k := u.get_slice(":", 0)
	var v := u.get_slice(":", 1)
	match k:
		"seen": return v in Campaign.data.get("seen_races", []) or (v == "levit_velitel" and false)
		"res": return Campaign.researched(v)
		"loot": return int(Campaign.data.get("found", {}).get(v, 0)) > 0
		"missions": return int(Campaign.data.get("stats", {}).get("missions", 0)) >= int(v)
	return false

## The entry (if any) a research project opens.
static func for_research(id: String) -> String:
	for e in entries():
		if String(e["unlock"]) == "res:" + id:
			return String(e["id"])
	return ""
