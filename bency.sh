mkdir -p .benchy

SOLVED_DAYS=15

function profile () {
    zig build -Doptimize=$OPTIMIZE;

    echo "Hyperfine all days [$OPTIMIZE]";
    # hyperfine --warmup 10 -N "./zig-out/bin/advent-of-code-2023 {day}" -P day 1 $SOLVED_DAYS --export-markdown .benchy/hp.md;
    echo "Callgrind days separately [$OPTIMIZE]";
    for day in $(seq 1 $SOLVED_DAYS); do
        mkdir -p ./.benchy/$day
        local callgrind_file="./.benchy/$day/callgrind.$OPTIMIZE.out"
        valgrind --tool=callgrind --callgrind-out-file=$callgrind_file ./zig-out/bin/advent-of-code-2023 $day
        gprof2dot -f callgrind $callgrind_file | dot -Tsvg -o ./.benchy/$day/trace.$OPTIMIZE.svg
    done
        
}


# OPTIMIZE="Debug"
# profile

OPTIMIZE="ReleaseSafe"
profile
