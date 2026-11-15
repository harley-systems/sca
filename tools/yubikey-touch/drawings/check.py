"""Check that each printable STL is the assembled part turned and moved, never mirrored.

A part that is turned over for printing with a mirror comes out of the printer as its mirror image, and no
amount of turning makes it fit (rev H's lid). For each pair "name printed.stl assembled.stl" this tries the 48
ways of lining the axes up; the 24 that are rotations are fine, the 24 that are mirrors are not.
"""
import itertools
import re
import sys

Q = 1e-3   # mm


def points(path):
    text = open(path).read()
    pts = {tuple(float(v) for v in m) for m in re.findall(r"vertex\s+(\S+)\s+(\S+)\s+(\S+)", text)}
    if not pts:
        sys.exit(f"{path}: no vertices (is it an ASCII STL?)")
    return pts


def keyed(pts):
    lo = [min(p[i] for p in pts) for i in range(3)]
    return {tuple(round((p[i] - lo[i]) / Q) for i in range(3)) for p in pts}


def near(a, b):
    """Every point of a has a point of b within Q in each direction."""
    steps = list(itertools.product((-1, 0, 1), repeat=3))
    return all(any((k[0] + s[0], k[1] + s[1], k[2] + s[2]) in b for s in steps) for k in a)


def fits(printed, assembled):
    want = keyed(assembled)
    found = {1: False, -1: False}
    for perm in itertools.permutations(range(3)):
        for signs in itertools.product((1, -1), repeat=3):
            swaps = sum(1 for i in range(3) for j in range(i) if perm[j] > perm[i])
            det = (-1) ** swaps * signs[0] * signs[1] * signs[2]
            if found[det]:
                continue
            got = keyed({tuple(signs[i] * p[perm[i]] for i in range(3)) for p in printed})
            if len(got) == len(want) and near(got, want) and near(want, got):
                found[det] = True
    return found


bad = False
for line in sys.stdin:
    name, printed, assembled = line.split()
    f = fits(points(printed), points(assembled))
    if f[1]:
        print(f"ok        {name}")
    else:
        bad = True
        print(f"MIRRORED  {name}: only a mirror image of the STL fits the assembled part" if f[-1]
              else f"NO FIT    {name}: the STL is not the assembled part")
sys.exit(1 if bad else 0)
