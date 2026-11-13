// YubiKey touch fixture, rev G: body, deck, lid, plus a knob and a slide bar per pin. No glue.
//
// Render one part:  openscad -D 'part="body"' -o body.stl fixture.scad
// Parts: "body", "deck", "lid" (flipped for printing), "knob", "bar" (print one of each per pin),
//        "test" (north end: wall, hub seat, YubiKey 4 drawer and tower), "assembly" (for looking at).
//
// Rev G: the layout comes from the parts in hand, measured with calipers (hub board, sockets,
// adapters, keys). Both pins sit over the buttons, the hub (it has no mounting holes) rests on corner
// pads between fences, the box is tall enough for the U-turn adapter and the RP2040 above the hub,
// and the slide bar is thicker (the rev F bar broke coming off the plate).
//
// Pin lift: the pogo pin sits in a square knob that slides straight up and down in a square hole in
// the tower, so it can't turn and twist the wire. A 1.75 mm filament piece crosses the knob, rests on
// top of the pin barrel, and runs in a slanted slot in a slide bar held in a sleeve on the tower's
// west face. Bar pushed south: pin pressed onto the button. Bar pushed north: pin lifted pin_lift mm
// so the key slides freely. The flat ends of the slot hold the bar where it is left.
//
// Coordinates (mm): x runs west -> east, ty runs north -> south (the YubiKey 4 drawer is north,
// the YubiKey 5 drawer south), z is up from the bed. ty = 0 is the outside of the north wall.
// Everything is built in (x, ty, z) and mirrored into OpenSCAD's y = -ty at the end.
//
// Values marked MEASURE are still estimates.

part = "body";
lift_up = false;   // for "test_assembly": show the pin lifted

$fn = 48;

// ---------------------------------------------------------------- measured parts (calipers)
// hub board: USB-C input on the west edge, two USB-A sockets on the north edge, two on the south
hub_ns      = 32.3;   // board, north-south (along the USB-C edge)
hub_we      = 35.5;   // board, west-east
hub_t       = 1.6;    // board thickness (MEASURE)
sock_out    = 2.85;   // the A sockets stick out past the board edge: (38.0 - 32.3) / 2
sock_top    = 3.6;    // top of an A socket above the board top
sock_near   = 9.2;    // middle of the A sockets nearer the USB-C edge, from that edge (far ones 26.3)
sock_h      = 5.7;    // A socket shell height (USB standard)
adapter_out = 25.0;   // YubiKey 5 adapter: its USB-C face is this far past the south socket face (63.0 - 38.0)
uturn_h     = 25.1;   // U-turn adapter (RP2040): body height
uturn_below = 2.5;    // ... and how far it reaches below the bottom of its A plug
mcu_z       = 15.4;   // RP2040 board bottom above the hub board top
usbc_from_n = 17.0;   // middle of the hub's USB-C input from the board's north edge (MEASURE: from a photo; the wall hole is wide)
// keys: YubiKey 4 (USB-A) and YubiKey 5C NFC, button 10 mm across
yk4_btn     = 12.8;   // YubiKey 4 plugged into the hub: socket face -> start of the button
yk5_btn     = 14.7;   // YubiKey 5 plugged into its adapter: adapter face -> start of the button
btn_d       = 10;
yk4_plug_gap = 0.45;  // YubiKey 4 lying flat, button up: gap under its plug (MEASURE)
yk5_plug_gap = -0.6;  // YubiKey 5 + adapter lying flat: adapter's A plug bottom above the key's bottom (MEASURE)
yk5_neck    = [11.0, 3.7];   // hole in the south wall for the YubiKey 5's plug neck, width x height (MEASURE)

// ---------------------------------------------------------------- key drawers and pins
pin_x       = 11.9;    // drawer centre line, also the key centre line and the near sockets' middle
tunnel_x0 = 2.75;  tunnel_x1 = 21.05;   // 18.3 wide, YubiKey body 17.8
tunnel_z0 = 4.6;   tunnel_z1 = 9.8;     // 5.2 tall, YubiKey body 3.3 (in the drawer's own frame)

// pogo pin P75 (barrel 1.02 mm)
pin_len     = 16.5;    // barrel top to tip, plunger fully out (measured)
pad_z       = 7.6;     // height of the touch disk in the tunnel: key on the floor, 3.3 thick, 0.3 dip
pin_press   = 1.0;     // how far the plunger is pushed in when the pin is down on the disk
pin_lift    = 2.5;     // how far the bar lifts the pin; the tip then clears the key by ~1.5 mm
channel_d   = 1.6;     // touch-wire channel (30 AWG)

// knob and slide bar
knob_w      = 3.6;     // square knob, in a knob_w + 0.3 square hole
knob_bore_d = 1.4;     // loose on the 1.02 barrel, so the tip passes; the solder joint rests on the slot floor
fil_d       = 1.75;    // filament cross pin
tower_w     = 7;       // square tower
barrel_top  = pad_z - pin_press + pin_len;   // 23.1 with the values above
fil_z       = barrel_top + fil_d / 2 + 0.03;   // the filament sits right on top of the barrel
bar_t       = 2.4;     // slide bar: 13 long x 8.5 tall x 2.4 thick (rev F: 11 x 6.9 x 1.6 broke)
bar_len     = 13;
bar_h       = 8.5;
bar_v_low   = 3.0;     // slot height in the bar, from its bottom edge, for pin down (pin up: + pin_lift)
bar_u_down  = 2.5;     // slot positions along the bar where the filament rests (flat ends)
bar_u_up    = 10.5;
slot_w      = 1.95;
knob_z0     = barrel_top - 10.15;   // knob bottom when the pin is down
tower_top   = fil_z - bar_v_low + bar_h + 0.95;   // 0.8 mm roof over the bar sleeve
knob_h      = tower_top - knob_z0 + 1.5;          // sticks out 1.5 mm above the tower when down, 4 mm when up

// ---------------------------------------------------------------- box layout (derived)
wall    = 2;
box_w   = 42;
hub_x0  = pin_x - sock_near;      // board west edge, the USB-C side (2.7)
hub_x1  = hub_x0 + hub_we;        // board east edge (38.2); the RP2040 lines up with it
far_x   = hub_x1 - sock_near;     // middle of the far A sockets (29.0): the U-turn goes south here
n_face  = wall;                   // north socket faces touch the inside of the north wall
hub_t0  = n_face + sock_out;      // board north edge (4.85)
hub_t1  = hub_t0 + hub_ns;        // board south edge (37.15)
s_face  = hub_t1 + sock_out;      // south socket faces (40.0)
a_face  = s_face + adapter_out;   // YubiKey 5 adapter face = inside of the south wall (65.0)
box_l   = a_face + wall;          // 67.0
usbc_t  = hub_t0 + usbc_from_n;

sock_floor = sock_h - sock_top - 0.3;                  // socket opening floor below the board top (1.8)
hub_top    = tunnel_z0 + sock_floor + yk4_plug_gap;    // board top: the YubiKey 4 then lies on its tunnel floor
plug_bot   = hub_top - sock_floor + 0.3;               // bottom of a full-size A plug (the adapters) in a socket
yk5_dz     = plug_bot - yk5_plug_gap - tunnel_z0;      // the south drawer is raised so the YubiKey 5 lies on its floor
uturn_top  = plug_bot - uturn_below + uturn_h;
mcu_bot    = hub_top + mcu_z;
lid_z      = uturn_top + 0.8;                          // underside of the lid
box_h      = lid_z + 2;
deck_z0    = hub_top + sock_top;                       // the deck rests on the A sockets
deck_z1    = deck_z0 + 1.2;

pin_ty_yk4 = n_face - (yk4_btn + btn_d / 2);   // -15.8: over the YubiKey 4 button
pin_ty_yk5 = a_face + yk5_btn + btn_d / 2;     //  84.7: over the YubiKey 5 button

// M2 heat-set insert 3.5 OD x 3: hole 3.2, pressed in with the Pinecil at ~220 C (PLA)
insert_hole_d = 3.2;
screw_clear_d = 2.3;
INS = [[4.2, a_face - 2.8], [36.5, a_face - 3.5]];

// ---------------------------------------------------------------- helpers
module bx(x0, x1, t0, t1, z0, z1) { translate([x0, t0, z0]) cube([x1 - x0, t1 - t0, z1 - z0]); }
module cy(x, t, z0, z1, d, fn = $fn) { translate([x, t, z0]) cylinder(d = d, h = z1 - z0, $fn = fn); }
module rod(p1, p2, d) { hull() { translate(p1) sphere(d = d, $fn = 16); translate(p2) sphere(d = d, $fn = 16); } }
module out() { mirror([0, 1, 0]) children(); }

// ---------------------------------------------------------------- body
DRAWERS = [  // t0, t1, pin ty, rib wall end ty0..ty1, s (+1 north drawer, -1 south), channel exit, dz
    [-28, 0, pin_ty_yk4, -1.0, 0.0, 1, [20, n_face + 0.6, 14.0], 0],
    [box_l, box_l + 28, pin_ty_yk5, box_l, box_l + 1, -1, [20, a_face - 0.6, 14.0], yk5_dz]];

module drawer(d) {
    t0 = d[0]; t1 = d[1]; pty = d[2]; s = d[5];
    if (d[7] > 0) bx(0.75, 23.05, t0, t1, 0, d[7] + 0.01);     // raises the drawer
    translate([0, 0, d[7]]) {
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
}

module drawer_cuts(d) {
    pty = d[2]; s = d[5];
    tw = tower_w / 2; xf = pin_x - tw; kh = knob_w / 2 + 0.15;
    bz = fil_z - bar_v_low;
    fz0 = fil_z - slot_w / 2 - 0.1; fz1 = fil_z + pin_lift + slot_w / 2 + 0.1;
    translate([0, 0, d[7]]) {
        cy(pin_x, pty, 9.0, 12.1, 2.2, 24);                         // hole in the tunnel roof for the plunger
        bx(pin_x - kh, pin_x + kh, pty - kh, pty + kh, 12.0, tower_top + 1);   // square hole for the knob
        w = s > 0 ? [pty + kh - 0.1, pty + tw + 0.1] : [pty - tw - 0.1, pty - kh + 0.1];
        bx(pin_x - 0.8, pin_x + 0.8, w[0], w[1], barrel_top - 1.6, barrel_top + pin_lift + 1.05);   // wire slot, box side
        rod([pin_x, pty + s * 2.9, barrel_top - 0.4], d[6], channel_d);   // wire channel to the box
        bx(xf - 0.1, pin_x - kh + 0.1, pty - 1, pty + 1, fz0, fz1);   // filament slot, west wall
        bx(xf - bar_t - 0.25, xf + 0.01, pty - tw - 1, pty + tw + 1, bz - 0.15, bz + bar_h + 0.15);   // inside of the sleeve
        bx(xf - bar_t - 1.1, xf - bar_t - 0.2, pty - 1, pty + 1, fz0, fz1);   // window: push the filament in here
    }
}

// 45 degree support under a block that hangs off the inside of the south wall
module south_chamfer(x0, x1, t0, zb) {
    hull() { bx(x0, x1, t0, a_face, zb - 0.01, zb); bx(x0, x1, a_face - 0.01, a_face, zb - (a_face - t0), zb); }
}

// the hub has no mounting holes: it sits on four corner pads between low fences, with its north
// socket faces against the north wall; the deck on top of the sockets holds it down
module hub_seat() {
    hb = hub_top - hub_t;      // board underside
    ft = hub_top + 1;          // fences reach 1 mm above the board top
    for (x = [hub_x0 + 0.2, hub_x1 - 2.4]) for (t = [hub_t0 + 0.2, hub_t1 - 2.4]) bx(x, x + 2.2, t, t + 2.2, 1, hb);
    for (t = [hub_t0 + 0.5, hub_t1 - 3.5]) {
        bx(1, hub_x0 - 0.15, t, t + 3, 1, ft);                     // west, clear of the USB-C hole
        bx(hub_x1 + 0.15, box_w - 1, t, t + 3, 1, ft);             // east
    }
    for (x = [[hub_x0, hub_x0 + 2.4], [pin_x + 7.0, far_x - 7.0], [hub_x1 - 2.4, hub_x1]])
        bx(x[0], x[1], hub_t1 + 0.15, hub_t1 + 1.5, 1, ft);       // south, between the sockets
}

module body() {
    ie = box_w - wall;   // inside of the east wall
    difference() {
        union() {
            bx(0, box_w, 0, box_l, 0, 1.4);                                       // floor
            bx(0, box_w, 0, wall, 0, box_h);  bx(0, box_w, a_face, box_l, 0, box_h);   // walls
            bx(0, wall, 0, box_l, 0, box_h);  bx(ie, box_w, 0, box_l, 0, box_h);
            // lid ledges, 45 degrees underneath
            hull() { bx(wall, wall + 1, 3, a_face - 8, lid_z - 1, lid_z); bx(wall, wall + 0.01, 3, a_face - 8, lid_z - 2, lid_z); }
            hull() { bx(ie - 1, ie, 3, a_face - 8, lid_z - 1, lid_z); bx(ie - 0.01, ie, 3, a_face - 8, lid_z - 2, lid_z); }
            // insert blocks, hanging off the south wall
            ib = lid_z - 5.4;
            bx(33, ie, a_face - 7, a_face, ib, lid_z);  south_chamfer(33, ie, a_face - 7, ib);
            bx(wall, 6.3, a_face - 7, a_face, ib, lid_z);  south_chamfer(wall, 6.3, a_face - 7, ib);
            bx(wall, 13, a_face - 3.7, a_face, ib, lid_z); south_chamfer(wall, 13, a_face - 3.7, ib);
            hub_seat();
            for (d = DRAWERS) drawer(d);
        }
        // YubiKey 4 plug into the north socket (the hole is a little bigger than the socket)
        bx(5.0, 18.8, -1, wall + 1, tunnel_z0 - 0.2, deck_z0 + 0.3);
        // YubiKey 5 plug neck through the south wall; the adapter face bears on the wall
        k5 = tunnel_z0 + yk5_dz;
        bx(pin_x - yk5_neck[0] / 2, pin_x + yk5_neck[0] / 2, a_face - 1, box_l + 1, k5 - 0.2, k5 - 0.2 + yk5_neck[1]);
        // the laptop's USB-C plug into the hub (wide, so the plug's body fits too)
        bx(-1, wall + 1, usbc_t - 7.5, usbc_t + 7.5, hub_top - 2.5, hub_top + 5.5);
        bx(11.6, 30.4, 1.1, 2.2, lid_z + 0.1, lid_z + 1.3);                     // slot for the lid's tab
        for (p = INS) cy(p[0], p[1], lid_z - 4.2, lid_z + 0.2, insert_hole_d);
        for (d = DRAWERS) drawer_cuts(d);
    }
}

// ---------------------------------------------------------------- deck (sits on the hub sockets)
BOARDS = [[3.5, 6], [11.5, 6], [3.5, 28], [11.5, 28]];   // AO3401 / 2N7002 boards, 7 x 9
MCU_POSTS = [[22, 18.5], [37, 18.5]];                     // under the RP2040's far end

module deck() {
    difference() {
        bx(3.4, 38.6, 2.5, s_face - 0.3, deck_z0, deck_z1);   // ends before the U-turn and the adapter
        bx(4, 18.5, 15.5, 17.9, deck_z0 - 1, deck_z1 + 1);    // wire slots
        bx(4, 18.5, 24.3, 27.5, deck_z0 - 1, deck_z1 + 1);
        for (b = BOARDS) bx(b[0] - 0.15, b[0] + 7.15, b[1] - 0.15, b[1] + 9.15, deck_z1 - 0.6, deck_z1 + 0.4);   // board pockets
    }
    for (p = MCU_POSTS) bx(p[0] - 1, p[0] + 1, p[1] - 1, p[1] + 1, deck_z1, mcu_bot - 0.1);   // RP2040 rests on these
}

// ---------------------------------------------------------------- lid (drops in 1 mm south, slides north)
module lid() {
    difference() {
        union() {
            bx(2.3, box_w - 2.3, 2.3, a_face - 1, lid_z, lid_z + 2);   // 0.3 mm clear of the walls
            bx(12, 30, 1.3, 2.4, lid_z + 0.3, lid_z + 1.1);                // tab into the north wall slot
            for (b = [[3.5, 6, 0], [11.5, 6, 0], [3.5, 28, 1], [11.5, 28, 1]]) {   // ribs holding the boards down
                rt = b[2] == 0 ? [b[1] + 0.4, b[1] + 2.0] : [b[1] + 7.0, b[1] + 8.6];
                bx(b[0] + 0.6, b[0] + 6.4, rt[0], rt[1], deck_z1 + 0.6, lid_z);
            }
            for (x = [24, 33]) bx(x, x + 2, 17.0, 18.5, mcu_bot + 1.1, lid_z);   // RP2040 hold-down
            bx(3.3, 5.3, 20, 22, deck_z1, lid_z);                                // deck hold-down
            bx(36.7, 38.7, 5, 7, deck_z1, lid_z);
            bx(19.0, 20.4, 33, 35, deck_z1, lid_z);
        }
        for (p = INS) cy(p[0], p[1], lid_z - 0.5, lid_z + 2.5, screw_clear_d);
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
    translate([0, 0, d[7]]) {
        translate([pin_x, pty, knob_z0 + lz]) mirror([0, s > 0 ? 0 : 1, 0]) knob();
        color("white") translate([xf - bar_t, pty, fil_z + lz]) rotate([0, 90, 0]) cylinder(d = fil_d, h = pin_x + knob_w / 2 - xf + bar_t, $fn = 16);
        u = up ? bar_u_up : bar_u_down;
        multmatrix([[0, 0, 1, xf - bar_t - 0.05], [1, 0, 0, pty - u], [0, 1, 0, fil_z - bar_v_low], [0, 0, 0, 1]]) bar();
    }
}

// ---------------------------------------------------------------- output
TEST = [-1, box_w + 1, -29, 12, -1, max(tower_top, box_h) + 1];   // north end: wall, hub seat, drawer
module test_piece() { intersection() { body(); bx(TEST[0], TEST[1], TEST[2], TEST[3], TEST[4], TEST[5]); } }

if (part == "body") out() body();
if (part == "test") out() test_piece();
if (part == "knob") knob();
if (part == "bar")  bar();
if (part == "test_assembly") out() { test_piece(); lift_in_place(DRAWERS[0], up = lift_up); }
if (part == "deck") out() translate([0, 0, -deck_z0]) deck();
if (part == "lid")  out() translate([0, 0, lid_z + 2]) mirror([0, 0, 1]) lid();   // top face on the bed
if (part == "assembly") out() { body(); deck(); lid(); for (d = DRAWERS) lift_in_place(d); }
