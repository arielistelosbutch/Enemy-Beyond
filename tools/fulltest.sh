#!/bin/bash
# The big test before every release: every automatic check in a row, one summary at the end.
# Usage: tools/fulltest.sh [godot binary]   (Linux; screenshots need xvfb-run)
G=${1:-/root/godot/Godot_v4.7-stable_linux.x86_64}
cd "$(dirname "$0")/.."
LOG=/tmp/fulltest; mkdir -p $LOG; rm -f $LOG/*.log
pass=0; fail=0; report=""
run() {   # name, timeout, mode(h=headless,x=xvfb), expected pattern, args...
  local name=$1 to=$2 mode=$3 want=$4; shift 4
  if [ "$mode" = s ]; then      # (0.72) a test script on its own: the first arg is the script
    timeout $to $G --headless --path . -s "$@" > $LOG/$name.log 2>&1
  elif [ "$mode" = x ]; then
    timeout $to xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --resolution 1280x720 -- "$@" > $LOG/$name.log 2>&1
  else
    timeout $to $G --headless --path . -- "$@" > $LOG/$name.log 2>&1
  fi
  local errs=$(grep -c "SCRIPT ERROR" $LOG/$name.log)
  local ui=$(grep -E "\[UI\] .*: [1-9][0-9]* problém|přetéká" $LOG/$name.log | head -3)
  if [ "$errs" = 0 ] && [ -z "$ui" ] && grep -qE "$want" $LOG/$name.log; then
    pass=$((pass+1)); report+="OK    $name\n"
  else
    fail=$((fail+1)); report+="CHYBA $name (skript. chyb: $errs) $(echo $ui | cut -c1-120)\n"
  fi
}
run checkall    600 h "\[CHECK\] workshop.gd ok"           --autotest=checkall
run sound       200 h "RESULT soundcheck 0 chyb"           --autotest=soundcheck
run pass_base   200 h "passcheck .* 0 blocked"             --autotest=basepass
run pass_farm   200 h "passcheck .* 0 blocked"             --autotest=passcheck --mtype=terror --biome=farm
run pass_town   200 h "passcheck .* 0 blocked"             --autotest=passcheck --mtype=terror --biome=town
run pass_giant  300 h "passcheck .* 0 blocked"             --autotest=passcheck --mtype=landed --ufo=battleship --size=huge --biome=farm
run pass_wreck  300 h "passcheck .* 0 blocked"             --autotest=passcheck --mtype=crash --ufo=supply --size=huge --biome=farm
run air_giant   200 x "AIR-air\] end outcome"            --autotest=air --ufo=battleship
run airfx       200 x "RESULT airfx lead true hit_a true cracks [1-9] hit_b false .* crash true over true" --autotest=airfx
run escort_kit 200 h "RESULT escortkit escort gun laser heavy laser_cannon hawk true fired [1-9]" --autotest=escort --kit=1 --gun=laser --heavy=laser_cannon --hawks=1
for sd in 1 2 3; do
run pass_ind_$sd  200 h "passcheck .* 0 blocked"           --autotest=passcheck --mtype=sabotage --biome=industrial --seed=$sd
run pass_town_$sd 200 h "passcheck .* 0 blocked"           --autotest=passcheck --mtype=terror --biome=town --seed=$sd
run pass_farm_$sd 200 h "passcheck .* 0 blocked"           --autotest=passcheck --mtype=crash --biome=farm --seed=$sd
done
run pass_desert 200 h "passcheck .* 0 blocked"             --autotest=passcheck --mtype=terror --biome=town --terrain=desert --seed=1
run menu_ui     300 x "\[UI\] ready: 0"                    --autotest=ui
run mods_ui     200 x "\[MODS\] bought true"              --autotest=modsui
run talent_ui   200 x "\[TALENT\] skip true chain true rank true spent true eye true drone true" --autotest=talentui
run dice        60 s "RESULT dicetest ok"                tools/test/dicetest.gd
run caprank     90 s "RESULT caprank ok"                 tools/test/caprank.gd
run recovery    90 s "RESULT recoverytest ok"            tools/test/recoverytest.gd
# (2026-11-27, Ari: "hra ukazovala den, ale ve hře byla noc") glóbus = mise, předpověď při příletu, roční doby
run daynight   120 s "RESULT daynight ok"                tools/test/daynight.gd
run dn_night   200 h "RESULT daynight daynight phase noc .*brief ok globe ok weather 'jasno, svítí měsíc' nvgwx ok" --autotest=daynight --lat=30 --lon=31.2 --cday=0.92 --weather=clear
run dn_dusk    200 h "RESULT daynight daynight phase soumrak .*brief ok globe ok weather 'jasno, slunce" --autotest=daynight --lat=49.5 --lon=15.6 --cday=0.725 --weather=clear
run dn_day     200 h "RESULT daynight daynight phase den .*brief ok globe ok weather 'zataženo'" --autotest=daynight --lat=-33.9 --lon=18.4 --cday=0.45 --weather=overcast
run racelate    90 s "RESULT racelate ok"                tools/test/racelate.gd
run sickbay     60 s "RESULT sickbaytest ok"             tools/test/sickbaytest.gd
run debug       60 s "RESULT debugtest ok"               tools/test/debugtest.gd
run firemode    60 s "RESULT firemode ok"                tools/test/firemodetest.gd
run mtypes      60 s "RESULT missiontypes ok"            tools/test/missiontypes.gd
run alloy       60 s "RESULT alloytest ok"               tools/test/alloytest.gd
run stack       60 s "RESULT stacktest ok"               tools/test/stacktest.gd
run basesell    60 s "RESULT basesell ok"                tools/test/basesell.gd
run convoy      300 h "RESULT convoytest saved true banner true .* finished true" --autotest=convoytest --mtype=convoy --biome=forest --hold=90
run convoy_fail 300 h "Vetřelci rozbili náklad konvoje"  --autotest=convoytest --mtype=convoy --biome=farm --group=bijci --fail=1
run pilot       300 h "END\] success=true"               --autotest=objtest --mtype=pilot --biome=forest
run radar_st    300 h "OBJ radar on true"                 --autotest=objtest --mtype=radar --biome=base --size=large
run bug         200 h "RESULT bugtest tagged true gone false finished true" --autotest=bugtest --mtype=bug --biome=forest --ufo=raider --crewof=raider
run bug_fail    200 h "RESULT bugtest tagged false gone true finished true" --autotest=bugtest --mtype=bug --biome=forest --ufo=raider --crewof=raider --fail=1
run quarantine  300 h "RESULT quartest carriers [2-9] tell true/false hatched [1-9] saved true nest 0 finished true" --autotest=quartest --mtype=quarantine --biome=town --size=large
run presets     200 x "\[PRESET\] first false list true merc true levels true dice_nolevels true gear true" --autotest=presets
# 2026-11-27 Komando Štír: hotová parta v šablonách + přezdívky v generátoru jmen (snímky parta_*.png)
run squadshot   300 x "RESULT squadshot 7 clenu, prezdivek [0-9]+/400, 0 chyb" --autotest=squadshot --day=1 --mtype=crash --biome=farm --seed=3
run sights     1000 x "scope mode=scope on=true"          --autotest=sightshot --day=1 --fast=1
run scopelens  300 x "RESULT scopelens bad 0"            --autotest=scopelens --day=1 --seed=3
run menu_flick  200 x "RESULT menuflicker 0"               --autotest=menuflicker
run geo_ui      300 x "\[UI\] geo_ency_grey: 0"            --autotest=uigeo
run geo_events  150 x "RESULT geoevents shown true rows 3 stopped true back true slow true full 8 viewer 1 bar true" --autotest=geoevents
run geo_models  120 x "RESULT geomodels ships 5 crafts 3 models 8"   --autotest=geomodels
run base_pick   120 x "RESULT basepick picking true frozen true bloc na place Texas credits 1200->1500 near [1-9][0-9]/40 running true"   --autotest=basepick
run mission_ui  250 x "\[UI\] m_result: 0"                 --autotest=uimission
run solo        250 h "RESULT"                             --autotest=solo
run campaign    300 h "back on globe"                             --autotest=campaign
run drone       420 x "first fall: downed false" --autotest=dronetest
run drone_real  300 h "t16 downed false" --autotest=dronereal --race=grey
run voice       200 h "RESULT voice: snippets \[1\]"       --autotest=voice
run voicedsp    120 h "RESULT voicedsp ok"                 --autotest=voicedsp
run basewalk    400 x "RESULT basewalk 16"                 --autotest=basewalk
run base_attack 400 x "RESULT basewalk 16"                 --autotest=basewalk --attack=1
run base_fly    300 h "RESULT basefly top [0-9.]+ above 0 inside 0 .* unreachable 0" --autotest=basefly --attack=1 --crew=levit,levit,levit_velitel,grey
run gameover    150 x "RESULT gameover shown true had_save true save_gone true closed true archived [1-9][0-9]* ufo 1 races 6 fallen 15 why base bad 0" --autotest=gameover
run base_def    120 h "RESULT basedef raids [1-2] first ([7-9][0-9]|1[0-9][0-9])\.[0-9] won_lost false fail_lost true konec true ignored true ignored_lost true" --autotest=basedef
run alienbase   400 x "RESULT coreglance true"            --autotest=abase --mtype=alienbase
run fire        450 x "RESULT fireshot"                    --autotest=fireshot
run doors       300 x "RESULT doorshot"                    --autotest=doorshot --biome=farm
run blastdoor   300 h "RESULT blastdoor OK"                --autotest=blastdoor
run navcache    200 h "RESULT navcache same true"         --autotest=navcache --mtype=landed --ufo=battleship --seed=2
run perf        200 h "RESULT perf frames"                --autotest=perf --mtype=landed --ufo=battleship --seed=2 --dur=25 --kill=1
run gunlag      400 h "RESULT gunlag minigun zaznam true .* navic -?[0-4]\.[0-9] ms" --autotest=gunlag --biome=town --seed=3 --gun=minigun --crew=grey,grey,grey,jestetan,jestetan,lihnoun,lihnoun,bijec,levit,ohar
run deadcost    200 h "RESULT deadcost alive [0-9.]+ ms/krok .* dead 0\.0[0-2][0-9] ms/krok" --autotest=deadcost --perflog=1 --mtype=crash --biome=farm --seed=3 --crew=bijec,bijec,bijec,grey,grey,jestetan
run roofwalk    300 h "RESULT gunlag minigun zaznam true klid [0-9]\.[0-9] ms .* strelba [0-9]\.[0-9] ms \(99 % ([0-9]|[1-3][0-9]),"  --autotest=gunlag --mtype=terror --biome=town --seed=3 --gun=minigun --roof=2 --walk=1 --crew=grey
# (2026-11-27, Ari: lagy při velkém požáru) 24 ohňů + granát každých 1,5 s; stín jen u 2 nejbližších ohňů
run firelag     300 h "RESULT firelag firelag klid [0-9.]+ ms pozar [0-9]\.[0-9] ms .* ohnu 2[0-4] stin [0-9]+ stin_ohnu [0-2] " --autotest=firelag --mtype=terror --biome=town --seed=3 --perflog=1
run farview     300 x "RESULT farview"                   --autotest=farview --mtype=terror --biome=town --seed=3
run loadprog  300 x "RESULT loadprog parked true same true signals true back_ms [0-9]+ loading_on_back false bar 1.00 .* dropped true" --autotest=loadprog
run cart      120 h "RESULT carttest paid \\[true, true, 2, 1, 3, 0\\] kept \\[true, true, true, 51\\]" --autotest=carttest
# co-op: two games at once (host and client on this machine)
pair() {   # name, host mode, client mode, expected in host log, expected in client log, port
  local name=$1
  local pto=120; [ "$name" = coop_fire ] && pto=240
  timeout $pto $G --headless --path . -- --autotest=$2 --port=$6 > $LOG/${name}_host.log 2>&1 &
  local hp=$!
  sleep 1
  timeout $pto $G --headless --path . -- --autotest=$3 --port=$6 > $LOG/${name}_client.log 2>&1
  wait $hp
  local errs=$(cat $LOG/${name}_host.log $LOG/${name}_client.log | grep -c "SCRIPT ERROR")
  if [ "$errs" = 0 ] && grep -qE "$4" $LOG/${name}_host.log && grep -qE "$5" $LOG/${name}_client.log; then
    pass=$((pass+1)); report+="OK    $name\n"
  else
    fail=$((fail+1)); report+="CHYBA $name (skript. chyb: $errs)\n"
  fi
}
pair coop_mission host client          "players=2"                "blk=false vet=false players=2"  7901
pair coop_fire  firehost fireclient     "RESULT firelag firehost .* stin_ohnu [0-2] " "RESULT firelag fireclient klid [0-9.]+ ms pozar [0-9]+\.[0-9] ms .* ohnu 2[0-4] stin [0-9]+ stin_ohnu [0-2] " 7995
pair coop_radar nmradarhost nmradarclient "RESULT nm nmradarhost radar true" "RESULT nm nmradarclient radar true lit [1-9]" 7961
pair coop_bug   nmbughost nmbugclient   "RESULT nm nmbughost radar false bug true gone true" "RESULT nm nmbugclient radar false lit 0 bug true gone true banner true" 7962
pair coop_pot     pothost potclient     "RESULT potpaid pothost paid 315 money \\+315" "RESULT potpaid potclient paid 315 money \\+315" 7936
pair coop_heal    coophealhost coophealclient "RESULT coopheal host ok" "client t=10 hp [0-9.]+ bleeding 0.00"  7902
pair safe_out   safeouthost safeoutclient "RESULT safeout host out true players 1 shots 0" "RESULT safeout client finished true hp ([0-9.]+) -> \\1" 7935
pair coop_evac  coopevachost coopevacclient "reinf cleared: hidden true back true" "client back in the menu, online" 7937
# (0.7x, Ari) a failed mission, both fly home with all their kit: nothing of it may be lost
FAILARGS="--fail=1 --reinf=0"
timeout 120 $G --headless --path . -- --autotest=coopevachost --port=7983 $FAILARGS > $LOG/coop_failkit_host.log 2>&1 &
fkp=$!; sleep 1
timeout 120 $G --headless --path . -- --autotest=coopevacclient --port=7983 $FAILARGS > $LOG/coop_failkit_client.log 2>&1
wait $fkp
if [ "$(cat $LOG/coop_failkit_*.log | grep -c 'SCRIPT ERROR')" = 0 ] && grep -qE "fail kit players 2 items [1-9][0-9]* lost 0" $LOG/coop_failkit_host.log && grep -q "client back in the menu, online" $LOG/coop_failkit_client.log; then
  pass=$((pass+1)); report+="OK    coop_failkit\n"
else
  fail=$((fail+1)); report+="CHYBA coop_failkit\n"
fi
# 0.72.6 alien grenades stick where they land and blow 1.2 s later, same spot on host and client
run alnade 200 h "RESULT alnade alnadetest throws 4 roll 0.00 delay 1.2" --autotest=alnadetest --mtype=crash --biome=farm --crew=bijec,jestetan --seed=5 --throws=4
ANARGS="--mtype=crash --biome=farm --crew=bijec,jestetan --seed=5 --throws=4"
timeout 150 $G --headless --path . -- --autotest=alnadehost --port=7991 $ANARGS > $LOG/coop_alnade_host.log 2>&1 &
anp=$!; sleep 1
timeout 150 $G --headless --path . -- --autotest=alnadeclient --port=7991 $ANARGS > $LOG/coop_alnade_client.log 2>&1
wait $anp
if [ "$(cat $LOG/coop_alnade_*.log | grep -c 'SCRIPT ERROR')" = 0 ] && grep -qE "RESULT alnade alnadehost throws 4 roll 0.00" $LOG/coop_alnade_host.log && grep -qE "RESULT alnade alnadeclient throws 4 roll 0.00 delay 1.2[0-9]-1.2[0-9] drift 0.0" $LOG/coop_alnade_client.log; then
  pass=$((pass+1)); report+="OK    coop_alnade\n"
else
  fail=$((fail+1)); report+="CHYBA coop_alnade\n"
fi
# 2026-11-27 stromy a auta: auto hoří a vybuchne (a zasáhne vedlejší), laser zapálí strom, kanón ho porazí, granát taky
run wreck_town 200 h "RESULT wrecktest trees [0-9]+ cars [0-9]+ car_smoke true car_burn true car_boom true wreck true chain [1-9][0-9]* tree_burn true tree_fall true lying true stump true" --autotest=wrecktest --mtype=terror --biome=town --seed=3 --day=1
run wreck_farm 200 h "RESULT wrecktest .* tree_burn true tree_fall true lying true stump true blast_fall true" --autotest=wrecktest --mtype=crash --biome=farm --seed=3 --day=1
run wreck_stress 200 h "RESULT wreckstress lit 8 cars 6 gone 6" --autotest=wrecktest --stress=1 --mtype=terror --biome=town --seed=3 --day=1
WRARGS="--mtype=terror --biome=town --seed=3 --day=1"
timeout 200 $G --headless --path . -- --autotest=wreckhost --port=7998 $WRARGS > $LOG/coop_wreck_host.log 2>&1 &
wrp=$!; sleep 1
timeout 200 $G --headless --path . -- --autotest=wreckclient --port=7998 $WRARGS > $LOG/coop_wreck_client.log 2>&1
wait $wrp
wh=$(grep -oE "states .* hash -?[0-9]+" $LOG/coop_wreck_host.log); wc=$(grep -oE "states .* hash -?[0-9]+" $LOG/coop_wreck_client.log)
if [ "$(cat $LOG/coop_wreck_*.log | grep -c 'SCRIPT ERROR')" = 0 ] && [ -n "$wh" ] && [ "$wh" = "$wc" ] && grep -q "lying true" $LOG/coop_wreck_client.log; then
  pass=$((pass+1)); report+="OK    coop_wreck\n"
else
  fail=$((fail+1)); report+="CHYBA coop_wreck\n"
fi
# 2026-11-27 the last alien does not hide for ever: it runs for a ship (beam) or, a beast, comes out to hunt
run last_crash  300 h "RESULT last lasttest mode done ship 1 escaped 1 done true" --autotest=lasttest --mtype=crash --biome=farm --crew=grey,grey,grey,grey --seed=3 --lastquiet=3
run last_terror 300 h "RESULT last lasttest mode done ship 1 escaped 1 done true reach false sky true" --autotest=lasttest --mtype=terror --biome=town --crew=grey,grey,grey,grey,grey --seed=3 --lastquiet=3
run last_shot   300 h "RESULT last lasttest mode done ship 1 escaped 0 done true" --autotest=lasttest --mtype=crash --biome=farm --crew=grey,grey,grey,grey --seed=3 --lastquiet=3 --shoot=1
run last_beast  300 h "RESULT last lasttest mode hunt ship 0 escaped 0 done false reach true" --autotest=lasttest --mtype=crash --biome=farm --crew=lihnoun,lihnoun,grey,grey --race=lihnoun --seed=3 --lastquiet=3
LSARGS="--mtype=crash --biome=farm --crew=grey,grey,grey,grey --seed=3 --lastquiet=3"
timeout 200 $G --headless --path . -- --autotest=lasthost --port=7995 $LSARGS > $LOG/coop_last_host.log 2>&1 &
lsp=$!; sleep 1
timeout 200 $G --headless --path . -- --autotest=lastclient --port=7995 $LSARGS > $LOG/coop_last_client.log 2>&1
wait $lsp
if [ "$(cat $LOG/coop_last_*.log | grep -c 'SCRIPT ERROR')" = 0 ] && grep -qE "RESULT last lasthost mode done ship 1 escaped 1 done true" $LOG/coop_last_host.log && grep -qE "RESULT last lastclient mode - ship 1 escaped 1 done true" $LOG/coop_last_client.log; then
  pass=$((pass+1)); report+="OK    coop_last\n"
else
  fail=$((fail+1)); report+="CHYBA coop_last\n"
fi
pair coop_base    lbhost lbclient       "start_mission"            "RESULT lb lbclient players 2" 7903
pair host_base    hbhost hbclient       "RESULT hb drop hbhost players 2" "RESULT hbclient globe true day \\+0\\.0[1-9]" 7951
pair coop_wipe    coopwipehost coopwipeclient "globe ready"     "END\\] leave"                  7904
pair coop_gameover gohost goclient "RESULT gohost shown true save_gone true online true" "RESULT goclient shown true kills 77 races 1 closed true" 7953
pair coop_ready readyhost readyclient "RESULT readyhost early false window true ran true" "RESULT readyclient saw 'Výsadek: test' panel '.*' me true done true" 7938
pair coop_cart  econhost econclient  "ECON-HOST\\] credits=1200" "RESULT cart client my=90 clips \\+2 grenades on order 1" 7952
pair coop_stock stockhost stockclient "RESULT stockhost claim true mine 0 names 'Klient 1' back 1" "RESULT stockclient grenades 4 -> 9 fast true redrawn true" 7953
pair coop_sick  sickhost sickclient   "RESULT sickhost bravo true locker 2 record 2" "RESULT sickclient alfa 2 sick 1 bravo 2 alfa_left 0 stash [56] -> [56]" 7971
pair geo_live geolivehost geoliveclient "globe ready \(viewer false\)" "RESULT geolive day \+0\.0[1-9][0-9]* craft moved [1-9]" 7912
pair ai_coop    aimphost aimpclient "RESULT aimp old 0 players 2 hide [1-9]" "AIMP aimpclient" 7913
# co-op with four mercenaries: a host and three clients (0.63: the squads know about all of them)
quad() {   # name, expected in host log, port
  local name=$1
  timeout 150 $G --headless --path . -- --autotest=aimphost --players=4 --port=$3 > $LOG/${name}_host.log 2>&1 &
  local hp=$!
  sleep 1
  for ci in 1 2 3; do
    timeout 150 $G --headless --path . -- --autotest=aimpclient --players=4 --ci=$ci --port=$3 > $LOG/${name}_c$ci.log 2>&1 &
  done
  wait
  local errs=$(cat $LOG/${name}_*.log | grep -c "SCRIPT ERROR")
  if [ "$errs" = 0 ] && grep -qE "$2" $LOG/${name}_host.log; then
    pass=$((pass+1)); report+="OK    $name\n"
  else
    fail=$((fail+1)); report+="CHYBA $name (skript. chyb: $errs)\n"
  fi
}
# (0.72.x) a friend who joins while the team is out is not in the mission (ramp opens for two);
# one who never finishes loading is left out after --loadwait s and put down when he does load
late_join() {
  local name=late_join
  timeout 120 $G --headless --path . -- --autotest=latehost --prep=1 --port=7996 > $LOG/${name}_host.log 2>&1 &
  sleep 1
  timeout 120 $G --headless --path . -- --autotest=latemate --prep=1 --port=7996 > $LOG/${name}_mate.log 2>&1 &
  timeout 120 $G --headless --path . -- --autotest=latecomer --port=7996 > $LOG/${name}_late.log 2>&1
  wait
  local errs=$(cat $LOG/${name}_*.log | grep -c "SCRIPT ERROR")
  if [ "$errs" = 0 ] && grep -qE "RESULT latehost t12 roster 2 lobby 3 ramp true players 2 solo false" $LOG/${name}_host.log \
      && grep -qE "RESULT latecomer scene Main roster 3 told true" $LOG/${name}_late.log; then
    pass=$((pass+1)); report+="OK    $name\n"
  else
    fail=$((fail+1)); report+="CHYBA $name (skript. chyb: $errs)\n"
  fi
}
late_join
slow_load() {
  local name=slow_load
  timeout 120 $G --headless --path . -- --autotest=slowhost --prep=1 --loadwait=6 --port=7997 > $LOG/${name}_host.log 2>&1 &
  sleep 1
  timeout 120 $G --headless --path . -- --autotest=slowmate --prep=1 --readydelay=20 --port=7997 > $LOG/${name}_client.log 2>&1
  wait
  local errs=$(cat $LOG/${name}_*.log | grep -c "SCRIPT ERROR")
  if [ "$errs" = 0 ] && grep -qE "RESULT slowhost t9 roster 1 players 1" $LOG/${name}_host.log \
      && grep -qE "RESULT slowhost end roster 2 lobby 2 ramp true players 2" $LOG/${name}_host.log; then
    pass=$((pass+1)); report+="OK    $name\n"
  else
    fail=$((fail+1)); report+="CHYBA $name (skript. chyb: $errs)\n"
  fi
}
slow_load
quad ai_coop4 "RESULT aimp old 0 players 4 hide [1-9]" 7915
# (2026-11-27, trhání v co-opu) hostitel + klient: střelba, posily z lodi, výbuch - záznamník výkonu u obou
CPARGS="--players=2 --perflog=1 --mtype=crash --biome=farm --seed=3 --crew=grey,grey,grey,jestetan,jestetan,lihnoun,bijec,levit"
timeout 200 $G --headless --path . -- --autotest=cperfhost --port=7992 $CPARGS > $LOG/coop_perf_host.log 2>&1 &
cpp=$!; sleep 1
timeout 200 $G --headless --path . -- --autotest=cperfclient --ci=1 --port=7992 $CPARGS > $LOG/coop_perf_client.log 2>&1
wait $cpp
if [ "$(cat $LOG/coop_perf_*.log | grep -c 'SCRIPT ERROR')" = 0 ] && grep -qE "RESULT cperf cperfhost frames [0-9]{3,}" $LOG/coop_perf_host.log && grep -qE "RESULT cperf cperfclient frames [0-9]{3,}" $LOG/coop_perf_client.log; then
  pass=$((pass+1)); report+="OK    coop_perf\n"
else
  fail=$((fail+1)); report+="CHYBA coop_perf\n"
fi
pair lobby_kick kickhost kickclient "RESULT kick summary rows 2 ping [0-9]+ mic open after 1 rejoined false" "RESULT kick client .*vyhodil.*za 5 min" 7914
pair coop_escort_kit escorthost escortclient "RESULT escortkit escorthost gun laser heavy plasma_cannon hawk true fired [1-9]" "RESULT escortkit escortclient gun laser heavy plasma_cannon hawk false fired [1-9]" 7974
pair coop_air_sfx airhost airclient "RESULT airsfx airhost shots [1-9][0-9]* missiles [1-9]" "RESULT airsfx airclient shots [1-9][0-9]* missiles [1-9]" 7973
# (2026-11-27) co-op: the client lights the mission exactly like the host (a dusk in Vysočina)
timeout 120 $G --headless --path . -- --autotest=dnhost --port=7996 --lat=49.5 --lon=15.6 --cday=0.725 --weather=clear > $LOG/daynight_coop_host.log 2>&1 &
dnp=$!; sleep 1
timeout 120 $G --headless --path . -- --autotest=dnclient --port=7996 > $LOG/daynight_coop_client.log 2>&1
wait $dnp
dnh=$(grep -oE "phase [a-z]+ sun [-0-9.]+ moon [0-9.]+ amb [0-9.]+ brief ok globe ok" $LOG/daynight_coop_host.log)
dnc=$(grep -oE "phase [a-z]+ sun [-0-9.]+ moon [0-9.]+ amb [0-9.]+ brief ok globe ok" $LOG/daynight_coop_client.log)
if [ -n "$dnh" ] && [ "$dnh" = "$dnc" ] && [ "$(cat $LOG/daynight_coop_*.log | grep -c 'SCRIPT ERROR')" = 0 ]; then
  pass=$((pass+1)); report+="OK    daynight_coop\n"
else
  fail=$((fail+1)); report+="CHYBA daynight_coop ($dnh | $dnc)\n"
fi
pair ufo_hull hullhost hullclient "RESULT ufohull raider rays [0-9]+ leak 0\.[0-4] % hug_inside 0 seen 0" "RESULT ufohull raider rays [0-9]+ leak 0\.[0-4] % hug_inside 0 seen 0" 7917
pair coop_leak leakhost leakclient "RESULT leakhost .* stone_leak 0\.[0-4] %" "RESULT leakclient .* stone_leak 0\.[0-4] %" 7958
pair coop_flare flarehost flareclient "RESULT coopflare flarehost seen (59|6[0-9]) pos \\(-?[0-9.]+, [0-9]" "RESULT coopflare flareclient seen (59|6[0-9]) pos \\(-?[0-9.]+, [0-9]" 7918
pair coop_quiet quiethost quietclient "RESULT quietcoop host listener true quiet_sound true quiet_heard false loud_heard true" "RESULT quietcoop client quiet_shots 1" 7982
pair coop_sentry sentryhost sentryclient "RESULT coopsentry sentryhost seen true ammo 33 folded true back false" "RESULT coopsentry sentryclient seen true ammo 33 folded true back true" 7972
pair voice_net vnethost vnetclient "RESULT vnet received 43 lost [0-9]+ dry 0" "RESULT vnet client sent 43" 7916
# (0.61) a client with an other version of the game is not let in, both are told why
timeout 60 $G --headless --path . -- --autotest=host --port=7915 > $LOG/version_host.log 2>&1 &
vh=$!; sleep 1
timeout 30 $G --headless --path . -- --autotest=client --port=7915 --fakever=0.01 > $LOG/version_client.log 2>&1
kill $vh 2>/dev/null; wait $vh 2>/dev/null
if grep -q "refused version 0.01" $LOG/version_host.log && grep -q "version refused: Hostitel má jinou verzi" $LOG/version_client.log && ! grep -q "players=2" $LOG/version_host.log; then
  pass=$((pass+1)); report+="OK    version_check\n"
else
  fail=$((fail+1)); report+="CHYBA version_check\n"
fi
run airdeath    150 h "RESULT airdeath ok"                 --autotest=airdeath --group=levite
run vipcheck    200 h "RESULT vipcheck [0-9]+ spots, 0 bad" --autotest=vipcheck --mtype=rescue
run climb       200 x "RESULT climb ok"                    --autotest=climb --mtype=terror --biome=farm
run ground     250 h "RESULT groundtest [0-9]+ raised, 0 bare, .*sunk [01] \(0\.0 .*kerbs alien [6-8]/8 merc [6-8]/8" --autotest=groundtest --day=1 --nomerge=all --dur=20 --seed=5
run kerb       250 h "RESULT kerbtest merc 54/54 stall 0 " --autotest=kerbtest --mtype=terror --biome=town --seed=3 --day=1 --nomerge=all
run rocks       250 x "RESULT rocktest [0-9]+ stones, 0 hollow, 0 nav inside, walked 12, 0 bad" --autotest=rocktest --mtype=crash --biome=mountain --seed=7 --day=1
run hitbox      200 h "RESULT hitbox [0-9]+ props, [0-9]+ rays, phantom [0-4]\.[0-9] %" --autotest=hitbox --mtype=crash --biome=farm --seed=7
run leak_mtn  250 x "RESULT leaktest mountain .* stone_leak 0\.[0-4] %" --autotest=leaktest --mtype=crash --biome=mountain --seed=7 --day=1
run leak_abase 300 x "RESULT leaktest alienbase .* stone_leak 0\.[0-4] %" --autotest=leaktest --mtype=alienbase --biome=alienbase --seed=7 --day=1
run leak_mars 200 x "RESULT leaktest mars .* stone_leak 0\.[0-4] %" --autotest=leaktest --mtype=mars --biome=mars --seed=7 --day=1
run leakmap_town 300 x "RESULT leakmap terror town .* hard [0-9]{1,2} nav_miss [0-2]\." --autotest=leakmap --mtype=terror --biome=town --seed=7 --day=1 --nomerge=all
run leakmap_ind  300 x "RESULT leakmap terror industrial .* hard [0-9]{1,2} nav_miss [0-2]\." --autotest=leakmap --mtype=terror --biome=industrial --seed=7 --day=1 --nomerge=all
run leakmap_base 300 x "RESULT leakmap landed base .* hard [0-9]{1,2} nav_miss [0-2]\." --autotest=leakmap --mtype=landed --biome=base --seed=7 --day=1 --nomerge=all
run leakmap_mars 300 x "RESULT leakmap mars mars .* hard [0-9]{1,2} nav_miss [0-2]\." --autotest=leakmap --mtype=mars --biome=mars --seed=7 --day=1 --nomerge=all
# (0.69 oprava) plášť UFO zastaví střely i pohled (Ari: stříleli nás skrz obrys lodě)
for u in scout raider harvester; do
run ufohull_$u 150 h "RESULT ufohull $u rays [0-9]+ leak 0\.[0-4] % hug_inside 0 seen 0" --autotest=ufohull --mtype=crash --ufo=$u --biome=farm --day=1
done
for u in battleship supply; do
run ufohull_$u 300 h "RESULT ufohull $u rays [0-9]+ leak 0\.[0-4] % hug_inside 0 seen 0" --autotest=ufohull --mtype=landed --ufo=$u --size=huge --biome=farm --day=1
done
# (0.72.6 oprava) do každé lodi se dá vejít dveřmi (Ari: u sestřelené bitevní lodi nebyl vchod)
for u in scout raider harvester battleship supply; do
run ufoentry_$u 300 h "RESULT ufoentry $u nav [0-9.]+ walk [0-9.]+ inside true" --autotest=ufoentry --mtype=crash --ufo=$u --biome=farm --day=1
done
run wedge      150 x "RESULT wedgetest ok"                --autotest=wedgetest --mtype=crash --biome=farm --seed=7 --day=1
run ceiling   200 h "RESULT ceiltest [0-9]+ spots, [0-9]+ tries, leaks 0, unstuck 0, jumps [0-9]+ bad 0" --autotest=ceiltest --mtype=terror --biome=farm --seed=7 --day=1
for bm in town farm mountain industrial base; do
run interiors_$bm 200 h "RESULT interiors [0-9]+ houses, pockets 0, stairs_bad 0" --autotest=interiors --mtype=terror --biome=$bm --seed=3
done
# (2026-11-27) the desert town: flat roofs, so the whole ground floor is sampled
run interiors_desert 200 h "RESULT interiors [0-9]+ houses, pockets 0, stairs_bad 0" --autotest=interiors --mtype=terror --biome=town --terrain=desert --seed=3
run interiors_dry 200 h "RESULT interiors [0-9]+ houses, pockets 0, stairs_bad 0" --autotest=interiors --mtype=terror --biome=farm --terrain=dry --seed=3
for bm in farm town; do
run yard_$bm 150 h "RESULT yardtest moved [0-9]+, indoors 0," --autotest=yardtest --mtype=quarantine --biome=$bm --seed=3
done
run spectate  200 x "RESULT spectate active true eyes true next true auto true running true noaim true" --autotest=spectate --mtype=terror --biome=farm --seed=3 --day=1
run daze      150 h "RESULT dazetest home false frozen ([0-3]?[0-9]) % .* cooldown true wall true" --autotest=dazetest --crew=ohar,grey --mtype=crash --biome=farm --seed=3
run quiet     240 h "RESULT quiettest guns [1-9][0-9]* bad 0 knife true steps true" --autotest=quiettest --crew=grey,grey,grey,grey,grey,grey,grey,grey --mtype=crash --biome=farm --seed=3
run sabre     120 h "RESULT sabretest shield true near true far true swing true clip true" --autotest=sabretest --crew=jestetan,grey --mtype=crash --biome=farm --seed=3
run scan    200 h "RESULT scantest base true upgraded true belt true" --autotest=scantest --mtype=terror --biome=town --seed=3 --day=1
run debugkeys 200 h "RESULT debugkeys ok" --autotest=debugkeys --mtype=crash --biome=farm --seed=3 --day=1
run daze_base 150 h "RESULT dazetest home true frozen ([0-2]?[0-9]) % .* cooldown true wall true" --autotest=dazebase --attack=1 --crew=ohar,grey
run chain     200 h "RESULT chaintest solo true longest [0-4]\.[0-9] s frozen ([0-2]?[0-9]) % .* ko_again false blind 1\.00/1\.00/0\.00" --autotest=chaintest --crew=grey --mtype=crash --biome=farm --seed=3
run chain_base 200 h "RESULT chaintest solo true longest [0-4]\.[0-9] s frozen ([0-2]?[0-9]) % .* ko_again false blind 1\.00/1\.00/0\.00" --autotest=chainbase --attack=1 --crew=grey
run lean       200 x "RESULT leantest ok"                 --autotest=leantest --mtype=crash --biome=farm --seed=7 --day=1
run ws_click    100 x "RESULT wsclick bone true ring true item true" --autotest=wsclick
run agun        150 x "RESULT agun ([0-9]+) of \1"        --autotest=agun
run modelcheck  120 h "RESULT modelcheck [0-9]+ problems"  --autotest=modelcheck
run anim_edit   100 x "RESULT animtest mid true fp true"  --autotest=animtest
run mod_click   100 x "RESULT modclick sel '(Rifle:[0-9]+)' \(want '\1'\)"   --autotest=modclick
run mod_speed   300 x "RESULT modspeed ok" --autotest=modspeed
run animator   150 x "RESULT animator click true imported true turned true keyed true moved true follows true fp true" --autotest=animator
run locktest   120 h "RESULT locktest follows true turned true body true root true fp true" --autotest=locktest
run blendtest  150 x "RESULT blendtest off [0-9.]+ on [0-9.]+ smoother true" --autotest=blendtest
run shoulder   200 h "RESULT shouldershot mean 0\.0[0-9]"  --autotest=shouldershot --mtype=crash --biome=farm --seed=3 --day=1 --snaps=0
run talenttest 250 h "RESULT talenttest .* ok true"     --autotest=talenttest
# 0.62 animations: hit reactions, turning on the spot, the Ohař's moods (afk models: only in the game package)
# (deadclips none: no clip of the model names another skeleton - the Bijec ran in a T-pose, 2026-11-26)
for r in ohar jestetan zombie bijec bijec_velitel; do
run afk_$r      300 h "RESULT afkalien $r .* hitplay hit[a-z_0-9]* turnplay turn.* deadclips none" --autotest=afkalien --race=$r --mtype=landed
done
run civanim     150 h "RESULT civanim [0-9]+ civilians afk idle,walk,run,lurk cower lurk" --autotest=civanim --mtype=terror
run civdeath    150 h "RESULT civdeath 10 deaths bad 0" --autotest=civdeath --mtype=terror
# 0.66 Facelift I: the drone's radar in solo, the transport after a mission, the people of the base, the loading screen
run flare       200 h "RESULT flaretest life (59|6[0-9]) lit true moved 0.00" --autotest=flaretest --mtype=crash --biome=farm
run claymore    200 h "RESULT claytest placed 1 faces true levit_over true fired true walker_hit true levit_in_wedge [1-9][0-9]* behind_6m 0" --autotest=claytest --mtype=crash --biome=farm --crew=grey,grey,levit --seed=3
run sentry      200 h "RESULT sentrytest kind rifle placed 1 faces true still_shots 0 shots [1-9][0-9]* dealt [1-9][0-9]* kills 1 behind 0 friendly 0 topped 20 folded true kept true left [0-9]* wrecked true" --autotest=sentrytest --mtype=crash --biome=farm --crew=grey,grey --seed=3
run sentry_pl   200 h "RESULT sentrytest kind plasma placed 1 faces true still_shots 0 shots [1-9][0-9]* dealt [1-9][0-9]* kills 1 behind 0 friendly 0 topped 20 folded true kept true left [0-9]* wrecked true" --autotest=sentrytest --mtype=crash --biome=farm --crew=grey,grey --seed=3 --tier=plasma
run frag        200 h "RESULT fragtest wood [5-8]/8 bare [0-8]/8 hurt6m [1-9]" --autotest=fragtest --mtype=crash --biome=farm --crew=grey,grey
run radar       150 h "RESULT radar solo true scanner true kit_scanner false kit_radio false" --autotest=radartest --mtype=crash --biome=farm --day=1
run rampcheck   200 h "RESULT rampcheck shut true open true" --autotest=rampcheck --prep=1
run transport   150 h "RESULT transport closed true"     --autotest=transport --mtype=crash --biome=farm --day=1
run task_crash  150 x "RESULT tasktest open true task true fits 0 done true esc true again true hud true keys true" --autotest=tasktest --mtype=crash --biome=farm --day=1
run task_rescue 150 x "RESULT tasktest open true task true fits 0 done true esc true again true hud true keys true" --autotest=tasktest --mtype=rescue --biome=town --day=1
run uifit       150 x "RESULT uifit bad 0"               --autotest=uifit --mtype=crash --biome=farm --day=1
run npcbase     150 h "RESULT npc moved [1-9]"           --autotest=npcshot --shots=0 --wait=25
run baseshot    150 x "RESULT baseshot builders 3 inside 0" --autotest=baseshot
# 0.70 Facelift II: the echo of the place (a reverb on the sounds the game has), dirt and blood, the wall of the fallen, the intro
run echo_farm   150 h "RESULT echo kinds room,metal,[a-z]*,room open true bus Room" --autotest=echotest --mtype=landed --biome=farm --day=1
run echo_base   150 h "RESULT echo kinds metal,metal,metal open false bus Room" --autotest=echobase
run dirt        200 x "RESULT dirt blood [1-8] copy [1-9][0-9]* same true" --autotest=dirtshot --mtype=crash --biome=farm --day=1
run wall        150 x "RESULT wall title 1 shown 9"      --autotest=wallshot --fallen=9
run intro       200 x "RESULT intro sets (space|farm|velin),(space|farm|velin),(space|farm|velin) skipped true gone true" --autotest=introshots
run vrstrike    150 h "RESULT vrstrike vr true" --autotest=vrstrike
run beltthrow  120 h "RESULT beltthrow started true belt_used true pack_kept true" --autotest=beltthrow
run mocapgame  200 h "RESULT mocapgame 19 of 19" --autotest=mocapgame
run tileround  300 h "RESULT tileround ok 38 bad 0" --autotest=tileround
run tileeditor 150 x "RESULT tileeditor parts [0-9]+ click true moved true turned true stretched true follows true model true mirror true delete true undo true saved true picked true built true" --autotest=tileeditor
run leaveany    150 h "RESULT leaveany early_block true done true finished true" --autotest=leaveany
run reinf_early 90 h "success=true why=Úkol splněn, ale tým odletěl před posilami" --autotest=coopevachost --port=7939 --players=1 --reinf=early
run safeend     150 h "RESULT safeend finished true hp ([0-9.]+) -> \\1 shots 0 stress_rise 20.1" --autotest=safeend
run recovery_mission 150 h "RESULT recoverymission ufo true crew [1-9][0-9]* near true kits 2 left 0 carried 2 done true brought 2 dead_brings 0" --autotest=recoverymission --oftype=crash
run failkit     90 h "RESULT failkit aboard true walk_safe true walk_field true same_as_won true left_behind true fell_won true" --autotest=failkit
run suit        100 h "RESULT suittest down true"        --autotest=suittest --group=sedaci --mtype=crash
run levgrab     100 h "RESULT levgrab ko true carried true" --autotest=levgrab --group=levite --mtype=crash
run mirotest   150 h "RESULT mirotest frenzy true .* mending true .* healed true" --autotest=mirotest --group=levite --mtype=landed
run bijtest    150 h "RESULT bijtest broken true flinch false taken 7.5 -> 9.0 alive true" --autotest=bijtest --group=bijci --mtype=landed
run weaktest   200 h "RESULT weaktest grey true/true \| suit true \| mast true/true \| antenna true \| kolos true/true/true \| legs true 0.6 eye 2 \| ohar deaf true winded true belly true \| jest blind true fire 9.0 bullet 6.0 \| lih back true front true \| bijec laser 8.75 bullet 7.50 \| mys free true cd true \\| mines 2->1" --autotest=weaktest --mtype=landed
run sgtest     150 h "RESULT sgtest full 7 7 tube slugs,beanbag,beanbag bean dmg 3 stun true slug dmg true loaded 4" --autotest=sgtest --mtype=landed --seed=1
run kanontest  150 h "RESULT kanontest hit true burn true cycle true mag 5" --autotest=kanontest --mtype=landed --seed=1
run mgheat     150 h "RESULT mgheat shots 11[0-9] hot true cooled true mag 300" --autotest=mgheat --mtype=landed
run seedtest   200 h "RESULT seedtest bleed true seed true nvg true/false true/true false/false" --autotest=seedtest --mtype=landed
run supplytest 200 h "RESULT supplytest drops 2 total" --autotest=supplytest --mtype=terror --biome=town --seed=1
run striketest 200 h "RESULT striketest core false strike true lost true \\| core true strike false lost false \\| grey ok" --autotest=striketest
run rockettest 150 h "RESULT rockettest tube \[\"rocket_ap\"\] ap true inc \[\]" --autotest=rockettest --mtype=landed --seed=1
run bvtest     150 h "RESULT bvtest weak true body true module false reinf [23]" --autotest=bvtest --mtype=landed
run nadtest    150 h "RESULT nadtest husk true still true blast true direct true" --autotest=nadtest --mtype=landed
run ohntest    150 h "RESULT ohntest knows true charged true hurt true" --autotest=ohntest --mtype=landed
run mystest    150 h "RESULT mystest moved true again false alive true" --autotest=mystest --mtype=landed
run koltest    200 h "RESULT koltest found true up true top [0-9.]+ down true" --autotest=koltest --mtype=terror --biome=town
run lasertest  120 h "RESULT lasertest drained true waiting true ready true burst true pr_auto true mg_dry true mg_full true edge true" --autotest=lasertest --mtype=landed
run prone_heavy 200 h "RESULT pronetest stowed true key true inv true forced true back true pistol true standing true" --autotest=pronetest --mtype=crash --biome=farm --seed=3
run lcshot     150 h "RESULT lcshot hit true shards true hum true ready true" --autotest=lcshot --mtype=landed
run lcsound    60 s "RESULT lcsound ok"                 tools/test/lcsound.gd
run plasmatest 150 h "RESULT plasmatest pistol 30 hot true interlock true cannon 6 minigun true rifle 15 grenade true seared true mags_left 0" --autotest=plasmatest --mtype=landed
run shieldtest 100 h "RESULT shieldtest stit low 10 up 2 broke true after [0-9]+ plasma 4 knock true vest 16/13 worn true" --autotest=shieldtest --mtype=landed
run shield_x  100 h "RESULT shieldtest stit_x low 10 up 1 broke true after [0-9]+ plasma 2 knock true vest 16/13 worn true" --autotest=shieldtest --mtype=landed --shield=stit_x
run gearloss    60 h "RESULT gearloss order_wait true arrived true sold true won_grenades 4->3 clips_kept true lost_grenades 1 vests 1" --autotest=gearloss
run workshoptest 60 h "RESULT workshoptest ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok$" --autotest=workshoptest
run nadetest   150 h "RESULT nadetest old 0 away [4-8] of 8" --autotest=nadetest --mtype=crash --biome=farm --seed=3 --hour=13
run searchtest 150 h "RESULT searchtest old 0 searched true walked ([2-9][0-9]|[1-9][0-9][0-9]) m" --autotest=searchtest --mtype=crash --biome=farm --seed=3 --hour=13
run feartest   120 h "RESULT feartest old 0 .* fell_back [1-9]" --autotest=feartest --mtype=crash --biome=farm --seed=3 --hour=13
run squadtest  150 h "RESULT squadtest old 0 shots [1-9][0-9]* sides [3-8]" --autotest=squadtest --mtype=crash --biome=farm --seed=3 --hour=13
run packtest   150 h "RESULT packtest old 0 race lihnoun strikes [1-9]" --autotest=packtest --mtype=crash --biome=farm --seed=3 --hour=13
run packohar   150 h "RESULT packtest old 0 race ohar strikes [1-9]" --autotest=packtest --race=ohar --mtype=crash --biome=farm --seed=3 --hour=13
run heattest   150 h "RESULT heattest old 0 .* near_a [1-9]" --autotest=heattest --mtype=crash --biome=farm --seed=1 --hour=13
run styletest  100 h "RESULT styletest .*far: advance" --autotest=styletest --mtype=crash --biome=farm --seed=3 --hour=13
run nemtest    120 h "RESULT nemtest old 0 .* unseen_stalk false .* seen_stalk true goal_to_seen 1[0-9] m" --autotest=nemtest --mtype=crash --biome=farm --seed=3 --hour=13
run dirtest    330 h "RESULT dirtest old 0 .* in_fight 0" --autotest=dirtest --mtype=crash --biome=farm --seed=3 --hour=13
run civtest    150 h "RESULT civtest old 0 v063 0 civ [1-9]" --autotest=civtest --mtype=terror --biome=town --seed=2 --hour=13
run civpanic   150 h "RESULT civpanic hidden [1-9][0-9]* locked [1-9][0-9]* knock true talk true refused true pry true" --autotest=civpanic --mtype=terror --biome=town --seed=2 --hour=13
run nvgtest    120 h "RESULT nvgtest blind true recover true shot true torch true low true dead true off true" --autotest=nvgtest --mtype=landed --hour=23
run civstuck_town 150 h "RESULT civstuck .* spawn_in_wall 0 .* longest_wall 0\.[0-9] s longest_stuck [0-7]\.[0-9] s" --autotest=civstuck --mtype=terror --biome=town --seed=4 --hour=13
run civstuck_farm 150 h "RESULT civstuck .* spawn_in_wall 0 .* longest_wall 0\.[0-9] s longest_stuck [0-7]\.[0-9] s" --autotest=civstuck --mtype=terror --biome=farm --seed=7 --hour=13
run tunetest   160 h "RESULT tunetest diff normal" --autotest=tunetest --mtype=crash --biome=farm --seed=3 --hour=13
run ai_late    160 h "RESULT aitest jestetan late 1 dmg [1-9][0-9][0-9]" --autotest=aitest --mtype=crash --biome=farm --late=1 --seed=5 --hour=13
run latetest   120 h "RESULT latetest pack [2-9] nemesis [1-9][0-9]* marked true waves 2 added [2-9]" --autotest=latetest --mtype=crash --biome=farm --late=1 --seed=5 --hour=23
run reinfcap   120 h "RESULT reinfcap calls 2 max 2 added [2-9] officer 0 waves [01]" --autotest=reinfcap --mtype=sabotage --biome=farm --late=1 --seed=5
run dropshot   400 x "RESULT dropshot fx 1 pending 2 alive_counts true early 0 landed 2 gone true" --autotest=dropshot --mtype=crash --biome=farm --day=1
run lzcheck     200 h "RESULT lzcheck side 54 ahead false near 66 safe true" --autotest=lzcheck --mtype=crash --biome=farm --seed=5
run sab_easy   120 h "RESULT sabcrew start [2-7] bcalls 1 called .* officer_in_call 0" --autotest=reinfcap --mtype=sabotage --biome=farm --late=1 --seed=5 --difficulty=easy
run maptown   220 x "RESULT topshot untangled" --autotest=topshot --mtype=crash --biome=town --hour=13 --seed=11 --late=1
run mapdesert 220 x "RESULT topshot untangled" --autotest=topshot --mtype=crash --biome=desert --terrain=desert --hour=13 --seed=7 --late=1
run wrecks      60 h "RESULT wrecks \[\[1, 0, false\], \[0, 1, true\], \[1, 1, true\]\]" --autotest=wrecks
run ui_bigpack  200 x "m_result: 0 probl"                  --autotest=uimission --research=batohy
run rooftest   250 h "RESULT rooftest slabs [1-9][0-9]* holes 0" --autotest=rooftest --mtype=terror --biome=town --seed=3
# 2026-11-17 déšť: GPU kapky běží pořád (i z budovy je vidět venku), střecha je zastaví; xvfb s Vulkanem navíc fotí rain_inside*.png
run rain       250 h "RESULT rainshot gpu true visible_inside true visible_outside true" --autotest=rainshot --weather=storm --mtype=terror --biome=town --day=1 --seed=3
run lamps      200 h "RESULT lamptest lamps [1-9][0-9]* hittable [1-9][0-9]* shot_dark true" --autotest=lamptest --mtype=terror --biome=town --hour=23 --seed=3
run wxshift    200 h "RESULT wxtest from overcast .* -> rain rain true ratio 0.55 .* puddles [1-9][0-9]* sound true .* -> fog rain false sound false" --autotest=wxtest --mtype=crash --biome=farm --weather=overcast --wxshift=rain@4 --wxblend=6 --seed=3
run scorch     200 h "RESULT scorchshot decals [1-9][0-9]* discs 0" --autotest=scorchshot --mtype=terror --biome=town --day=1 --seed=5
run puddles    200 h "RESULT pudcheck puddles [1-9][0-9]* roofed 0 under [01]$" --autotest=pudcheck --mtype=terror --biome=town --weather=rain --hour=23 --seed=5
run tracks_snow 200 h "RESULT tracktest .* tracks [3-9][0-9]* .*smoke_drift" --autotest=tracktest --mtype=crash --biome=forest --terrain=snow --day=1 --seed=3
run tracks_mud 200 h "RESULT tracktest weather storm .* tracks [3-9][0-9]* .*fire_down 2.20 fire_up 0.30" --autotest=tracktest --mtype=crash --biome=farm --weather=storm --seed=3
run lens       200 h "RESULT lensshot sight dot drops ([3-9]|[1-9][0-9]) fog 0.[4-9]" --autotest=lensshot --mtype=crash --biome=farm --weather=storm --seed=3
# car windows lean in with the pillars in the model itself, glass tinted (a script test, not --autotest)
timeout 120 $G --headless --path . -s tools/test/cartest.gd > $LOG/cartest.log 2>&1
if grep -q "RESULT cartest ok" $LOG/cartest.log; then pass=$((pass+1)); report+="OK    cartest\n"; else fail=$((fail+1)); report+="CHYBA cartest $(grep RESULT $LOG/cartest.log | cut -c1-120)\n"; fi
# (0.72, Ari 22. 11.) the yard forklift is the model v_forklift with collision as it looks
run forklift 120 s "RESULT forklifttest ok" tools/test/forklifttest.gd
# (Ari 27. 11.) places, countries and climate of missions (Egypt, Sahara with grass)
run geo 240 s "RESULT geotest ok" tools/test/geotest.gd
# (Ari 27. 11.) nothing stands inside anything else (cars in cars, a thing in a house): physics + the visible boxes
for ov in "terror town temperate 3" "terror town desert 2" "crash farm dry 2" "landed forest tropic 1" "sabotage industrial temperate 2"; do
  set -- $ov
  run overlap_$2_$3 200 h "RESULT overlaptest props [0-9]+ pairs 0 .* seen 0 of" --autotest=overlaptest --mtype=$1 --biome=$2 --terrain=$3 --seed=$4 --day=1 --size=large
done
echo -e "\n==== VELKÝ TEST: $pass OK, $fail CHYB ====\n$report"
