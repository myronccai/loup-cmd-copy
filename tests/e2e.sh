#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. Every case runs in a fresh fixture tree under $TMP, and
# the tree is checked afterwards (copy only writes under $TMP).
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# The fixture tree, rebuilt before every case. z.txt holds a Ctrl-Z.
W="$TMP/w"
reset() {
    cd "$TMP" && rm -rf "$W"
    mkdir -p "$W/sub" "$W/dst"
    printf 'alpha\n' > "$W/a.txt"
    printf 'bravo\n' > "$W/b.txt"
    printf 'x\032hidden' > "$W/z.txt"
    printf 'sub c\n' > "$W/sub/c.txt"
    printf 'old\n' > "$W/dst/b.txt"
    cd "$W"
}

# The tree as one line per entry: `dir/` or `file=content` (cat -v: a
# Ctrl-Z shows as ^Z, newlines as |).
state() {
    (cd "$W" && find . -mindepth 1 | LC_ALL=C sort | while read -r p; do
        if [ -d "$p" ]; then echo "${p#./}/"; else echo "${p#./}=$(cat -v "$p" | tr '\n' '|')"; fi
    done)
}

# check_state NAME EXPECTED: the tree after the last case.
check_state() {
    local got
    got=$(state)
    if [ "$got" = "$2" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $1 (tree)"
        diff <(echo "$2") <(echo "$got") | sed 's/^/    /'
    fi
}

START=$'a.txt=alpha|\nb.txt=bravo|\ndst/\ndst/b.txt=old|\nsub/\nsub/c.txt=sub c|\nz.txt=x^Zhidden'
# with LINE...: the starting tree plus (or with replaced) entries.
with() {
    local out="$START" line name
    for line in "$@"; do
        name=${line%%=*}
        out=$(echo "$out" | grep -v "^$name=")
        out=$(printf '%s\n%s' "$out" "$line")
    done
    echo "$out" | LC_ALL=C sort
}

unset COPYCMD
one=$'        1 file(s) copied.\n'
zero=$'        0 file(s) copied.\n'
printf 'y\n' > "$TMP/yes"; printf 'n\n' > "$TMP/no"; printf 'all\n' > "$TMP/all"

# Help and version.
reset
"$BIN" '/?' > "$TMP/help" 2>&1
if [ "$(head -1 "$TMP/help")" = 'Copy files, or combine several files into one.' ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: /? help"; fi
check      "--version"          0 $'copy (loup-cmd-copy) 0.1.0\n' --version

# Plain copies are binary and print only the count.
reset; check_both "to a name"   0 "$one" ''                     a.txt new.txt
check_state "to a name" "$(with 'new.txt=alpha|')"
reset; check "into a directory" 0 "$one"                        'a.txt' 'dst\'
check_state "into a directory" "$(with 'dst/a.txt=alpha|')"
reset; check "keeps a Ctrl-Z"   0 "$one"                        z.txt zz.txt
check_state "keeps a Ctrl-Z" "$(with 'zz.txt=x^Zhidden')"
reset; check "no destination"   0 "$one"                        'sub\c.txt'
check_state "no destination" "$(with 'c.txt=sub c|')"
reset; check "absolute paths"   0 "$one"                        "$W/a.txt" "$W/sub"
check_state "absolute paths" "$(with 'sub/a.txt=alpha|')"

# Patterns and directories copy each file and name it.
reset; check "pattern into a directory" 0 $'sub\\c.txt\n'"$one" 'sub\*' dst
check_state "pattern into a directory" "$(with 'dst/c.txt=sub c|')"
reset; check "wildcard destination" 0 $'a.txt\nb.txt\nz.txt\n        3 file(s) copied.\n' '*.txt' '*.bak'
check_state "wildcard destination" "$(with 'a.bak=alpha|' 'b.bak=bravo|' 'z.bak=x^Zhidden')"
reset; check "a directory's files" 0 $'sub\\c.txt\n'"$one"      sub dst
check_state "a directory's files" "$(with 'dst/c.txt=sub c|')"

# Combining: text mode by default (stop at Ctrl-Z, end with one).
reset; check_both "a+b"         0 $'a.txt\nb.txt\n'"$one" ''    a.txt+b.txt ab.txt
check_state "a+b" "$(with 'ab.txt=alpha|bravo|^Z')"
reset; check "a + b, spaced"    0 $'a.txt\nb.txt\n'"$one"       a.txt + b.txt ab.txt
check_state "a + b, spaced" "$(with 'ab.txt=alpha|bravo|^Z')"
reset; check "/B"               0 $'z.txt\na.txt\n'"$one"       /B z.txt+a.txt za.txt
check_state "/B" "$(with 'za.txt=x^Zhiddenalpha|')"
reset; check "text stops at Ctrl-Z" 0 $'z.txt\na.txt\n'"$one"   z.txt+a.txt za.txt
check_state "text stops at Ctrl-Z" "$(with 'za.txt=xalpha|^Z')"
reset; check "/B on the destination only" 0 $'a.txt\nb.txt\n'"$one" a.txt+b.txt ab.txt /B
check_state "/B on the destination only" "$(with 'ab.txt=alpha|bravo|')"
reset; check "/A on a plain copy" 0 "$one"                      /A z.txt zz.txt
check_state "/A on a plain copy" "$(with 'zz.txt=x^Z')"
reset; check "pattern to one file" 0 $'a.txt\nb.txt\nz.txt\n'"$one" '?.txt' /B ab.txt
check_state "pattern to one file" "$(with 'ab.txt=alpha|bravo|x^Zhidden')"
reset; check "append to the first" 0 $'a.txt\nb.txt\n'"$one"    /B a.txt+b.txt
check_state "append to the first" "$(with 'a.txt=alpha|bravo|')"

# Overwriting asks (one line of stdin) unless /Y or COPYCMD=/Y.
ask=$'Overwrite dst\\b.txt? (Yes/No/All): '
reset; IN="$TMP/yes" check "answer yes" 0 "${ask}y
$one"                                                           b.txt dst
check_state "answer yes" "$(with 'dst/b.txt=bravo|')"
reset; IN="$TMP/no" check "answer no" 0 "${ask}n
$zero"                                                          b.txt dst
check_state "answer no" "$START"
reset; check "end of input is no" 0 "${ask}
$zero"                                                          b.txt dst
reset; check "/Y"               0 "$one"                        /Y b.txt dst
check_state "/Y" "$(with 'dst/b.txt=bravo|')"
reset; COPYCMD=/Y check "COPYCMD=/Y" 0 "$one"                   b.txt dst
reset; printf 'old a\n' > dst/a.txt
IN="$TMP/all" check "answer all" 0 "a.txt
Overwrite dst\\a.txt? (Yes/No/All): all
b.txt
z.txt
        3 file(s) copied.
"                                                               '?.txt' dst /-Y /B /Y /-Y
reset; check "/V"               0 "$one"                        /V /Y b.txt dst
check_state "/V" "$(with 'dst/b.txt=bravo|')"

# Errors.
reset; check_both "onto itself" 1 "$zero" $'The file cannot be copied onto itself.\n' a.txt
reset; check_both "onto itself, by path" 1 "$zero" $'The file cannot be copied onto itself.\n' a.txt "$W"
reset; check_both "missing file" 1 "$zero" $'The system cannot find the file specified.\n' nope.txt x.txt
reset; check_both "missing part of a join" 1 "$zero" $'The system cannot find the file specified.\n' a.txt+nope.txt x.txt
reset; check_both "no match"    1 "$zero" $'The system cannot find the file specified.\n' '*.none' dst
reset; check_both "missing directory" 1 "$zero" $'The system cannot find the path specified.\n' 'nodir\a.txt' dst
reset; check_both "missing target directory" 1 "$zero" $'The system cannot find the path specified.\n' a.txt 'nodir\a.txt'
reset; check_both "wildcard in directory" 1 "$zero" \
    $'The filename, directory name, or volume label syntax is incorrect.\n' 's*\c.txt' dst
reset; check_both "no source"   1 '' $'The syntax of the command is incorrect.\n'
reset; check_both "three names" 1 '' $'The syntax of the command is incorrect.\n' a.txt b.txt dst
reset; check_both "unknown switch is a name" 1 "$zero" $'The system cannot find the file specified.\n' -q dst
check_state "errors change nothing" "$START"

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
