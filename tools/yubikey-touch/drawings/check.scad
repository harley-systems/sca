// The printable parts as they sit in the assembled fixture, for drawings/check.sh:
//   -D 'part="none"' -D 'which="lid"'
include <../fixture.scad>

which = "lid";

out() {
    if (which == "body") body();
    if (which == "deck") deck();
    if (which == "lid")  lid();
    if (which == "knob") lift_part(DRAWERS[0], "knob");
    if (which == "bar")  lift_part(DRAWERS[0], "bar");
}
