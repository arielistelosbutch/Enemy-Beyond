#!/bin/bash
# Autoladění AI vetřelců (0.64, krok 8 plánu AI).
# Pro každou obtížnost pustí autotest tunetest (voják se zdravím jako ve hře u krytu, robot střílí
# po nejbližším viditelném vetřelci, tři šediví ho napadnou) na několika mapách a pro několik
# hodnot --aitune (násobič rozptylu střel vetřelců; víc = míň trefují). Vypíše, jak často voják
# padne, a hodnotu, která je nejblíž cíli. S --apply ji zapíše do alien_mind.gd (TUNE_MISS).
#
# Pozor: robot není člověk. Cíl je "jak často padne v jedné přestřelce se třemi šedivými", ne
# úmrtnost na misi - ta se počítá ve hře sama (Campaign.data["ai_stats"]: mise, vojáci, ztráty,
# podle obtížnosti) a podle ní se cíle tady dají posunout.
#
#   bash tools/autotune.sh <godot> [--apply] [--seeds="1 2 3 4 5 6"] [--tunes="0.7 0.85 1.0 1.2 1.45"]
#   cíle: TARGET_easy=0.15 TARGET_normal=0.3 TARGET_veteran=0.5 (proměnné prostředí)
G="${1:-/root/godot/Godot_v4.7.2-stable_linux.x86_64}"
shift || true
APPLY=0
SEEDS="1 2 3 4 5 6"
TUNES="0.7 0.85 1.0 1.2 1.45"
JOBS="${JOBS:-6}"
for a in "$@"; do
	case "$a" in
		--apply) APPLY=1 ;;
		--seeds=*) SEEDS="${a#--seeds=}" ;;
		--tunes=*) TUNES="${a#--tunes=}" ;;
	esac
done
declare -A TARGET=([easy]="${TARGET_easy:-0.15}" [normal]="${TARGET_normal:-0.3}" [veteran]="${TARGET_veteran:-0.5}")
BIOMES=(farm town farm town farm town farm town)
cd "$(dirname "$0")/.." || exit 1
OUT=/tmp/autotune
rm -rf "$OUT"; mkdir -p "$OUT"
# every run in the background, JOBS at a time
run_one() {
	local diff=$1 tune=$2 seed=$3 biome=$4
	timeout 200 "$G" --headless --path . -- --autotest=tunetest --mtype=crash --biome="$biome" --seed="$seed" --hour=13 \
		--difficulty="$diff" --aitune="$tune" > "$OUT/${diff}_${tune}_${seed}.log" 2>&1
}
for diff in easy normal veteran; do
	for tune in $TUNES; do
		i=0
		for seed in $SEEDS; do
			run_one "$diff" "$tune" "$seed" "${BIOMES[$((i % ${#BIOMES[@]}))]}" &
			i=$((i + 1))
			while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
		done
	done
done
wait
declare -A BEST
for diff in easy normal veteran; do
	t="${TARGET[$diff]}"
	echo "== $diff (cíl: padne v $(python3 -c "print(round($t*100))") % přestřelek)"
	best=""; bestd=9
	for tune in $TUNES; do
		n=0; down=0
		for f in "$OUT"/${diff}_${tune}_*.log; do
			r=$(grep -h "RESULT tunetest" "$f" | tail -1)
			[ -z "$r" ] && continue
			n=$((n + 1))
			echo "$r" | grep -q "down true" && down=$((down + 1))
		done
		[ "$n" -eq 0 ] && continue
		rate=$(python3 -c "print(round($down/$n, 2))")
		d=$(python3 -c "print(abs($rate-$t))")
		printf "  aitune %-5s padl %d z %d (%s)\n" "$tune" "$down" "$n" "$rate"
		if python3 -c "import sys; sys.exit(0 if $d < $bestd else 1)"; then bestd=$d; best=$tune; fi
	done
	BEST[$diff]="$best"
	echo "  -> nejblíž cíli: $best"
done
echo "TUNE_MISS := {\"easy\": ${BEST[easy]}, \"normal\": ${BEST[normal]}, \"veteran\": ${BEST[veteran]}}"
if [ "$APPLY" = 1 ] && [ -n "${BEST[easy]}" ] && [ -n "${BEST[normal]}" ] && [ -n "${BEST[veteran]}" ]; then
	sed -i "s/^const TUNE_MISS := .*/const TUNE_MISS := {\"easy\": ${BEST[easy]}, \"normal\": ${BEST[normal]}, \"veteran\": ${BEST[veteran]}}/" scripts/alien_mind.gd
	echo "zapsáno do scripts/alien_mind.gd"
fi
