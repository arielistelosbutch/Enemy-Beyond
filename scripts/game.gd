extends Node
## Enemy Beyond - global state: controls, the mercenary's profile, item rules,
## shared materials and sounds.

const VERSION := "0.56 prototyp"
const VERSION_NUM := "0.56"

# ---- items (like UFO: every item has weight; hands, belt and backpack hold them) ----
const ITEMS := {
	# hands: "two" = needs both hands. kind: gun / melee / throw / tool / ammo
	"rifle": {"name": "Puška", "short": "Puška", "weight": 7, "type": "weapon", "modes": true, "two": true, "ammo": "rifle_clip", "damage": 32, "spread": 1.4, "rate": 0.16, "auto": true, "sound": "rifle", "noise": 45.0, "muzzle": 0.72, "reload": 1.5},
	"pistol": {"name": "Pistole", "short": "Pistole", "weight": 3, "type": "weapon", "ammo": "pistol_clip", "damage": 26, "spread": 2.0, "rate": 0.28, "auto": false, "sound": "pistol", "noise": 35.0, "muzzle": 0.16, "reload": 1.7, "ext_mag": 21},
	"shotgun": {"name": "Brokovnice", "short": "Brokovnice", "weight": 6, "type": "weapon", "two": true, "ammo": "shells", "ammo_alt": ["slugs", "beanbag"], "damage": 16, "pellets": 8, "choke": 3.2, "spread": 3.0, "rate": 0.85, "auto": false, "sound": "shotgun", "noise": 55.0, "muzzle": 0.72, "single": 0.5, "cap": 7, "kick": 2.0},
	"magnum": {"name": "Revolver Magnum", "short": "Magnum", "weight": 3, "type": "weapon", "ammo": "magnum_rounds", "damage": 78, "ap": true, "spread": 1.1, "rate": 0.75, "auto": false, "sound": "magnum", "noise": 70.0, "muzzle": 0.27, "single": 0.7, "cap": 6, "kick": 2.5},
	# 0.57 (Ari, HC-01's entry): one heavy armour-piercing incendiary round at a time, a long cycle after every shot
	"autocannon": {"name": "Těžký kanón", "short": "Kanón", "weight": 16, "type": "weapon", "two": true, "heavy": 0.72, "brace": true, "ammo": "ac_clip", "damage": 150, "ap": true, "incendiary": true, "spread": 1.3, "rate": 1.9, "auto": false, "sound": "autocannon", "noise": 75.0, "muzzle": 1.2, "reload": 3.0, "kick": 3.0},
	"minigun": {"name": "Minigun", "short": "Minigun", "weight": 20, "type": "weapon", "two": true, "heavy": 0.6, "brace": true, "ammo": "minigun_belt", "damage": 15, "spread": 3.4, "rate": 0.05, "auto": true, "spinup": 0.9, "heat": 0.0085, "sound": "minigun", "noise": 75.0, "muzzle": 0.86, "reload": 4.0, "kick": 0.4},
	"rocket_launcher": {"name": "Raketomet", "short": "Raketomet", "weight": 12, "type": "weapon", "two": true, "heavy": 0.85, "ammo": "rocket", "ammo_alt": ["rocket_ap", "rocket_inc"], "damage": 160, "splash": 4.5, "spread": 0.8, "rate": 1.0, "auto": false, "projectile": true, "sound": "launch", "noise": 80.0, "muzzle": 0.9, "reload": 3.0, "kick": 3.0},
	"plasma_rifle": {"name": "Plazmová puška PR-01", "short": "PR-01", "weight": 6, "type": "weapon", "two": true, "ammo": "plasma_cell", "cap": 5, "falloff": [35.0, 80.0], "damage": 92, "spread": 0.8, "rate": 0.32, "auto": false, "heat": 0.2, "sound": "plasma", "noise": 34.0, "muzzle": 0.8, "reload": 1.3, "kick": 0.5},
	"plasma_pistol": {"name": "Plazmová pistole PP-01", "short": "PP-01", "weight": 3, "type": "weapon", "ammo": "plasma_cell", "cap": 10, "falloff": [20.0, 50.0], "damage": 44, "spread": 1.3, "rate": 0.28, "auto": false, "heat": 0.14, "sound": "plasma", "noise": 28.0, "muzzle": 0.21, "reload": 1.4, "kick": 0.4},
	"plasma_cannon": {"name": "Plazmový kanón PC-01", "short": "PC-01", "weight": 15, "type": "weapon", "two": true, "heavy": 0.72, "brace": true, "ammo": "plasma_cell", "cap": 2, "damage": 340, "pc": true, "spread": 0.9, "rate": 0.9, "auto": false, "heat": 0.3, "sound": "plasma", "noise": 60.0, "muzzle": 0.86, "reload": 3.0, "kick": 1.2},
	"plasma_minigun": {"name": "Plazmový minigun PM-01", "short": "PM-01", "weight": 20, "type": "weapon", "two": true, "heavy": 0.58, "brace": true, "ammo": "plasma_cell", "cap": 20, "damage": 30, "spread": 3.0, "rate": 0.08, "auto": true, "bursts": [5, 10, 0], "spinup": 0.7, "heat": 0.03, "sound": "plasma_mg", "noise": 70.0, "muzzle": 0.86, "reload": 3.5, "kick": 0.4},
	"sniper": {"name": "Odstřelovací puška", "short": "Odstřelovačka", "weight": 9, "type": "weapon", "two": true, "ammo": "sniper_clip", "damage": 120, "ap": true, "spread": 0.25, "hip": 5.0, "scope": true, "rate": 1.3, "auto": false, "sound": "sniper", "noise": 75.0, "muzzle": 1.07, "reload": 2.4, "kick": 3.5, "ext_mag": 8},
	# lasers: no magazines - the cell recharges by itself after a short pause (cap = shots in the cell)
	"laser_pistol": {"name": "Laserová pistole LP-01", "short": "Laser. pistole", "weight": 2, "type": "weapon", "ammo": "", "laser": true, "cap": 1, "recharge": 2.0, "falloff": [25.0, 60.0], "damage": 42, "spread": 1.0, "rate": 0.3, "auto": false, "sound": "laser", "noise": 25.0, "muzzle": 0.21, "kick": 0.3},
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
		"cap": 5, "cells": 2, "damage": 110, "splash": 2.2, "spread": 0.9, "rate": 0.9, "auto": false, "sound": "plasma", "noise": 45.0, "muzzle": 0.7, "kick": 2.0, "reload": 4.0},
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
const MODS := {
	"svitilna": {"name": "Zbraňová svítilna", "price": 120, "desc": "Silnější a delší kužel světla, když držíš zbraň. Vetřelci tě ale uvidí z větší dálky."},
	"laser": {"name": "Laserový zaměřovač", "price": 180, "desc": "Červená tečka: střelba od boku skoro o polovinu přesnější. Vetřelec, kterému tečka sedne na tělo, si tě ale všimne."},
	"optika": {"name": "Optika 2x", "price": 220, "desc": "Při míření větší přiblížení, o 40 % přesnější a klidnější mířidla."},
	"tlumic": {"name": "Tlumič", "price": 200, "desc": "Výstřel slyší vetřelci jen na pětinu vzdálenosti."},
	"kolimator": {"name": "Kolimátor", "price": 150, "desc": "Malý kolimátor na pistoli: tečka v okénku, mírně přesnější střelba."},
	"nosic": {"name": "Nosič nábojů", "price": 90, "desc": "Pár nábojů na pouzdře přímo na zbrani: brokovnice se dobíjí rychleji."},
	"pazba": {"name": "Ergonomická pažba", "price": 140, "desc": "Pažba, která pohltí část zpětného rázu: další rána jde přesněji."},
	"dvojnozka": {"name": "Stabilizační dvojnožka", "price": 260, "desc": "Opěra pod hlaveň: když stojíš na místě, kanón je o polovinu přesnější."},
	"tlumeni": {"name": "Zesílené tlumení rázu", "price": 300, "desc": "Mechanika, která spolkne část zpětného rázu: rychleji jsi zpátky na cíli."},
	"nosny": {"name": "Ergonomický nosný systém", "price": 220, "desc": "Popruhy a opěry: s kanónem v rukou se pohybuješ o něco rychleji."},
	"dalkomer": {"name": "Balistický dálkoměr", "price": 280, "desc": "Změří vzdálenost a dopočítá pokles střely: na velkou dálku přesnější rána."},
	"brzda": {"name": "Úsťová brzda", "price": 200, "desc": "Odvede část plynů do stran: menší ráz, rychleji jsi zpátky na cíli."},
	"stabilizator": {"name": "Elektronický stabilizátor", "price": 320, "desc": "Gyroskop v postroji: dlouhé dávky se tolik nerozlévají."},
	"chladic": {"name": "Pokročilý chladicí modul", "price": 300, "desc": "Proudění vzduchu kolem hlavní: přehřívají se pomaleji."},
	"zamerovac": {"name": "Taktický zaměřovač", "price": 180, "desc": "Jednoduchý zaměřovač na těžkou zbraň: o něco přesnější na střední vzdálenost."},
	"ergo": {"name": "Ergonomická rukojeť", "price": 120, "desc": "Rukojeť, která sedí v dlani: u revolveru menší postih za zpětný ráz, u nože jistější a o kus delší sek."},
	"rychlonabijec": {"name": "Rychlonabíječ", "price": 110, "desc": "Šest nábojů v kroužku najednou do bubínku: přebíjení zabere zlomek času."},
	"kompenzator": {"name": "Kompenzační úsťový modul", "price": 160, "desc": "Méně zdvihu hlavně po ráně. Výstřel je ale ještě hlasitější."},
	"pocitac": {"name": "Zaměřovací počítač", "price": 350, "desc": "Spočítá předstih na pohyblivý cíl: raketa letí přesněji."},
	"pouzdro": {"name": "Odlehčené taktické pouzdro", "price": 60, "desc": "Nůž vyjde z pouzdra na jeden pohyb: rychlejší tasení."},
	"akumulator": {"name": "Vysokokapacitní akumulátor", "price": 200, "desc": "Větší článek v rukojeti obušku: víc výbojů na misi."},
	"lehky": {"name": "Odlehčená konstrukce", "price": 120, "desc": "Kompozitní tělo obušku: rychleji v ruce, rychlejší rána."},
	"diagnostika": {"name": "Diagnostický indikátor", "price": 90, "desc": "Displej na rukojeti: ukáže, kolik energie v obušku zbývá."},
	"zasobnik": {"name": "Prodloužený zásobník", "price": 160, "desc": "O polovinu víc ran v zásobníku, zbraň je ale o 1 kg těžší."},
	"rukojet": {"name": "Přední rukojeť", "price": 140, "desc": "Poloviční zpětný ráz, rozptyl při dávce roste pomaleji, klidnější ruce."},
}
## Which upgrade fits which weapon (not everything on everything).
const MOD_FITS := {
	"pistol": ["kolimator", "svitilna", "laser", "tlumic", "zasobnik"],
	"rifle": ["svitilna", "laser", "optika", "tlumic", "zasobnik", "rukojet"],
	"sniper": ["optika", "dvojnozka", "dalkomer", "brzda", "zasobnik"],
	"shotgun": ["kolimator", "nosic", "svitilna", "laser", "pazba"],
	"magnum": ["kolimator", "ergo", "rychlonabijec", "kompenzator", "laser"],
	"autocannon": ["optika", "dvojnozka", "tlumeni", "nosny"],
	"rocket_launcher": ["optika", "dalkomer", "nosny", "pocitac"],
	"minigun": ["nosny", "zasobnik", "stabilizator", "chladic", "zamerovac"],
	"plasma_rifle": ["svitilna", "laser", "optika", "rukojet"],
	"laser_pistol": ["svitilna", "laser"],
	"laser_rifle": ["svitilna", "optika", "rukojet"],
	"laser_cannon": ["svitilna", "optika", "rukojet"],
	"laser_minigun": ["nosny", "stabilizator", "zamerovac"],
	"plasma_pistol": ["svitilna", "laser"],
	"plasma_cannon": ["optika", "rukojet"],
	"plasma_minigun": ["nosny", "stabilizator", "chladic", "zamerovac"],
	"knife": ["ergo", "pouzdro"],
	"energo_nuz": ["pouzdro"],
	"stun_baton": ["akumulator", "lehky", "diagnostika"],
}
func has_mod(weapon: String, mod: String, m: Dictionary = {}) -> bool:
	var src: Dictionary = m if not m.is_empty() else merc
	return mod in src.get("mods", {}).get(weapon, [])

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
	if has_mod(weapon, mod) or not mod in MOD_FITS.get(weapon, []) or not spend(mod_price(mod)):
		return false
	var mods: Dictionary = merc.get("mods", {})
	var l: Array = mods.get(weapon, [])
	l.append(mod)
	mods[weapon] = l
	merc["mods"] = mods
	save_merc()
	Net.update_merc()
	return true

## Texts say "Kondor"; before its research the team flies the old helicopter Čáp.
func shipify(t: String) -> String:
	if String(Net.mission_params.get("transport", "kondor")) != "heli" or not "Kondor" in t:
		return t
	return t.replace("v Kondoru", "v Čápu").replace("Kondoru", "Čápa").replace("Kondor", "Čáp")

func two_handed(id: String) -> bool:
	return ITEMS.get(id, {}).get("two", false)

## Seconds to take an item out of a slot: belt is quick, backpack is a dig.
func fetch_time(id: String, from_slot: String) -> float:
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
const HEADGEAR := [["helmet", "Helma se svítilnou"], ["cap", "Polní čepice"], ["none", "Nic (vlasy na odiv)"]]
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
		"headgear": 0 if r.randf() < 0.65 else 1,
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
	var hair_nodes := {"buzz": "Look_HairBuzz", "short": "Look_HairShort", "long": "Look_HairLong", "pony": "Look_HairPony", "mohawk": "Look_HairMohawk", "bun": "Look_HairBun"}
	var beard_nodes := {"stubble": "Look_Stubble", "moustache": "Look_Moustache", "goatee": "Look_Goatee", "full": "Look_BeardFull"}
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("Look_Hair"):
			mi.visible = hair_nodes.get(hair, "") == nm and not (gear != "none" and hair == "mohawk")
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
}
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
		out.append("POVÝŠEN na %s! %s. Nový talent k výběru (Můj voják)." % [RANKS[lvl], ", ".join(grown)])
	save_merc()
	return out

const STAT_NAMES := {"accuracy": "Přesnost", "reactions": "Reakce", "strength": "Síla", "bravery": "Odvaha", "health": "Zdraví", "stamina": "Výdrž"}

## Three talents on offer (stable until one is picked).
func talent_offer() -> Array:
	if merc.has("offer"):
		merc["offer"] = (merc["offer"] as Array).filter(func(o): return TALENTS.has(o) and not has_talent(merc, o))
	if merc.has("offer") and not merc["offer"].is_empty():
		return merc["offer"]
	var pool := []
	for k in TALENTS:
		if not has_talent(merc, k):
			pool.append(k)
	pool.shuffle()
	merc["offer"] = pool.slice(0, 3)
	save_merc()
	return merc["offer"]

func pick_talent(id: String) -> void:
	if int(merc.get("talent_points", 0)) <= 0:
		return
	var t: Array = merc.get("talents", [])
	t.append(id)
	merc["talents"] = t
	merc["talent_points"] = int(merc["talent_points"]) - 1
	merc["offer"] = []
	save_merc()

func load_merc() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://merc.cfg") == OK:
		mercs = cf.get_value("merc", "roster", [])
		active = int(cf.get_value("merc", "active", 0))
		if mercs.is_empty():
			var one: Dictionary = cf.get_value("merc", "data", {})
			if not one.is_empty():
				mercs = [one]
	if mercs.is_empty():
		mercs = [new_merc()]
	active = clampi(active, 0, mercs.size() - 1)
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
		fullscreen = cf.get_value("video", "fullscreen", false)
		seen_version = cf.get_value("game", "seen_version", "")
		voice_mode = cf.get_value("voice", "mode", "ptt")
		mic_gate = cf.get_value("voice", "gate", 0.03)
		mimic_ok = cf.get_value("voice", "mimic", true)
		mic_gain = cf.get_value("voice", "gain", 1.0)
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
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("game", "seen_version", seen_version)
	cf.set_value("voice", "mode", voice_mode)
	cf.set_value("voice", "gate", mic_gate)
	cf.set_value("voice", "mimic", mimic_ok)
	cf.set_value("voice", "gain", mic_gain)
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
const METAL_SHADER := preload("res://shaders/world_metal.gdshader")
var retro := true          # the screen filter: dithering, grain, colour bleed
var wobble := false        # PS1 vertex jitter (the world "shivers" a little) - its own switch since 0.50
var volumetric := true     # volumetric fog (Forward+ only)
var render_scale := 1.0    # 3D resolution (1 = native, sharp; lower = faster)
var grass := true          # grass blades swaying in the wind
var fullscreen := false
var seen_version := ""     # the newest version whose "what's new" the player has seen
var voice_mode := "ptt"    # "off", "ptt" (hold Tab), "open" (voice activation)
var mic_gate := 0.03       # voice activation threshold (open mic)
var friendly_fire := true   # host's choice: bullets hit teammates too
var mic_gain := 1.0        # own microphone loudness (x0.5 .. x4)
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
const VARIANTS := {"plasma_heavy": 10, "casing": 4, "step_heavy": 3, "gear": 4, "sting": 4, "type": 4, "breath": 2}
func sound(sname: String) -> AudioStream:
	if VARIANTS.has(sname):
		sname = "%s_%d" % [sname, randi() % int(VARIANTS[sname])]
	if not _sounds.has(sname):
		_sounds[sname] = load("res://assets/sounds/%s.wav" % sname)
	return _sounds[sname]

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

func play_at(world: Node, sname: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if world == null or not world.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = sound(sname)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	if sname in ALIEN_SOUNDS and world.has_method("alien_db"):
		p.volume_db += world.alien_db()      # rain covers them
	p.unit_size = 6.0
	p.max_distance = 80.0
	p.bus = "SFX"
	world.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)

func play_ui(world: Node, sname: String, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sound(sname)
	p.volume_db = volume_db
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
