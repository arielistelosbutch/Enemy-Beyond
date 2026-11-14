# Operace X - Enemy Beyond — prototyp 0.70

**Hratelný test (Windows 64 bit):** stáhni [hratelny-test/EnemyBeyond-0.28-windows.zip](hratelny-test/EnemyBeyond-0.28-windows.zip)
(tlačítko „Download raw file“), rozbal a spusť `EnemyBeyond.exe` - nic se neinstaluje.
Windows může napoprvé ukázat varování SmartScreen (soubor není podepsaný): „Další informace“ → „Přesto spustit“.
Co-op: jeden hráč dá „Hostovat hru“, ostatní „Připojit ke hře“ s jeho IP (UDP port 7777; přes internet Radmin VPN / ZeroTier).

Fanouškovská pocta UFO: Enemy Unknown. Kooperativní hororová střílečka z pohledu
první osoby pro 1–4 hráče. Nekomerční projekt, veškerá grafika a zvuky jsou vlastní
(generované skriptem `tools/gen_assets.py`).

## Novinky 0.50
Velká aktualizace, na kterou jsem šetřil:
- Všichni vetřelci mají nové modely podle mých kreseb, vlastní schopnosti a texty z vojenské databáze (Levit Mírotvůrce, Ještěřan, Líhavec, Nakažený, Bijec, Nádor, Ohnivec, Mysloděj, Kolos, Ohař...).
- Válka sílí: v pozdní hře chytřejší a tvrdší vetřelci, noční tlupy, posily během mise, nemesis (zabiješ velitele - jdou po tobě), raketomety, těžká děla, granáty a miny. V co-op přitvrzuje s každým hráčem.
- Ekonomika: všechno dražší, nákupy se doručují, kořist se dá prodat, nepovedená mise = ztracená výbava, výzkum skrytý za ???.
- Nové modely zbraní a lodí vetřelců, na mapách vraky, krátery, trosky a fialový porost kolem UFO. Transportér už nestojí na kraji mapy a nic se nespawnuje v sobě.

## Novinky 0.70
- Co-op přes VPN je plynulejší: hra posílá polohy 30× za sekundu místo každého snímku a cizí postavy se mezi nimi hladce posouvají. Hlas jde jednou cestou, takže se slyšíme v menu, na glóbu, v tvorbě vojáka, v misi i v transportéru, a už tolik nepraská.
- Na glóbu je v co-opu tlačítko PŘIPRAVEN: hostitel s výsadkem, stíhačkami i misí počká, až budou všichni připraveni (nebo začne hned).
- Na základnu chodím přímo z glóbu, každý do své kopie, a mezitím, co čekáme, běží kampaň dál. Zpátky se vrátím z Velína nebo přes Esc.
- Když v co-opu padnu, můžu sledovat spoluhráče, který ještě žije: za zády nebo z jeho očí a přepínat mezi nimi.
- Q a E nakloní vojáka za roh. Klávesy se přeházely: F = použít, kolečko myši = rychlá výměna zbraně, L = svítilna, B = dávky, 8 = mina.
- Odměny z misí jdou do společné hromádky a dělí se rovným dílem mezi celý tým. Piloti stíhaček dostanou letecký příplatek a v Hangáru na glóbu si můžu koupit Sokol ze svých peněz. V souboji stíhaček vidím, jak jsou na tom letouny spoluhráčů.
- Obrana základny je vzácnější (první útok až po 30. dni) a lehčí, ale když ji prohrajeme, kampaň končí.
- Posily po splnění úkolu vezmou hlášku o splnění zpět. Odlet před nimi je úspěch s horším hodnocením. Po konci mise mě už nikdo nezraní a strach roste o třetinu pomaleji.
- Ošetřování běží, jen dokud držím tlačítko. Světlice zůstane ležet a svítí na místě (dřív propadla pod mapu).
- Kolize: plášť UFO je pevný (už se nedá střílet skrz loď), skalní stěny, krápníky, suť a klády nepropustí, nedá se proskočit stropem budovy ani přelézt okraj mapy.
- Domy: v patrovém domě odděluje schodiště stěna, gauč nestojí za schody, pod schody se nedá vlézt, podkroví srubu je vyšší a obchod a sklad mají zábradlí u schodů.
- Grafika: auta mají správné sloupky a tmavá skla, stodola nemá bílý pás přes vrata, na stavbě základny pracují technici v helmách, stojan na zbraně v dílně a konzole jsou opravené a ranění v transportéru leží na zádech.
- Mířidla jsou při míření vždycky průhledná: oko se za kolimátor usadí hned i v chůzi a po sprintu (už žádná černá klapka) a sklo mířidel je čiré.

## Novinky 0.69
- Novou kampaň začínám výběrem místa pro základnu na glóbu: devět bloků světa roku 1990 a každý dává jinou výhodu na začátek (Vysočina zůstává jako dřív).
- Na glóbu létají malé 3D modely UFO i našich lodí místo obrázků. Velká UFO mají zavřený trup, žádné díly mapy pod nimi.
- Souboj stíhaček: kamera drží rovinu, úhyb A/D je celý výkrut, kosočtverec ukazuje, kam mířit, Q vypustí návnady, prostřední tlačítko rozhlíží a 1/2/3 dávají rozkazy křídlu. Poškozený letoun hůř zatáčí, kouří a praská mu sklo a nenápadný signál ukáže, že mě má něco v hledáčku.
- Čáp, Kondor a Pelikán mají rampu, která se za letu, v hangáru a v transportéru po misi zavírá.
- Strážce má nový model se čtyřmi točícími se vrtulkami a v singlu mě v boji opravdu zvedne, i když jsou vetřelci kousek ode mě.
- Kamera z očí se při chůzi a běhu pohupuje (v Nastavení se dá zeslabit nebo vypnout). Revolver už se při R s plným bubnem neprotáčí.
- Stahování aktualizace ukazuje průběh v procentech a megabajtech a hra se při něm nesekne (projeví se od další verze).
- Opravy v rozhraní: jmenovky lodí na glóbu, přehled lodí ve vzduchu ve Velínu a HUD stíhačky.

## Novinky 0.68
- Strom talentů u vojáků (vedle úprav zbraní): čtyři větve po pěti stupních a vidím dopředu, co mě čeká. Rychlé přebíjení pušky je teď až talent a sprint vydrží aspoň 8 sekund.
- Vetřelci se domlouvají ve skupinách: mají velitele, role a útočí společně. Mezi misemi si pamatují, jak hrajeme, a na blízko bojují chytřeji. Vždy počítají s jedním až čtyřmi hráči.
- Posádka UFO odpovídá velikosti lodi, aby byl čas se na větší lodě připravit výzkumem.
- Všichni vetřelci reagují na zásah vlastním pohybem, Mírotvůrce má konečně pohyby a civilisté umí umírat jako lidé.
- Údery z očí jsem natočil ve VR pro každou zbraň, nůž, energonůž i obušek. Úder pažbou jde dál od těla a V s nožem v opasku sekne hned, bez tasení.
- Šediváci a Levité střílí laserem, plazmu mají až Ještěřani a velitelé. Zvednutý štít zastaví víc plazmy.
- Den a noc na misi sedí s glóbem – kde je na glóbu tma, je tma i na misi.
- Kulky se už nezastavují o neviditelné hranice kolem stromů, plotů, aut a dalších předmětů. Chodníky a podlahy mají kolizi, takže nikdo nepropadá do země, a kroky zní podle toho, po čem jdu.
- Konec blikajících ploch u regálů, aut a dalších modelů. Auta mají boční okna podle sloupků.
- Při obvazování se můžu pomalu hýbat, kdo obvazuje jiného, stojí.
- Načítací obrazovky s obrázky, transportér po misi, vědci a technici na základně, jednotný HUD, ozvěna podle prostoru a špína na uniformě.
- V singlu mám radar od Strážce napořád a Strážce mě nezvedne, dokud jsou vetřelci blízko.
- Lepší hlasový chat (méně brumu a sykotu) a hlas vojáka sedí k pohlaví i po změně.
- Co-op hlídá verzi hry: s jinou verzí se hráč nepřipojí a dozví se proč. Méně propadů FPS v co-opu i při pohledu do dálky ve městě.
- Opravy: vetřelci při útoku na základnu nestojí za zdí, UFO sestřelené nad mořem spadne na nejbližší pevninu, nezaseknu se u trosek velké lodi, hra nespadne po misi s kouřem a plazmovky jdou přebít hned po výstřelu.

## Novinky 0.61
- Obtížnost po prvním hraní: strach vojáka roste pomaleji a hned ho neochromí, ruce se třesou méně a panika přijde vzácněji.
- Kampaň začíná jen se Šediváky. Další druhy přicházejí postupně: Levité od druhého měsíce, Ještěřani od třetího, Bijci a Myslodějové od čtvrtého.
- Ocelové posuvné dveře v chodbách základny: E je zavře i otevře, vetřelci je musí chvíli páčit (Bijec rychleji) a plazma nebo výbuch je prorazí. E u dveří funguje i s věcí na zemi.
- Levité už při útoku na základnu nelétají stropem a zdmi a neobjeví se týmu za zády. Kde nemůžou letět, jdou pěšky.
- Kameny jsou pevné – už se nedá vejít dovnitř ani projít skrz, vetřelci je obcházejí.
- Štít: vlastní lampa už v něm z očí nedělá bílou skvrnu a zvednutý štít opravdu zastaví většinu kulek a střepin.
- Šablony vojáků a sady výstroje: vzhled, jméno a body nového vojáka i oblíbenou výstroj si uložím a příště je jen vyberu.
- V lobby vidím u každého hráče ping a jestli mu jde mikrofon, a jako hostitel můžu hráče vyhodit.
- Zpět z tvorby vojáka mě vrátí tam, odkud jsem přišel (glóbus, co-op lobby), ne do hlavního menu.

## Novinky 0.60
- Vojáci se konečně hýbou podle pohybů, které jsem sám natočil v afk.ai: běžné, s pistolí i s těžkými zbraněmi, střelba za chůze i běhu, kulhání raněného, tasení zbraně a kolo emocí na J.
- Přebíjení, obvazování, hrabání v batohu a hody z pohledu z očí jsem natočil ve VR na Questu 3 – ruce dělají přesně to, co jsem dělal já. Zásobník je samostatný díl a opravdu vypadne a zacvakne se.
- Úpravy zbraní: do slotů se montují koupené díly – kolimátor, optika 2x s opravdovým zvětšením, tlumič, bajonet, rukojeť, svítilna, laser, dvojnožka a k laserům a plazmě vlastní díly. Každý díl něco dá a něco vezme.
- Všichni vetřelci mají nové pohyby a smrti z afk.ai: Šedivák, Bijec, Líhavec, Ještěřan s ocasem, Levit s chapadly, Ohař, Nakažený, Diskoll, Kolos, Mysloděj, Nádor a Ohnivec.
- Vetřelci jsou chytřejší i v co-opu: kryjí se proti všem hráčům najednou, vybírají si toho nejnebezpečnějšího, slyší, odkud se střílí, utíkají před granátem, mrtvý druh jim nahání strach a místo točení na místě prohledávají úkryty.
- Vzhled vojáka si vybereš při jeho tvoření: oblečení, baret, tetování, barvy na obličej a vlajka.
- Raněného kamaráda jde odtáhnout do bezpečí.
- Kdo opustí misi přes menu nebo když hra spadne, ten misi prohrál – vojáci, kteří v ní zůstali, jsou nezvěstní a do mise se už nedá vrátit.
- Opravené dílky map: obchod má zadní dveře do skladu, v parku jsou lavičky podél cest a z prašné cesty zmizelo auto uprostřed.
- Encyklopedie ukáže, co zbraň dělá proti rase, až po pitvě. Základna je vidět shora a přibyla psionická ochrana.

## Novinky 0.56
- Obří lodě (bitevní a zásobovací) mají na zemi skutečný trup a dvě patra: z haly pod kupolí vede rampa na galerii a chodby do sálů na palubě. Od třetího měsíce války obři i létají a ve vzduchu vypadají stejně jako na zemi.
- Sestřelené UFO je na zemi to, co jsi sestřelil. Malé lodě na zemi odpovídají těm ve vzduchu.
- Nové modely přírody, ulic a dvorů, zařízení naší i jejich základny, nové ruce v pohledu z očí, suť ve spálené ruině.
- Otáčení na místě, smrt z kleku, hod granátu vleže; všech 154 nahraných zvuků je ve hře.

## Novinky 0.55
- Editor Mapové díly: každý díl mapy jde otevřít, upravit (zdi, okna, nábytek, rekvizity, světla, značky pro vetřelce) a uložit jako novou variantu, kterou pak mapy používají (`dilky/<druh>/*.json`).
- Budovy s rámy oken, parapety, zárubněmi a sokly; stodola, sklad, kasárna, polární chata a benzínka s novou výbavou; nový nábytek uvnitř domů a hospody.

## Novinky 0.54
- Vojáci se hýbou podle Mixama: chůze, běh a plížení do všech směrů, sprint, leh, plazení, raněný na zemi, šest smrtí, skok, šplhání, míření, přebíjení vleže, hrabání v batohu, panika. Ruce: přebíjení, hody, nůž, obušek, pažba, dveře, škubnutí při zásahu.
- Nové ovládání: lékárnička X, granát z opasku G, kouřový H, noční vidění N, mluví se podržením Tabu.
- Pohyby z Mixama (`animace/tp_body_*` a akce rukou) nejsou ve zdrojácích kvůli licenci Mixama, jsou jen v balíčku hry (`update/*.pck`). Kdo hru staví ze zdrojáků, má místo nich původní pohyby.

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
| G | hodit granát z opasku (výbušný nebo kouřový - ten, který tam máš) |
| H | kouřový granát |
| B / 7 | mina / světlice |
| F | svítilna |
| X | lékárnička (do ruky, znovu X ošetří) |
| N | noční vidění |
| E | ošetřit / táhnout padlého / sebrat; u lodi držet 2 s = odlet |
| I | výstroj (ruce, záda, opasek, batoh) |
| Tab (držet) | mluvit (mikrofon); s vysílačkou v ruce do vysílačky |
| M | mikrofon stále zapnutý / vypnout |
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
- Mikrofon: Tab (držet) = mluvíš, M = mikrofon stále zapnutý. Hlas jde z tvé postavy a slábne se vzdáleností (3D).
  V nastavení: při stisku / stále zapnutý (podle hlasitosti) / vypnutý.
- **Vysílačka** (na opasku, klávesa 4): drž ji v ruce a mluv (Tab, nebo tlačítko myši té ruky) - slyší tě
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
