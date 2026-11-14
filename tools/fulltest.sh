#!/bin/bash
# The big test before every release: every automatic check in a row, one summary at the end.
# Usage: tools/fulltest.sh [godot binary]   (Linux; screenshots need xvfb-run)
G=${1:-/root/godot/Godot_v4.7-stable_linux.x86_64}
cd "$(dirname "$0")/.."
LOG=/tmp/fulltest; mkdir -p $LOG; rm -f $LOG/*.log
pass=0; fail=0; report=""
run() {   # name, timeout, mode(h=headless,x=xvfb), expected pattern, args...
  local name=$1 to=$2 mode=$3 want=$4; shift 4
  if [ "$mode" = x ]; then
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
for sd in 1 2 3; do
run pass_ind_$sd  200 h "passcheck .* 0 blocked"           --autotest=passcheck --mtype=sabotage --biome=industrial --seed=$sd
run pass_town_$sd 200 h "passcheck .* 0 blocked"           --autotest=passcheck --mtype=terror --biome=town --seed=$sd
run pass_farm_$sd 200 h "passcheck .* 0 blocked"           --autotest=passcheck --mtype=crash --biome=farm --seed=$sd
done
run menu_ui     300 x "\[UI\] ready: 0"                    --autotest=ui
run mods_ui     200 x "\[MODS\] bought true"              --autotest=modsui
run talent_ui   200 x "\[TALENT\] skip true chain true rank true spent true eye true drone true" --autotest=talentui
run presets     200 x "\[PRESET\] first false list true merc true levels true dice_nolevels true gear true" --autotest=presets
run sights     1000 x "scope mode=scope on=true"          --autotest=sightshot --day=1 --fast=1
run menu_flick  200 x "RESULT menuflicker 0"               --autotest=menuflicker
run geo_ui      300 x "\[UI\] geo_ency_grey: 0"            --autotest=uigeo
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
run base_fly    300 h "RESULT basefly top [0-2]\.[0-9]+ inside 0 .* unreachable 0" --autotest=basefly --attack=1 --crew=levit,levit,levit_velitel,grey
run base_def    120 h "RESULT basedef raids ([5-9]|1[0-6]) .* won_lost false fail_lost true konec true ignored true ignored_lost true" --autotest=basedef
run alienbase   400 x "RESULT abase"                       --autotest=abase --mtype=alienbase
run fire        450 x "RESULT fireshot"                    --autotest=fireshot
run doors       300 x "RESULT doorshot"                    --autotest=doorshot --biome=farm
run blastdoor   300 h "RESULT blastdoor OK"                --autotest=blastdoor
run navcache    200 h "RESULT navcache same true"         --autotest=navcache --mtype=landed --ufo=battleship --seed=2
run perf        200 h "RESULT perf frames"                --autotest=perf --mtype=landed --ufo=battleship --seed=2 --dur=25 --kill=1
run farview     300 x "RESULT farview"                   --autotest=farview --mtype=terror --biome=town --seed=3
# co-op: two games at once (host and client on this machine)
pair() {   # name, host mode, client mode, expected in host log, expected in client log, port
  local name=$1
  timeout 120 $G --headless --path . -- --autotest=$2 --port=$6 > $LOG/${name}_host.log 2>&1 &
  local hp=$!
  sleep 1
  timeout 120 $G --headless --path . -- --autotest=$3 --port=$6 > $LOG/${name}_client.log 2>&1
  wait $hp
  local errs=$(cat $LOG/${name}_host.log $LOG/${name}_client.log | grep -c "SCRIPT ERROR")
  if [ "$errs" = 0 ] && grep -qE "$4" $LOG/${name}_host.log && grep -qE "$5" $LOG/${name}_client.log; then
    pass=$((pass+1)); report+="OK    $name\n"
  else
    fail=$((fail+1)); report+="CHYBA $name (skript. chyb: $errs)\n"
  fi
}
pair coop_mission host client          "players=2"                "blk=false vet=false players=2"  7901
pair coop_pot     pothost potclient     "RESULT potpaid pothost paid 315 money \\+315" "RESULT potpaid potclient paid 315 money \\+315" 7936
pair coop_heal    coophealhost coophealclient "RESULT coopheal host ok" "client t=10 hp [0-9.]+ bleeding 0.00"  7902
pair safe_out   safeouthost safeoutclient "RESULT safeout host out true players 1 shots 0" "RESULT safeout client finished true hp ([0-9.]+) -> \\1" 7935
pair coop_evac  coopevachost coopevacclient "reinf cleared: hidden true back true" "client back in the menu, online" 7937
pair coop_base    lbhost lbclient       "start_mission"            "RESULT lb lbclient players 2" 7903
pair host_base    hbhost hbclient       "RESULT hb drop hbhost players 2" "RESULT hbclient globe true day \\+0\\.0[1-9]" 7951
pair coop_wipe    coopwipehost coopwipeclient "globe ready"     "END\\] leave"                  7904
pair coop_ready readyhost readyclient "RESULT readyhost early false window true ran true" "RESULT readyclient saw 'Výsadek: test' panel '.*' me true done true" 7938
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
quad ai_coop4 "RESULT aimp old 0 players 4 hide [1-9]" 7915
pair lobby_kick kickhost kickclient "RESULT kick summary rows 2 ping [0-9]+ mic open after 1 rejoined false" "RESULT kick client .*vyhodil.*za 5 min" 7914
pair ufo_hull hullhost hullclient "RESULT ufohull raider rays [0-9]+ leak 0\.[0-4] % hug_inside 0 seen 0" "RESULT ufohull raider rays [0-9]+ leak 0\.[0-4] % hug_inside 0 seen 0" 7917
pair coop_leak leakhost leakclient "RESULT leakhost .* stone_leak 0\.[0-4] %" "RESULT leakclient .* stone_leak 0\.[0-4] %" 7958
pair coop_flare flarehost flareclient "RESULT coopflare flarehost seen (59|6[0-9]) pos \\(-?[0-9.]+, [0-9]" "RESULT coopflare flareclient seen (59|6[0-9]) pos \\(-?[0-9.]+, [0-9]" 7918
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
run ground     250 h "RESULT groundtest [0-9]+ raised, 0 bare, .*sunk 0 .*kerbs alien [6-8]/8 merc [6-8]/8" --autotest=groundtest --day=1 --nomerge=all --dur=20 --seed=5
run rocks       250 x "RESULT rocktest [0-9]+ stones, 0 hollow, 0 nav inside, walked 12, 0 bad" --autotest=rocktest --mtype=crash --biome=mountain --seed=7 --day=1
run hitbox      200 h "RESULT hitbox [0-9]+ props, [0-9]+ rays, phantom [0-4]\.[0-9] %" --autotest=hitbox --mtype=crash --biome=farm --seed=7
run leak_mtn  250 x "RESULT leaktest mountain .* stone_leak 0\.[0-4] %" --autotest=leaktest --mtype=crash --biome=mountain --seed=7 --day=1
run leak_abase 300 x "RESULT leaktest alienbase .* stone_leak 0\.[0-4] %" --autotest=leaktest --mtype=alienbase --biome=alienbase --seed=7 --day=1
run leak_mars 200 x "RESULT leaktest mars .* stone_leak 0\.[0-4] %" --autotest=leaktest --mtype=mars --biome=mars --seed=7 --day=1
# (0.69 oprava) plášť UFO zastaví střely i pohled (Ari: stříleli nás skrz obrys lodě)
for u in scout raider harvester; do
run ufohull_$u 150 h "RESULT ufohull $u rays [0-9]+ leak 0\.[0-4] % hug_inside 0 seen 0" --autotest=ufohull --mtype=crash --ufo=$u --biome=farm --day=1
done
for u in battleship supply; do
run ufohull_$u 300 h "RESULT ufohull $u rays [0-9]+ leak 0\.[0-4] % hug_inside 0 seen 0" --autotest=ufohull --mtype=landed --ufo=$u --size=huge --biome=farm --day=1
done
run wedge      150 x "RESULT wedgetest ok"                --autotest=wedgetest --mtype=crash --biome=farm --seed=7 --day=1
run ceiling   200 h "RESULT ceiltest [0-9]+ spots, [0-9]+ tries, leaks 0, unstuck 0, jumps [0-9]+ bad 0" --autotest=ceiltest --mtype=terror --biome=farm --seed=7 --day=1
for bm in town farm mountain industrial base; do
run interiors_$bm 200 h "RESULT interiors [0-9]+ houses, pockets 0, stairs_bad 0" --autotest=interiors --mtype=terror --biome=$bm --seed=3
done
run spectate  200 x "RESULT spectate active true eyes true next true auto true running true" --autotest=spectate --mtype=terror --biome=farm --seed=3 --day=1
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
run talenttest 250 h "RESULT talenttest .* ok true"     --autotest=talenttest
# 0.62 animations: hit reactions, turning on the spot, the Ohař's moods (afk models: only in the game package)
for r in ohar jestetan zombie bijec_velitel; do
run afk_$r      300 h "RESULT afkalien $r .* hitplay hit[a-z_0-9]* turnplay turn" --autotest=afkalien --race=$r --mtype=landed
done
run civanim     150 h "RESULT civanim [0-9]+ civilians afk idle,walk,run,lurk cower lurk" --autotest=civanim --mtype=terror
run civdeath    150 h "RESULT civdeath 10 deaths bad 0" --autotest=civdeath --mtype=terror
# 0.66 Facelift I: the drone's radar in solo, the transport after a mission, the people of the base, the loading screen
run flare       200 h "RESULT flaretest life (59|6[0-9]) lit true moved 0.00" --autotest=flaretest --mtype=crash --biome=farm
run radar       150 h "RESULT radar solo true scanner true kit_scanner false kit_radio false" --autotest=radartest --mtype=crash --biome=farm --day=1
run rampcheck   200 h "RESULT rampcheck shut true open true" --autotest=rampcheck --prep=1
run transport   150 h "RESULT transport closed true"     --autotest=transport --mtype=crash --biome=farm --day=1
run uifit       150 x "RESULT uifit bad 0"               --autotest=uifit --mtype=crash --biome=farm --day=1
run npcbase     150 h "RESULT npc moved [1-9]"           --autotest=npcshot --shots=0 --wait=25
run baseshot    150 x "RESULT baseshot builders 3"     --autotest=baseshot
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
run lasertest  120 h "RESULT lasertest drained true waiting true ready true mg_dry true mg_full true edge true" --autotest=lasertest --mtype=landed
run lcshot     150 h "RESULT lcshot hit true shards true hum true ready true" --autotest=lcshot --mtype=landed
run plasmatest 150 h "RESULT plasmatest pistol 20 hot true interlock true cannon 4 minigun true rifle 10 grenade true seared true mags_left 0" --autotest=plasmatest --mtype=landed
run shieldtest 100 h "RESULT shieldtest low 10 up 2 broke true after [0-9]+ plasma 4 knock true vest 16/13 worn true" --autotest=shieldtest --mtype=landed
run gearloss    60 h "RESULT gearloss order_wait true arrived true sold true won_grenades 4->3 clips_kept true lost_grenades 1 vests 1" --autotest=gearloss
run workshoptest 60 h "RESULT workshoptest ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok ok$" --autotest=workshoptest
run nadetest   150 h "RESULT nadetest old 0 away [4-8] of 8" --autotest=nadetest --mtype=crash --biome=farm --seed=3 --hour=13
run searchtest 150 h "RESULT searchtest old 0 searched true walked ([2-9][0-9]|[1-9][0-9][0-9]) m" --autotest=searchtest --mtype=crash --biome=farm --seed=3 --hour=13
run feartest   120 h "RESULT feartest old 0 .* fell_back [1-9]" --autotest=feartest --mtype=crash --biome=farm --seed=3 --hour=13
run squadtest  150 h "RESULT squadtest old 0 shots [1-9][0-9]* sides [3-8]" --autotest=squadtest --mtype=crash --biome=farm --seed=3 --hour=13
run packtest   150 h "RESULT packtest old 0 race lihnoun strikes [1-9]" --autotest=packtest --mtype=crash --biome=farm --seed=3 --hour=13
run packohar   150 h "RESULT packtest old 0 race ohar strikes [1-9]" --autotest=packtest --race=ohar --mtype=crash --biome=farm --seed=3 --hour=13
run heattest   150 h "RESULT heattest old 0 .* near_a [1-9]" --autotest=heattest --mtype=crash --biome=farm --seed=3 --hour=13
run styletest  100 h "RESULT styletest .*far: advance" --autotest=styletest --mtype=crash --biome=farm --seed=3 --hour=13
run nemtest    120 h "RESULT nemtest old 0 .* unseen_stalk false .* seen_stalk true goal_to_seen 1[0-9] m" --autotest=nemtest --mtype=crash --biome=farm --seed=3 --hour=13
run dirtest    330 h "RESULT dirtest old 0 .* in_fight 0" --autotest=dirtest --mtype=crash --biome=farm --seed=3 --hour=13
run civtest    150 h "RESULT civtest old 0 v063 0 civ [1-9]" --autotest=civtest --mtype=terror --biome=town --seed=2 --hour=13
run tunetest   160 h "RESULT tunetest diff normal" --autotest=tunetest --mtype=crash --biome=farm --seed=3 --hour=13
run ai_late    160 h "RESULT aitest jestetan late 1 dmg [1-9][0-9][0-9]" --autotest=aitest --mtype=crash --biome=farm --late=1 --seed=5 --hour=13
run latetest   120 h "RESULT latetest pack [2-9] nemesis [1-9][0-9]* marked true waves 3 added [3-9]" --autotest=latetest --mtype=crash --biome=farm --late=1 --seed=5 --hour=23
run maptown   220 x "RESULT topshot untangled" --autotest=topshot --mtype=crash --biome=town --hour=13 --seed=11 --late=1
run mapdesert 220 x "RESULT topshot untangled" --autotest=topshot --mtype=crash --biome=desert --terrain=desert --hour=13 --seed=7 --late=1
run wrecks      60 h "RESULT wrecks \[\[1, 0, false\], \[2, 0, false\], \[0, 1, true\]\]" --autotest=wrecks
run ui_bigpack  200 x "m_result: 0 probl"                  --autotest=uimission --research=batohy
echo -e "\n==== VELKÝ TEST: $pass OK, $fail CHYB ====\n$report"
