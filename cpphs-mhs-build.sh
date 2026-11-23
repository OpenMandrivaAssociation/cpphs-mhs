#!/bin/bash
# cpphs 1.20.9 compiled by MicroHs, with no cpphs to start from.
#
#   round 1  gcc -traditional preprocesses polyparse, then mhs compiles
#            cpphs with no CPP (MicroHs libraries never meet gcc's cpp).
#   round 2  upstream bootstrap, using round 1.
#   round 3  the same with round 2. round 2's C must equal round 3's.
# Round 2 is the installed binary.
#
# Usage: cpphs-mhs-build.sh ROOT MHS_PREFIX
# MHS_PREFIX contains bin/mhs and src/runtime (the microhs rpm layout).
# cpphscompat comes from the MicroHs tarball staged in ROOT, because the
# microhs package does not install it.
set -euo pipefail

ROOT=${1:?usage: cpphs-mhs-build.sh ROOT MHS_PREFIX}
MHS=${2:?}
WORK=$ROOT/work
PREFIX=$ROOT/dest
export TMPDIR=$WORK/tmp
mkdir -p "$TMPDIR" "$WORK/src" "$PREFIX/bin"
unset CFLAGS CXXFLAGS LDFLAGS || true

MHS_BIN=$MHS/bin/mhs
[ -x "$MHS_BIN" ] || { echo "mhs missing: $MHS_BIN" >&2; exit 1; }
[ -f "$MHS/src/runtime/eval.c" ] || { echo "mhs runtime missing under $MHS" >&2; exit 1; }
[ -f "$MHS/lib/Prelude.hs" ] || { echo "mhs Prelude missing under $MHS/lib" >&2; exit 1; }
[ -f "$MHS/mhs.conf" ] || { echo "mhs.conf missing under $MHS" >&2; exit 1; }
# The packaged layout is inplace (bin/, lib/, src/runtime). Setting MHSDIR
# makes mhs use that tree even when the binary is a symlink.
export MHSDIR=$MHS

if [ ! -d "$WORK/src/cpphs-1.20.9" ]; then
	tar -C "$WORK/src" -xzf "$ROOT/cpphs-1.20.9.tar.gz"
	tar -C "$WORK/src" -xzf "$ROOT/polyparse-1.12.tar.gz"
	tar -C "$WORK/src" -xzf "$ROOT/MicroHs-0.16.6.0.tar.gz"
	patch -d "$WORK/src" -p1 < "$ROOT/cpphs-1.20.9-mhs.patch"
	patch -d "$WORK/src" -p1 < "$ROOT/polyparse-1.12-mhs.patch"
fi
[ -d "$WORK/src/MicroHs/cpphscompat" ]

cd "$WORK/src"
minver='-DMIN_VERSION_base(x,y,z)=((x)<4||(x)==4&&(y)<19||(x)==4&&(y)==19&&(z)<=1)'
link() {
	# /usr/bin/cc is clang. The MicroHs runtime is built with gcc.
	gcc -w -O1 -I"$MHS/src/runtime" -I"$MHS/src/runtime/unix" \
		"$MHS/src/runtime/main.c" "$MHS/src/runtime/eval.c" "$1.c" -lm -o "$1"
}

rm -rf pp
cp -a polyparse-1.12/src pp
if grep -RIn -- '\\$' pp; then
	echo "trailing backslash: gcc's cpp would join lines" >&2
	exit 1
fi
while IFS= read -r f; do
	[ -n "$f" ] || continue
	gcc -E -P -traditional -undef -x c "$minver" "$f" -o "$f.cpp"
	mv "$f.cpp" "$f"
done < <(grep -RIl '^#' pp || true)

"$MHS_BIN" -z -i"$WORK/src/MicroHs/cpphscompat" -ipp -icpphs-1.20.9 \
	cpphs-1.20.9/cpphs.hs -ocpphs1.c
link cpphs1

for r in 1 2; do
	MHSCPPHS=$PWD/cpphs$r "$MHS_BIN" -z -XCPP "$minver" \
		-i"$WORK/src/MicroHs/cpphscompat" \
		-ipolyparse-1.12/src -icpphs-1.20.9 \
		cpphs-1.20.9/cpphs.hs -ocpphs$((r + 1)).c
	link cpphs$((r + 1))
done
cmp cpphs2.c cpphs3.c
install -m 755 cpphs2 "$PREFIX/bin/cpphs-mhs"
"$PREFIX/bin/cpphs-mhs" --version
printf 'CPPHS_MHS_DONE %s\n' "$PREFIX/bin/cpphs-mhs"
