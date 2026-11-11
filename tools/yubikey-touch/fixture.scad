// YubiKey touch fixture, rev F: body, deck, lid, plus a knob and a slide bar per pin. No glue.
//
// Render one part:  openscad -D 'part="body"' -o body.stl fixture.scad
// Parts: "body", "deck", "lid" (flipped for printing), "knob", "bar" (print one of each per pin),
//        "test" (north drawer + tower only), "assembly" (everything in place, for looking at).
//
// Pin lift (rev F): the pogo pin is pressed into a square knob that slides straight up and down in a
// square hole in the tower, so it can't turn and twist the wire. A 1.75 mm filament piece crosses the
// knob and runs in a slanted slot in a slide bar held in a sleeve on the tower's west face. Bar pushed
// south: pin pressed onto the touch disk. Bar pushed north: pin lifted pin_lift mm so the key slides
// freely. The flat ends of the slot hold the bar where it is left.
//
// Coordinates (mm): x runs west -> east, ty runs north -> south (the YubiKey 4 drawer is north,
// the YubiKey 5 drawer south), z is up from the bed. Everything is built in (x, ty, z) and
// mirrored into OpenSCAD's y = -ty at the end, so the part matches the sketch and the animation.
//
// The values marked MEASURE are taken from the AliExpress listings and YubiKey datasheets,
// not from the parts in hand. Check them with calipers before printing the full body.

part = "body";
lift_up = false;   // for "test_assembly": show the pin lifted

$fn = 48;

// ---------------------------------------------------------------- parameters
// YubiKey touch pads: pin positions along each drawer (MEASURE: connector edge -> pad centre)
pin_x       = 11.9;    // drawer centre line, also the key centre line
pin_ty_yk4  = -22;     // 21 mm north of the box wall
pin_ty_yk5  = 85;      // 23 mm south of the box wall

// pogo pin P75 (barrel 1.02 mm)
pin_len     = 15.85;   // barrel top to tip, plunger fully out (MEASURE)
pad_z       = 7.6;     // height of the touch disk in the tunnel: key on the floor, 3.3 thick, 0.3 dip (MEASURE)
pin_press   = 1.0;     // how far the plunger is pushed in when the pin is down on the disk
pin_lift    = 2.5;     // how far the bar lifts the pin; the tip then clears the key by ~1.2 mm
channel_d   = 1.6;     // touch-wire channel (30 AWG)

// knob and slide bar
knob_w      = 3.6;     // square knob, in a knob_w + 0.3 square hole
knob_z0     = 12.3;    // knob bottom when the pin is down
knob_h      = 18.2;    // sticks out 1.5 mm above the tower when down, 4 mm when up
knob_bore_d = 1.4;     // loose on the 1.02 barrel, so the tip passes; the solder joint rests on the slot floor
fil_d       = 1.75;    // filament cross pin
tower_w     = 7;       // square tower
tower_top   = 29;
barrel_top  = pad_z - pin_press + pin_len;   // 22.45 with the values above
fil_z       = barrel_top + fil_d / 2 + 0.03;   // the filament sits right on top of the barrel
bar_t       = 1.6;     // slide bar: 11 long x 6.9 tall x 1.6 thick
bar_len     = 11;
bar_h       = 6.9;
bar_v_low   = 2.2;     // slot height in the bar, from its bottom edge, for pin down / pin up
bar_u_down  = 1.5;     // slot positions along the bar where the filament rests (flat ends)
bar_u_up    = 9.5;
slot_w      = 1.95;

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
    tw = tower_w / 2; xf = pin_x - tw;                          // xf: west face of the tower
    bx(pin_x - tw, pin_x + tw, pty - tw, pty + tw, 11.8, tower_top);   // square pin tower
    bz = fil_z - bar_v_low;                                     // bar bottom edge
    bx(xf - bar_t - 1.05, xf, pty - tw, pty + tw, bz - 0.95, tower_top);   // sleeve for the slide bar
    hull() {                                                    // 45 degrees under the sleeve
        bx(xf - bar_t - 1.05, xf, pty - tw, pty + tw, bz - 0.96, bz - 0.95);
        bx(xf - 0.01, xf, pty - tw, pty + tw, bz - 0.95 - (bar_t + 1.05), bz - 0.95);
    }
    hull() {                                                    // sloped rib, carries the wire channel
        bx(9.9, 13.9, rb[0], rb[1], 11.8, 24.8);
        bx(18, 22, d[3], d[4], 11.8, 16.6);
    }
}

module drawer_cuts(d) {
    pty = d[2]; s = d[5];
    tw = tower_w / 2; xf = pin_x - tw; kh = knob_w / 2 + 0.15;
    bz = fil_z - bar_v_low;
    fz0 = fil_z - slot_w / 2 - 0.1; fz1 = fil_z + pin_lift + slot_w / 2 + 0.1;
    cy(pin_x, pty, 9.0, 12.1, 2.2, 24);                         // hole in the tunnel roof for the plunger
    bx(pin_x - kh, pin_x + kh, pty - kh, pty + kh, 12.0, tower_top + 1);   // square hole for the knob
    w = s > 0 ? [pty + kh - 0.1, pty + tw + 0.1] : [pty - tw - 0.1, pty - kh + 0.1];
    bx(pin_x - 0.8, pin_x + 0.8, w[0], w[1], barrel_top - 1.6, barrel_top + pin_lift + 1.05);   // wire slot, box side
    rod([pin_x, pty + s * 2.9, barrel_top - 0.4], d[6], channel_d);   // wire channel to the box
    bx(xf - 0.1, pin_x - kh + 0.1, pty - 1, pty + 1, fz0, fz1);   // filament slot, west wall
    bx(xf - bar_t - 0.25, xf + 0.01, pty - tw - 1, pty + tw + 1, bz - 0.15, bz + bar_h + 0.15);   // inside of the sleeve
    bx(xf - bar_t - 1.1, xf - bar_t - 0.2, pty - 1, pty + 1, fz0, fz1);   // window: push the filament in here
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

// ---------------------------------------------------------------- knob and slide bar (print orientation)
module knob() {   // bottom on the bed; the wire slot faces +y
    k = knob_w / 2;
    difference() {
        bx(-k, k, -k, k, 0, knob_h);
        cy(0, 0, -1, knob_h + 1, knob_bore_d, 24);                          // the barrel is pressed in from the top
        bx(-0.7, 0.7, 0, k + 1, barrel_top - knob_z0 - 1.3, knob_h + 1);    // wire slot, open at the top; its floor
                                                                            // catches the solder joint
        translate([0, 0, fil_z - knob_z0]) rotate([0, 90, 0]) cylinder(d = fil_d, h = knob_w + 2, center = true, $fn = 24);
    }
}

module bar() {   // flat on the bed; u runs along x, v along y
    pts = [[bar_u_down, bar_v_low], [bar_u_down + 1.5, bar_v_low],
           [bar_u_up - 1.5, bar_v_low + pin_lift], [bar_u_up, bar_v_low + pin_lift]];
    difference() {
        bx(0, bar_len, 0, bar_h, 0, bar_t);
        for (i = [0 : 2]) hull() for (p = [pts[i], pts[i + 1]]) cy(p[0], p[1], -1, bar_t + 1, slot_w, 24);
    }
}

// knob, filament and bar in place for one drawer; up = true shows the pin lifted
module lift_in_place(d, up = false) {
    pty = d[2]; s = d[5]; xf = pin_x - tower_w / 2; lz = up ? pin_lift : 0;
    translate([pin_x, pty, knob_z0 + lz]) mirror([0, s > 0 ? 0 : 1, 0]) knob();
    color("white") translate([xf - bar_t, pty, fil_z + lz]) rotate([0, 90, 0]) cylinder(d = fil_d, h = pin_x + knob_w / 2 - xf + bar_t, $fn = 16);
    u = up ? bar_u_up : bar_u_down;
    multmatrix([[0, 0, 1, xf - bar_t - 0.05], [1, 0, 0, pty - u], [0, 1, 0, fil_z - bar_v_low], [0, 0, 0, 1]]) bar();
}

// ---------------------------------------------------------------- output
if (part == "body") out() body();
if (part == "test") out() intersection() { body(); bx(-1, 24, -29, 2, -1, tower_top + 1); }
if (part == "knob") knob();
if (part == "bar")  bar();
if (part == "test_assembly") out() { intersection() { body(); bx(-1, 24, -29, 2, -1, tower_top + 1); } lift_in_place(DRAWERS[0], up = lift_up); }
if (part == "deck") out() translate([0, 0, -10]) deck();
if (part == "lid")  out() translate([0, 0, 19]) mirror([0, 0, 1]) lid();   // top face on the bed
if (part == "assembly") out() { body(); deck(); lid(); for (d = DRAWERS) lift_in_place(d); }
