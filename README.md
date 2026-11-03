# Enemy Beyond — prototyp 0.26

**Hratelný test (Windows 64 bit):** stáhni [hratelny-test/EnemyBeyond-0.26-windows.zip](hratelny-test/EnemyBeyond-0.26-windows.zip)
(tlačítko „Download raw file“), rozbal a spusť `EnemyBeyond.exe` - nic se neinstaluje.
Windows může napoprvé ukázat varování SmartScreen (soubor není podepsaný): „Další informace“ → „Přesto spustit“.
Co-op: jeden hráč dá „Hostovat hru“, ostatní „Připojit ke hře“ s jeho IP (UDP port 7777; přes internet Radmin VPN / ZeroTier).

Fanouškovská pocta UFO: Enemy Unknown. Kooperativní hororová střílečka z pohledu
první osoby pro 1–4 hráče. Nekomerční projekt, veškerá grafika a zvuky jsou vlastní
(generované skriptem `tools/gen_assets.py`).

## Spuštění
Otevři složku v Godotu 4.7 a dej F5. Hlavní scéna je `scenes/Main.tscn`.

## Ovládání
| Klávesa | Akce |
|---|---|
| WASD | pohyb |
| Shift | sprint (nejde střílet, zbraň visí podél těla; po sprintu se uklidňuje dech) |
| C / Ctrl | přikrčit se |
| Z | lehnout si / vstát (nejpřesnější, nejtišší, skoro neviditelný) |
| Myš L / P | **obouruční zbraň:** L střílí, P míří · **jednoruční věci:** L = levá ruka, P = pravá ruka |
| R | přebít (z opasku rychle, z batohu stojíš a hrabeš se; brokovnice a magnum po nábojích) |
| Q | dlouhá zbraň ruce ↔ záda |
| 1–4 | věc z opasku do ruky (dlouhou zbraň si hodí na záda); náboje na opasku = nabít zbraň |
| V | rychlý útok nožem / obuškem (nebo pažbou) |
| G / X / B / T | granát / kouřový granát / mina / světlice |
| F | svítilna |
| H | ošetřit se lékárničkou |
| E | ošetřit / táhnout padlého / sebrat; u lodi držet 2 s = odlet |
| I / Tab | výstroj (ruce, záda, opasek, batoh) |
| Caps Lock / N | mluvit (mikrofon); s vysílačkou v ruce do vysílačky |
| F11 | celá obrazovka |
| Esc | pauza a nastavení |

## Zbraně a výbava (verze 0.7)
Puška, pistole, brokovnice, revolver Magnum (silný, nabíjí se po náboji), autokanón (výbušné náboje, těžký),
minigun (musí se roztočit, velmi těžký), raketomet, bojový nůž (zezadu smrtící), omračovací obušek (drží se vzpřímeně a mlátí se jím shora - střídá se úder shora,
zprava šikmo a zleva šikmo; omráčený vetřelec je zajat živý = víc zkušeností, později víc peněz), granát, kouřový granát
(vetřelci přes kouř nevidí), nášlapná mina, světlice, lékárnička, detektor pohybu.
Obouruční zbraně zaberou obě ruce. Přendávání věcí trvá podle váhy a místa (opasek rychle, batoh pomalu).

## Novinky 0.15
- Oprava ukončení mise (E u Kondoru), vysílačka na K, lepší mikrofon, kdo mluví v lobby.
- Přehlednější výstroj s klávesami, palba do vlastních, obtížnost snadná / normální / hardcore.
- Co-op stíhačky (každý hráč svůj Sokol, pokud jich základna má dost).

## Novinky 0.14
- Stíhačky arkádově (A/D ostrý úhyb), přesnější UFO, které uhýbá raketám.
- Lobby: peníze mezi hráči, nákup do základny hostitele, náhled glóbu, talenty, výstroj, hlas.
- Připravenost po briefingu (všichni potvrdí), výsadek čelem ven z Kondoru.
- Automatická kořist, Moskovium 115, laserové zbraně, odstřelovací puška, úpravy zbraní.
- Velikosti map, sníh a poušť, chytřejší vetřelci, těžší Veterán.
- Hudba: vlastní soubory do složky `hudba` vedle hry (návod v `hudba/CTI_ME.txt`).

## Aktualizace (od verze 0.13)
Hra si po spuštění sama zkontroluje GitHub. Menší aktualizace stáhne (pár MB) a nabídne restart, po restartu ukáže okno Novinky. Pokud je potřeba nový .exe, menu napíše, ať stáhneš nový zip.

## Počasí a postoj (verze 0.12)
- Každá mise má jiné počasí: bouřka (déšť, blesky), déšť, hustá mlha, zataženo (tma), jasno (svítí měsíc - vidíš dál, ale ony tebe taky).
  Počasí je uvedené v briefingu.
- Vlevo dole vedle ukazatelů ikonka postavy: stojíš / klečíš / ležíš / sprint / bez dechu.
- Když dojde výdrž, sprint se zamkne, dokud se nevydýcháš (čtvrtina výdrže) a znovu nezmáčkneš Shift.

## Tvorba žoldáka (verze 0.11)
Hlavní menu → Můj žoldák → „Najmout jiného žoldáka“ (nebo automaticky, když tvůj žoldák padne).
- Jméno (nebo náhodné podle pohlaví), pohlaví, vlasy, barva vlasů, vousy, barva očí, pleť, pokrývka hlavy
  (helma se svítilnou / čepice / nic). Náhled se otáčí, „Tvář / celý“ přiblíží obličej. Vzhled vidí i spoluhráči.
- Vlastnosti: **Rozdělit body** (30 bodů do 6 vlastností, každá 0–10) nebo **Hodit kostkami** (2k6−2 za každou,
  3 hody, hod nejde upravit). U každé vlastnosti je vysvětlivka, co dělá ve hře.
- Existujícímu žoldákovi jde změnit vzhled (Upravit vzhled), vlastnosti ne.

## Hodnosti a talenty
Za přežité mise dostává žoldák zkušenosti (úspěch, zabití, zajetí, ošetření). Při povýšení mu rostou
dvě vlastnosti a vybere si trvalý talent ze tří nabídnutých (Můj žoldák). Smrtí se všechno ztrácí.

## Kampaň (verze 0.8)
- Hlavní menu → KAMPAŇ. Velín s točícím se glóbem: den a noc podle skutečného času, světla měst na noční straně.
  Pravé tlačítko otáčí glóbem, kolečko přibližuje, čas běží rychlostmi 5 min / 1 h / 6 h za sekundu.
- Radar hlásí mise: havárie UFO, přistání UFO, únos, teror v městečku. Každá má místo, místní čas
  (noc / den), krajinu (venkov, lesy, městečko), odhad posádky, odměnu a čas, než zmizí.
  Nevyřízená mise snižuje důvěru sponzorů, teror nejvíc. Důvěra 0 = konec kampaně.
- Odměny: kredity za úspěch, za zabité a hlavně za zajaté vetřelce. Měsíční příspěvek podle důvěry.
- Výzkum (za kredity, trvá dny): pitva, ženijní výbava, těžké zbraně, citlivější detektor, slitiny do vest,
  polní medicína, výslech zajatce, plazmová puška. Některé potřebují zabitého nebo živého vetřelce.
- Základna: mřížka 6×4, stavba laboratoří, zbrojnic, ošetřovny a radaru.
- Zbrojnice: nákup trvale zvětší výbavu, kterou si žoldáci mohou vzít na misi.
- Co-op: hostitel klikne ve velínu na „Hostovat co-op“, kamarádi se připojí z hlavního menu.
  Hostitelova kampaň vybírá mise; po misi se všichni vrátí (hostitel na glóbus, ostatní do lobby).
- Těžké zbraně (autokanón, minigun): pravé tlačítko = přitáhnout k tělu (přesnější, pomalejší pohyb).

## Vzdušný souboj (verze 0.9, prototyp)
- Radar občas zachytí UFO v letu (zelená značka, pohybuje se). Vyber ho a vyšli stíhačku **Sokol**.
- Ovládání: myš řídí (virtuální knipl), A/D náklon, W/S plyn, Shift forsáž,
  levé tlačítko kanón, pravé tlačítko (nebo R) raketa – nejdřív musíš UFO 1,5 s držet ve středu (zaměření).
- Tři velikosti: Průzkumník (malé, rychlé, neozbrojené), Nájezdník (střední, střílí), Sklízeč (velké, pancéřované, střílí hodně).
  Kanón velkým UFO skoro neublíží – na ně jsou rakety.
- Výsledek: UFO dostane-li poslední zásahy postupně, **spadne** (vznikne mise Havárie s posádkou a kořistí).
  Když mu v posledních 2 s ubereš víc než třetinu (salva raket do malého UFO), **rozletí se** – jen malá odměna.
  Poškozené UFO utíká; když se vzdálí na 1,5 km, **uniklo**. Sestřelený Sokol je 5 dní v opravě.
- Nezastavené UFO může později přistát – vznikne mise Přistání.

## Obraz a příroda (verze 0.9.1)
- Hra se vykresluje v plném rozlišení okna, písmo je ostré (už žádné kostičky). F11 nebo Alt+Enter = celá obrazovka.
- V nastavení: rozlišení 3D (plné / 75 % / 50 % pro slabší počítače), tráva ve větru, celá obrazovka.
- Tráva, obilí a koruny stromů se hýbou ve větru; vítr sílí a slábne, při blesku se opře do polí.
- Kolem rozsvícených lamp poletují můry (zmizí, když světlo zhasne).
- Velín: značky drží na glóbu, klepnutím vybereš hlášení (kurzor se změní na ručičku), vlevo nahoře je seznam všech hlášení.

## Vetřelci (verze 0.11) - vlastní modely, role podle starého X-COMu
Posádky chodí ve skupinách: **Šeďáci + Diskoll**, **Levité + Ohař**, **Ještěřani + Líhnouni**,
**Bijci + Nádor + Ohnivec**, **Myslodějové + Kolos**. V kampani přicházejí těžší skupiny postupně (měsíc 1, 2, 3).
| Druh | Co dělá |
|---|---|
| Šeďák | Slabý, rychlý, chytrý, plazmová pistole. Vystřelí a zmizí, padlé táhne do tmy. |
| Šeďák velitel | V uniformě. Psionik: vnutí paniku, když tě vidí kterýkoli vetřelec. |
| Diskoll | Létající disk. Rychlé, velmi přesné dávky (ne na jednu ránu). Plazma a výbuchy ho trhají, kulky odráží. |
| Levit | Létající mutant s děsivou tváří, plazmová puška. |
| Ohař | Zmutovaný vlk s kostěnou čepelí místo tlamy a pancířem. Rychlý, hloupý, běží rovnou na tebe. |
| Ještěřan / velitel | Vysoký ještěr, pomalý a odolný; voják s krunýřem, velitel v plné zbroji. |
| Líhnoun | Černý dravec, zabíjí zblízka, z obětí se stávají Nakažení a z nich noví Líhnouni. |
| Bijec / velitel | Svalnatý mutant v tmavě modrém biologickém obleku (velitel v rudém), těžká karabina. |
| Nádor | Pulzující nádor, plivá kyselinu. Když padne, musíš ho na zemi dorazit, jinak se zvedne. |
| Ohnivec | Hromada žhavé skály, plivá lávu, vedle něj se hoří. Neberou ho kulky ani plazma, jen výbuchy. |
| Mysloděj | Prázdný fialový rubáš, zbraň drží myslí ve vzduchu. Panika, ovládnutí, psionická bolest; spojence hojí a zrychluje. |
| Kolos | Chodící stroj na třech nohách: dvě plazmové hlavice a dělo na střeše. Smrtící, ale hloupý. Exploduje. |
- Civilisté (teror, únos): E u vyděšeného civilisty = půjde za tebou ke Kondoru.
- Rychlá mise: Noc na samotě (Šeďáci), Teror (Ještěřani a Líhnouni), Únos (Levité, Ohař), Přistání (Bijci),
  Velká loď (Myslodějové, Kolos), Náhodná.

## Vysílačky a hlas (verze 0.10)
- Mikrofon: Caps Lock nebo N (držet) = mluvíš. Hlas jde z tvé postavy a slábne se vzdáleností (3D).
  V nastavení: při stisku / stále zapnutý (podle hlasitosti) / vypnutý.
- **Vysílačka** (na opasku, klávesa 4): drž ji v ruce a mluv (Caps Lock, nebo tlačítko myši té ruky) - slyší tě
  všichni, kdo vysílačku nesou, ať jsou kdekoli. Blízko vetřelců chrčí a vypadává.
  Výzkum Helmové vysílačky: vysíláš bez ruky.
- Mluvení dělá hluk - vetřelci ho slyší, Ohař přiběhne.
- **Napodobování:** vetřelci si pamatují, co jste během mise řekli, a pouštějí to ze tmy - věrně jako vábničku,
  nebo zpomaleně a špatně. Hlas mrtvého spoluhráče se může ozvat ve vysílačce.
  Nahrávky jsou jen v paměti a po misi zmizí. V nastavení jde zakázat („Vetřelci smí napodobit můj hlas“).

## Pravidla mise
- Noc, havarované UFO na farmě. Zneškodni posádku a vrať se do Kondoru (výsadková loď).
- Když padneš, krvácíš 60 s. Spoluhráč tě musí ošetřit lékárničkou, nebo odtáhnout
  na palubu. Jinak žoldák umírá natrvalo a najímáš nového.
- Staty žoldáka (přesnost, reakce, síla, odvaha, zdraví, výdrž) ovlivňují hru.

## Strach (verze 0.2)
- Vetřelců je málo (2 + počet hráčů) a nestojí na ráně: vystřelí, zmizí a vrátí se z jiné strany.
- Prvních 60 s je klid. Pak si „režisér“ občas vybere osamělého žoldáka a jeden šedák se k němu plíží.
- Padlého hráče vetřelec odtáhne do tmy – spoluhráč ho může vyrvat zpátky (E).
- Žádná hudba: vítr, šustění v obilí, vzdálené zvuky. Krátký úder jen ve chvíli, kdy vetřelce opravdu uvidíš.
- Detektor ukazuje cokoliv, co se hýbe (i spoluhráče), pípá rychleji, když je to blíž, a vystrašenému hráči lže.
- Zaměřovač je vidět jen při míření (pravé tlačítko). Svítilna bliká, když je vetřelec blízko. Oči se zalesknou jen ve světle.

## Obtížnost Veterán (verze 0.3)
Přepíná se v hlavním menu, při hře ve více lidech platí volba hostitele.
- Plazma zabíjí na 1–2 zásahy. Jen jeden náhradní zásobník a lékárnička na 2 použití.
- Žádné ukazatele zdraví a strachu: krev na okrajích obrazu, těžký dech, kulhání.
- Palba do vlastních – kulky nerozlišují, kdo je kdo.
- Panika jako v X-COMu: při velkém strachu ti vypadne zbraň (E ji zvedne), utečeš, nebo začneš střílet naslepo.
- Zranění si žoldák nese do další mise. Hojí se v reálném čase (1 bod zdraví za 10 minut).
- Panika (bez šílení) existuje i na normální obtížnost, jen mnohem vzácněji.

## Noc na samotě (verze 0.4)
- Briefing před misí, pak se z černé pomalu vynoří noc. Prší a bouří se – blesk na zlomek vteřiny osvětlí celé okolí.
- Farma vypráví, co se stalo: převržený stůl a rozsvícená lampa v kuchyni, prázdná psí bouda s utrženým řetězem,
  mrtvý dobytek s chirurgicky přesnými řezy, spálený kruh v obilí, auto se zapnutými světly a otevřenými dveřmi,
  stopa vedoucí od domu k UFO. Elektrika na farmě bliká, když jsou vetřelci blízko.
- Rádio: pilot Kondoru – a pak hlas, který na frekvenci být nemá. Kolem 3,5 minuty farma přijde o proud.
- Halucinace: vystrašený žoldák zahlédne postavu na kraji světla, uslyší kroky za zády nebo šepot.
- Výstroj na misi: v menu si ze skladu základny vybereš, co poneseš (Veterán má skromnější sklad).

## Grafika (verze 0.5)
- Hra běží na Forward+ (Vulkan) s objemovou mlhou: kužel svítilny v dešti, záře UFO v mlze.
  Bez Vulkanu se sama přepne na OpenGL (bez objemové mlhy).
- Retro filtr ve stylu PS1 hororů: chvění vrcholů, omezená paleta s rastrem, zrno, jemná VHS barva.
- Modely z Blenderu (assets/models): šedák s animacemi (klid, chůze, běh, krčení, míření),
  puška, pistole, kráva, výsadková loď. Zdrojové skripty: tools/blender/*.py
  (spustí se `python grey.py cesta/grey.glb` s Blenderem jako Python modulem nebo v Blenderu).

## Nastavení
Citlivost myši, zorné pole, obrácení osy Y, retro filtr a objemová mlha: v menu „Nastavení ovládání“ nebo ve hře v pauze (Esc).
Briefing se přeskakuje mezerníkem nebo kliknutím.

## Multiplayer
Hostitel klikne na „Hostovat hru“, ostatní na „Připojit ke hře“ a zadají jeho IP.
Port 7777 (UDP). Přes internet nejlépe přes Radmin VPN nebo ZeroTier.

## Testy (pro vývoj)
`godot --path . -- --autotest=solo` · `--autotest=host` + `--autotest=client` · `--autotest=shot`
