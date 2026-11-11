// YubiKey touch fixture, rev F: printed body, deck, lid, and per drawer a pin knob and a slide bar
// that lift the pogo pin off the key. No glue.
//
// Render one part:  openscad -D 'part="body"' -o body.stl fixture.scad
// Parts: "body", "deck", "lid" (flipped for printing), "test" (north drawer + tower only),
//        "knob" (upright), "bar" (flat; print two of each),
//        "assembly" (everything in place, for looking at; add -D 'lifted=true' for the lifted pins).
//
// Coordinates (mm): x runs west -> east, ty runs north -> south (the YubiKey 4 drawer is north,
// the YubiKey 5 drawer south), z is up from the bed. Everything is built in (x, ty, z) and
// mirrored into OpenSCAD's y = -ty at the end, so the part matches the sketch and the animation.
//
// The values marked MEASURE are taken from the AliExpress listings and YubiKey datasheets,
// not from the parts in hand. Check them with calipers before printing the full body.

part = "body";
lifted = false;   // assembly only: show the pins lifted instead of pressed

$fn = 48;

// ---------------------------------------------------------------- parameters
// YubiKey touch pads: pin positions along each drawer (MEASURE: connector edge -> pad centre)
pin_x       = 11.9;    // drawer centre line, also the key centre line
pin_ty_yk4  = -22;     // 21 mm north of the box wall
pin_ty_yk5  = 85;      // 23 mm south of the box wall

// pogo pin P75 (barrel 1.02 mm): printed holes come out ~0.1 mm small; ream with the pin vise if tight
bore_d      = 1.2;
access_d    = 2.0;     // hole in the drawer floor the pin is pushed up through
channel_d   = 1.6;     // touch-wire channel (30 AWG)

// pin lift: the pin sits in a square knob that slides in a square hole in the tower. A 1.75 mm
// filament cross-pin through the knob runs in a Z-shaped slot in a bar on the tower's west face.
// Bar pushed in towards the box: pin pressed. Bar pulled out towards the drawer mouth: pin lifted.
seat_z      = 24.4;    // pin seat (barrel tail) when pressed, same as rev E's chamber ceiling
lift        = 2.5;
knob_w      = 5.0;     // square knob, in a hole 2 x knob_clear wider
knob_clear  = 0.2;
knob_seat   = 6.5;     // seat height above the knob's bottom; the solder slot is the 2 mm below it
knob_h      = 10.2;    // about 2x its width so the one-sided push from the bar can't cock it
slot_w      = 2.6;     // solder slot through the knob (ty) and wire windows through the tower
tower_wall  = 1.8;
fil_d       = 1.75;    // filament cross-pin
fil_hole_d  = 1.75;    // in the knob: prints ~0.1 mm small, a press fit; ream if too tight
fil_up      = 1.8;     // filament centre above the seat, clear of the solder slot
fil_slot_w  = 2.0;     // filament slots in the tower and bar
bar_t       = 2.4;     // bar thickness (x), 0.3 mm clearance in its channel
bar_dwell   = 1.5;     // level dwells at both ends of the bar slot lock both positions
bar_run     = 4.5;     // slant length: 2.5 mm rise over 4.5 mm is 29 degrees
bar_len     = 18.5;

// M2 heat-set insert 3.5 OD x 3: hole 3.2, pressed in with the Pinecil at ~220 C (PLA)
insert_hole_d = 3.2;
screw_clear_d = 2.3;
INS = [[4.2, 57.2], [36.5, 56.5]];

// key tunnels: YubiKey body 18 x 3.3 mm (MEASURE)
tunnel_x0 = 2.75;  tunnel_x1 = 21.05;   // 18.3 wide
tunnel_z0 = 4.6;   tunnel_z1 = 9.8;     // 5.2 tall

// hub board 32 x 35 (MEASURE: board size, the four mounting holes, socket positions)
HUB_POSTS = [[4.0, 4.4], [37.5, 4.4], [4.0, 38.2], [37.5, 38.2]];
yk4_opening = [5.0, 18.8, 2.4, 10.2];   // x0 x1 z0 z1 through the north wall
yk5_recess  = [7.6, 16.2, 4.8, 7.8];    // through the south wall
plug_opening = [17.3, 25.7, 2.9, 6.3];  // ty0 ty1 z0 z1 through the west wall (laptop USB-C plug)

// ---------------------------------------------------------------- helpers
module bx(x0, x1, t0, t1, z0, z1) { translate([x0, t0, z0]) cube([x1 - x0, t1 - t0, z1 - z0]); }
module cy(x, t, z0, z1, d, fn = $fn) { translate([x, t, z0]) cylinder(d = d, h = z1 - z0, $fn = fn); }
module rod(p1, p2, d) { hull() { translate(p1) sphere(d = d, $fn = 16); translate(p2) sphere(d = d, $fn = 16); } }
module out() { mirror([0, 1, 0]) children(); }

// ---------------------------------------------------------------- body
DRAWERS = [  // t0, t1, pin ty, rib wall end ty0..ty1, s (+1 north drawer, -1 south), channel exit b
    [-28, 0,  pin_ty_yk4, -1.0, 0.0,  1, [20, 2.6, 14.0]],
    [62,  90, pin_ty_yk5, 62.0, 63.0, -1, [20, 59.4, 14.0]]];

module drawer(d) {
    t0 = d[0]; t1 = d[1]; pty = d[2]; s = d[5];
    rb = s > 0 ? [pty - 0.5, pty + 2] : [pty - 2, pty + 0.5];
    bx(0.75, 23.05, t0, t1, 0, tunnel_z0);                      // floor
    bx(0.75, tunnel_x0, t0, t1, tunnel_z0, tunnel_z1);          // rails
    bx(tunnel_x1, 23.05, t0, t1, tunnel_z0, tunnel_z1);
    bx(0.75, 23.05, t0, t1, tunnel_z1, 11.8);                   // roof
    lift_block(d);                                              // pin tower and bar channel
    hull() {                                                    // sloped rib, carries the wire channel
        bx(9.9, 13.9, rb[0], rb[1], 11.8, 24.8);
        bx(18, 22, d[3], d[4], 11.8, 16.6);
    }
}

module drawer_cuts(d) {
    pty = d[2]; s = d[5];
    cy(pin_x, pty, -1, 4.9, access_d);                          // hole in the drawer floor
    cy(pin_x, pty, 9.0, hole_z0 + 0.1, bore_d, 24);             // bore, guides the barrel up into the knob
    lift_cuts(d);
    rod([pin_x + 0.9, pty + s * hole_w / 2, seat_z - 2], d[6], channel_d);   // wire channel from the box-side window, on rev E's line
}

// ---------------------------------------------------------------- pin lift
// Built per drawer in a local frame: x from the pin axis, o outwards from the pin towards the
// drawer mouth (away from the box), z as usual. The local frame of the south drawer is mirrored.
hole_w   = knob_w + 2 * knob_clear;
tower_h  = hole_w / 2 + tower_wall;          // half width of the square tower
knob_z0  = seat_z - knob_seat;               // knob bottom when pressed
hole_z0  = knob_z0 - 0.5;                    // the bar sets both positions, not the hole floor
fil_z    = seat_z + fil_up;                  // filament centre when pressed
fslot_z  = [fil_z - fil_slot_w / 2 - 0.25, fil_z + lift + fil_slot_w / 2 + 0.25];
bar_z0   = fil_z + fil_d / 2 - fil_slot_w - 1.5;    // the spring holds the filament up on the slot top
bar_h    = 1.5 + fil_slot_w + lift + 1.5;
chan_x   = [-tower_h - bar_t - 0.3, -tower_h];
chan_z   = [bar_z0 - 0.4, bar_z0 + bar_h];   // the spring holds the bar up against the channel roof
top_z    = chan_z[1] + 1.2;
u0       = 1.5 + fil_slot_w / 2;             // slot points along the bar, from its inner end:
bar_u    = [u0, u0 + bar_dwell, u0 + bar_dwell + bar_run, u0 + 2 * bar_dwell + bar_run];   // lifted .. pressed

module loc(d) { multmatrix([[1, 0, 0, pin_x], [0, -d[5], 0, d[2]], [0, 0, 1, 0]]) children(); }

module lift_block(d) {
    loc(d) {
        bx(-tower_h, tower_h, -tower_h, tower_h, 11.8, top_z);                     // square tower
        bx(chan_x[0] - 1.2, -tower_h, -tower_h, tower_h + 0.5, 11.8, top_z);      // bar channel housing
    }
}

module lift_cuts(d) {
    loc(d) {
        bx(-hole_w / 2, hole_w / 2, -hole_w / 2, hole_w / 2, hole_z0, top_z + 1);   // knob hole
        bx(chan_x[0] - 2, tower_h + 0.5, -fil_slot_w / 2, fil_slot_w / 2, fslot_z[0], fslot_z[1]);   // filament slots
        bx(-slot_w / 2, slot_w / 2, -tower_h - 0.1, tower_h + 0.1, seat_z - 2.8, seat_z + lift);   // solder and wire windows
        bx(chan_x[0], chan_x[1], -tower_h - 1, tower_h + 2, chan_z[0], chan_z[1]);   // bar channel
    }
}

module knob() {   // bottom at z = 0, axis on z
    difference() {
        bx(-knob_w / 2, knob_w / 2, -knob_w / 2, knob_w / 2, 0, knob_h);
        cy(0, 0, -1, knob_seat, bore_d, 24);                                       // pin bore
        translate([0, 0, -0.01]) cylinder(d1 = bore_d + 1.0, d2 = bore_d, h = 0.5, $fn = 24);   // lead-in, 45 degrees
        bx(-slot_w / 2, slot_w / 2, -knob_w, knob_w, knob_seat - 2, knob_seat);    // solder slot; the barrel stops on its ceiling
        translate([-knob_w, 0, knob_seat + fil_up]) rotate([0, 90, 0]) cylinder(d = fil_hole_d, h = 2 * knob_w, $fn = 24);
    }
}

module bar() {   // flat, as printed: x along the bar (u), y up the bar, z through it
    p = [[bar_u[0], 1.5 + fil_slot_w / 2 + lift], [bar_u[1], 1.5 + fil_slot_w / 2 + lift],
         [bar_u[2], 1.5 + fil_slot_w / 2], [bar_u[3], 1.5 + fil_slot_w / 2]];
    linear_extrude(height = bar_t) difference() {
        union() {
            square([bar_len, bar_h]);
            translate([bar_len - 3, 0]) square([3, bar_h + 4]);                     // grip, outside the channel
        }
        for (i = [0 : 2]) hull() for (q = [p[i], p[i + 1]]) translate(q) circle(d = fil_slot_w, $fn = 24);
    }
}

module lift_parts(d) {   // knob, filament and bar in place
    up = lifted ? lift : 0;
    loc(d) {
        translate([0, 0, knob_z0 + up]) knob();
        translate([chan_x[0] + 0.4, 0, fil_z + up]) rotate([0, 90, 0]) cylinder(d = fil_d, h = tower_h - chan_x[0] - 0.6, $fn = 24);
        multmatrix([[0, 0, -1, -tower_h], [1, 0, 0, -(lifted ? bar_u[0] : bar_u[3])], [0, 1, 0, bar_z0]]) bar();
    }
}

// 45 degree support under an overhanging block that hangs off the south wall (ty = 60)
module south_chamfer(x0, x1, t0, zb) {
    hull() { bx(x0, x1, t0, 60, zb - 0.01, zb); bx(x0, x1, 59.99, 60, zb - (60 - t0), zb); }
}

module body() {
    difference() {
        union() {
            bx(0, 42, 0, 62, 0, 1.4);                                    // floor
            bx(0, 42, 0, 2, 0, 19);  bx(0, 42, 60, 62, 0, 19);           // walls
            bx(0, 2, 0, 62, 0, 19);  bx(40, 42, 0, 62, 0, 19);
            // lid ledges, 45 degrees underneath; gap over the hub's USB-C input
            for (r = [[3, 16.5], [26.5, 52]]) hull() { bx(2, 3, r[0], r[1], 16, 17); bx(2, 2.01, r[0], r[1], 15, 17); }
            hull() { bx(39, 40, 3, 52, 16, 17); bx(39.99, 40, 3, 52, 15, 17); }
            // insert blocks; west one L-shaped so the YubiKey 5 adapter can be lowered past it
            bx(33, 40, 53, 60, 11.6, 17);  south_chamfer(33, 40, 53, 11.6);
            bx(2, 6.3, 53, 60, 11.6, 17);  south_chamfer(2, 6.3, 53, 11.6);
            bx(2, 13, 56.3, 60, 11.6, 17); south_chamfer(2, 13, 56.3, 11.6);
            for (p = HUB_POSTS) bx(p[0] - 0.6, p[0] + 0.6, p[1] - 0.6, p[1] + 0.6, 1.4, 3.6);
            for (d = DRAWERS) drawer(d);
        }
        bx(yk4_opening[0], yk4_opening[1], -1, 3, yk4_opening[2], yk4_opening[3]);
        bx(yk5_recess[0], yk5_recess[1], 55, 63, yk5_recess[2], yk5_recess[3]);
        bx(-1, 3, plug_opening[0], plug_opening[1], plug_opening[2], plug_opening[3]);
        bx(11.6, 30.4, 1.1, 2.2, 17.1, 18.3);                                 // slot for the lid's tab
        for (p = INS) cy(p[0], p[1], 12.8, 17.2, insert_hole_d);
        for (d = DRAWERS) drawer_cuts(d);
    }
}

// ---------------------------------------------------------------- deck (sits on the hub sockets)
BOARDS = [[3.5, 6], [11.5, 6], [3.5, 28], [11.5, 28]];   // AO3401 / 2N7002 boards, 7 x 9

module deck() {
    difference() {
        bx(3.4, 38.6, 2.5, 59.5, 10.0, 11.2);   // 0.4 mm clear of the lid ledges
        bx(23.6, 35.6, 39.8, 49.7, 9, 12.5);      // open notch round the U-turn adapter
        bx(2.0, 13.4, 52.6, 60, 9, 12.5);         // west insert block
        bx(32.6, 40, 52.6, 60, 9, 12.5);          // east insert block
        bx(4, 18.5, 15.5, 17.9, 9, 12.5);         // wire slots
        bx(4, 18.5, 24.3, 27.5, 9, 12.5);
        for (b = BOARDS) bx(b[0] - 0.15, b[0] + 7.15, b[1] - 0.15, b[1] + 9.15, 10.6, 11.6);   // board pockets
    }
    for (p = [[23, 18], [36, 18], [23, 35], [36, 35]]) bx(p[0] - 1, p[0] + 1, p[1] - 1, p[1] + 1, 11.2, 12.4);   // RP2040 cradle
}

// ---------------------------------------------------------------- lid (drops in 1 mm south, slides north)
module lid() {
    difference() {
        union() {
            bx(2.3, 39.7, 2.3, 59.0, 17, 19);      // 0.3 mm clear of the walls
            bx(12, 30, 1.3, 2.4, 17.3, 18.1);                                   // tab into the north wall slot
            for (b = [[3.5, 6, 0], [11.5, 6, 0], [3.5, 28, 1], [11.5, 28, 1]]) {   // ribs holding the boards down
                rt = b[2] == 0 ? [b[1] + 0.4, b[1] + 1.4] : [b[1] + 7.6, b[1] + 8.6];
                bx(b[0] + 0.6, b[0] + 6.4, rt[0], rt[1], 11.8, 17);
            }
            bx(24, 26, 16.8, 18.3, 13.4, 17); bx(33, 35, 16.8, 18.3, 13.4, 17);  // RP2040 hold-down
            bx(3.3, 5.3, 20, 22, 11.2, 17);  bx(3.3, 5.3, 45, 47, 11.2, 17);    // deck hold-down
            bx(36.7, 38.7, 45, 47, 11.2, 17);
        }
        for (p = INS) cy(p[0], p[1], 16.5, 19.5, screw_clear_d);
    }
}

// ---------------------------------------------------------------- output
if (part == "body") out() body();
if (part == "test") out() intersection() { body(); bx(-1, 24, -29, 2, -1, 40); }
if (part == "deck") out() translate([0, 0, -10]) deck();
if (part == "lid")  out() translate([0, 0, 19]) mirror([0, 0, 1]) lid();   // top face on the bed
if (part == "knob") knob();
if (part == "bar")  bar();
if (part == "assembly") out() { body(); deck(); lid(); for (d = DRAWERS) lift_parts(d); }
