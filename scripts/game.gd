extends Node
## Enemy Beyond - global state: controls, the mercenary's profile, item rules,
## shared materials and sounds.

const VERSION := "0.68 prototyp"
const VERSION_NUM := "0.68"

# ---- items (like UFO: every item has weight; hands, belt and backpack hold them) ----
const ITEMS := {
	# hands: "two" = needs both hands. kind: gun / melee / throw / tool / ammo
	"rifle": {"name": "Puška", "short": "Puška", "weight": 7, "type": "weapon", "modes": true, "two": true, "ammo": "rifle_clip", "damage": 32, "spread": 1.4, "rate": 0.16, "auto": true, "sound": "rifle", "noise": 45.0, "muzzle": 0.72, "reload": 2.4},
	"pistol": {"name": "Pistole", "short": "Pistole", "weight": 3, "type": "weapon", "ammo": "pistol_clip", "damage": 26, "spread": 2.0, "rate": 0.28, "auto": false, "sound": "pistol", "noise": 35.0, "muzzle": 0.16, "reload": 1.7, "ext_mag": 21},
	"shotgun": {"name": "Brokovnice", "short": "Brokovnice", "weight": 6, "type": "weapon", "two": true, "ammo": "shells", "ammo_alt": ["slugs", "beanbag"], "damage": 16, "pellets": 8, "choke": 3.2, "spread": 3.0, "rate": 0.85, "auto": false, "sound": "shotgun", "noise": 55.0, "muzzle": 0.72, "single": 0.5, "cap": 7, "kick": 2.0},
	"magnum": {"name": "Revolver Magnum", "short": "Magnum", "weight": 3, "type": "weapon", "ammo": "magnum_rounds", "damage": 78, "ap": true, "spread": 1.1, "rate": 0.75, "auto": false, "sound": "magnum", "noise": 70.0, "muzzle": 0.27, "single": 0.7, "cap": 6, "kick": 2.5},
	# 0.57 (Ari, HC-01's entry): one heavy armour-piercing incendiary round at a time, a long cycle after every shot
	"autocannon": {"name": "Těžký kanón", "short": "Kanón", "weight": 16, "type": "weapon", "two": true, "heavy": 0.72, "brace": true, "ammo": "ac_clip", "damage": 150, "ap": true, "incendiary": true, "spread": 1.3, "rate": 1.9, "auto": false, "sound": "autocannon", "noise": 75.0, "muzzle": 1.2, "reload": 3.0, "kick": 3.0},
	"minigun": {"name": "Minigun", "short": "Minigun", "weight": 20, "type": "weapon", "two": true, "heavy": 0.6, "brace": true, "ammo": "minigun_belt", "damage": 15, "spread": 3.4, "rate": 0.05, "auto": true, "spinup": 0.9, "heat": 0.0085, "sound": "minigun", "noise": 75.0, "muzzle": 0.86, "reload": 4.0, "kick": 0.4},
	"rocket_launcher": {"name": "Raketomet", "short": "Raketomet", "weight": 12, "type": "weapon", "two": true, "heavy": 0.85, "ammo": "rocket", "ammo_alt": ["rocket_ap", "rocket_inc"], "damage": 160, "splash": 4.5, "spread": 0.8, "rate": 1.0, "auto": false, "projectile": true, "sound": "launch", "noise": 80.0, "muzzle": 0.9, "reload": 3.0, "kick": 3.0},
	"plasma_rifle": {"name": "Plazmová puška PR-01", "short": "PR-01", "weight": 6, "type": "weapon", "two": true, "ammo": "plasma_cell", "cap": 10, "falloff": [35.0, 80.0], "damage": 75, "spread": 0.8, "rate": 0.32, "auto": false, "heat": 0.2, "sound": "plasma", "noise": 34.0, "muzzle": 0.8, "reload": 1.3, "kick": 0.5},
	"plasma_pistol": {"name": "Plazmová pistole PP-01", "short": "PP-01", "weight": 3, "type": "weapon", "ammo": "plasma_cell", "cap": 20, "falloff": [20.0, 50.0], "damage": 34, "spread": 1.3, "rate": 0.28, "auto": false, "heat": 0.14, "sound": "plasma_p", "noise": 28.0, "muzzle": 0.21, "reload": 1.4, "kick": 0.4},
	"plasma_cannon": {"name": "Plazmový kanón PC-01", "short": "PC-01", "weight": 15, "type": "weapon", "two": true, "heavy": 0.72, "brace": true, "ammo": "plasma_cell", "cap": 4, "damage": 290, "pc": true, "spread": 0.9, "rate": 0.9, "auto": false, "heat": 0.3, "sound": "plasma_cannon", "noise": 60.0, "muzzle": 0.86, "reload": 3.0, "kick": 1.2},
	"plasma_minigun": {"name": "Plazmový minigun PM-01", "short": "PM-01", "weight": 20, "type": "weapon", "two": true, "heavy": 0.58, "brace": true, "ammo": "plasma_cell", "cap": 50, "damage": 26, "spread": 3.0, "rate": 0.08, "auto": true, "bursts": [5, 10, 0], "spinup": 0.7, "heat": 0.02, "sound": "plasma_mg", "noise": 70.0, "muzzle": 0.86, "reload": 3.5, "kick": 0.4},
	"sniper": {"name": "Odstřelovací puška", "short": "Odstřelovačka", "weight": 9, "type": "weapon", "two": true, "ammo": "sniper_clip", "damage": 120, "ap": true, "spread": 0.25, "hip": 5.0, "scope": true, "rate": 1.3, "auto": false, "sound": "sniper", "noise": 75.0, "muzzle": 1.07, "reload": 2.4, "kick": 3.5, "ext_mag": 8},
	# lasers: no magazines - the cell recharges by itself after a short pause (cap = shots in the cell)
	"laser_pistol": {"name": "Laserová pistole LP-01", "short": "Laser. pistole", "weight": 2, "type": "weapon", "ammo": "", "laser": true, "cap": 1, "recharge": 2.0, "falloff": [25.0, 60.0], "damage": 42, "spread": 1.0, "rate": 0.3, "auto": false, "sound": "laser_p", "noise": 25.0, "muzzle": 0.21, "kick": 0.3},
	"laser_rifle": {"name": "Laserová puška LR-01", "short": "Laser. puška", "weight": 6, "type": "weapon", "two": true, "ammo": "", "laser": true, "cap": 1, "recharge": 1.55, "heat": 0.2, "damage": 58, "spread": 0.6, "rate": 0.3, "auto": false, "sound": "laser", "noise": 28.0, "muzzle": 0.6, "kick": 0.4},
	"laser_cannon": {"name": "Laserový kanón LC-01", "short": "Laser. kanón", "weight": 13, "type": "weapon", "two": true, "heavy": 0.75, "brace": true, "ammo": "", "laser": true, "lc": true, "cap": 1, "recharge": 0.18, "damage": 260, "spread": 0.7, "rate": 0.6, "auto": false, "sound": "laser_cannon", "noise": 55.0, "muzzle": 0.78, "kick": 0.6},
	"laser_minigun": {"name": "Laserový minigun LM-01", "short": "Laser. minigun", "weight": 18, "type": "weapon", "two": true, "heavy": 0.6, "brace": true, "ammo": "", "laser": true, "cap": 60, "recharge": 7.0, "heat": 0.012, "damage": 15, "spread": 2.6, "rate": 0.07, "auto": true, "spinup": 0.5, "sound": "laser_mg", "noise": 45.0, "muzzle": 0.86, "kick": 0.35},
	"stun_baton": {"name": "Omračovací obušek", "short": "Obušek", "weight": 2, "type": "melee", "blunt": true, "damage": 4, "stun": 42, "reach": 2.1, "rate": 0.8, "sound": "zap"},
	"knife": {"name": "Bojový nůž", "short": "Nůž", "weight": 1, "type": "melee", "damage": 38, "backstab": 3.0, "reach": 1.7, "rate": 0.45, "sound": "swish"},
	"energo_nuz": {"name": "Energo nůž EN-01", "short": "Energo nůž", "weight": 1, "type": "melee", "damage": 38, "edge": 66, "backstab": 3.0, "reach": 1.7, "rate": 0.5, "sound": "swish"},
	"rifle_clip": {"name": "Zásobník pušky", "short": "Zás. puška", "weight": 3, "type": "ammo", "rounds": 20},
	"sniper_clip": {"name": "Zásobník odstřelovačky", "short": "Zás. odstř.", "weight": 1, "type": "ammo", "rounds": 5},
	"pistol_clip": {"name": "Zásobník pistole", "short": "Zás. pistole", "weight": 1, "type": "ammo", "rounds": 15},
	"shells": {"name": "Broky (krabička)", "short": "Broky", "weight": 1, "type": "ammo", "rounds": 8},
	# 0.57 (Ari, SG-01's entry): other loads for the shotgun - L picks what goes into the tube next
	"slugs": {"name": "Jednotné střely (krabička)", "short": "Jedn. střely", "weight": 1, "type": "ammo", "rounds": 8},
	"beanbag": {"name": "Nesmrtící náboje (krabička)", "short": "Nesmrt. náboje", "weight": 1, "type": "ammo", "rounds": 8},
	"magnum_rounds": {"name": "Náboje Magnum", "short": "Náb. Magnum", "weight": 1, "type": "ammo", "rounds": 6},
	"ac_clip": {"name": "Zásobník kanónu", "short": "Zás. kanón", "weight": 5, "type": "ammo", "rounds": 5},
	"minigun_belt": {"name": "Muniční kontejner minigunu", "short": "Kontejner MG", "weight": 8, "type": "ammo", "rounds": 300},
	"plasma_cell": {"name": "Plazmový zásobník PL-MAG-01", "short": "PL-MAG", "weight": 2, "type": "ammo", "rounds": 20},
	"rocket": {"name": "Výbušná raketa", "short": "Raketa", "weight": 4, "type": "ammo", "rounds": 1},
	"rocket_ap": {"name": "Průbojná raketa", "short": "Průb. raketa", "weight": 4, "type": "ammo", "rounds": 1},
	"rocket_inc": {"name": "Zápalná raketa", "short": "Záp. raketa", "weight": 4, "type": "ammo", "rounds": 1},
	"grenade": {"name": "Granát", "short": "Granát", "weight": 2, "type": "grenade"},
	"plasma_grenade": {"name": "Plazmový granát PG-01", "short": "PG-01", "weight": 2, "type": "grenade"},
	"smoke_grenade": {"name": "Kouřový granát", "short": "Kouř", "weight": 1, "type": "grenade"},
	"mine": {"name": "Nášlapná mina", "short": "Mina", "weight": 3, "type": "grenade"},
	"flare": {"name": "Světlice", "short": "Světlice", "weight": 1, "type": "flare"},
	"medkit": {"name": "Lékárnička", "short": "Lékárnička", "weight": 3, "type": "medkit", "uses": 3},
	# the aliens' own guns, picked up from the dead: no magazines - a charge cell that has to be
	# re-primed (slow and clumsy until research explains how), weak in human hands at first
	"a_pistol": {"name": "Plazmová pistole vetřelců", "short": "Cizí pistole", "weight": 3, "type": "weapon", "ammo": "", "alien": true, "know": "laser",
		"cap": 8, "cells": 3, "damage": 42, "spread": 1.3, "rate": 0.35, "auto": false, "sound": "plasma", "noise": 25.0, "muzzle": 0.21, "kick": 0.4, "reload": 2.5},
	"a_rifle": {"name": "Plazmová puška vetřelců", "short": "Cizí puška", "weight": 6, "type": "weapon", "modes": true, "two": true, "ammo": "", "alien": true, "know": "plazma",
		"cap": 20, "cells": 2, "damage": 50, "spread": 1.0, "rate": 0.22, "auto": true, "sound": "plasma", "noise": 30.0, "muzzle": 0.8, "kick": 0.6, "reload": 3.0},
	"a_heavy": {"name": "Těžká plazma vetřelců", "short": "Cizí těžká", "weight": 11, "type": "weapon", "two": true, "heavy": 0.8, "ammo": "", "alien": true, "know": "laser_tezky",
		"cap": 5, "cells": 2, "damage": 110, "splash": 2.2, "spread": 0.9, "rate": 0.9, "auto": false, "sound": "plasma_heavy", "noise": 45.0, "muzzle": 0.7, "kick": 2.0, "reload": 4.0},
	"a_pack": {"name": "Batoh vetřelce", "short": "Batoh vetřelce", "weight": 0, "type": "salvage"},
	"stit": {"name": "Balistický štít", "short": "Štít", "weight": 6, "type": "shield"},
	"vesta": {"name": "Balistická vesta „Želva“", "short": "Vesta", "weight": 4, "type": "armor", "protect": 0.8},
	"pancir": {"name": "Experimentální pancéřová vesta ARM-02", "short": "ARM-02", "weight": 5, "type": "armor", "protect": 0.66},
	"scanner": {"name": "Detektor pohybu", "short": "Detektor", "weight": 4, "type": "scanner"},
	"radio": {"name": "Vysílačka", "short": "Vysílačka", "weight": 1, "type": "radio"},
	"nvg": {"name": "Noktovizor NVG-01", "short": "Noktovizor", "weight": 1, "type": "nvg"},
}

## The loads a gun takes: its own first, then the others (the shotgun's slugs and less-lethal rounds).
func ammo_types(wid: String) -> Array:
	var r: Dictionary = ITEMS.get(wid, {})
	if String(r.get("ammo", "")) == "":
		return []
	return [String(r["ammo"])] + Array(r.get("ammo_alt", []))

## How many rounds the weapon itself holds.
## An alien gun nobody has researched yet: weak, wild and slow to re-prime.
func alien_unknown(id: String) -> bool:
	var r: Dictionary = ITEMS.get(id, {})
	return r.get("alien", false) and not has_research(String(r.get("know", "")))

func mag_size(id: String) -> int:
	var r: Dictionary = ITEMS[id]
	var n: int = int(r["cap"]) if r.has("cap") else int(ITEMS[r["ammo"]]["rounds"])
	if has_mod(id, "zasobnik"):
		n = int(r["ext_mag"]) if r.has("ext_mag") else int(ceil(n * 1.5))
	return n

# ---- personal weapon upgrades (each mercenary his own, bought with his money) ---------------
## 0.57: a part sits in a slot of the gun (one optic, one thing on the muzzle, ...); a bought part
## stays in the soldier's box when another is mounted instead. Almost every part is "something for
## something": "w" = kilograms more on the gun; multipliers: "ads" = how fast the sights come up,
## "reload" = reload time, "draw" = time to get the gun into the hands, "sway" = shaking hands.
const MODS := {
	"svitilna": {"name": "Zbraňová svítilna", "price": 120, "slot": "bok_l", "w": 0.2, "desc": "Silnější a delší kužel světla, když držíš zbraň. Vetřelci tě ale uvidí z větší dálky."},
	"laser": {"name": "Laserový zaměřovač", "price": 180, "slot": "bok_p", "w": 0.15, "desc": "Červená tečka: střelba od boku skoro o polovinu přesnější. Vetřelec, kterému tečka sedne na tělo, si tě ale všimne."},
	"optika": {"name": "Optika 2x", "price": 220, "slot": "optika", "w": 0.5, "ads": 0.75, "draw": 1.1, "desc": "Dvojnásobné zvětšení v objektivu, o 40 % přesnější a klidnější mířidla. Do oka jde pomaleji a kolem objektivu toho vidíš míň."},
	"kolimator_t": {"name": "Tovární kolimátor", "price": 0, "slot": "optika", "w": 0.3, "stock": true, "desc": "Průhled s červeným bodem, je na pušce z výroby. Bez zvětšení, ale rychle do oka: tečka sedí tam, kam letí kulka."},
	"tlumic": {"name": "Tlumič", "price": 200, "slot": "hlaven", "w": 0.6, "ads": 0.92, "draw": 1.15, "sway": 1.05, "desc": "Výstřel slyší vetřelci jen na pětinu vzdálenosti. Zbraň je delší a vpředu těžší."},
	"bajonet": {"name": "Bajonet", "price": 130, "slot": "hlaven", "w": 0.45, "ads": 0.95, "draw": 1.1, "sway": 1.12, "desc": "Čepel pod hlavní: na V bodneš bajonetem místo rány pažbou, silný a dlouhý výpad. Vpředu těžší zbraň se ale víc klepe."},
	"kolimator": {"name": "Kolimátor", "price": 150, "slot": "optika", "w": 0.1, "draw": 1.1, "desc": "Malý kolimátor na pistoli: tečka v okénku, mírně přesnější střelba. Z pouzdra jde o kus pomaleji."},
	"nosic": {"name": "Nosič nábojů", "price": 90, "w": 0.25, "desc": "Pár nábojů na pouzdře přímo na zbrani: brokovnice se dobíjí rychleji."},
	"pazba": {"name": "Ergonomická pažba", "price": 140, "slot": "pazba", "w": 0.3, "desc": "Pažba, která pohltí část zpětného rázu: další rána jde přesněji."},
	"dvojnozka": {"name": "Stabilizační dvojnožka", "price": 260, "slot": "spodek", "w": 0.6, "ads": 0.9, "desc": "Sklopné nožky pod hlaveň: když stojíš na místě, je zbraň o polovinu přesnější. Kanón s nimi jde položit i vleže."},
	"tlumeni": {"name": "Zesílené tlumení rázu", "price": 300, "w": 1.0, "desc": "Mechanika, která spolkne část zpětného rázu: rychleji jsi zpátky na cíli."},
	"nosny": {"name": "Ergonomický nosný systém", "price": 220, "w": 0.5, "desc": "Popruhy a opěry: s kanónem v rukou se pohybuješ o něco rychleji."},
	"dalkomer": {"name": "Balistický dálkoměr", "price": 280, "w": 0.3, "desc": "Změří vzdálenost a dopočítá pokles střely: na velkou dálku přesnější rána."},
	"brzda": {"name": "Úsťová brzda", "price": 200, "slot": "hlaven", "w": 0.3, "desc": "Odvede část plynů do stran: menší ráz, rychleji jsi zpátky na cíli."},
	"stabilizator": {"name": "Elektronický stabilizátor", "price": 320, "w": 1.0, "desc": "Gyroskop v postroji: dlouhé dávky se tolik nerozlévají."},
	"chladic": {"name": "Pokročilý chladicí modul", "price": 300, "w": 0.8, "desc": "Žebra a proudění vzduchu kolem hlavně nebo emitoru: zbraň se přehřívá pomaleji."},
	"fokus": {"name": "Magnetický fokusér", "price": 280, "slot": "hlaven", "w": 0.35, "spread": 0.75, "heat": 1.25, "desc": "Prstence kolem emitoru stáhnou plazmu do užšího proudu: o čtvrtinu menší rozptyl. Emitor se ale víc zahřívá."},
	"motor": {"name": "Výkonnější pohon rotoru", "price": 260, "w": 0.7, "spin": 0.55, "draw": 1.05, "desc": "Silnější elektromotor s větším akumulátorem: hlavně se roztočí skoro dvakrát rychleji. Pohon je ale o dost těžší."},
	"zamerovac": {"name": "Taktický zaměřovač", "price": 180, "slot": "optika", "w": 0.4, "desc": "Jednoduchý zaměřovač na těžkou zbraň: o něco přesnější na střední vzdálenost."},
	"ergo": {"name": "Ergonomická rukojeť", "price": 120, "w": 0.1, "desc": "Rukojeť, která sedí v dlani: u revolveru menší postih za zpětný ráz, u nože jistější a o kus delší sek."},
	"rychlonabijec": {"name": "Rychlonabíječ", "price": 110, "w": 0.1, "desc": "Šest nábojů v kroužku najednou do bubínku: přebíjení zabere zlomek času."},
	"kompenzator": {"name": "Kompenzační úsťový modul", "price": 160, "slot": "hlaven", "w": 0.2, "desc": "Méně zdvihu hlavně po ráně. Výstřel je ale ještě hlasitější."},
	"pocitac": {"name": "Zaměřovací počítač", "price": 350, "w": 0.8, "desc": "Spočítá předstih na pohyblivý cíl: raketa letí přesněji."},
	"pouzdro": {"name": "Odlehčené taktické pouzdro", "price": 60, "desc": "Nůž vyjde z pouzdra na jeden pohyb: rychlejší tasení."},
	"akumulator": {"name": "Vysokokapacitní akumulátor", "price": 200, "w": 0.3, "desc": "Větší článek v rukojeti obušku: víc výbojů na misi."},
	"lehky": {"name": "Odlehčená konstrukce", "price": 120, "w": -0.3, "desc": "Kompozitní tělo obušku: rychleji v ruce, rychlejší rána."},
	"diagnostika": {"name": "Diagnostický indikátor", "price": 90, "desc": "Displej na rukojeti: ukáže, kolik energie v obušku zbývá."},
	"zasobnik": {"name": "Prodloužený zásobník", "price": 160, "slot": "zasobnik", "w": 1.0, "reload": 1.15, "ads": 0.95, "desc": "O polovinu víc ran v zásobníku. Zbraň je o kilo těžší a delší zásobník se hůř zasouvá."},
	"holo": {"name": "Holografický zaměřovač", "price": 170, "slot": "optika", "w": 0.15, "draw": 1.05, "desc": "Lehký rámeček se sklíčkem pro laserové zbraně: červený bod se promítá do skla, rychle do oka a o kus přesnější rána."},
	"clanek": {"name": "Vysokokapacitní článek", "price": 240, "slot": "clanek", "w": 0.5, "charge": 1.4, "ads": 0.95, "desc": "Větší napájecí článek: zbraň se mezi výstřely nabije o dost rychleji. Je ale o půl kila těžší a vpředu objemnější."},
	"cocka": {"name": "Zaostřovací čočka", "price": 260, "slot": "hlaven", "w": 0.25, "dmg": 1.2, "charge": 0.85, "desc": "Nástavec s čočkou, který stáhne paprsek do užšího svazku: o pětinu silnější zásah. Článek se ale po ráně nabíjí déle."},
	"rukojet": {"name": "Přední rukojeť", "price": 140, "slot": "spodek", "w": 0.3, "ads": 0.92, "desc": "Poloviční zpětný ráz, rozptyl při dávce roste pomaleji, klidnější ruce. Do oka jde o chlup pomaleji."},
}
## The slots a part goes into (only one part per slot); a part without one has a slot of its own.
const MOD_SLOTS := {"optika": "Mířidla", "hlaven": "Ústí hlavně", "spodek": "Pod hlavní", "bok_l": "Levá lišta",
	"bok_p": "Pravá lišta", "zasobnik": "Zásobník", "pazba": "Pažba", "clanek": "Článek"}
## Parts a gun has from the factory: free, mounted from the start; their slot is never empty
## (the factory part goes back on when another comes off).
const STOCK_PARTS := {"rifle": ["kolimator_t"]}
## Which upgrade fits which weapon (not everything on everything).
const MOD_FITS := {
	"pistol": ["kolimator", "svitilna", "laser", "tlumic", "zasobnik"],
	"rifle": ["kolimator_t", "optika", "tlumic", "bajonet", "rukojet", "svitilna", "laser", "zasobnik"],
	"sniper": ["dvojnozka", "dalkomer", "brzda", "zasobnik"],
	"shotgun": ["kolimator", "nosic", "svitilna", "laser", "pazba"],
	"magnum": ["kolimator", "ergo", "rychlonabijec", "kompenzator", "laser"],
	"autocannon": ["zamerovac", "dvojnozka", "tlumeni", "nosny"],
	"rocket_launcher": ["optika", "dalkomer", "nosny", "pocitac"],
	"minigun": ["nosny", "zasobnik", "stabilizator", "chladic", "motor"],
	"plasma_rifle": ["holo", "fokus", "zasobnik", "chladic", "svitilna", "laser"],
	"laser_pistol": ["holo", "clanek", "cocka", "svitilna", "laser"],
	"laser_rifle": ["holo", "clanek", "cocka", "chladic", "svitilna", "laser", "rukojet"],
	"laser_cannon": ["clanek", "cocka", "svitilna", "nosny"],
	"laser_minigun": ["nosny", "stabilizator", "motor", "clanek", "chladic"],
	"plasma_pistol": ["holo", "fokus", "zasobnik", "chladic"],
	"plasma_cannon": ["fokus", "chladic", "zasobnik", "nosny"],
	"plasma_minigun": ["nosny", "stabilizator", "chladic", "motor", "zasobnik"],
	"knife": ["ergo", "pouzdro"],
	"energo_nuz": ["pouzdro"],
	"stun_baton": ["akumulator", "lehky", "diagnostika"],
}
## Where a part's model sits on a gun (the gun model's own space; parts without an entry are not
## seen): a point, or a whole transform (turned under the barrel, smaller on a pistol).
## Part models: assets/models/part_<part>.glb (tools/blender/gun_parts.py).
const PART_AT := {
	"pistol": {"zasobnik": [Vector3(0, -0.103, 0.019), 0.0, 1, "zasobnik_p"],
		"kolimator": Vector3(0, 0.0475, -0.03), "tlumic": Vector3(0, 0.03, -0.194),
		"svitilna": [Vector3(0, -0.014, -0.1), 90.0, 0.8],
		"laser": [Vector3(0.014, 0.006, -0.09), 0.0, 0.7]},
	"shotgun": {"nosic": Vector3(-0.025, 0.033, -0.05), "pazba": Vector3(0, -0.02, 0.364),
		"kolimator": Vector3(0, 0.0655, -0.08), "svitilna": Vector3(-0.016, 0.035, -0.62), "laser": Vector3(0.016, 0.035, -0.6)},
	"magnum": {"ergo": Vector3(0, -0.035, 0.01), "kompenzator": Vector3(0, 0.045, -0.27),
		"kolimator": Vector3(0, 0.061, -0.12),
		"laser": [Vector3(0, 0.023, -0.18), -90.0, 0.7]},
	"laser_pistol": {"holo": Vector3(0, 0.066, -0.06), "clanek": [Vector3(-0.023, 0.03, -0.09), -90.0, 0.7], "cocka": [Vector3(0, 0.03, -0.205), 0.0, 0.85],
		"svitilna": [Vector3(0, 0.005, -0.13), 90.0, 0.8], "laser": [Vector3(0.023, 0.03, -0.12), 0.0, 0.7]},
	"laser_rifle": {"holo": Vector3(0, 0.115, -0.1), "clanek": Vector3(0, -0.065, -0.12), "cocka": Vector3(0, 0.04, -0.6), "chladic": Vector3(0, 0.04, -0.335),
		"svitilna": Vector3(-0.026, 0.04, -0.42), "laser": Vector3(0.026, 0.04, -0.45), "rukojet": Vector3(0, -0.005, -0.26)},
	"laser_cannon": {"nosny": Vector3(0.056, 0, 0.2),
		"cocka": [Vector3(0, 0.05, -0.78), 0.0, 1.5], "clanek": [Vector3(0, -0.02, 0.2), 0.0, 1.5], "svitilna": Vector3(-0.044, 0.05, -0.6)},
	"rifle": {"zasobnik": [Vector3(0, -0.06, -0.128), 0.0, 1, "zasobnik_r"],
		"kolimator_t": Vector3(0, 0.079, -0.08), "optika": Vector3(0, 0.079, -0.06), "bajonet": Vector3(0, 0.042, -0.565), "tlumic": Vector3(0, 0.042, -0.725),
		"rukojet": Vector3(0, 0.012, -0.33), "svitilna": Vector3(-0.032, 0.042, -0.42), "laser": Vector3(0.032, 0.042, -0.44)},
	"sniper": {"zasobnik": [Vector3(0, -0.06, -0.04), 0.0, 1, "zasobnik_s"], "dvojnozka": Vector3(0, -0.005, -0.5), "brzda": Vector3(0, 0.045, -0.98), "dalkomer": Vector3(0.019, 0.115, -0.15)},
	"autocannon": {"zamerovac": Vector3(0, 0.195, -0.05), "dvojnozka": [Vector3(0, 0.03, -0.6), 0.0, 1.3], "tlumeni": Vector3(0, 0.1, 0.2), "nosny": Vector3(0.058, 0, 0.1)},
	"rocket_launcher": {"optika": Vector3(0, 0.125, -0.05), "dalkomer": [Vector3(-0.055, 0.07, -0.2), 180.0, 1], "pocitac": Vector3(0.04, 0.03, 0), "nosny": Vector3(0.055, 0.04, 0.25)},
	"minigun": {"nosny": Vector3(0.072, 0.03, 0.15), "zasobnik": [Vector3(-0.12, -0.12, 0.05), 0.0, 1, "zasobnik_mg"], "stabilizator": Vector3(0, -0.03, 0.15), "chladic": [Vector3(0, 0.05, -0.18), 0.0, 1, "chladic_mg"], "motor": Vector3(-0.06, 0.085, 0.1)},
	"laser_minigun": {"nosny": Vector3(0.072, 0.03, 0.15), "stabilizator": Vector3(0, -0.03, 0.15), "motor": Vector3(-0.06, 0.085, 0.1), "clanek": [Vector3(-0.12, -0.12, 0.05), 0.0, 1.6], "chladic": [Vector3(0, 0.05, -0.18), 0.0, 2.4]},
	"plasma_minigun": {"nosny": Vector3(0.072, 0.03, 0.15), "stabilizator": Vector3(0, -0.03, 0.15), "motor": Vector3(-0.06, 0.085, 0.1), "zasobnik": [Vector3(-0.12, -0.134, 0.01), 0.0, 0.9, "zasobnik_pl"], "chladic": [Vector3(0, 0.05, -0.18), 0.0, 1.4, "chladic_pl"]},
	"plasma_pistol": {"holo": [Vector3(0, 0.057, -0.04), 0.0, 1, "holo_pl"], "fokus": [Vector3(0, 0.035, -0.19), 0.0, 0.6], "zasobnik": [Vector3(0, -0.08, 0.02), 0.0, 0.7, "zasobnik_pl"], "chladic": [Vector3(0, 0.035, -0.145), 0.0, 0.6, "chladic_pl"]},
	"plasma_rifle": {"holo": [Vector3(0, 0.105, -0.12), 0.0, 1, "holo_pl"], "fokus": Vector3(0, 0.04, -0.5), "zasobnik": [Vector3(0, -0.076, -0.11), 0.0, 1, "zasobnik_pl"], "chladic": [Vector3(0, 0.04, -0.2), 0.0, 1, "chladic_pl"], "svitilna": Vector3(-0.036, 0.04, -0.3), "laser": Vector3(0.036, 0.04, -0.32)},
	"plasma_cannon": {"fokus": [Vector3(0, 0.05, -0.72), 0.0, 1.5], "chladic": [Vector3(0, 0.05, -0.355), 0.0, 1.3, "chladic_pl"], "zasobnik": [Vector3(0, -0.075, -0.18), 0.0, 1, "zasobnik_pl"], "nosny": Vector3(0.052, 0, 0.2)},
}
## Factory parts that are baked into the gun's own mesh: the islands inside this box go away (by
## Game.dress_gun) when the part is taken off, or when it has a model of its own in PART_AT (the
## rifle's red dot: the baked one is a solid cylinder, the part an open tube to look through).
const STOCK_MESH := {"rifle": {"kolimator_t": AABB(Vector3(-0.03, 0.0805, -0.135), Vector3(0.06, 0.08, 0.115))},
	# (0.57: the sniper's folded bipod and its muzzle brake are bought parts now - without them the gun has none)
	"sniper": {"dvojnozka": AABB(Vector3(-0.035, -0.02, -0.785), Vector3(0.07, 0.032, 0.288)), "brzda": AABB(Vector3(-0.03, 0.02, -1.08), Vector3(0.06, 0.05, 0.1))}}
## (0.57) The magazine as its own piece in the eyes' view (the reload hides it, the hand brings it):
## the blocks of the gun's mesh inside "box" (the gun model's space), or made of the material "mat"
## (with the small bits of other materials stuck to it). The pistol has its own "Mag" in the model.
## "Pump" the same way: the shotgun's forend (the left hand racks it). "mats": only blocks of these
## materials inside the box.
const MAG_PART := {"rifle": {"box": AABB(Vector3(-0.03, -0.21, -0.22), Vector3(0.06, 0.157, 0.13))},
	"plasma_pistol": {"mat": "PlasmaMag"}, "plasma_rifle": {"box": AABB(Vector3(-0.025, -0.085, -0.145), Vector3(0.05, 0.065, 0.07))},
	"plasma_cannon": {"mat": "PlasmaMag"}, "plasma_minigun": {"mat": "PlasmaMag"},
	"shotgun": {"name": "Pump", "box": AABB(Vector3(-0.04, -0.02, -0.52), Vector3(0.08, 0.08, 0.2)), "mats": ["Walnut", "WalnutDark"]}}
## Looking through a sight (aiming): the point the eye looks along, in the gun model's space (a
## mounted part: in the part's space, PART_AT is added), the eye's distance behind it, the view's
## narrowing (x Game.fov) and for a scope its magnification and the eyepiece radius.
const SIGHTS := {
	"kolimator_t": {"at": Vector3(0, 0.036, -0.032), "relief": 0.2, "kind": "dot", "fov": 0.75},
	"optika": {"at": Vector3(0, 0.045, 0.076), "relief": 0.075, "kind": "scope", "fov": 0.8, "zoom": 2.0, "r": 0.0165},
	"holo": {"at": Vector3(0, 0.024, -0.012), "relief": 0.24, "kind": "dot", "fov": 0.8},
	"kolimator": {"at": Vector3(0, 0.016, -0.011), "relief": 0.26, "kind": "dot", "fov": 0.8},
}
## A gun's own sights (used when no sight part is mounted): "iron" = the notch and post line up in
## the middle of the screen; the sniper rifle's built-in scope magnifies in its eyepiece.
const GUN_SIGHTS := {
	"pistol": {"at": Vector3(0, 0.054, 0.015), "relief": 0.3, "kind": "iron", "fov": 0.85},
	"magnum": {"at": Vector3(0, 0.0705, -0.03), "relief": 0.3, "kind": "iron", "fov": 0.85},
	"shotgun": {"at": Vector3(0, 0.085, -0.02), "relief": 0.22, "kind": "iron", "fov": 0.8},      # (0.57: the eye further back - the receiver went through the view)
	"laser_pistol": {"at": Vector3(0, 0.074, 0.0), "relief": 0.3, "kind": "iron", "fov": 0.85},
	"laser_rifle": {"at": Vector3(0, 0.119, -0.045), "relief": 0.12, "kind": "iron", "fov": 0.8},
	"sniper": {"at": Vector3(0, 0.115, 0.087), "relief": 0.08, "kind": "scope", "fov": 0.8, "zoom": 4.5, "r": 0.022},
}

## Where a part sits on a gun, as a transform (identity: no place for it).
## The model a part shows on this gun (PART_AT may give its own: a plasma gun's cooler looks alien).
func part_model(weapon: String, mid: String) -> String:
	var v: Variant = PART_AT.get(weapon, {}).get(mid, null)
	return String(v[3]) if v is Array and (v as Array).size() > 3 else mid

func part_xf(weapon: String, mid: String) -> Transform3D:
	var v: Variant = PART_AT.get(weapon, {}).get(mid, null)
	if v is Array:  # [poloha, otočení kolem osy hlavně ve stupních, měřítko(, jiný model dílu)]
		return Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(v[1])).scaled(Vector3.ONE * float(v[2])), v[0])
	return Transform3D(Basis(), v as Vector3) if v is Vector3 else Transform3D()

func _mod_src(m: Dictionary) -> Dictionary:
	return m if not m.is_empty() else merc

func mod_slot(mod: String) -> String:
	return String(MODS.get(mod, {}).get("slot", mod))

## The soldier has this part for this gun (bought, or it came with the gun).
func owns_mod(weapon: String, mod: String, m: Dictionary = {}) -> bool:
	return mod in STOCK_PARTS.get(weapon, []) or mod in _mod_src(m).get("mods", {}).get(weapon, [])

## What is mounted on a gun: slot -> part. Saved with the soldier ("fit"); a soldier from before
## 0.57 gets the factory parts and everything he bought (one per slot) mounted.
func fitted(weapon: String, m: Dictionary = {}) -> Dictionary:
	var src := _mod_src(m)
	var f: Dictionary = src.get("fit", {})
	if f.has(weapon):
		var fits: Array = MOD_FITS.get(weapon, [])
		for sl in (f[weapon] as Dictionary).keys():
			if not f[weapon][sl] in fits:       # a part that no longer fits this gun (0.57 changes) comes off
				f[weapon].erase(sl)
		return f[weapon]
	var out := {}
	for mid in STOCK_PARTS.get(weapon, []) + Array(src.get("mods", {}).get(weapon, [])):
		if MODS.has(mid):
			out[mod_slot(mid)] = mid
	if out.is_empty():
		return out
	f[weapon] = out
	src["fit"] = f
	return out

func has_mod(weapon: String, mod: String, m: Dictionary = {}) -> bool:
	return fitted(weapon, m).get(mod_slot(mod), "") == mod

## The product of the mounted parts' multipliers ("ads", "reload", "draw", "sway").
func part_mult(weapon: String, key: String, m: Dictionary = {}) -> float:
	var k := 1.0
	for s in fitted(weapon, m):
		k *= float(MODS.get(fitted(weapon, m)[s], {}).get(key, 1.0))
	return k

## Kilograms the mounted parts add to a gun.
func part_weight(weapon: String, m: Dictionary = {}) -> float:
	var w := 0.0
	for s in fitted(weapon, m):
		w += float(MODS.get(fitted(weapon, m)[s], {}).get("w", 0.0))
	return w

## Puts an owned part on the gun (what was in its slot goes back to the box).
func mount_mod(weapon: String, mod: String) -> bool:
	if not owns_mod(weapon, mod) or not mod in MOD_FITS.get(weapon, []):
		return false
	var fit := fitted(weapon).duplicate()
	fit[mod_slot(mod)] = mod
	_set_fit(weapon, fit)
	return true

## Takes the part off a slot; a factory part goes back in its place.
func unmount_slot(weapon: String, slot: String) -> void:
	var fit := fitted(weapon).duplicate()
	fit.erase(slot)
	for sp in STOCK_PARTS.get(weapon, []):
		if mod_slot(sp) == slot:
			fit[slot] = sp
	_set_fit(weapon, fit)

func _set_fit(weapon: String, fit: Dictionary) -> void:
	var f: Dictionary = merc.get("fit", {})
	f[weapon] = fit
	merc["fit"] = f
	save_merc()
	Net.update_merc()

## The sight the soldier looks through when he aims this gun (empty: the old way, no sight line).
func sight_of(weapon: String, m: Dictionary = {}) -> Dictionary:
	var opt := String(fitted(weapon, m).get("optika", ""))
	if not SIGHTS.has(opt) or not PART_AT.get(weapon, {}).has(opt):
		# no sight part with a place on this gun's model: its own sights (or the old way)
		return GUN_SIGHTS.get(weapon, {}).duplicate()
	var s: Dictionary = SIGHTS[opt].duplicate()
	s["at"] = part_xf(weapon, opt) * (s["at"] as Vector3)
	s["part"] = opt
	return s

## Dresses a gun model for this soldier: the mounted parts on it, factory parts taken off hidden.
func dress_gun(n: Node3D, weapon: String, m: Dictionary = {}, split_mag := false) -> void:
	if not MOD_FITS.has(weapon):
		return
	var fit := fitted(weapon, m)
	split_mag = split_mag and MAG_PART.has(weapon)
	var at: Dictionary = PART_AT.get(weapon, {})
	for s in fit:
		var mid: String = fit[s]
		var pmid := part_model(weapon, mid)
		if at.has(mid) and ResourceLoader.exists("res://assets/models/part_%s.glb" % pmid):
			var pm := model("part_" + pmid)
			pm.name = "Part_" + mid
			pm.transform = part_xf(weapon, mid)
			n.add_child(pm)
	var hide := []
	for sp in STOCK_MESH.get(weapon, {}):
		if not fit.values().has(sp) or at.has(sp):
			hide.append(STOCK_MESH[weapon][sp])
	if hide.is_empty() and not split_mag:
		return
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).begins_with("Part_") or String(mi.get_parent().name).begins_with("Part_"):
			continue
		if split_mag:
			_split_mag(mi, weapon, hide)
			continue
		var ck := "%s/%s/%s" % [weapon, mi.name, str(hide)]
		if _dress_cache.has(ck):
			if _dress_cache[ck] != null:
				_redress(mi, _dress_cache[ck])
			continue
		var src: Mesh = mi.get_meta("eb_src") if mi.has_meta("eb_src") else mi.mesh
		var mods: Dictionary = model_mods.get(weapon, {}).duplicate(true)
		if not mods.has("parts"):
			mods["parts"] = {}
		var isl := ModelMods.islands(src)
		var gone := 0
		for i in isl.size():
			for box in hide:
				if (box as AABB).has_point(isl[i]["center"]):
					var k := "%s:%d" % [mi.name, i]
					var e: Dictionary = mods["parts"].get(k, {})
					e["del"] = true
					mods["parts"][k] = e
					gone += 1
		if gone > 0:
			ModelMods.rebuild(mi, mods)
			_dress_cache[ck] = mi.mesh
			_redress(mi, mi.mesh)
		else:
			_dress_cache[ck] = null

## The gun's mesh without the magazine (and the factory parts taken off), and the magazine as a
## mesh of its own next to it, named "Mag" (made once per gun and hidden parts).
func _split_mag(mi: MeshInstance3D, weapon: String, hide: Array) -> void:
	var ck := "mag/%s/%s/%s" % [weapon, mi.name, str(hide)]
	if not _dress_cache.has(ck):
		var src: Mesh = mi.get_meta("eb_src") if mi.has_meta("eb_src") else mi.mesh
		var isl := ModelMods.islands(src)
		var rule: Dictionary = MAG_PART[weapon]
		var is_mag := {}
		if rule.has("box"):
			for i in isl.size():
				if (rule["box"] as AABB).has_point(isl[i]["center"]):
					if rule.has("mats"):
						var mt0 := src.surface_get_material(int(isl[i]["surf"]))
						if mt0 == null or not mt0.resource_name in (rule["mats"] as Array):
							continue
					is_mag[i] = true
		elif rule.has("mat"):
			var box := AABB()
			var any := false
			for i in isl.size():
				var mt := src.surface_get_material(int(isl[i]["surf"]))
				if mt and mt.resource_name == String(rule["mat"]):
					is_mag[i] = true
					box = isl[i]["box"] if not any else box.merge(isl[i]["box"])
					any = true
			if any:
				box = box.grow(0.004)
				for i in isl.size():
					if not is_mag.has(i) and box.encloses(isl[i]["box"]):
						is_mag[i] = true
		var gun_mods: Dictionary = model_mods.get(weapon, {}).duplicate(true)
		if not gun_mods.has("parts"):
			gun_mods["parts"] = {}
		var mag_mods: Dictionary = gun_mods.duplicate(true)
		mag_mods["new"] = []
		for i in isl.size():
			var k := "%s:%d" % [mi.name, i]
			var gone := false
			for b in hide:
				if (b as AABB).has_point(isl[i]["center"]):
					gone = true
			# a magazine block leaves the gun's mesh, every other block leaves the magazine's
			# (a factory part taken off leaves both)
			var drop_from: Array = []
			if is_mag.has(i) or gone:
				drop_from.append(gun_mods)
			if not is_mag.has(i) or gone:
				drop_from.append(mag_mods)
			for target in drop_from:
				var e: Dictionary = ((target as Dictionary)["parts"] as Dictionary).get(k, {}).duplicate()
				e["del"] = true
				target["parts"][k] = e
		var mm := MeshInstance3D.new()
		mm.mesh = src
		mm.name = mi.name
		ModelMods.rebuild(mm, mag_mods)
		var mag_mesh: Mesh = mm.mesh if not is_mag.is_empty() else null
		mm.free()
		ModelMods.rebuild(mi, gun_mods)
		_dress_cache[ck] = [mi.mesh, mag_mesh]
	var got: Array = _dress_cache[ck]
	_redress(mi, got[0])
	var pname := String(MAG_PART[weapon].get("name", "Mag"))
	if got[1] != null and mi.get_node_or_null(pname) == null:
		var mg := MeshInstance3D.new()
		mg.name = pname
		mg.mesh = got[1]
		mi.add_child(mg)
		_restyle(mg)

var _dress_cache := {}       # a gun mesh without its factory part, made once
func _redress(mi: MeshInstance3D, mesh: Mesh) -> void:
	mi.mesh = mesh
	for i in mi.get_surface_override_material_count():
		mi.set_surface_override_material(i, null)
	_restyle(mi)


## Personal money: the host in a campaign pays from the base treasury, everyone else from his own purse.
func purse() -> int:
	return Net.my_money()

func spend(amount: int) -> bool:
	if purse() < amount:
		return false
	merc["money"] = int(merc.get("money", 0)) - amount
	save_merc()
	Net.update_merc()
	return true

func mod_price(mod: String) -> int:
	var k: float = Campaign.econ() if (Campaign.active or Campaign.viewer) and not skirmish else 1.0
	return int(round(float(MODS[mod]["price"]) * k / 5.0) * 5)

## Buy an item for yourself (own money): it goes into your own locker - only you take it on missions.
func buy_for_me(item: String) -> bool:
	var p := Campaign.price(item)
	if not Campaign.unlocked(item) or Campaign.workshop_item(item):
		return false      # what the workshop makes belongs to the base, not to one man
	if not spend(p):
		return false
	var lk: Dictionary = merc.get("locker", {})
	lk[item] = int(lk.get(item, 0)) + 1
	merc["locker"] = lk
	save_merc()
	Net.update_merc()
	return true

func buy_mod(weapon: String, mod: String) -> bool:
	if owns_mod(weapon, mod) or not mod in MOD_FITS.get(weapon, []) or not spend(mod_price(mod)):
		return false
	var mods: Dictionary = merc.get("mods", {})
	var l: Array = mods.get(weapon, [])
	l.append(mod)
	mods[weapon] = l
	merc["mods"] = mods
	var fit := fitted(weapon).duplicate()
	fit[mod_slot(mod)] = mod      # a new part goes straight on the gun
	_set_fit(weapon, fit)
	return true

## Texts say "Kondor"; before its research the team flies the old helicopter Čáp.
func shipify(t: String) -> String:
	if String(Net.mission_params.get("transport", "kondor")) != "heli" or not "Kondor" in t:
		return t
	return t.replace("v Kondoru", "v Čápu").replace("Kondoru", "Čápa").replace("Kondor", "Čáp")

func two_handed(id: String) -> bool:
	return ITEMS.get(id, {}).get("two", false)

## Seconds to take an item out of a slot: belt is quick, backpack is a dig.
## (0.57) A soldier's parts on a gun make it slower to get out (m = that soldier).
func fetch_time(id: String, from_slot: String, m: Dictionary = {}) -> float:
	# (0.62) talent Rychlé tasení: a gun comes out (or goes away) in half the time
	var quick := 0.5 if not m.is_empty() and ITEMS.get(id, {}).get("type", "") == "weapon" and has_talent(m, "rychle_taseni") else 1.0
	if not m.is_empty() and MOD_FITS.has(id):
		return _fetch_time(id, from_slot) * part_mult(id, "draw", m) * quick
	return _fetch_time(id, from_slot) * quick

func _fetch_time(id: String, from_slot: String) -> float:
	var w := float(ITEMS[id]["weight"])
	if from_slot.begins_with("p"):
		return 1.2 + w * 0.18
	if from_slot.begins_with("b"):
		return 0.3 + w * 0.04
	if from_slot == "back":
		return 0.8
	if from_slot == "side":
		return 0.45
	return 0.25

## Where a thing may go: "" = fine, else why not. One weapon in the hands at a time; the left
## hand only carries the shield. 1 = primary weapon, 2 = secondary (a sidearm), 3-6 = belt.
func slot_refuse(slot: String, id: String) -> String:
	var t: String = ITEMS.get(id, {}).get("type", "")
	match slot:
		"rh":
			if t == "ammo": return "Náboje se do ruky neberou - nabíjí se klávesou R."
			if t == "shield": return "Štít patří do levé ruky."
		"lh":
			if t != "shield": return "Levá ruka drží jen štít - zbraň se drží oběma rukama."
		"back":
			if t != "weapon" and t != "melee": return "Primární slot je jen pro zbraň."
		"side":
			if t != "weapon" and t != "melee": return "Sekundární slot je jen pro zbraň."
			if two_handed(id): return "Do sekundárního slotu patří jen jednoruční zbraň (pistole, revolver, nůž...)."
	return ""

const SLOTS := ["rh", "lh", "back", "side", "b0", "b1", "b2", "b3", "p0", "p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8"]

## The backpack's places: six, nine with the researched paratrooper pack (výzkum "batohy").
func pack_slots() -> Array:
	if has_research("batohy"):
		return ["p0", "p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8"]
	return ["p0", "p1", "p2", "p3", "p4", "p5"]
const SLOT_NAMES := {"rh": "V rukou", "lh": "Štít", "back": "Primární zbraň", "side": "Sekundární zbraň", "b": "Opasek", "p": "Batoh"}

# ---- the mercenaries (kept between sessions in user://merc.cfg) ----
## a player keeps up to three; one of them (merc) goes on missions, the wounded wait at the sick bay
const MERC_SLOTS := 3
var mercs: Array = []
var active := 0
var merc := {}:
	set(v):
		merc = v
		if active < mercs.size():
			mercs[active] = v
var seed_override := -1
var test_phase := 0
var open_screen := ""      # main menu screen to open (from the globe)

# ---- 0.66: the loading screen (scripts/loading.gd) -----------------------------------------
const LoadingScreen := preload("res://scripts/loading.gd")
var _loading: Node = null
const LOAD_WHAT := {"Mission.tscn": "Příprava mise", "Geoscape.tscn": "Velín", "Intercept.tscn": "Stíhačka startuje",
	"Escort.tscn": "Doprovod transportu"}
## Changes the scene behind the loading screen: shows it, lets it be drawn (the building of a mission
## blocks the screen - what is drawn last stays up), changes, and lets it fade into the new scene.
func load_scene(path: String) -> void:
	var tree := get_tree()
	if not is_instance_valid(_loading):
		_loading = LoadingScreen.new()
		_loading.setup(String(LOAD_WHAT.get(path.get_file(), "Načítání")), path.ends_with("Mission.tscn"))
		add_child(_loading)
		for i in 3:
			if DisplayServer.get_name() == "headless":
				await tree.process_frame      # (no drawing there - frame_post_draw never comes)
			else:
				await RenderingServer.frame_post_draw
	tree.change_scene_to_file(path)
	await tree.scene_changed
	if is_instance_valid(_loading):
		_loading.scene_ready()

## Still covering the screen (the mission's briefing waits with its typing until it is gone).
func loading_busy() -> bool:
	return is_instance_valid(_loading) and _loading.busy()

func _ready() -> void:
	load_tweaks()
	# the steel look for every control in the game, CanvasLayers included
	ThemeDB.get_default_theme().merge_with(UiSkin.theme())
	ThemeDB.get_default_theme().default_font = UiSkin.font()
	ThemeDB.fallback_font = UiSkin.font()
	get_window().title = "Operace X - Enemy Beyond"
	_make_buses()
	load_settings()
	apply_volumes()
	_preload_sounds()
	if cmd_arg("grass", "") != "":
		grass = cmd_arg("grass", "1") == "1"
	if cmd_arg("retro", "") != "":
		retro = cmd_arg("retro", "1") == "1"
	if cmd_arg("seed", "") != "":
		seed_override = int(cmd_arg("seed", "-1"))
	if cmd_arg("difficulty", "") != "":
		difficulty = cmd_arg("difficulty", "")
	_setup_input()
	load_merc()

## M: the microphone stays open (talks whenever you speak) until M again. (Tab held = talk.)
var mic_live := false
signal mic_toggled(on: bool)
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mic_toggle") and not event.is_echo():
		var fo := get_viewport().gui_get_focus_owner()
		if fo is LineEdit or fo is TextEdit:
			return
		mic_live = not mic_live
		mic_toggled.emit(mic_live)

func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A], "move_right": [KEY_D],
		"sprint": [KEY_SHIFT], "crouch": [KEY_C, KEY_CTRL], "jump": [KEY_SPACE],
		"reload": [KEY_R], "flashlight": [KEY_F], "use": [KEY_E], "heal": [KEY_X],
		"grenade": [KEY_G], "flare": [KEY_7], "swap": [KEY_Q], "inventory": [KEY_I],
		"pause": [KEY_ESCAPE], "prone": [KEY_Z, KEY_Y], "melee": [KEY_V], "smoke": [KEY_H], "mine": [KEY_B],
		"primary": [KEY_1], "secondary": [KEY_2],
		"belt1": [KEY_3], "belt2": [KEY_4], "belt3": [KEY_5], "belt4": [KEY_6],
		"talk": [KEY_TAB], "radio_talk": [KEY_T, KEY_K], "mic_toggle": [KEY_M], "nvg": [KEY_N], "firemode": [KEY_L], "drop": [KEY_BACKSPACE], "ready": [KEY_ENTER, KEY_KP_ENTER], "salute": [KEY_J], "atease": [KEY_U],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# Tab is held to talk: it must not also jump between the buttons of a menu
	for ui in ["ui_focus_next", "ui_focus_prev"]:
		if InputMap.has_action(ui):
			for ev in InputMap.action_get_events(ui):
				if ev is InputEventKey and ((ev as InputEventKey).keycode == KEY_TAB or (ev as InputEventKey).physical_keycode == KEY_TAB):
					InputMap.action_erase_event(ui, ev)
	for pair in [["fire", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)

# ---- mercenary profile ----
const FIRST := ["Jan", "Petr", "Mira", "Karel", "Ivo", "Lukas", "Ota", "Rene", "Vlad", "Erik", "Dana", "Ema", "Sara", "Iva"]
const LAST := ["Novak", "Kral", "Dvorak", "Holub", "Cerny", "Marek", "Vlk", "Hruby", "Sokol", "Kopecky", "Barta", "Krejci"]

func new_merc(name_hint := "") -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.randomize()
	var female := r.randf() < 0.3
	var n := name_hint if name_hint != "" else random_name(female, r)
	var m := {
		"name": n,
		"missions": 0, "kills": 0, "captures": 0, "xp": 0, "talents": [], "talent_points": 0,
		"created": false,     # not shaped by the player yet (the menu offers the creation screen)
		"look": random_look(female, r),
	}
	var lv := roll_levels(r)
	for st in STAT_ORDER:
		m[st] = stat_value(st, int(lv[st]))
	m["levels"] = lv
	return m

# ---- creating a mercenary: stats as levels 0..10, 30 levels to spend (or roll) ----------
const STAT_ORDER := ["accuracy", "reactions", "strength", "bravery", "health", "stamina"]
const STAT_RANGE := {"accuracy": [40, 75], "reactions": [30, 65], "strength": [28, 50], "bravery": [20, 75], "health": [28, 42], "stamina": [50, 85]}
const STAT_HELP := {
	"accuracy": "Jak daleko od středu zaměřovače letí kulky. Vyšší = menší rozptyl všech zbraní.",
	"reactions": "Jak rychle se zbraň po pohybu a výstřelu ustálí a jak moc se třese ve strachu.",
	"strength": "Kolik kilogramů uneseš bez zpomalení. Těžké zbraně (kanón, minigun) a plný batoh chtějí sílu.",
	"bravery": "Jak snášíš tmu, vetřelce a zranění. Nízká odvaha = rychlejší strach, panika, slabší odpor proti psionice.",
	"health": "Kolik zásahů vydržíš, než padneš. Každý bod se počítá - plazma bere 8-14 (Veterán 18-30).",
	"stamina": "Jak dlouho vydržíš sprintovat a jak rychle se po běhu uklidní dech (a s ním mířidla).",
}
const LEVEL_POOL := 30
const LEVEL_MAX := 10

func stat_value(st: String, level: int) -> int:
	var r: Array = STAT_RANGE[st]
	return int(round(lerp(float(r[0]), float(r[1]), float(level) / LEVEL_MAX)))

## Dice: each stat is 2d6-2 (0..10, most often 5) - on average the same 30 levels as the points.
func roll_levels(r: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for st in STAT_ORDER:
		out[st] = r.randi_range(1, 6) + r.randi_range(1, 6) - 2
	return out

func set_levels(m: Dictionary, lv: Dictionary) -> void:
	m["levels"] = lv.duplicate()
	for st in STAT_ORDER:
		m[st] = stat_value(st, int(lv[st]))

# ---- looks ------------------------------------------------------------------------------
const HAIR_STYLES := [["none", "Holá hlava"], ["buzz", "Nakrátko"], ["short", "Krátké"], ["long", "Dlouhé"], ["pony", "Culík"], ["bun", "Drdol"], ["mohawk", "Číro"]]
const BEARDS := [["none", "Bez vousů"], ["stubble", "Strniště"], ["moustache", "Knír"], ["goatee", "Bradka"], ["full", "Plnovous"]]
const HAIR_COLORS := [["Černé", Color(0.04, 0.035, 0.03)], ["Tmavě hnědé", Color(0.12, 0.07, 0.04)], ["Hnědé", Color(0.25, 0.15, 0.08)],
	["Kaštanové", Color(0.35, 0.13, 0.06)], ["Zrzavé", Color(0.6, 0.22, 0.06)], ["Blond", Color(0.7, 0.55, 0.3)],
	["Platinové", Color(0.85, 0.82, 0.7)], ["Šedivé", Color(0.5, 0.5, 0.5)], ["Bílé", Color(0.85, 0.85, 0.85)]]
const EYE_COLORS := [["Hnědé", Color(0.3, 0.17, 0.07)], ["Tmavé", Color(0.1, 0.06, 0.03)], ["Oříškové", Color(0.45, 0.33, 0.12)],
	["Zelené", Color(0.18, 0.45, 0.2)], ["Modré", Color(0.2, 0.4, 0.75)], ["Šedé", Color(0.5, 0.55, 0.6)]]
const SKIN_TONES := [["Světlá", Color(0.78, 0.6, 0.5)], ["Pleť", Color(0.62, 0.47, 0.38)], ["Snědá", Color(0.5, 0.35, 0.24)],
	["Tmavší", Color(0.36, 0.24, 0.16)], ["Tmavá", Color(0.22, 0.14, 0.1)]]
const HEADGEAR := [["helmet", "Helma se svítilnou"], ["cap", "Polní čepice"], ["none", "Nic (vlasy na odiv)"],
	["beret", "Baret"], ["boonie", "Klobouk do buše"], ["bandana", "Šátek na hlavě"], ["headset", "Jen sluchátka"]]
# ---- 0.57 facelift: clothes and trinkets chosen when the soldier is made ----
# (all of it is only looks: new Look_*/Gear_* pieces of merc.glb on the same bones - the movements,
#  the weapon grips and the Workshop anchors do not change. A missing key = the old look.)
## Indices into these lists are kept in merc["look"], so new entries go only at the END.
const BERET_COLORS := [["Zelená", Color(0.16, 0.25, 0.12)], ["Vínová", Color(0.42, 0.07, 0.1)], ["Černá", Color(0.05, 0.05, 0.05)],
	["Modrá", Color(0.14, 0.33, 0.6)], ["Písková", Color(0.6, 0.5, 0.33)], ["Šedá", Color(0.35, 0.36, 0.36)]]
const TOPS := [["jacket", "Bunda"], ["rolled", "Ohrnuté rukávy"], ["tee", "Tričko"], ["bare", "Bez trička"]]
const PANTS := [["pads", "Maskáče s chrániči"], ["cargo", "Maskáče"], ["plain", "Rovné kalhoty"], ["plain_pads", "Rovné s chrániči"]]
const VESTS := [["harness", "Popruhy"], ["carrier", "Nosič plátů"], ["rig", "Hrudní nosič"], ["none", "Jen opasek"]]
const PAINTS := [["none", "Bez barvy"], ["eyes", "Pod očima"], ["stripes", "Pruhy na lících"], ["band", "Pás přes oči"], ["full", "Celý obličej"]]
const TATTOOS := [["none", "Bez tetování"], ["skull", "Lebka"], ["anchor", "Kotva"], ["x", "Znak X"], ["tribal", "Pásy"], ["sleeve", "Rukáv"]]
const GLASSES := [["none", "Bez brýlí"], ["shades", "Sluneční brýle"], ["ballistic", "Střelecké brýle"]]
const NECKS := [["none", "Nic"], ["shemagh", "Šátek kolem krku"], ["mask", "Šátek přes obličej"], ["tags", "Psí známky"]]
const MOUTHS := [["none", "Nic"], ["cigar", "Doutník"], ["match", "Sirka"]]
const _FW := Color(0.92, 0.92, 0.9)
const _FR := Color(0.78, 0.08, 0.1)
const _FB := Color(0.08, 0.22, 0.55)
const _FN := Color(0.02, 0.13, 0.38)
const _FK := Color(0.05, 0.05, 0.05)
const _FY := Color(0.98, 0.8, 0.1)
const _FG := Color(0.05, 0.5, 0.25)
## Flag on the right shoulder: [code, name, layout (Look_Flag_<layout> in merc.glb), colours Flag1..3].
## Only the code is kept in the look (and goes over the network). Drawn from shapes, no pictures.
const FLAGS := [["", "Bez vlajky", "", []],
	["cz", "Česko", "cz", [_FW, _FR, _FB]], ["sk", "Slovensko", "h3", [_FW, _FB, _FR]], ["pl", "Polsko", "h2", [_FW, _FR]],
	["de", "Německo", "h3", [_FK, Color(0.85, 0.05, 0.05), _FY]], ["at", "Rakousko", "h3", [_FR, _FW, _FR]],
	["hu", "Maďarsko", "h3", [_FR, _FW, _FG]], ["fr", "Francie", "v3", [_FB, _FW, _FR]], ["it", "Itálie", "v3", [_FG, _FW, _FR]],
	["ie", "Irsko", "v3", [_FG, _FW, Color(1.0, 0.5, 0.15)]], ["be", "Belgie", "v3", [_FK, _FY, _FR]],
	["nl", "Nizozemsko", "h3", [_FR, _FW, _FB]], ["ro", "Rumunsko", "v3", [_FN, _FY, _FR]], ["bg", "Bulharsko", "h3", [_FW, _FG, _FR]],
	["hr", "Chorvatsko", "h3", [_FR, _FW, _FB]], ["es", "Španělsko", "h3", [_FR, _FY, _FR]],
	["ua", "Ukrajina", "h2", [Color(0.0, 0.36, 0.73), Color(1.0, 0.84, 0.0)]], ["lt", "Litva", "h3", [_FY, _FG, _FR]],
	["lv", "Lotyšsko", "h3", [Color(0.55, 0.12, 0.18), _FW, Color(0.55, 0.12, 0.18)]], ["ee", "Estonsko", "h3", [Color(0.0, 0.45, 0.8), _FK, _FW]],
	["se", "Švédsko", "nordic", [Color(0.0, 0.42, 0.66), _FY]], ["dk", "Dánsko", "nordic", [_FR, _FW]],
	["fi", "Finsko", "nordic", [_FW, _FN]], ["no", "Norsko", "nordic3", [_FR, _FW, _FN]], ["is", "Island", "nordic3", [Color(0.0, 0.3, 0.6), _FW, _FR]],
	["ch", "Švýcarsko", "swiss", [_FR, _FW]], ["en", "Anglie", "cross", [_FW, _FR]], ["gb", "Velká Británie", "uk", [_FW, _FR, _FN]],
	["us", "USA", "us", [_FR, _FW, _FN]], ["jp", "Japonsko", "jp", [_FW, _FR]]]

func flag_index(code: String) -> int:
	for i in FLAGS.size():
		if FLAGS[i][0] == code:
			return i
	return 0

## The list index of a look key, kept in range (old looks without it: 0 = what they always wore).
func look_i(look: Dictionary, key: String, list: Array) -> int:
	return clampi(int(look.get(key, 0)), 0, list.size() - 1)
const FIRST_M := ["Jan", "Petr", "Mirek", "Karel", "Ivo", "Lukáš", "Ota", "René", "Vlad", "Erik", "Tomáš", "Radek", "Bořek", "Zdeněk"]
const FIRST_F := ["Dana", "Ema", "Sára", "Iva", "Klára", "Petra", "Zuzana", "Lenka", "Vendula", "Hana", "Jitka", "Bára"]
const LAST_M := ["Novák", "Král", "Dvořák", "Holub", "Černý", "Marek", "Vlk", "Hrubý", "Sokol", "Kopecký", "Bárta", "Krejčí"]
const LAST_F := ["Nováková", "Králová", "Dvořáková", "Holubová", "Černá", "Marková", "Vlková", "Hrubá", "Sokolová", "Kopecká", "Bártová", "Krejčí"]

func random_name(female: bool, r: RandomNumberGenerator) -> String:
	if female:
		return "%s %s" % [FIRST_F[r.randi() % FIRST_F.size()], LAST_F[r.randi() % LAST_F.size()]]
	return "%s %s" % [FIRST_M[r.randi() % FIRST_M.size()], LAST_M[r.randi() % LAST_M.size()]]

func random_look(female: bool, r: RandomNumberGenerator) -> Dictionary:
	return {
		"female": female,
		"hair": (["long", "pony", "bun", "short"] if female else ["buzz", "short", "none", "buzz", "mohawk"])[r.randi() % (4 if female else 5)],
		"hair_color": r.randi() % 6,
		"beard": 0 if female else r.randi() % BEARDS.size(),
		"eye_color": r.randi() % EYE_COLORS.size(),
		"skin": r.randi() % SKIN_TONES.size(),
		"headgear": 0 if r.randf() < 0.65 else (1 if r.randf() < 0.4 else r.randi_range(3, HEADGEAR.size() - 1)),
		"beret_color": r.randi() % BERET_COLORS.size(),
		"top": 0 if r.randf() < 0.5 else r.randi() % TOPS.size(),
		"pants": r.randi() % PANTS.size(),
		"vest": 0 if r.randf() < 0.5 else r.randi() % VESTS.size(),
		"paint": 0 if r.randf() < 0.6 else r.randi() % PAINTS.size(),
		"tattoo": 0 if r.randf() < 0.6 else r.randi() % TATTOOS.size(),
		"glasses": 0 if r.randf() < 0.75 else r.randi() % GLASSES.size(),
		"neck": 0 if r.randf() < 0.6 else r.randi() % NECKS.size(),
		"mouth": 0 if r.randf() < 0.85 else r.randi() % MOUTHS.size(),
	}

## Shows the chosen looks on a merc model (players in the mission, the menu preview).
func apply_look(model: Node, look: Dictionary) -> void:
	var hair: String = look.get("hair", "short")
	var beard: String = BEARDS[clampi(int(look.get("beard", 0)), 0, BEARDS.size() - 1)][0]
	var female: bool = look.get("female", false)
	var gear: String = HEADGEAR[clampi(int(look.get("headgear", 0)), 0, HEADGEAR.size() - 1)][0]
	var hc: Color = HAIR_COLORS[clampi(int(look.get("hair_color", 1)), 0, HAIR_COLORS.size() - 1)][1]
	var ec: Color = EYE_COLORS[clampi(int(look.get("eye_color", 0)), 0, EYE_COLORS.size() - 1)][1]
	var sc: Color = SKIN_TONES[clampi(int(look.get("skin", 1)), 0, SKIN_TONES.size() - 1)][1]
	var top: String = TOPS[look_i(look, "top", TOPS)][0]
	var pants: String = PANTS[look_i(look, "pants", PANTS)][0]
	var vest: String = VESTS[look_i(look, "vest", VESTS)][0]
	var paint: String = PAINTS[look_i(look, "paint", PAINTS)][0]
	var tattoo: String = TATTOOS[look_i(look, "tattoo", TATTOOS)][0]
	var glasses: String = GLASSES[look_i(look, "glasses", GLASSES)][0]
	var neck: String = NECKS[look_i(look, "neck", NECKS)][0]
	var mouth: String = MOUTHS[look_i(look, "mouth", MOUTHS)][0]
	var bc: Color = BERET_COLORS[look_i(look, "beret_color", BERET_COLORS)][1]
	var flag: Array = FLAGS[flag_index(str(look.get("flag", "")))]
	var bare := top == "bare"
	if neck == "mask":
		beard = "none"            # (the scarf covers the chin)
		mouth = "none"
	# which piece shows what (a piece missing from an older merc.glb is simply not there)
	var on := {
		"Look_TopJacket": top == "jacket", "Look_TopRolled": top == "rolled", "Look_TopTee": top == "tee", "Look_TopTank": bare and female,
		"Look_PatchL": not bare, "Look_PatchR": not bare and flag[0] == "", "Look_ArmbandL": bare, "Look_ArmbandR": bare,
		"Look_PantsCargo": pants in ["pads", "cargo"], "Look_KneePads": pants in ["pads", "plain_pads"],
		"Look_VestHarness": vest == "harness", "Look_VestCarrier": vest == "carrier", "Look_VestRig": vest == "rig",
		"Look_PaintEyes": paint == "eyes", "Look_PaintStripes": paint == "stripes", "Look_PaintBand": paint == "band", "Look_PaintFull": paint == "full",
		"Look_TatSkull": tattoo == "skull", "Look_TatAnchor": tattoo == "anchor", "Look_TatX": tattoo == "x",
		"Look_TatTribal": tattoo == "tribal", "Look_TatSleeve": tattoo == "sleeve",
		"Look_GlassShades": glasses == "shades", "Look_GlassBallistic": glasses == "ballistic",
		"Look_NeckShemagh": neck == "shemagh", "Look_NeckMask": neck == "mask", "Look_NeckTags": neck == "tags",
		"Look_MouthCigar": mouth == "cigar", "Look_MouthMatch": mouth == "match",
		"Gear_Beret": gear == "beret", "Gear_Boonie": gear == "boonie", "Gear_Bandana": gear == "bandana", "Gear_Headset": gear == "headset",
	}
	if top == "jacket":
		for k in on:
			if k.begins_with("Look_Tat"):
				on[k] = false       # (under the sleeve anyway)
	# face paint in the mission's camouflage colours (at the base: woodland)
	var pc: Array = CAMO_COLORS.get(camo, CAMO_COLORS["woodland"])
	var hair_nodes := {"buzz": "Look_HairBuzz", "short": "Look_HairShort", "long": "Look_HairLong", "pony": "Look_HairPony", "mohawk": "Look_HairMohawk", "bun": "Look_HairBun"}
	var beard_nodes := {"stubble": "Look_Stubble", "moustache": "Look_Moustache", "goatee": "Look_Goatee", "full": "Look_BeardFull"}
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("Look_Hair"):
			mi.visible = hair_nodes.get(hair, "") == nm and not (gear not in ["none", "headset"] and hair == "mohawk")
		elif on.has(nm):
			mi.visible = on[nm]
			mi.set_meta("look_on", on[nm])       # (player._apply_gear: armour from the inventory hides a vest)
		elif nm.begins_with("Look_Flag_"):
			mi.visible = not bare and nm == "Look_Flag_" + str(flag[2])
		elif nm in beard_nodes.values():
			mi.visible = not female and beard_nodes.get(beard, "") == nm
		elif nm == "Look_Female":
			mi.visible = female
		elif nm == "Look_Jaw":
			mi.visible = not female
		elif nm == "Gear_Helmet":
			mi.visible = gear == "helmet"
		elif nm == "Gear_Torch":
			mi.visible = gear == "helmet"
		elif nm == "Gear_Cap":
			mi.visible = gear == "cap"
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src == null:
				continue
			match src.resource_name:
				"Hair":
					mi.set_surface_override_material(i, color_mat(hc))
				"Beard":
					mi.set_surface_override_material(i, color_mat(hc.darkened(0.1)))
				"Eyes":
					mi.set_surface_override_material(i, color_mat(ec))
				"Skin":
					mi.set_surface_override_material(i, color_mat(sc))
				"Beret", "Bandana":
					mi.set_surface_override_material(i, color_mat(bc))
				"FacePaint":
					mi.set_surface_override_material(i, color_mat(pc[3] if camo != "snow" else pc[2]))
				"FacePaint2":
					mi.set_surface_override_material(i, color_mat(pc[1]))
				"Flag1", "Flag2", "Flag3":
					var fc: Array = flag[3]
					var k := int(String(src.resource_name).right(1)) - 1
					if k < fc.size():
						mi.set_surface_override_material(i, color_mat(fc[k]))

## First-person hands: with bare arms (rolled sleeves, T-shirt, no shirt) the sleeve is skin.
## (hands*.glb: materials "Sleeve", "SleeveCuff", "Wrist" - the bones and grips stay as they are)
func dress_hands(n: Node, look: Dictionary) -> void:
	var top: String = TOPS[look_i(look, "top", TOPS)][0]
	var sc: Color = SKIN_TONES[clampi(int(look.get("skin", 1)), 0, SKIN_TONES.size() - 1)][1]
	for mi in ([n] if n is MeshInstance3D else []) + n.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src == null:
				continue
			match src.resource_name:
				"Wrist":
					mi.set_surface_override_material(i, color_mat(sc))
				"Sleeve":
					if top != "jacket":
						mi.set_surface_override_material(i, color_mat(sc))
				"SleeveCuff":
					if top == "tee" or top == "bare":
						mi.set_surface_override_material(i, color_mat(sc))

# ---- ranks, experience and permanent talents -------------------------------------------
const RANKS := ["Nováček", "Vojín", "Svobodník", "Desátník", "Četař", "Rotný", "Rotmistr", "Poručík", "Kapitán"]
const RANK_XP := [0, 120, 300, 550, 850, 1250, 1750, 2400, 3200]
const TALENTS := {
	"pevna_ruka": ["Pevná ruka", "Zbraň se méně třese (−35 % chvění) a míříš o polovinu rychleji."],
	"mezek": ["Mezek", "Unese o 15 kg víc."],
	"rychle_prebiti": ["Rychlé ruce", "Přebíjení i přendávání výstroje o třetinu rychlejší."],
	"kocici_krok": ["Kočičí krok", "Kroky jsou poloviční hluk (i ve sprintu)."],
	"felcar": ["Felčar", "Lékárnička léčí dvojnásob, ošetření spolubojovníka trvá 2 s."],
	"zelezne_nervy": ["Železné nervy", "Strach roste o 40 % pomaleji a psí útoky tě skoro neberou."],
	"sprinter": ["Sprinter", "Sprint méně vyčerpává, dech se uklidní rychleji."],
	"houzevnaty": ["Houževnatý", "+12 zdraví a o 45 s delší vykrvácení."],
	"strelec": ["Střelec", "O čtvrtinu menší rozptyl všech zbraní."],
	"tichy_zabijak": ["Tichý zabiják", "Nůž zezadu zabíjí na jednu ránu a nedělá hluk; obušek omračuje o polovinu silněji."],
	"tezka_vaha": ["Těžká váha", "Těžké zbraně zpomalují jen napůl."],
	"sesty_smysl": ["Šestý smysl", "Cítíš, když tě vetřelci vidí: oko vlevo dole i na obtížnosti normal a veterán."],
	"druhy_dech": ["Druhý dech", "Jednou za misi se po pádu sám zvedneš (za 6 s, s třetinou zdraví)."],
	"nocni_oko": ["Noční oko", "Ve tmě vidíš víc než ostatní (oči si zvyknou), noktovizor ti nezrní."],
	"granatnik": ["Granátník", "Granáty, kouř i světlice hodíš o polovinu dál."],
	# 0.62 (Ari): new talents of the tree
	"rychle_taseni": ["Rychlé tasení", "Výměna a tasení zbraně o polovinu rychleji."],
	"zadrzet_dech": ["Zadržet dech", "V mířidle podržíš Shift a zbraň se 4 s skoro nehne (pak se chvíli třese víc)."],
	"rvac": ["Rváč", "Rychlý úder (nůž, obušek, pažba, pistole) o polovinu silnější a rychlejší."],
	"polni_osetreni": ["Polní ošetření", "Při obvazování se hýbeš normální chůzí, ne jen pomalu."],
	"opora_tymu": ["Opora týmu", "Spolubojovníkům do 10 m od tebe roste strach o čtvrtinu pomaleji."],
	"technik_dronu": ["Technik dronu", "Strážce léčí dvakrát rychleji a až do tří čtvrtin zdraví, za misi tě zvedne dvakrát."],
}
## 0.62 (Ari): the talent tree - four branches of five. A talent can be taken once the one before it
## in the branch is owned and the soldier has the rank of its tier (TREE_RANK). Nothing is taken back.
## On the easy difficulty (where the eye is always shown) the 4th of Specialista is the drone instead.
const TALENT_TREE := [
	["Střelec", ["rychle_prebiti", "pevna_ruka", "strelec", "rychle_taseni", "zadrzet_dech"]],
	["Útočník", ["sprinter", "kocici_krok", "granatnik", "tichy_zabijak", "rvac"]],
	["Přežití", ["houzevnaty", "felcar", "zelezne_nervy", "polni_osetreni", "druhy_dech"]],
	["Specialista", ["mezek", "tezka_vaha", "nocni_oko", "sesty_smysl", "opora_tymu"]],
]
const TREE_RANK := [1, 2, 4, 6, 8]      # Vojín, Svobodník, Četař, Rotmistr, Kapitán
const TREE_SWAP := {"sesty_smysl": "technik_dronu"}   # shown instead on the easy difficulty

## The talent in a place of the tree (the drone on easy). m = the soldier (owned one wins).
func tree_talent(b: int, tier: int, m: Dictionary = {}) -> String:
	var id: String = TALENT_TREE[b][1][tier]
	if TREE_SWAP.has(id):
		var alt: String = TREE_SWAP[id]
		if not m.is_empty() and has_talent(m, alt):
			return alt
		if not m.is_empty() and has_talent(m, id):
			return id
		if difficulty == "easy":
			return alt
	return id

func _tier_owned(m: Dictionary, b: int, tier: int) -> bool:
	var id: String = TALENT_TREE[b][1][tier]
	return has_talent(m, id) or (TREE_SWAP.has(id) and has_talent(m, TREE_SWAP[id]))

## "owned" / "open" (can be taken now) / "nopoint" (could, but no point) / "rank" (needs a higher rank)
## / "locked" (the one before it is missing).
func talent_state(m: Dictionary, b: int, tier: int) -> String:
	if _tier_owned(m, b, tier):
		return "owned"
	if tier > 0 and not _tier_owned(m, b, tier - 1):
		return "locked"
	if rank_of(m) < TREE_RANK[tier]:
		return "rank"
	return "open" if int(m.get("talent_points", 0)) > 0 else "nopoint"

func _tree_place(id: String) -> Vector2i:
	for b in TALENT_TREE.size():
		for t in 5:
			var tid: String = TALENT_TREE[b][1][t]
			if tid == id or TREE_SWAP.get(tid, "") == id:
				return Vector2i(b, t)
	return Vector2i(-1, -1)
## Talents that were replaced by better ones (old saves keep what they had, under the new name).
const TALENT_NEW := {"rychle_ruce": "rychle_prebiti", "lovec_hlav": "tichy_zabijak"}

func has_talent(m: Dictionary, id: String) -> bool:
	var t: Array = m.get("talents", [])
	if id in t:
		return true
	for old in TALENT_NEW:
		if TALENT_NEW[old] == id and old in t:
			return true
	return false

func rank_of(m: Dictionary) -> int:
	var xp := int(m.get("xp", 0))
	var r := 0
	for i in RANK_XP.size():
		if xp >= RANK_XP[i]:
			r = i
	return r

func rank_name(m: Dictionary) -> String:
	return RANKS[rank_of(m)]

## Adds experience to the current mercenary; returns lines describing promotions.
func add_xp(amount: int) -> Array:
	var out := []
	var before := rank_of(merc)
	merc["xp"] = int(merc.get("xp", 0)) + amount
	var after := rank_of(merc)
	var r := RandomNumberGenerator.new()
	r.randomize()
	for lvl in range(before + 1, after + 1):
		# a promotion: two stats grow, and a talent can be chosen
		var stats := ["accuracy", "reactions", "strength", "bravery", "health", "stamina"]
		var grown := []
		for k in 2:
			var st: String = stats[r.randi() % stats.size()]
			var inc := r.randi_range(2, 5) if st != "health" else r.randi_range(1, 3)
			merc[st] = int(merc[st]) + inc
			grown.append("%s +%d" % [STAT_NAMES[st], inc])
		merc["talent_points"] = int(merc.get("talent_points", 0)) + 1
		out.append("POVÝŠEN na %s! %s. Nový bod do stromu talentů (Vojáci → Talenty)." % [RANKS[lvl], ", ".join(grown)])
	save_merc()
	return out

const STAT_NAMES := {"accuracy": "Přesnost", "reactions": "Reakce", "strength": "Síla", "bravery": "Odvaha", "health": "Zdraví", "stamina": "Výdrž"}

func pick_talent(id: String) -> void:
	if int(merc.get("talent_points", 0)) <= 0 or has_talent(merc, id):
		return
	var at := _tree_place(id)
	if at.x < 0 or talent_state(merc, at.x, at.y) != "open":
		return
	var t: Array = merc.get("talents", [])
	t.append(id)
	merc["talents"] = t
	merc["talent_points"] = int(merc["talent_points"]) - 1
	merc.erase("offer")      # (the old random offer of three - gone with the tree)
	save_merc()
	Net.update_merc()        # (co-op: the host keeps the soldier, the others see the talent)

## (0.57) The campaign merc out on a mission right now (his name, kept in merc.cfg until the
## mission ends). Still set when the game starts = it went down mid-mission (Alt+F4, a crash):
## no way out of a bad mission - nobody came for him, he is missing.
var on_mission := ""
## What the main menu says once after such a start.
var crash_note := ""
func mission_out(going: bool) -> void:
	on_mission = String(merc.get("name", "")) if going else ""
	save_merc()

func load_merc() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://merc.cfg") == OK:
		mercs = cf.get_value("merc", "roster", [])
		active = int(cf.get_value("merc", "active", 0))
		on_mission = String(cf.get_value("merc", "on_mission", ""))
		if mercs.is_empty():
			var one: Dictionary = cf.get_value("merc", "data", {})
			if not one.is_empty():
				mercs = [one]
	if mercs.is_empty():
		mercs = [new_merc()]
	active = clampi(active, 0, mercs.size() - 1)
	if on_mission != "":
		for i in mercs.size():
			var lost: Dictionary = mercs[i]
			if String(lost.get("name", "")) == on_mission:
				var fresh := new_merc()
				fresh["money"] = maxi(0, int(lost.get("money", 0)) - 250)
				mercs[i] = fresh
				crash_note = "Hra skončila uprostřed mise. %s zůstal na místě - NEZVĚSTNÝ (odškodné rodině -250 kr; úspory převzal nový voják %s)." % [on_mission, String(fresh["name"])]
				break
		on_mission = ""
	merc = mercs[active]
	# wounds from before 0.26 healed in real time - let them be healed
	for m in mercs:
		if m.has("injury_time"):
			m.erase("injury_time")
			m.erase("injury")
	save_merc()

# ---- quick missions (skirmish): a mercenary for one use only ---------------------------------
## In a quick mission nothing counts: the merc is a copy (or a made-up one), his pay, experience,
## wounds and death are thrown away afterwards. Only the campaign shapes a mercenary.
var skirmish := false
var _real_merc := {}
const SKIRMISH_KINDS := {"copy": "Kopie mého vojáka", "rookie": "Nováček", "veteran": "Ostřílený veterán", "elite": "Elitní voják"}
func begin_skirmish(kind := "copy") -> void:
	if skirmish:
		end_skirmish()
	_real_merc = merc
	var m: Dictionary = merc.duplicate(true)
	m.erase("injury"); m.erase("heal_days"); m.erase("sick")
	var bonus: int = int({"copy": 0, "rookie": -1, "veteran": 2, "elite": 4}.get(kind, 0))
	if kind != "copy":
		var lv: Dictionary = (m.get("levels", {}) as Dictionary).duplicate()
		for st in STAT_ORDER:
			var l := clampi((5 if kind != "rookie" else 3) + bonus, 0, LEVEL_MAX)
			lv[st] = l
			m[st] = stat_value(st, l)
		m["levels"] = lv
		m["xp"] = {"rookie": 0, "veteran": 1500, "elite": 4000}.get(kind, 0)
	skirmish = true
	merc = m

func end_skirmish() -> void:
	if not skirmish:
		return
	skirmish = false
	if not _real_merc.is_empty():
		merc = _real_merc
	_real_merc = {}

## Quick missions: the whole arsenal, as much as you like (it is only a try-out).
func free_stash() -> Dictionary:
	var out := {}
	for k in STASH:
		out[k] = 6
	for k in Campaign.SHOP:
		if ITEMS.has(k):
			out[k] = 6
	return out

func save_merc() -> void:
	if skirmish:
		return      # a quick mission's merc is never saved
	if active < mercs.size():
		mercs[active] = merc
	var cf := ConfigFile.new()
	cf.set_value("merc", "data", merc)
	cf.set_value("merc", "roster", mercs)
	cf.set_value("merc", "active", active)
	cf.set_value("merc", "on_mission", on_mission)
	cf.save("user://merc.cfg")

## Another mercenary from the roster goes on the next mission (the purse goes with the player).
func switch_merc(i: int) -> void:
	if i < 0 or i >= mercs.size() or i == active:
		return
	var money := int(merc.get("money", 0))
	merc["money"] = 0
	mercs[active] = merc
	active = i
	merc = mercs[i]
	merc["money"] = int(merc.get("money", 0)) + money
	save_merc()
	Net.reregister()

## A new recruit in a free slot (made with the creation screen afterwards).
func hire_merc() -> int:
	if mercs.size() >= MERC_SLOTS:
		return -1
	var m := new_merc()
	mercs.append(m)
	save_merc()
	return mercs.size() - 1

## Dismiss a mercenary for good (never the last one).
func dismiss_merc(i: int) -> void:
	if mercs.size() <= 1 or i < 0 or i >= mercs.size():
		return
	var money := int(mercs[i].get("money", 0))
	var was_active := i == active
	mercs.remove_at(i)
	if i < active:
		active -= 1
	active = clampi(active, 0, mercs.size() - 1)
	merc = mercs[active]
	if was_active:
		merc["money"] = int(merc.get("money", 0)) + money
		Net.reregister()
	save_merc()

# ---- difficulty: "normal" or "veteran" (the host's choice decides the mission) ----
var difficulty := "normal"
var mouse_sens := 1.0      # multiplier
var invert_y := false
var fov := 75.0
const HEAL_MINUTES_PER_HP := 10.0   # veteran: wounds heal in real time, like X-COM's days

func veteran() -> bool:
	return Net.mission_difficulty == "veteran"

## Easy: weaker, slower, less accurate aliens and one fewer of them; your wounds hurt less.
func easy() -> bool:
	return Net.mission_difficulty == "easy"

const DIFF_NAMES := {"easy": "snadná", "normal": "normální", "veteran": "HARDCORE (veterán)"}
func next_difficulty() -> void:
	difficulty = {"easy": "normal", "normal": "veteran", "veteran": "easy"}[difficulty] if difficulty in ["easy", "normal", "veteran"] else "normal"

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		difficulty = cf.get_value("game", "difficulty", "normal")
		loadout = cf.get_value("game", "loadout", {})
		mouse_sens = cf.get_value("controls", "mouse_sens", 1.0)
		invert_y = cf.get_value("controls", "invert_y", false)
		fov = cf.get_value("controls", "fov", 75.0)
		retro = false       # (the PS1 look is gone since 0.50: a modern picture)
		wobble = false
		volumetric = cf.get_value("video", "volumetric", true)
		render_scale = cf.get_value("video", "render_scale", 1.0)
		grass = cf.get_value("video", "grass", true)
		shadows = clampi(int(cf.get_value("video", "shadows", 1)), 0, 2)
		detail = clampi(int(cf.get_value("video", "detail", 1)), 0, 2)
		hud_min = bool(cf.get_value("video", "hud_min", false))
		fullscreen = cf.get_value("video", "fullscreen", false)
		seen_version = cf.get_value("game", "seen_version", "")
		intro_seen = cf.get_value("game", "intro_seen", false)
		voice_mode = cf.get_value("voice", "mode", "ptt")
		mic_gate = cf.get_value("voice", "gate", 0.03)
		mimic_ok = cf.get_value("voice", "mimic", true)
		mic_gain = cf.get_value("voice", "gain", 1.0)
		mic_clean = cf.get_value("voice", "clean", true)
		mic_device = cf.get_value("voice", "device", "")
		friendly_fire = cf.get_value("game", "friendly_fire", true)
		music_volume = cf.get_value("game", "music_volume", 0.7)
		for b in volumes:
			volumes[b] = cf.get_value("audio", b, volumes[b])
		tactical_music = cf.get_value("game", "tactical_music", false)
		voice_volumes = cf.get_value("voice", "volumes", {})
	apply_video()

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("game", "loadout", loadout)
	cf.set_value("controls", "mouse_sens", mouse_sens)
	cf.set_value("controls", "invert_y", invert_y)
	cf.set_value("controls", "fov", fov)
	cf.set_value("video", "retro", retro)
	cf.set_value("video", "wobble", wobble)
	cf.set_value("video", "volumetric", volumetric)
	cf.set_value("video", "render_scale", render_scale)
	cf.set_value("video", "grass", grass)
	cf.set_value("video", "shadows", shadows)
	cf.set_value("video", "detail", detail)
	cf.set_value("video", "hud_min", hud_min)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("game", "seen_version", seen_version)
	cf.set_value("game", "intro_seen", intro_seen)
	cf.set_value("voice", "mode", voice_mode)
	cf.set_value("voice", "gate", mic_gate)
	cf.set_value("voice", "mimic", mimic_ok)
	cf.set_value("voice", "gain", mic_gain)
	cf.set_value("voice", "clean", mic_clean)
	cf.set_value("voice", "device", mic_device)
	cf.set_value("game", "friendly_fire", friendly_fire)
	cf.set_value("game", "music_volume", music_volume)
	for b in volumes:
		cf.set_value("audio", b, volumes[b])
	cf.set_value("game", "tactical_music", tactical_music)
	cf.set_value("voice", "volumes", voice_volumes)
	cf.save("user://settings.cfg")

## Wounds heal in GAME time: days on the campaign clock (any campaign the player is in -
## days that pass in a campaign count, real time does not).
const HEAL_HP_PER_DAY := 5.0
func wound(m: Dictionary, hp_lost: float, cid: String, day: float) -> float:
	if hp_lost < 1.0:
		return 0.0
	var days := maxf(1.0, ceilf(hp_lost / HEAL_HP_PER_DAY * (1.0 if veteran() else 0.6)))
	m["injury"] = hp_lost
	m["heal_days"] = days
	m["heal_cid"] = cid
	m["heal_seen"] = day
	return days

## counts the days that passed on the campaign clock since we last looked
func tick_injury(m: Dictionary) -> void:
	if float(m.get("heal_days", 0.0)) <= 0.0 or not Campaign.data.has("day"):
		return
	var cid := str(Campaign.data.get("cid", ""))
	var d := float(Campaign.data["day"])
	if str(m.get("heal_cid", "")) == cid:
		m["heal_days"] = float(m["heal_days"]) - maxf(0.0, d - float(m.get("heal_seen", d))) * (2.0 if Campaign.active and Campaign.count("osetrovna") > 0 else 1.0)
	m["heal_cid"] = cid
	m["heal_seen"] = d
	if float(m["heal_days"]) <= 0.0:
		m.erase("heal_days")
		m.erase("injury")

func heal_days_left(m: Dictionary) -> float:
	tick_injury(m)
	return float(m.get("heal_days", 0.0))

func can_deploy(m: Dictionary) -> bool:
	return heal_days_left(m) <= 0.0

## health still missing (only while on the sick bay - and then he does not go anyway)
func injury_now(m: Dictionary) -> float:
	return float(m.get("injury", 0.0)) if heal_days_left(m) > 0.0 else 0.0

func sick_text(m: Dictionary) -> String:
	var d := heal_days_left(m)
	if d <= 0.0:
		return ""
	var h := ceili(d * 24.0)
	return "NA MARODCE ještě %s (herního času)" % (("%d h" % h) if h < 24 else ("%.1f dne" % d))

# ---- loadout: chosen in the menu from what the base can spare ------------------------
const STASH := {"sniper": 1, "sniper_clip": 3, "rifle": 1, "pistol": 1, "shotgun": 1, "magnum": 1, "autocannon": 1, "minigun": 1, "rocket_launcher": 1,
	"stun_baton": 1, "knife": 1, "rifle_clip": 4, "pistol_clip": 3, "shells": 3, "slugs": 2, "beanbag": 2, "magnum_rounds": 3, "ac_clip": 3,
	"minigun_belt": 2, "rocket": 3, "rocket_ap": 1, "rocket_inc": 1, "grenade": 3, "smoke_grenade": 2, "mine": 2, "flare": 4, "medkit": 1, "scanner": 1, "radio": 4,
	"vesta": 1, "stit": 1, "pancir": 1, "nvg": 1}
const STASH_VETERAN := {"sniper": 1, "sniper_clip": 2, "rifle": 1, "pistol": 1, "shotgun": 1, "magnum": 1, "autocannon": 1, "minigun": 1, "rocket_launcher": 1,
	"stun_baton": 1, "knife": 1, "rifle_clip": 2, "pistol_clip": 2, "shells": 2, "slugs": 1, "beanbag": 1, "magnum_rounds": 2, "ac_clip": 1,
	"minigun_belt": 1, "rocket": 1, "grenade": 1, "smoke_grenade": 1, "mine": 1, "flare": 2, "medkit": 1, "scanner": 1, "radio": 4,
	"vesta": 1, "stit": 1, "pancir": 1}
const DEFAULT_LOADOUT := {"rh": "rifle", "back": "", "b0": "scanner", "b1": "rifle_clip", "b2": "rifle_clip", "b3": "radio",
	"side": "pistol", "p0": "medkit", "p1": "pistol_clip", "p2": "knife", "p3": "flare", "p4": "grenade", "p5": "smoke_grenade"}
## Starting kits by soldier type (trimmed to what the base has).
const KITS := {
	"Střelec": {"rh": "rifle", "b0": "rifle_clip", "b1": "rifle_clip", "b2": "medkit", "b3": "radio", "side": "pistol", "p0": "rifle_clip", "p1": "pistol_clip", "p2": "grenade", "p3": "flare", "p4": "scanner", "p5": "knife", "armor": "vesta"},
	"Odstřelovač": {"rh": "sniper", "b0": "sniper_clip", "b1": "sniper_clip", "b2": "pistol_clip", "b3": "radio", "side": "pistol", "p0": "sniper_clip", "p1": "pistol_clip", "p2": "knife", "p3": "flare", "p4": "smoke_grenade", "p5": "medkit", "armor": "vesta"},
	"Útočník": {"rh": "shotgun", "b0": "shells", "b1": "shells", "b2": "grenade", "b3": "radio", "side": "magnum", "p0": "shells", "p1": "magnum_rounds", "p2": "magnum_rounds", "p3": "grenade", "p4": "knife", "p5": "flare", "armor": "vesta"},
	"Těžký": {"rh": "autocannon", "b0": "ac_clip", "b1": "ac_clip", "b2": "grenade", "b3": "radio", "side": "pistol", "p0": "ac_clip", "p1": "pistol_clip", "p2": "pistol_clip", "p3": "flare", "armor": "vesta"},
	"Zdravotník": {"rh": "rifle", "b0": "rifle_clip", "b1": "medkit", "b2": "smoke_grenade", "b3": "radio", "p0": "rifle_clip", "p1": "medkit", "p2": "smoke_grenade", "p3": "flare", "side": "pistol", "p4": "pistol_clip", "p5": "stun_baton", "armor": "vesta"},
	"Ženista": {"rh": "shotgun", "b0": "shells", "b1": "mine", "b2": "grenade", "b3": "radio", "p0": "shells", "p1": "mine", "p2": "grenade", "p3": "smoke_grenade", "p4": "scanner", "p5": "flare"},
	"Štítař": {"rh": "pistol", "lh": "stit", "armor": "vesta", "b0": "pistol_clip", "b1": "pistol_clip", "b2": "grenade", "b3": "radio", "p0": "pistol_clip", "p1": "medkit", "p2": "smoke_grenade", "p3": "flare", "p4": "knife"},
}
var loadout := {}    # slot -> item id

# ---- 0.60: the player's own templates (soldiers die often - no need to make each one again) ----
## Kept on this computer only (user://presety.cfg), not with the merc, so they outlive him.
## "merc" = the looks, the name and (only when made with the points, never a lucky dice roll)
## the levels; "gear" = a full loadout (trimmed to the stores only when it is put on).
## Co-op: each player keeps his own; what they make goes the usual way (save_merc + Net).
var preset_file := "user://presety.cfg"
const PRESET_MAX := 6

func presets(kind: String) -> Array:
	var cf := ConfigFile.new()
	if cf.load(preset_file) != OK:
		return []
	var out: Array = []
	for p in cf.get_value("presets", kind, []):
		if p is Dictionary:
			out.append(p)
	return out

func _save_presets(kind: String, list: Array) -> void:
	var cf := ConfigFile.new()
	cf.load(preset_file)
	cf.set_value("presets", kind, list)
	cf.save(preset_file)

## Saves (or overwrites the one with the same label); false when the list is full.
func save_preset(kind: String, label: String, data: Dictionary) -> bool:
	var list := presets(kind)
	var d := data.duplicate(true)
	d["label"] = label
	for i in list.size():
		if String(list[i].get("label", "")) == label:
			list[i] = d
			_save_presets(kind, list)
			return true
	if list.size() >= PRESET_MAX:
		return false
	list.append(d)
	_save_presets(kind, list)
	return true

func delete_preset(kind: String, i: int) -> void:
	var list := presets(kind)
	if i >= 0 and i < list.size():
		list.remove_at(i)
		_save_presets(kind, list)

## The soldier template from a merc being made (levels only from the points - dice stay dice).
func merc_preset(m: Dictionary, points: bool) -> Dictionary:
	var d := {"look": (m.get("look", {}) as Dictionary).duplicate(true), "name": String(m.get("name", ""))}
	if points:
		d["levels"] = (m.get("levels", {}) as Dictionary).duplicate()
	return d

## A free label "<base>", "<base> 2", ...
func preset_label(kind: String, base: String) -> String:
	var used := presets(kind).map(func(p): return String(p.get("label", "")))
	if not base in used:
		return base
	for n in range(2, 99):
		if not ("%s %d" % [base, n]) in used:
			return "%s %d" % [base, n]
	return base

func stash_for(vet: bool) -> Dictionary:
	if not Net.mission_params.is_empty() and Net.mission_params.has("stash"):
		var ms: Dictionary = (Net.mission_params["stash"] as Dictionary).duplicate()
		for k in merc.get("locker", {}):
			ms[k] = int(ms.get(k, 0)) + int(merc["locker"][k])
		return ms
	if Campaign.active or Campaign.viewer:
		# what the (host's) base has, plus what this merc bought for himself
		var st: Dictionary = Campaign.stash().duplicate()
		for k in merc.get("locker", {}):
			st[k] = int(st.get(k, 0)) + int(merc["locker"][k])
		return st
	if skirmish or not Net.mission_params.has("cid"):
		return free_stash()
	return STASH_VETERAN if vet else STASH

## Research done in the running campaign mission (host's campaign).
func has_research(id: String) -> bool:
	if not Net.mission_params.is_empty():
		return id in Net.mission_params.get("research", [])
	return Campaign.built(id)

## The chosen loadout trimmed to what the stash allows on this difficulty.
func valid_loadout(vet: bool) -> Dictionary:
	var src: Dictionary = loadout if not loadout.is_empty() else DEFAULT_LOADOUT
	var left: Dictionary = stash_for(vet).duplicate()
	var out := {}
	for slot in SLOTS:
		if not src.has(slot):
			continue
		var id: String = src[slot]
		if id == "" or not ITEMS.has(id):
			continue
		if int(left.get(id, 0)) <= 0:
			continue
		# older loadouts: a gun on the back with nothing in the hands becomes the primary,
		# a second gun goes to the secondary slot (if it fits) or into the pack
		var to: String = slot
		if slot == "back":
			to = "rh" if not out.has("rh") else "p"
		if to == "rh" and slot_refuse("rh", id) != "":
			to = "p"
		if to == "lh" and slot_refuse("lh", id) != "":
			to = "side" if slot_refuse("side", id) == "" and not out.has("side") else "p"
		if to == "lh" and out.has("rh") and two_handed(out["rh"]):
			to = "p"
		if to == "side" and slot_refuse("side", id) != "":
			to = "p"
		if to == "p":
			to = ""
			for ps in pack_slots() + ["b0", "b1", "b2", "b3"]:
				if not out.has(ps) and not src.has(ps):
					to = ps
					break
			if to == "":
				continue
		if out.has(to):
			continue
		left[id] = int(left[id]) - 1
		out[to] = id
	# armour is worn, not carried in a slot
	var arm: String = String(src.get("armor", ""))
	if arm != "" and ITEMS.has(arm) and int(left.get(arm, 0)) > 0:
		out["armor"] = arm
	# older saved loadouts: the pistol in the pack becomes the secondary weapon
	if not out.has("side"):
		for ps in ["b0", "b1", "b2", "b3"] + pack_slots():
			if out.has(ps) and ITEMS[out[ps]]["type"] == "weapon" and slot_refuse("side", out[ps]) == "":
				out["side"] = out[ps]
				out.erase(ps)
				break
	# everybody gets a radio (older saved loadouts did not have one): first free belt/pack slot
	if not "radio" in out.values() and int(left.get("radio", 0)) > 0:
		for slot in ["b0", "b1", "b2", "b3"] + pack_slots():
			if not out.has(slot):
				out[slot] = "radio"
				break
	return out

func default_loadout() -> Dictionary:
	var vet := veteran()
	var inv := {}
	var ids := valid_loadout(vet)
	for slot in ids:
		if slot == "armor":
			continue
		var id: String = ids[slot]
		var it := {"id": id}
		if ITEMS[id]["type"] == "weapon":
			it["loaded"] = mag_size(id)
		elif id == "medkit":
			it["uses"] = (2 if vet else 3) + (1 if has_research("medicina") else 0)
		inv[slot] = it
	return inv

# ---- shared resources ----
var _materials := {}
var _sounds := {}

## Materials that sway in the wind (strength per metre of height above the mesh centre).
const WINDY := {"leaves": 0.09, "wheat": 0.16}
const WORLD_SHADER := preload("res://shaders/world.gdshader")
const RoomEcho := preload("res://scripts/room_echo.gd")
const METAL_SHADER := preload("res://shaders/world_metal.gdshader")
var retro := true          # the screen filter: dithering, grain, colour bleed
var wobble := false        # PS1 vertex jitter (the world "shivers" a little) - its own switch since 0.50
var volumetric := true     # volumetric fog (Forward+ only)
var render_scale := 1.0    # 3D resolution (1 = native, sharp; lower = faster)
var grass := true          # grass blades swaying in the wind
var hud_min := false       # (0.66) minimal HUD: ammunition only as a guess
var hud_hidden := false    # (0.66) F1 in the game: the HUD hidden (not saved)
var loud_at := Vector3.ZERO   # (0.66) where the last loud sound was played (the compass shows it)
var loud_ms := -100000
var shadows := 1           # 0.62 výkon: stíny 0 = nízké, 1 = střední, 2 = vysoké (jako do 0.61)
var fullscreen := false
var seen_version := ""     # the newest version whose "what's new" the player has seen
var intro_seen := false    # (0.70) the intro film played once on this machine (then only from the menu)
var voice_mode := "ptt"    # "off", "ptt" (hold Tab), "open" (voice activation)
var mic_gate := 0.03       # voice activation threshold (open mic)
var friendly_fire := true   # host's choice: bullets hit teammates too
var mic_gain := 1.0        # own microphone loudness (x0.5 .. x4)
var mic_clean := true      # (0.62) pull the room noise down between words (voice_dsp.gd)
var mic_device := ""       # input device name ("" = system default)
var mic_level := 0.0       # live level for the meter (set by whoever reads the mic)
var voice_volumes := {}    # teammate name -> 0..2 (how loud I hear them)
func peer_volume(player_name: String) -> float:
	return float(voice_volumes.get(player_name, 1.0))
var mimic_ok := true       # aliens may imitate my voice (snippets live only in RAM during a mission)

## Resolution / window settings. The UI is laid out at 640x360 but drawn at the
## real window resolution (stretch mode canvas_items), so text stays sharp.
func apply_video() -> void:
	var root := get_tree().root
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if render_scale >= 0.99 else Viewport.SCALING_3D_MODE_FSR
	root.scaling_3d_scale = render_scale
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)

## 0.62 výkon: každé světlo se stínem kreslí scénu znovu (bodové 6×), měsíc ve 4 pásmech až do 100 m -
## dohromady tisíce kreslení navíc za snímek. Lampy a ohně proto vrhají stín jen blízko kamery
## (dál svítí bez stínu, ve tmě a mlze to oko nepozná), měsíc ve 2 pásmech na kratší vzdálenost.
## Úroveň v Nastavení: nízké (lampy bez stínů), střední (výchozí), vysoké (stíny jako do 0.61).
const SHADOW_NEAR := [0.0, 22.0, 45.0]
func shadow_light(l: Light3D) -> void:
	if l == null or not l.shadow_enabled:
		return
	if shadows <= 0:
		l.shadow_enabled = false
		return
	l.distance_fade_enabled = true
	l.distance_fade_begin = 60.0
	l.distance_fade_length = 10.0
	l.distance_fade_shadow = SHADOW_NEAR[clampi(shadows, 0, 2)]

func shadow_sun(sun: DirectionalLight3D) -> void:
	if sun == null:
		return
	if shadows >= 2:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_max_distance = 100.0
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 50.0 if shadows == 1 else 35.0

## 0.62 výkon (Ari: ve městě propady FPS při pohledu do dálky): město má přes 2 000 samostatných
## kousků (rámy oken, květináče, lahve, cedule...) a 80 polí trávy s desítkami tisíc stébel - při
## pohledu přes celé město se kreslilo všechno až k obzoru. Drobnosti se teď kreslí jen do
## vzdálenosti podle velikosti (30 cm do 25 m, 1 m do 45 m, 2 m do 90 m), tráva do 45 m;
## velké věci (domy, zdi, sloučené díly) beze změny. Hra (střely, výhled vetřelců) to nijak nemění.
## Nastavení „Detaily v dálce“: blízko (slabý počítač) / střední / daleko.
var detail := 1
const DETAIL_K := [0.65, 1.0, 1.7]
func far_cull(root: Node) -> void:
	if root == null:
		return
	var k: float = DETAIL_K[clampi(detail, 0, 2)]
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.visibility_range_end > 0.0:
			continue
		if g is MultiMeshInstance3D:
			var a := (g as MultiMeshInstance3D).get_aabb()
			g.visibility_range_end = 45.0 * k + a.size.length() * 0.5
			continue
		if not g is MeshInstance3D or (g as MeshInstance3D).mesh == null or (g as MeshInstance3D).skin != null:
			continue
		var sz := (g.global_transform.basis * (g as MeshInstance3D).get_aabb().size).abs()
		var l := maxf(sz.x, maxf(sz.y, sz.z))
		if l >= 4.0:
			continue
		g.visibility_range_end = maxf(25.0, l * 45.0) * k

func mat(tex_name: String, scale := 0.5, emission := Color.BLACK) -> ShaderMaterial:
	var key := "%s|%s|%s" % [tex_name, scale, emission]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("tex", load("res://assets/textures/%s.png" % tex_name))
	if tex_name in WINDY:
		m.set_shader_parameter("wind", WINDY[tex_name])
	m.set_shader_parameter("uv_scale", scale)
	m.set_shader_parameter("emission_color", emission)
	m.set_shader_parameter("emission_energy", 1.0 if emission != Color.BLACK else 0.0)
	m.set_shader_parameter("jitter", 1.0 if wobble else 0.0)
	m.set_meta("tex", tex_name)
	m.set_meta("spec", ["t", tex_name, scale, [emission.r, emission.g, emission.b, emission.a]])
	_materials[key] = m
	return m

## What a texture sounds like underfoot.
## Collision layers: 1 the world, 64 doors (not in the nav mesh: they open), 128 window glass
## (sight passes through it, bullets and bodies do not).
const WORLD := 1 | 64
const GLASS := 128

const TEX_SURFACE := {"planks": "wood", "barn": "wood", "fence": "wood", "bark": "wood",
	"metal": "metal", "skyranger": "metal", "ufo_floor": "alien", "ufo_hull": "alien", "ufo_wall": "alien", "water": "water", "gun": "metal",
	"plaster": "hard", "roof": "hard", "dirt": "dirt", "hay": "dirt", "scorch": "dirt", "mars": "dirt",
	"snow": "snow", "sand": "sand", "grass": "grass", "wheat": "grass", "leaves": "grass",
	"concrete": "hard", "asphalt": "hard", "brick": "hard", "rock": "hard", "tiles": "hard", "wallpaper": "wood",
	"corrugated": "metal", "container_red": "metal", "container_blue": "metal", "container_green": "metal",
	"base_floor": "hard", "base_wall": "hard", "hangar_floor": "metal", "earth": "dirt", "alien_rock": "hard", "alien_panel": "alien"}

## The surface under @a pos: a decal floor (road, path) first, then what the feet stand on.
func surface_at(world: Node3D, pos: Vector3, map: Dictionary) -> String:
	for r in map.get("surfaces", []):
		var lp: Vector3 = (r[0] as Transform3D).affine_inverse() * pos
		if absf(lp.x) <= r[1].x and absf(lp.z) <= r[1].y and pos.y < r[3]:
			return r[2]
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.3, 0), pos + Vector3(0, -0.6, 0), 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var n: Node = hit["collider"]
		for k in 3:
			if n == null:
				break
			if n.has_meta("surf"):
				return n.get_meta("surf")
			if n.get_child_count() > 40:
				break        # (the map itself: its pieces say nothing about this spot - a random one rang like metal)
			for c in n.get_children():
				if c is MeshInstance3D and c.material_override and c.material_override.has_meta("tex"):
					var sf: String = TEX_SURFACE.get(String(c.material_override.get_meta("tex")), "")
					if sf != "":
						return sf
			n = n.get_parent()
	match String(map.get("terrain", "")):
		"snow": return "snow"
		"desert": return "sand"
		"mars": return "dirt"
	return "grass"

const STEP_DB := {"grass": -1.0, "dirt": 0.0, "hard": 0.0, "wood": 0.0, "metal": 0.0, "snow": 0.0, "sand": -1.0, "water": 0.0, "alien": 0.0}

func color_mat(c: Color, emission := false, metal := 0.0, rough := 1.0) -> ShaderMaterial:
	var key := "c|%s|%s|%.2f|%.2f" % [c, emission, metal, rough]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	if metal > 0.0:
		m.shader = METAL_SHADER     # (0.50: steel and alien alloy catch the light)
		m.set_shader_parameter("metal", metal)
		m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("use_tex", false)
	m.set_shader_parameter("albedo", c)
	if emission:
		m.set_shader_parameter("emission_color", Color(c.r, c.g, c.b))
		m.set_shader_parameter("emission_energy", 2.0)
	m.set_shader_parameter("jitter", 1.0 if wobble else 0.0)
	m.set_meta("spec", ["c", [snappedf(c.r, 0.001), snappedf(c.g, 0.001), snappedf(c.b, 0.001), snappedf(c.a, 0.001)], emission, metal, rough])
	_materials[key] = m
	return m

## Instances a model from assets/models and gives every surface the game's own
## material (same PS1 jitter and lighting as the rest of the world).
var _models := {}
func model(mname: String) -> Node3D:
	if not _models.has(mname):
		var path := "res://assets/models/%s.glb" % {"hands_a_rifle": "hands_plasma_rifle", "hands_a_heavy": "hands_plasma_rifle"}.get(mname, mname)
		_models[mname] = load(path) if ResourceLoader.exists(path) else null
	if _models[mname] == null:
		# no model for this thing (should not happen): a small grey box instead of a crash
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.05, 0.1)
		mi.mesh = bm
		mi.material_override = color_mat(Color(0.3, 0.3, 0.3))
		var holder := Node3D.new()
		holder.add_child(mi)
		mi.owner = holder
		holder.set_meta("model", mname)
		return holder
	var n: Node3D = _models[mname].instantiate()
	n.set_meta("model", mname)
	if model_mods.has(mname):
		ModelMods.apply(n, model_mods[mname])
	_restyle(n)
	return n

func _restyle(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src is BaseMaterial3D:
				if camo != "" and src.resource_name in CAMO_PARTS:
					mi.set_surface_override_material(i, camo_mat(camo))
					continue
				if src.resource_name.ends_with("Glass"):
					mi.set_surface_override_material(i, glass_mat())     # (a window you can see through)
					continue
				var c: Color = src.albedo_color
				var mt := 0.0
				if src.metallic >= 0.25 and not src.emission_enabled:
					mt = minf(src.metallic, 1.0) * 0.55      # (a sheen, not a mirror - at night it would go black)
				mi.set_surface_override_material(i, color_mat(c, src.emission_enabled, mt, clampf(src.roughness, 0.25, 0.9)))
	for c in n.get_children():
		_restyle(c)

var _glass_m: StandardMaterial3D
func glass_mat() -> StandardMaterial3D:
	if _glass_m == null:
		_glass_m = StandardMaterial3D.new()
		_glass_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_m.albedo_color = Color(0.6, 0.75, 0.8, 0.18)
		_glass_m.roughness = 0.05
		_glass_m.metallic_specular = 0.9
		_glass_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _glass_m

# ---- camouflage: the uniform matches where the team flies ---------------------------------------
## "" = plain uniform (menus, our own base). Set by the mission before anybody is spawned.
var camo := ""
const CAMO_PARTS := ["Uniform", "Sleeve", "Helmet"]
const CAMO_COLORS := {
	"woodland": [Color(0.33, 0.36, 0.22), Color(0.22, 0.27, 0.15), Color(0.36, 0.28, 0.17), Color(0.09, 0.09, 0.08)],
	"desert": [Color(0.72, 0.63, 0.46), Color(0.60, 0.50, 0.34), Color(0.46, 0.37, 0.25), Color(0.80, 0.74, 0.60)],
	"snow": [Color(0.86, 0.88, 0.90), Color(0.70, 0.73, 0.76), Color(0.52, 0.55, 0.58), Color(0.95, 0.95, 0.97)],
	"urban": [Color(0.45, 0.46, 0.47), Color(0.30, 0.31, 0.33), Color(0.62, 0.62, 0.62), Color(0.12, 0.12, 0.13)],
	"mars": [Color(0.55, 0.30, 0.20), Color(0.42, 0.22, 0.15), Color(0.30, 0.16, 0.12), Color(0.66, 0.43, 0.31)],
	"night": [Color(0.16, 0.18, 0.21), Color(0.10, 0.11, 0.13), Color(0.23, 0.25, 0.28), Color(0.05, 0.05, 0.06)],
}
const CAMO_NAMES := {"woodland": "lesní", "desert": "pouštní", "snow": "zimní", "urban": "městský", "mars": "marťanský", "night": "noční"}

## Which pattern for a mission: snow, desert, Mars, town and industry grey, underground black, else woodland.
func camo_for(params: Dictionary) -> String:
	var t := String(params.get("type", ""))
	if t == "home" or params.is_empty():
		return ""
	if t == "alienbase":
		return "night"
	var terr := String(params.get("terrain", ""))
	var biome := String(params.get("biome", ""))
	if terr == "mars" or t == "mars":
		return "mars"
	if terr == "snow" or biome == "polar":
		return "snow"
	if terr == "desert" or biome == "desert":
		return "desert"
	if biome in ["town", "industrial", "base"] or t == "base":
		return "urban"
	return "woodland"

var _camo_mats := {}
func camo_mat(scheme: String) -> Material:
	if _camo_mats.has(scheme):
		return _camo_mats[scheme]
	var cols: Array = CAMO_COLORS.get(scheme, CAMO_COLORS["woodland"])
	var n1 := FastNoiseLite.new()
	n1.seed = 7
	n1.frequency = 0.09
	var n2 := FastNoiseLite.new()
	n2.seed = 31
	n2.frequency = 0.13
	var sz := 48
	var img := Image.create(sz, sz, false, Image.FORMAT_RGB8)
	for y in sz:
		for x in sz:
			# seamless: sample the noise on a torus
			var ax := TAU * x / sz
			var ay := TAU * y / sz
			var a := n1.get_noise_3d(cos(ax) * 12.0, sin(ax) * 12.0, cos(ay) * 12.0 + sin(ay) * 7.0)
			var b := n2.get_noise_3d(sin(ay) * 10.0, cos(ay) * 10.0, cos(ax) * 9.0 + sin(ax) * 5.0)
			var c: Color = cols[0]
			if a > 0.12: c = cols[1]
			if b > 0.22: c = cols[2]
			if a < -0.3 and b < 0.0: c = cols[3]
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# (not triplanar: on a skinned helmet or cap the pattern would swim as the head moves)
	m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	m.roughness = 0.95
	_camo_mats[scheme] = m
	return m

## Turns the PS1 vertex jitter on/off on every material made so far.
func apply_retro() -> void:
	for k in _materials:
		var m = _materials[k]
		if m is ShaderMaterial:
			m.set_shader_parameter("jitter", 1.0 if wobble else 0.0)

## A looping copy of a sound (for hums, engines, burning flares).
func loop_stream(sname: String) -> AudioStream:
	var st: AudioStreamWAV = (sound(sname) as AudioStreamWAV).duplicate()
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = int(st.get_length() * st.mix_rate)
	return st

## Sounds with several takes (name_0..name_N-1): a random one each time.
## Names that play another sound at a different pitch (a pistol is the rifle's smaller sister).
const PITCHED := {"plasma_p": ["plasma", 1.18], "laser_p": ["laser", 1.15]}
const VARIANTS := {"plasma_heavy": 10, "casing": 4, "step_heavy": 3, "gear": 4, "sting": 4, "type": 4, "breath": 2}
## (0.61) The soldier's own voice by sex: "<name>_female" / "<name>_male" when that recording is in
## assets/sounds (also as takes <name>_female_0, _1...), else the common "<name>" - but a woman never
## gets the common one when it is a man's recording (VOICE_MALE): she stays quiet until hers is there.
const VOICE_MALE := ["breath", "breath_scared"]
var _voice_takes := {}
func voice_of(sname: String, female: bool) -> String:
	var own := sname + ("_female" if female else "_male")
	if not _voice_takes.has(own):
		var n := 0
		while ResourceLoader.exists("res://assets/sounds/%s_%d.wav" % [own, n]):
			n += 1
		_voice_takes[own] = n if n > 0 else (-1 if ResourceLoader.exists("res://assets/sounds/%s.wav" % own) else 0)
	var takes: int = _voice_takes[own]
	if takes > 0:
		return "%s_%d" % [own, randi() % takes]
	if takes < 0:
		return own
	if female and sname in VOICE_MALE:
		return ""
	return sname

func sound(sname: String) -> AudioStream:
	if PITCHED.has(sname):
		sname = PITCHED[sname][0]
	if VARIANTS.has(sname):
		sname = "%s_%d" % [sname, randi() % int(VARIANTS[sname])]
	if not _sounds.has(sname):
		var path := "res://assets/sounds/%s.wav" % sname
		if _sound_req.has(sname):
			_sound_req.erase(sname)
			_sounds[sname] = ResourceLoader.load_threaded_get(path)
		else:
			_sounds[sname] = load(path)
	return _sounds[sname]

## 0.62 výkon: zvuky se načítaly až při prvním přehrání - první výstřel, krok nebo výbuch v misi
## tak zasekl hru o desítky ms (načtení .wav z disku). Teď se po startu hry všechny začnou načítat
## na pozadí (vlákna), takže v misi už jsou v paměti (~70 MB).
var _sound_req := {}
func _preload_sounds() -> void:
	for f in ResourceLoader.list_directory("res://assets/sounds/"):
		if f.get_extension() == "wav":
			var sname := f.get_basename()
			if not _sounds.has(sname) and not _sound_req.has(sname):
				if ResourceLoader.load_threaded_request("res://assets/sounds/" + f) == OK:
					_sound_req[sname] = true

## Plays a positional sound once at @a pos (in @a world).
const ALIEN_SOUNDS := ["skitter", "groan", "growl", "sniff", "alien", "swish", "lunge", "zap", "psi", "burst"]
## A stain of blood on the ground under pos (alien blood glows faintly in the dark).
## Kept to a few hundred - the oldest dry up and go.
var _blood: Array = []
var _blood_texs: Array = []
## a ragged splash with droplets around it (a few variants, made once)
func _blood_tex() -> Texture2D:
	if _blood_texs.size() < 4:
		var n := 32
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var blobs := [[Vector2(16, 16), randf_range(7.0, 10.0)]]
		for i in randi_range(3, 6):
			var a := randf() * TAU
			blobs.append([Vector2(16, 16) + Vector2.from_angle(a) * randf_range(6.0, 9.0), randf_range(2.5, 5.0)])
		for i in randi_range(3, 7):
			var a := randf() * TAU
			blobs.append([Vector2(16, 16) + Vector2.from_angle(a) * randf_range(10.0, 14.5), randf_range(0.8, 1.8)])
		for y in n:
			for x in n:
				var v := 0.0
				for b in blobs:
					var d: float = (Vector2(x + 0.5, y + 0.5) - b[0]).length() / float(b[1])
					v = maxf(v, 1.0 - d)
				var shade := 0.75 + 0.25 * clampf(v * 3.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(shade, shade, shade, 1.0 if v > 0.0 else 0.0))
		_blood_texs.append(ImageTexture.create_from_image(img))
		return _blood_texs[-1]
	return _blood_texs[randi() % _blood_texs.size()]

func blood_splat(world: Node, pos: Vector3, col: Color, size := 0.3, glow := false) -> void:
	if world == null or not world.is_inside_tree():
		return
	var space := (world as Node3D).get_world_3d().direct_space_state if world is Node3D else null
	var ground := pos
	if space:
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.3, pos + Vector3.DOWN * 3.0, 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return
		ground = hit.position
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size * randf_range(0.75, 1.0)) * 1.4
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.albedo_color = col.darkened(0.55)
	m.albedo_texture = _blood_tex()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.2
	if glow:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.25
		m.emission_texture = m.albedo_texture
	mi.material_override = m
	world.add_child(mi)
	mi.global_position = ground + Vector3.UP * (0.012 + randf() * 0.006)
	mi.rotation.y = randf() * TAU
	_blood.append(mi)
	while _blood.size() > 300:
		var old = _blood.pop_front()
		if is_instance_valid(old):
			old.queue_free()

## (0.66) Sounds the compass does not mark as "hluk" (quiet ones, the soldier's own gear).
const QUIET_SOUNDS := ["click", "clink", "rustle", "pickup", "pistol_slide", "mag_out", "mag_in", "reload", "casings", "breath", "breath_scared", "hum"]
func play_at(world: Node, sname: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if world == null or not world.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = sound(sname)
	p.volume_db = volume_db
	p.pitch_scale = pitch * (float(PITCHED[sname][1]) if PITCHED.has(sname) else 1.0)
	if sname in ALIEN_SOUNDS and world.has_method("alien_db"):
		p.volume_db += world.alien_db()      # rain covers them
	p.unit_size = 6.0
	p.max_distance = 80.0
	p.bus = RoomEcho.bus()       # (0.70: through the echo of the place)
	world.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	if volume_db >= -8.0 and not sname.begins_with("step") and not sname in QUIET_SOUNDS:
		loud_at = pos
		loud_ms = Time.get_ticks_msec()

## Only a piece of a longer sound: from @a offset, faded out after @a secs (a yelp cut out of a roar).
func play_cut(world: Node, sname: String, pos: Vector3, volume_db: float, pitch: float, secs: float, offset := 0.0) -> void:
	if world == null or not world.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = sound(sname)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	if sname in ALIEN_SOUNDS and world.has_method("alien_db"):
		p.volume_db += world.alien_db()
	p.unit_size = 6.0
	p.max_distance = 80.0
	p.bus = RoomEcho.bus()       # (0.70: through the echo of the place)
	world.add_child(p)
	p.global_position = pos
	p.play(offset)
	p.finished.connect(p.queue_free)
	var tw := p.create_tween()
	tw.tween_interval(maxf(0.05, secs - 0.15))
	tw.tween_property(p, "volume_db", -60.0, 0.15)
	tw.tween_callback(p.queue_free)

func play_ui(world: Node, sname: String, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sound(sname)
	p.volume_db = volume_db
	if PITCHED.has(sname):
		p.pitch_scale = float(PITCHED[sname][1])
	p.bus = "SFX"
	world.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

## Command line: --autotest=solo|host|client|shot (headless tests).
func autotest() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			return a.substr(11)
	return ""

func cmd_arg(key: String, def := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return def

## F11 / Alt+Enter: fullscreen anywhere in the game.
func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_F11 or (e.keycode == KEY_ENTER and e.alt_pressed)):
		fullscreen = not fullscreen
		apply_video()
		save_settings()

## Test helper: lists every visible control that sticks out of the 640x360 screen
## (or whose text is wider than its box). Used by --autotest=ui.
func ui_audit(root: Node, tag: String) -> int:
	var bad := 0
	var screen := Rect2(Vector2(-1, -1), Vector2(642, 362))
	for c in root.find_children("*", "Control", true, false):
		var ctl: Control = c
		if not ctl.is_visible_in_tree() or ctl.size == Vector2.ZERO:
			continue
		var r := ctl.get_global_rect()
		var why := ""
		# inside a scrolling / clipping box: what matters is that box
		var clipped := false
		var an := ctl.get_parent()
		while an and an is Control:
			if an is ScrollContainer or (an as Control).clip_contents:
				clipped = true
				break
			an = an.get_parent()
		if clipped:
			continue
		if not screen.encloses(r):
			why = "mimo obrazovku %s" % r
		elif ctl is Label and (ctl as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (ctl as Label).clip_text and ctl.get_minimum_size().x > ctl.size.x + 1:
			why = "text oříznut"
		if why != "":
			# report only the outermost offender of a branch
			var parent_bad := false
			var pn := ctl.get_parent()
			while pn and pn is Control:
				if not screen.encloses((pn as Control).get_global_rect()) and (pn as Control).is_visible_in_tree():
					parent_bad = true
					break
				pn = pn.get_parent()
			if parent_bad:
				continue
			bad += 1
			var txt := ""
			if "text" in ctl:
				txt = String(ctl.get("text")).replace("\n", " / ").left(60)
			print("[UI] %s: %s %s - %s  \"%s\"" % [tag, ctl.get_class(), ctl.name, why, txt])
	print("[UI] %s: %d problém(ů)" % [tag, bad])
	return bad

# ---- updates from GitHub ------------------------------------------------------------------
## The menu checks GitHub once per start; a newer version is downloaded in the
## background as a resource pack (a few MB) that Boot mounts on the next start.
const UPDATE_URL := "https://raw.githubusercontent.com/arielistelosbutch/Enemy-Beyond/main/update/version.json"
var upd_state := ""        # "" / checking / downloading / ready / current / error / editor
var upd_version := ""
var upd_error := ""
var _upd_http: HTTPRequest
var _upd_dl: HTTPRequest
signal update_changed

func check_update() -> void:
	if upd_state != "":
		return
	if OS.has_feature("editor"):
		upd_state = "editor"      # running from the Godot editor: updates come from the project files
		return
	upd_state = "checking"
	_upd_http = HTTPRequest.new()
	_upd_http.timeout = 15.0
	add_child(_upd_http)
	_upd_http.request_completed.connect(_on_version_info)
	if _upd_http.request(UPDATE_URL + "?t=%d" % int(Time.get_unix_time_from_system())) != OK:
		_upd_fail("nelze se připojit")
	update_changed.emit()

func _upd_fail(why: String) -> void:
	upd_state = "error"
	upd_error = why
	update_changed.emit()

func _on_version_info(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_upd_fail("GitHub neodpověděl (%d/%d)" % [result, code])
		return
	var info = JSON.parse_string(body.get_string_from_utf8())
	if typeof(info) != TYPE_DICTIONARY:
		_upd_fail("vadné informace o verzi")
		return
	var v := String(info.get("version", ""))
	var base_ok := not Boot.newer(String(info.get("min_build", "0")), Boot.BUILD_VERSION)
	if not Boot.newer(v, VERSION_NUM):
		upd_state = "current"
		update_changed.emit()
		return
	upd_version = v
	if not base_ok:
		# the change needs a new .exe (engine or project settings): only point to the download
		upd_state = "full"
		update_changed.emit()
		return
	upd_state = "downloading"
	_upd_dl = HTTPRequest.new()
	_upd_dl.timeout = 300.0
	_upd_dl.download_file = "user://update.pck.part"
	add_child(_upd_dl)
	_upd_dl.request_completed.connect(func(r: int, c: int, _hh: PackedStringArray, _b: PackedByteArray):
		if r != HTTPRequest.RESULT_SUCCESS or c != 200:
			_upd_fail("stahování selhalo (%d/%d)" % [r, c])
			return
		var d := DirAccess.open("user://")
		if d.file_exists("update.pck"):
			d.remove("update.pck")
		d.rename("update.pck.part", "update.pck")
		var f := FileAccess.open("user://update.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"version": upd_version}))
		f.close()
		upd_state = "ready"
		update_changed.emit())
	if _upd_dl.request(String(info.get("pck", ""))) != OK:
		_upd_fail("nelze stáhnout balík")
	update_changed.emit()

func update_progress() -> float:
	if _upd_dl and _upd_dl.get_body_size() > 0:
		return float(_upd_dl.get_downloaded_bytes()) / float(_upd_dl.get_body_size())
	return 0.0

func restart_game() -> void:
	OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
	get_tree().quit()

## Changelog shipped with the game (changelog.json): version -> list of lines.
func changelog() -> Dictionary:
	if not FileAccess.file_exists("res://changelog.json"):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://changelog.json"))
	return d if typeof(d) == TYPE_DICTIONARY else {}

# ---- music: the player's own files in the folder "hudba" next to the game -------------------------
## The game ships without music. Put your tracks (ogg / mp3 / wav) into "hudba" next to
## EnemyBeyond.exe, named as below, and the game plays them in the right places.
const MUSIC_FILES := {
	"main_menu": "hlavni_menu", "geoscape": ["globus_1", "globus_2"], "interception": "stihacky",
	"briefing": "briefing", "terror_briefing": "briefing_teror", "tactical": "mise", "debriefing": "debriefing",
	"victory": "vitezstvi", "game_over": "konec_hry", "final_mission": "posledni_mise", "intro": ["intro_1", "intro_2", "intro_3"],
}
var music_volume := 0.7
var tactical_music := false     # music during the mission itself (off by default: wind and silence)
var _music: AudioStreamPlayer
var _music_name := ""

func music_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://hudba")
	return OS.get_executable_path().get_base_dir().path_join("hudba")

## A track: the player's own file in the "hudba" folder next to the game wins (so anyone can
## swap a track), otherwise Ari's music that comes with the game.
func _music_stream(base: String) -> AudioStream:
	var own := _music_file(base)
	if own:
		return own
	var bundled := "res://assets/music/%s.mp3" % base
	if ResourceLoader.exists(bundled):
		return (load(bundled) as AudioStream).duplicate()
	return null

func _music_file(base: String) -> AudioStream:
	for ext in ["ogg", "mp3", "wav"]:
		var p := music_dir().path_join(base + "." + ext)
		if not FileAccess.file_exists(p):
			continue
		match ext:
			"ogg": return AudioStreamOggVorbis.load_from_file(p)
			"mp3":
				var m := AudioStreamMP3.new()
				m.data = FileAccess.get_file_as_bytes(p)
				return m
			"wav": return AudioStreamWAV.load_from_file(p)
	return null

## Plays a track by its role (see MUSIC_FILES); "" stops. Missing files = silence.
func play_music(role: String, loop := true) -> void:
	if role == _music_name and _music and _music.playing:
		return
	_music_name = role
	if _music == null:
		_music = AudioStreamPlayer.new()
		add_child(_music)
	_music.stop()
	if role == "" or autotest() != "":
		return
	var f = MUSIC_FILES.get(role, "")
	if f is Array:
		f = f[randi() % f.size()]
	var st := _music_stream(String(f))
	if st == null:
		return
	if "loop" in st:
		st.loop = loop
	_music.stream = st
	_music.volume_db = 0.0
	_music.bus = "Music"
	_music.play()

func set_music_volume(v: float) -> void:
	music_volume = v
	apply_volumes()

## Sound buses: every sound goes to one of these, each with its own slider.
const BUSES := ["Music", "SFX", "Wind", "Ambient", "Voice"]
const BUS_NAMES := {"Master": "Celková hlasitost", "Music": "Hudba", "SFX": "Zbraně, kroky a vetřelci",
	"Wind": "Vítr", "Ambient": "Prostředí (déšť, zvuky mapy)", "Voice": "Hlasy spoluhráčů"}
var volumes := {"Master": 1.0, "SFX": 1.0, "Wind": 1.0, "Ambient": 1.0, "Voice": 1.0}

func _make_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

func get_volume(b: String) -> float:
	return music_volume if b == "Music" else float(volumes.get(b, 1.0))

func set_volume(b: String, v: float) -> void:
	if b == "Music":
		music_volume = v
	else:
		volumes[b] = v
	apply_volumes()

func apply_volumes() -> void:
	for b in BUS_NAMES:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			var v := get_volume(b)
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, v)))
			AudioServer.set_bus_mute(i, v <= 0.001)

# ---- tweaks: positions of held items and pose corrections, made in the Workshop ------------------
## Keys: "fp/<item>" and "tp/<item>" (in the hands, first person / seen by others), "back/<item>"
## {"pos": [x,y,z], "rot": [deg x,y,z], "scale": s}; "hold/<item>", "emote/<name>", "act/<job>"
## {bone: [deg x,y,z]} added to the pose. Bundled res://upravy.json first, then the player's own
## upravy.json next to the game (the Workshop writes that one).
var tweaks := {}

func tweak_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://upravy.json")
	return OS.get_executable_path().get_base_dir().path_join("upravy.json")

## Block-modeller changes per model (res://modely/<model>.json bundled, then modely/ next to the game).
var model_mods := {}

## A 3D preview in a SubViewportContainer: the game draws its menus at 640x360 and stretches them,
## so a stretched preview would be rendered at that low size and look blurry. Render it at the
## window's real pixel size instead and draw it scaled down into its holder.
func sharp_view(svc: SubViewportContainer) -> void:
	if svc == null or not is_instance_valid(svc):
		return
	var holder := svc.get_parent() as Control
	if holder == null:
		return
	var k: float = maxf(1.0, svc.get_viewport().get_final_transform().get_scale().x)
	var want: Vector2 = (holder.size * k).floor()
	if svc.size != want or svc.stretch:
		svc.stretch = false         # we size the view ourselves (stretch fights the scale)
		svc.scale = Vector2.ONE / k
		svc.position = Vector2.ZERO
		svc.size = want
		for c in svc.get_children():
			if c is SubViewport:
				(c as SubViewport).size = Vector2i(want)

func models_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://modely")
	return OS.get_executable_path().get_base_dir().path_join("modely")

func load_model_mods() -> void:
	model_mods = {}
	for dir in ["res://modely", models_dir()]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".json"):
				var m = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
				if m is Dictionary:
					model_mods[f.get_basename()] = m

func save_model_mods(mname: String) -> bool:
	DirAccess.make_dir_recursive_absolute(models_dir())
	var path := models_dir().path_join(mname + ".json")
	if not model_mods.has(mname) or (model_mods[mname].get("parts", {}).is_empty() and model_mods[mname].get("new", []).is_empty()):
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return true
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(model_mods[mname], "  ", true))
	return true

func load_tweaks() -> void:
	load_model_mods()
	tweaks = {}
	for p in ["res://upravy.json", tweak_path()]:
		if FileAccess.file_exists(p):
			var d = JSON.parse_string(FileAccess.get_file_as_string(p))
			if d is Dictionary:
				for k in d:
					tweaks[k] = d[k]

func save_tweaks() -> bool:
	var f := FileAccess.open(tweak_path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(tweaks, "  ", true))
	return true

static func _v3(a, def := Vector3.ZERO) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return def

## Moves/turns/scales an item model by its tweak (in the holder's space).
func apply_item_tweak(n: Node3D, key: String) -> void:
	var t: Dictionary = tweaks.get(key, {})
	if t.is_empty():
		return
	var r := _v3(t.get("rot", null)) * (PI / 180.0)
	var s := float(t.get("scale", 1.0))
	n.transform = Transform3D(Basis.from_euler(r).scaled(Vector3.ONE * s), _v3(t.get("pos", null))) * n.transform

## (0.57) Ari's fine-tuning of the left hand on a gun in the eyes' view ("fpl/<gun>": pos, rot):
## the hands model's "HandL" moved and turned round the hand itself. The hand's place without it is
## kept in the meta "rest", with it in "tuned" (the shotgun's pump goes on top of that).
func apply_left_hand(hands: Node, weapon: String) -> void:
	var hl := hands.find_child("HandL", true, false) as MeshInstance3D
	if hl == null:
		return
	if not hl.has_meta("rest"):
		hl.set_meta("rest", hl.transform)
		# the pivot: the hand (the frontmost part of the piece; the sleeve runs back from it)
		var zmin := INF
		var vs := PackedVector3Array()
		for si in hl.mesh.get_surface_count():
			vs.append_array(hl.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX])
		for v in vs:
			zmin = minf(zmin, v.z)
		var sum := Vector3.ZERO
		var n := 0
		for v in vs:
			if v.z < zmin + 0.07:
				sum += v
				n += 1
		hl.set_meta("pivot", sum / maxi(n, 1))
	var rest: Transform3D = hl.get_meta("rest")
	var t: Dictionary = tweaks.get("fpl/" + weapon, {})
	var tuned := rest
	if not t.is_empty():
		var piv: Vector3 = rest * (hl.get_meta("pivot") as Vector3)
		var r := Basis.from_euler(_v3(t.get("rot", null)) * (PI / 180.0))
		tuned = Transform3D(Basis(), piv + _v3(t.get("pos", null))) * Transform3D(r, Vector3.ZERO) * Transform3D(Basis(), -piv) * rest
	hl.set_meta("tuned", tuned)
	hl.transform = tuned

## Points a weapon model may carry (empties from Blender): "Grip" where the right hand holds it,
## "Grip_L" where the left one does, "Muzzle" where the shot leaves. In the model's own space;
## null when the model has none (then the game goes by its outline, as before).
var _points := {}
func model_point(id: String, pname: String) -> Variant:
	var key := id + "/" + pname
	if not _points.has(key):
		var path := "res://assets/models/%s.glb" % id
		var at: Variant = null
		if ResourceLoader.exists(path):
			var n: Node = (load(path) as PackedScene).instantiate()
			var p := n.find_child(pname, true, false) as Node3D
			if p:
				var t := Transform3D()
				var c: Node = p
				while c != n and c is Node3D:
					t = (c as Node3D).transform * t
					c = c.get_parent()
				at = t.origin
			n.free()
		_points[key] = at
	return _points[key]

## The shift that puts a weapon's "Grip" point into the hand (identity when it has none).
func grip_shift(id: String) -> Transform3D:
	var g: Variant = model_point(id, "Grip")
	return Transform3D(Basis(), -(g as Vector3)) if g != null else Transform3D()

## A workshop tweak as a transform (identity when there is none).
func tweak_xform(key: String) -> Transform3D:
	var t: Dictionary = tweaks.get(key, {})
	if t.is_empty():
		return Transform3D()
	var r := _v3(t.get("rot", null)) * (PI / 180.0)
	return Transform3D(Basis.from_euler(r).scaled(Vector3.ONE * float(t.get("scale", 1.0))), _v3(t.get("pos", null)))

## A pose with the workshop corrections added (degrees, per bone).
func tweak_pose(key: String, want: Dictionary) -> Dictionary:
	var t: Dictionary = tweaks.get(key, {})
	if t.is_empty():
		return want
	var out := want.duplicate()
	for bn in t:
		out[bn] = (out.get(bn, Vector3.ZERO) as Vector3) + _v3(t[bn]) * (PI / 180.0)
	return out

## A held item's model. Clubs (baton) are held upright, ready to come down.
## Knife: blade up in the fist. Radio: upright, antenna up. Plus the workshop tweak.
func held_model(id: String, third := false) -> Node3D:
	var m := model(id)
	if ITEMS.get(id, {}).get("blunt", false):
		m.rotation.x = deg_to_rad(78.0)
		m.position = Vector3(0, 0.01, 0.01)
	elif id in ["knife", "energo_nuz"]:
		m.rotation.x = deg_to_rad(80.0 if third else 58.0)
	elif id in ["radio", "flare", "scanner"]:
		m.rotation.x = deg_to_rad(80.0 if id == "radio" else 35.0)
	apply_item_tweak(m, ("tp/" if third else "fp/") + id)
	return m
