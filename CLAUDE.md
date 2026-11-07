# Operace X – Enemy Beyond: poznámky pro Clauda

Godot 4.7, Ariho projekt (D:\Godot\Enemy Beyond). Odpovídej česky. Changelog se píše v Ariho první osobě.

## Pravidla
- Nikdy nepřepisuj `upravy.json` (Ariho úpravy z Dílny) ani `project.godot`.
- Před nahráním souboru na PC zkontroluj, jestli ho Ari mezitím nezměnil (čas/velikost).
- Pohyby z Mixama a z afk.ai patří jen do balíčku hry (.pck), ne do veřejného repa (`animace/tp_*.json` je v .gitignore, kromě `tp_hold_*`).
- Žádné originální assety X-COM. Kredity Suno/ElevenLabs/afk.ai neutrácej bez Ariho.
- Před vydáním spusť `tools/fulltest.sh`. Verze 0.57 vyjde, až Ari řekne, že je facelift hotový.
- Hardcore: žádné nápovědy; účinnost vetřelců je skrytá až do pitev.
- Commit/push jen na požádání.

## Pohyby vojáka (afk.ai) – jak to funguje
- Ari animuje v afk.ai na modelu `animace/Maximo/postavy/merc_pest_T` (pěsti, bez prstů) a exporty dává do `animace/Maximo/AFKanimace/`.
- Převod do hry: `tools/test/afk_install.gd` (spuštění `--autotest=afkinstall`), seznam „klip ve hře ← pohyb z afk“ je v jeho `LIST`.
  Převádí kostru afk (Unreal pojmenování) na naše kosti přes `scripts/mocap.gd` (`Mocap.AFK`).
- Balíčky a pořadí (novější vyhrává; `soubor:Prefix` = jen pohyby s tím začátkem):
  - běžná sada: `merc_pest_T-animated_puvodni (první export, jsou v něm emoce a kulhání), merc_pest_T-animated, merc_pest_T-animated2, merc_pest_T-pistoles.glb:Pistol_, merc_pest_T-rifles.glb:Rifle_`
  - těžké zbraně: `--set=heavy` a `merc_pest_T-animated_heavyweapon.glb` jako poslední – jen pro miniguny, kanóny, raketomet, cizí těžkou (player.HEAVY). Nikdy nemíchat s běžnou sadou.
- Ve hře (`scripts/player.gd`): `_body_clip` vybírá `tp_body_<pohyb>[_směr][_pistol|_heavy]`, varianty `_2.._9` (postávání, smrti), `_hurt` pod 35 % zdraví, střelba `fire*` 0,35 s po výstřelu, pád `fall`.
  Akce rukou `tp_<akce>_<zbraň|vse>` (reload, strike, throw, use, heal, draw/drawp). Emoce: kolo na J (`scripts/emote_wheel.gd`, `player.EMOTES`), U pohov.
- Zbraň v rukou: dlouhá zbraň `player.afk_gun_xform` (úchop v pravé ruce, hlaveň k levé) + úpravy z Dílny `tpa/<zbraň>` a `tpa/<zbraň>@<pohyb>`; pistole `tp/<zbraň>` + `tpa/<zbraň>@<pohyb>`.
- Dílna (`scripts/workshop.gd`, Předmět v ruce – zvenku) přehrává stejné pohyby a počítá zbraň stejnou funkcí jako hra – při změnách ve hře ji drž v souladu.
- Z Mixama zůstává: otočka v přikrčení, přebíjení vleže, hod granátu vleže.
- Vetřelci: afk balíčky (grey, greyv-mind, zombie, myslodej, levit, nador, diskoll, kolos, ohnivec, Ohař z meshy) prohlédnuté, ještě nezapojené. Velitelé převezmou pohyby obyčejného typu (Šedivák velitel o ~4 cm vyšší).

## Otevřené věci
- Zapojit afk pohyby vetřelců; Ještěřanovi ocas (řetěz kostí + SpringBoneSimulator3D jako plášť).
- Text plazmové pušky v encyklopedii useknutý; krok gfx_anim_review; velká revize, pak facelift; otázky: miny, ztlumení skeneru, záloha do cloudu.
- Checklisty (artefakty): Encyklopedie, Animace postav – zachovávat Ariho zaškrtnutí.
