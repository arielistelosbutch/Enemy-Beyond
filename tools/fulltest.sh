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
for sd in 1 2 3; do
run pass_ind_$sd  200 h "passcheck .* 0 blocked"           --autotest=passcheck --mtype=sabotage --biome=industrial --seed=$sd
run pass_town_$sd 200 h "passcheck .* 0 blocked"           --autotest=passcheck --mtype=terror --biome=town --seed=$sd
run pass_farm_$sd 200 h "passcheck .* 0 blocked"           --autotest=passcheck --mtype=crash --biome=farm --seed=$sd
done
run menu_ui     300 x "\[UI\] ready: 0"                    --autotest=ui
run menu_flick  200 x "RESULT menuflicker 0"               --autotest=menuflicker
run geo_ui      300 x "\[UI\] geo_ency_grey: 0"            --autotest=uigeo
run mission_ui  250 x "\[UI\] m_result: 0"                 --autotest=uimission
run solo        250 h "RESULT"                             --autotest=solo
run campaign    300 h "back on globe"                             --autotest=campaign
run drone       200 x "first fall: downed false" --autotest=dronetest
run voice       200 h "RESULT voice: snippets \[1\]"       --autotest=voice
run basewalk    400 x "RESULT basewalk 11"                 --autotest=basewalk
run base_attack 400 x "RESULT basewalk 11"                 --autotest=basewalk --attack=1
run alienbase   400 x "RESULT abase"                       --autotest=abase --mtype=alienbase
run fire        300 x "RESULT fireshot"                    --autotest=fireshot
run doors       300 x "RESULT doorshot"                    --autotest=doorshot --biome=farm
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
pair coop_heal    coophealhost coophealclient "RESULT coopheal host ok" "client t=10 hp [0-9.]+ bleeding 0.00"  7902
pair coop_base    lbhost lbclient       "start_mission"            "RESULT lb lbclient players 2" 7903
pair coop_wipe    coopwipehost coopwipeclient "globe ready"     "END\\] leave"                  7904
run airdeath    150 h "RESULT airdeath ok"                 --autotest=airdeath --group=levite
echo -e "\n==== VELKÝ TEST: $pass OK, $fail CHYB ====\n$report"
