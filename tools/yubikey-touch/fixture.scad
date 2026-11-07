// YubiKey touch fixture, rev E: three printed parts (body, deck, lid), no glue.
//
// Render one part:  openscad -D 'part="body"' -o body.stl fixture.scad
// Parts: "body", "deck", "lid" (flipped for printing), "test" (north drawer + tower only),
//        "assembly" (all three in place, for looking at).
//
// Coordinates (mm): x runs west -> east, ty runs north -> south (the YubiKey 4 drawer is north,
// the YubiKey 5 drawer south), z is up from the bed. Everything is built in (x, ty, z) and
// mirrored into OpenSCAD's y = -ty at the end, so the part matches the sketch and the animation.
//
// The values marked MEASURE are taken from the AliExpress listings and YubiKey datasheets,
// not from the parts in hand. Check them with calipers before printing the full body.

part = "body";

$fn = 48;

// ---------------------------------------------------------------- parameters
// YubiKey touch pads: pin positions along each drawer (MEASURE: connector edge -> pad centre)
pin_x       = 11.9;    // drawer centre line, also the key centre line
pin_ty_yk4  = -22;     // 21 mm north of the box wall
pin_ty_yk5  = 85;      // 23 mm south of the box wall

// pogo pin P75 (barrel 1.02 mm): printed holes come out ~0.1 mm small; ream with the pin vise if tight
bore_d      = 1.2;
chamber_d   = 2.6;     // wider pocket at the top of the tower; the barrel stops on its ceiling
access_d    = 2.0;     // hole in the drawer floor the pin is pushed up through
channel_d   = 1.6;     // touch-wire channel (30 AWG)

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
    cy(pin_x, pty, 11.8, 25.6, 6.0, 64);                        // pin tower
    hull() {                                                    // sloped rib, carries the wire channel
        bx(9.9, 13.9, rb[0], rb[1], 11.8, 24.8);
        bx(18, 22, d[3], d[4], 11.8, 16.6);
    }
}

module drawer_cuts(d) {
    pty = d[2]; s = d[5];
    cy(pin_x, pty, -1, 4.9, access_d);                          // hole in the drawer floor
    cy(pin_x, pty, 9.0, 22.5, bore_d, 24);                      // bore
    cy(pin_x, pty, 22.4, 24.4, chamber_d, 32);                  // chamber; the barrel stops on its ceiling
    w = s > 0 ? [pty - 3.3, pty - 0.7] : [pty + 0.7, pty + 3.3];
    bx(10.6, 13.2, w[0], w[1], 22.4, 25.0);                     // solder window, outer side of the tower
    rod([pin_x, pty, 23.5], d[6], channel_d);                   // wire channel to the box
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
if (part == "test") out() intersection() { body(); bx(-1, 24, -29, 2, -1, 30); }
if (part == "deck") out() translate([0, 0, -10]) deck();
if (part == "lid")  out() translate([0, 0, 19]) mirror([0, 0, 1]) lid();   // top face on the bed
if (part == "assembly") out() { body(); deck(); lid(); }
