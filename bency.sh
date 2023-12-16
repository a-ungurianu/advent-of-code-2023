mkdir -p .benchy

SOLVED_DAYS=15

function set_optimize() {
    OPTIMIZE=$1;
    zig build -Doptimize=$OPTIMIZE;
}

function profile_day() {
    local day=$1;

    mkdir -p ./.benchy/$day
    local callgrind_file="./.benchy/$day/callgrind.$OPTIMIZE.out"
    valgrind --tool=callgrind --callgrind-out-file=$callgrind_file ./zig-out/bin/advent-of-code-2023 $day
    gprof2dot -f callgrind $callgrind_file | dot -Tsvg -o ./.benchy/$day/trace.$OPTIMIZE.svg
}

function profile_all () {
    zig build -Doptimize=$OPTIMIZE;

    echo "Hyperfine all days [$OPTIMIZE]";
    hyperfine --warmup 10 -N "./zig-out/bin/advent-of-code-2023 {day}" -P day 1 $SOLVED_DAYS --export-markdown .benchy/hp.md;
    echo "Callgrind days separately [$OPTIMIZE]";
    for day in $(seq 1 $SOLVED_DAYS); do
        profile_day $day
    done
        
}

if [ -z "$1" ]; then
    
    set_optimize Debug;
    profile_all;

    set_optimize ReleaseSafe;
    profile_all;
else
    set_optimize Debug;
    profile_day $1;

    set_optimize ReleaseSafe;
    profile_day $1;

fi
