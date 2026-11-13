// YubiKey touch fixture, rev G: body, deck, lid, plus a knob and a slide bar per pin. No glue.
//
// Render one part:  openscad -D 'part="body"' -o body.stl fixture.scad
// Parts: "body", "deck", "lid" (flipped for printing), "knob", "bar" (print one of each per pin),
//        "test" (north drawer, tower and the north strip of the box), "assembly" (everything in place,
//        for looking at), "test_assembly" (the test piece with its knob and bar).
//
// Pin lift: the pogo pin is pressed into a square knob that slides straight up and down in a
// square hole in the tower, so it can't turn and twist the wire. A 1.75 mm filament piece crosses the
// knob and runs in a slanted slot in a slide bar held in a sleeve on the tower's west face. Bar pushed
// south: pin pressed onto the touch disk. Bar pushed north: pin lifted pin_lift mm so the key slides
// freely. The flat ends of the slot hold the bar where it is left.
//
// Coordinates (mm): x runs west -> east, ty runs north -> south (the YubiKey 4 drawer is north,
// the YubiKey 5 drawer south), z is up from the bed. Everything is built in (x, ty, z) and
// mirrored into OpenSCAD's y = -ty at the end, so the part matches the sketch and the animation.
// ty = 0 is the north socket face, flush with the outer face of the north wall.
//
// Rev G: the hub, sockets, keys, U-turn adapter and RP2040 height are measured with calipers. They
// are the datums below, and every hub, socket, pin, tunnel and lid position is derived from them.
// The few values still assumed are marked MEASURE; the README lists them.

part = "body";
lift_up = false;   // for "test_assembly": show the pin lifted

$fn = 48;

// ---------------------------------------------------------------- measured datums
// Everything below the datums is derived from them. "measured" = calipers on the parts in hand,
// "MEASURE" = assumed, check it (see the README). A1..A6 are the assumptions listed in the README.
hub_w       = 32.3;    // hub board along the socket edges, x (measured; A1)
hub_l       = 35.5;    // hub board along the USB-C edge, ty (measured; A1)
hub_t       = 1.6;     // hub board thickness (MEASURE)
sock_out    = 2.85;    // A socket face past the board edge (measured)
sock_above  = 3.6;     // A socket shell top above the board top (measured; A2)
sock_h      = 7.0;     // A socket shell height, centred about on the board (MEASURE; A2)
sock_w      = 13.1;    // A socket shell width (MEASURE; A6)
sock_x      = 9.2;     // near A socket centre from the USB-C (west) edge (measured)
sock_x2     = hub_w - sock_x;   // far south socket, for the U-turn: mirrored (MEASURE; A6)
yk4_btn     = 12.8;    // YubiKey 4: socket face to the start of the touch button (measured)
yk5_btn     = 14.7;    // YubiKey 5: adapter face to the start of the touch button (measured)
btn_d       = 10;      // touch button across (measured)
yk5_face    = 63.0;    // YubiKey 5 adapter face from the north socket face (measured)
uturn_h     = 25.1;    // U-turn adapter height (measured)
uturn_below = 2.5;     // U-turn reaches this far below its A plug (measured; A4)
uturn_plug  = 4.5;     // USB-A plug height (standard)
uturn_w     = 12;      // U-turn adapter width in x, centred on its socket (MEASURE; A5)
rp_above    = 15.4;    // RP2040-Zero PCB underside above the hub board top (measured; A3)
rp_pcb_t    = 1.0;     // RP2040-Zero PCB thickness (MEASURE)
rp_w        = 18;      // RP2040-Zero PCB in x (standard, 18 x 23.5)
rp_l        = 23.5;    // in ty, its USB-C at the south end in the U-turn
rp_t0       = 16.8;    // RP2040 PCB north edge (MEASURE; A5: follows the U-turn's depth)
rp_h        = 4.4;     // RP2040-Zero PCB underside to the top of its USB-C socket (MEASURE)
key_t       = 3.3;     // key body thickness (YubiKey 4 and 5)
yk4_dz      = 0;       // key body centre above its connector centre (MEASURE)
yk5_dz      = 0;

// box
wall_t      = 2;
box_w       = 42;
floor_t     = 1.4;
n_in        = wall_t;               // north wall: ty 0..2, its outer face is the north socket face
s_out       = yk5_face;             // south wall: its outer face is the YubiKey 5 adapter face
s_in        = s_out - wall_t;
uturn_clear = 0.75;                 // U-turn above the floor
lid_clear   = 1.2;                  // lid underside above the U-turn and the RP2040
lid_t       = 2;

// ---------------------------------------------------------------- derived positions
hub_x0      = n_in + 0.3;           // board west edge, 0.3 off the west wall
hub_x1      = hub_x0 + hub_w;
hub_t0      = sock_out;             // board north edge
hub_t1      = sock_out + hub_l;     // board south edge
sock_s      = hub_t1 + sock_out;    // south socket face
hub_z       = floor_t + uturn_clear + uturn_plug / 2 + uturn_below - (sock_above - sock_h / 2);   // board top
sock_c      = hub_z + sock_above - sock_h / 2;   // A socket centre
uturn_z0    = sock_c - uturn_plug / 2 - uturn_below;
uturn_z1    = uturn_z0 + uturn_h;
rp_z        = hub_z + rp_above;     // RP2040 PCB underside
rp_top      = rp_z + rp_h;
lid_z0      = max(uturn_z1, rp_top) + lid_clear;   // lid underside
box_h       = lid_z0 + lid_t;
deck_z0     = hub_z + sock_above;   // the deck sits on the socket tops
deck_z1     = deck_z0 + 1.2;
usbc_ty     = hub_t0 + hub_l / 2;   // hub USB-C input centre: mid-board (MEASURE)
usbc_z      = hub_z - hub_t / 2;    // on the board mid-plane (MEASURE)
uturn_x     = hub_x0 + sock_x2;     // U-turn adapter and RP2040 centre line
rp_x0       = uturn_x - rp_w / 2;
rp_x1       = uturn_x + rp_w / 2;
rp_t1       = rp_t0 + rp_l;
notch_x0    = uturn_x - uturn_w / 2 - 0.5;   // deck notch round the U-turn
notch_x1    = uturn_x + uturn_w / 2 + 0.5;

// YubiKey touch pads: pins over the button centres
pin_x       = hub_x0 + sock_x;      // drawer centre line, also the key centre line
pin_ty_yk4  = -(yk4_btn + btn_d / 2);
pin_ty_yk5  = yk5_face + yk5_btn + btn_d / 2;

// pogo pin P75 (barrel 1.02 mm)
pin_len     = 16.5;    // barrel top to tip, plunger fully out (measured)
pin_press   = 1.0;     // how far the plunger is pushed in when the pin is down on the disk
pin_lift    = 2.5;     // how far the bar lifts the pin; the tip then clears the key by ~1.2 mm
channel_d   = 1.6;     // touch-wire channel (30 AWG)

// key tunnels, per drawer from the key centre kc: 18.3 x 5.2 for a key body of 18 x 3.3.
// The key rests on the tunnel floor; the touch disk is 0.3 below its top face.
tunnel_w    = 18.3;
tunnel_h    = 5.2;
function tun_z0(kc)     = kc - key_t / 2 - 0.2;
function tun_z1(kc)     = tun_z0(kc) + tunnel_h;
function roof_z(kc)     = tun_z1(kc) + 2;         // top of the 2 mm tunnel roof
function pad_z(kc)      = tun_z0(kc) + key_t - 0.3;
function barrel_top(kc) = pad_z(kc) - pin_press + pin_len;
function fil_z(kc)      = barrel_top(kc) + fil_d / 2 + 0.03;   // the filament sits right on top of the barrel
function knob_z0(kc)    = barrel_top(kc) - 10.15;              // knob bottom when the pin is down
function tower_top(kc)  = fil_z(kc) - bar_v_low + bar_h + 0.95;   // 0.8 mm roof over the bar sleeve
yk4_kc      = sock_c + yk4_dz;
yk5_kc      = sock_c + yk5_dz;      // the adapter is straight, so its socket is on the A socket centre

// knob and slide bar
knob_w      = 3.6;     // square knob, in a knob_w + 0.3 square hole
knob_bore_d = 1.4;     // loose on the 1.02 barrel, so the tip passes; the solder joint rests on the slot floor
fil_d       = 1.75;    // filament cross pin
tower_w     = 7;       // square tower
slot_w      = 1.95;
bar_t       = 2.4;     // slide bar
bar_u_down  = slot_w / 2 + 2.0;       // slot positions along the bar where the filament rests (flat ends)
bar_u_up    = bar_u_down + 8;
bar_len     = bar_u_up + slot_w / 2 + 2.0;
bar_v_low   = slot_w / 2 + 1.8;       // slot height in the bar, from its bottom edge, for pin down / pin up
bar_h       = bar_v_low + pin_lift + slot_w / 2 + 1.8;
bar_r       = 1;                      // rounded outer corners
knob_h      = tower_top(0) - knob_z0(0) + 1.5;   // sticks out 1.5 mm above the tower when down, 4 mm when up
fil_len     = tower_w / 2 + knob_w / 2 + 0.15 + bar_t + 0.45;   // sleeve window to the tower's far wall, 0.6 short

// M2 heat-set insert 3.5 OD x 3: hole 3.2, pressed in with the Pinecil at ~220 C (PLA)
insert_hole_d = 3.2;
screw_clear_d = 2.3;
INS = [[4.2, s_in - 2.8], [36.5, s_in - 3.5]];

// hub hold: corner pads under the board, fences round it
pad_w       = 2.0;     // x, clear of the socket shells hanging below the board
pad_l       = 4.0;     // ty
fence_t     = 1.2;
fence_z     = hub_z + 1.5;
SOCKS_N     = [sock_x];               // A socket centres from the board's west edge, north edge (A6)
SOCKS_S     = [sock_x, sock_x2];      // south edge: YubiKey 5 adapter, U-turn
PADS = [for (t = [hub_t0, hub_t1 - pad_l]) for (x = [hub_x0, hub_x1 - pad_w]) [x, t]];

yk4_opening  = [pin_x - 6.9, pin_x + 6.9, sock_c - 3.9, sock_c + 3.9];   // x0 x1 z0 z1 through the north wall
yk5_recess   = [pin_x - 4.3, pin_x + 4.3, yk5_kc - 1.5, yk5_kc + 1.5];   // through the south wall
plug_opening = [usbc_ty - 4.2, usbc_ty + 4.2, usbc_z - 1.7, usbc_z + 1.7];   // ty0 ty1 z0 z1 through the west wall

// wire channels leave the drawers 0.6 inside the box walls, above the deck
exit_x      = 20;
exit_z      = deck_z1 + 2.4;

// ---------------------------------------------------------------- checks
assert(lid_z0 - uturn_z1 >= 1.0, "U-turn adapter too close to the lid");
assert(lid_z0 - rp_top >= 1.0, "RP2040 too close to the lid");
assert(uturn_z0 - floor_t >= 0.5, "U-turn adapter too close to the floor");
eps = 1e-6;
assert(bar_u_down - slot_w / 2 >= 1.8 - eps && bar_len - bar_u_up - slot_w / 2 >= 1.8 - eps, "bar end wall under 1.8");
assert(bar_v_low - slot_w / 2 >= 1.8 - eps && bar_h - bar_v_low - pin_lift - slot_w / 2 >= 1.8 - eps, "bar edge under 1.8");
for (p = PADS) for (x = (p[1] < hub_t0 + hub_l / 2 ? SOCKS_N : SOCKS_S))
    assert(p[0] + pad_w <= hub_x0 + x - sock_w / 2 || p[0] >= hub_x0 + x + sock_w / 2, "hub pad overlaps a socket");
for (x = concat(SOCKS_N, SOCKS_S))
    assert(x - sock_w / 2 >= 0 && x + sock_w / 2 <= hub_w, "A socket hangs off the hub board");
assert(notch_x0 <= uturn_x - uturn_w / 2 - 0.3 && notch_x1 >= uturn_x + uturn_w / 2 + 0.3, "deck notch hits the U-turn adapter");
for (b = LID_RIBS) assert(b[3] <= rp_t0 || b[2] >= rp_t1 || b[1] <= rp_x0 - 0.3 || b[0] >= rp_x1 + 0.3,
                          "lid rib hits the RP2040");
for (p = RP_POSTS) {
    assert(p[0] >= rp_x0 && p[1] <= rp_x1 && p[2] >= rp_t0 && p[3] <= rp_t1, "RP2040 cradle post not under the RP2040");
    for (c = concat(WIRE_SLOTS, [for (b = BOARDS) [b[0] - 0.15, b[0] + 7.15, b[1] - 0.15, b[1] + 9.15]]))
        assert(p[1] <= c[0] - 0.3 || p[0] >= c[1] + 0.3 || p[3] <= c[2] - 0.3 || p[2] >= c[3] + 0.3,
               "RP2040 cradle post on a switch-board pocket or wire slot");
}
for (e = [[exit_x, n_in + 0.6, exit_z], [exit_x, s_in - 0.6, exit_z]])
    assert(e[0] - channel_d / 2 > wall_t && e[0] + channel_d / 2 < box_w - wall_t && e[1] >= n_in && e[1] <= s_in
           && e[2] - channel_d / 2 > deck_z1 && e[2] + channel_d / 2 < lid_z0, "wire channel exit outside the box interior");

echo(str("pin_ty_yk4 = ", pin_ty_yk4, ", pin_ty_yk5 = ", pin_ty_yk5, ", pin_x = ", pin_x));
echo(str("hub_z = ", hub_z, ", socket centre = ", sock_c, ", U-turn ", uturn_z0, "..", uturn_z1,
         ", RP2040 top = ", rp_top, ", lid underside = ", lid_z0, ", box height = ", box_h));
echo(str("U-turn x = ", uturn_x, ", deck notch x = ", notch_x0, "..", notch_x1, ", RP2040 x = ", rp_x0, "..", rp_x1,
         ", cradle posts x = ", [for (i = [0 : 2 : len(RP_POSTS) - 1]) [RP_POSTS[i][0], RP_POSTS[i][1]]]));
echo(str("tower top = ", tower_top(yk4_kc), ", knob_h = ", knob_h, ", bar = ", bar_len, " x ", bar_h, " x ", bar_t,
         ", filament length = ", fil_len));

// ---------------------------------------------------------------- helpers
module bx(x0, x1, t0, t1, z0, z1) { translate([x0, t0, z0]) cube([x1 - x0, t1 - t0, z1 - z0]); }
module cy(x, t, z0, z1, d, fn = $fn) { translate([x, t, z0]) cylinder(d = d, h = z1 - z0, $fn = fn); }
module rod(p1, p2, d) { hull() { translate(p1) sphere(d = d, $fn = 16); translate(p2) sphere(d = d, $fn = 16); } }
module out() { mirror([0, 1, 0]) children(); }

// ---------------------------------------------------------------- body
DRAWERS = [  // t0, t1, pin ty, rib wall end ty0..ty1, s (+1 north drawer, -1 south), channel exit, key centre z
    [-28, 0,  pin_ty_yk4, -1.0, 0.0,  1, [exit_x, n_in + 0.6, exit_z], yk4_kc],
    [s_out, s_out + 28, pin_ty_yk5, s_out, s_out + 1, -1, [exit_x, s_in - 0.6, exit_z], yk5_kc]];

module drawer(d) {
    t0 = d[0]; t1 = d[1]; pty = d[2]; s = d[5]; kc = d[7];
    tz0 = tun_z0(kc); tz1 = tun_z1(kc); rz = roof_z(kc); tt = tower_top(kc);
    x0 = pin_x - tunnel_w / 2; x1 = pin_x + tunnel_w / 2;      // tunnel walls
    dx0 = x0 - 2; dx1 = x1 + 2;                                 // drawer sides
    rb = s > 0 ? [pty - 0.5, pty + 2] : [pty - 2, pty + 0.5];
    bx(dx0, dx1, t0, t1, 0, tz0);                               // floor
    bx(dx0, x0, t0, t1, tz0, tz1);                              // rails
    bx(x1, dx1, t0, t1, tz0, tz1);
    bx(dx0, dx1, t0, t1, tz1, rz);                              // roof
    tw = tower_w / 2; xf = pin_x - tw;                          // xf: west face of the tower
    bx(pin_x - tw, pin_x + tw, pty - tw, pty + tw, rz, tt);     // square pin tower
    bz = fil_z(kc) - bar_v_low;                                 // bar bottom edge
    bx(xf - bar_t - 1.05, xf, pty - tw, pty + tw, bz - 0.95, tt);   // sleeve for the slide bar
    hull() {                                                    // 45 degrees under the sleeve
        bx(xf - bar_t - 1.05, xf, pty - tw, pty + tw, bz - 0.96, bz - 0.95);
        bx(xf - 0.01, xf, pty - tw, pty + tw, bz - 0.95 - (bar_t + 1.05), bz - 0.95);
    }
    hull() {                                                    // sloped rib, carries the wire channel
        bx(pin_x - 2, pin_x + 2, rb[0], rb[1], rz, barrel_top(kc) + 1.7);
        bx(d[6][0] - 2, d[6][0] + 2, d[3], d[4], rz, d[6][2] + 2.6);
    }
}

module drawer_cuts(d) {
    pty = d[2]; s = d[5]; kc = d[7];
    tw = tower_w / 2; xf = pin_x - tw; kh = knob_w / 2 + 0.15;
    bt = barrel_top(kc); fz = fil_z(kc); rz = roof_z(kc);
    bz = fz - bar_v_low;
    fz0 = fz - slot_w / 2 - 0.1; fz1 = fz + pin_lift + slot_w / 2 + 0.1;
    cy(pin_x, pty, tun_z1(kc) - 0.8, rz + 0.3, 2.2, 24);       // hole in the tunnel roof for the plunger
    bx(pin_x - kh, pin_x + kh, pty - kh, pty + kh, rz + 0.2, tower_top(kc) + 1);   // square hole for the knob
    w = s > 0 ? [pty + kh - 0.1, pty + tw + 0.1] : [pty - tw - 0.1, pty - kh + 0.1];
    bx(pin_x - 0.8, pin_x + 0.8, w[0], w[1], bt - 1.6, bt + pin_lift + 1.05);   // wire slot, box side
    rod([pin_x, pty + s * 2.9, bt - 0.4], d[6], channel_d);    // wire channel to the box
    bx(xf - 0.1, pin_x - kh + 0.1, pty - 1, pty + 1, fz0, fz1);   // filament slot, west wall
    bx(xf - bar_t - 0.25, xf + 0.01, pty - tw - 1, pty + tw + 1, bz - 0.15, bz + bar_h + 0.15);   // inside of the sleeve
    bx(xf - bar_t - 1.1, xf - bar_t - 0.2, pty - 1, pty + 1, fz0, fz1);   // window: push the filament in here
}

// 45 degree support under an overhanging block that hangs off the south wall
module south_chamfer(x0, x1, t0, zb) {
    hull() { bx(x0, x1, t0, s_in, zb - 0.01, zb); bx(x0, x1, s_in - 0.01, s_in, zb - (s_in - t0), zb); }
}

// hub hold: pads under the board corners, fences round its edges with gaps at the sockets
module hub_hold() {
    for (p = PADS) bx(p[0], p[0] + pad_w, p[1], p[1] + pad_l, floor_t - 0.01, hub_z - hub_t);
    fx1 = hub_x1 + 0.3 + fence_t;
    bx(hub_x1 + 0.3, fx1, hub_t0 - 0.3, hub_t1 + 0.3 + fence_t, floor_t - 0.01, fence_z);   // east
    for (e = [[SOCKS_N, n_in - 0.01, hub_t0 - 0.3], [SOCKS_S, hub_t1 + 0.3, hub_t1 + 0.3 + fence_t]]) {
        g = [for (x = e[0]) [hub_x0 + x - sock_w / 2 - 0.5, hub_x0 + x + sock_w / 2 + 0.5]];   // socket gaps
        ends = concat([wall_t - 0.01], [for (i = g) each i], [fx1]);
        for (i = [0 : 2 : len(ends) - 1]) if (ends[i + 1] > ends[i])
            bx(ends[i], ends[i + 1], e[1], e[2], floor_t - 0.01, fence_z);
    }
}

module body() {
    lz = lid_z0; bz = lz - 5.4;                                          // insert blocks hang bz..lz
    difference() {
        union() {
            bx(0, box_w, 0, s_out, 0, floor_t);                              // floor
            bx(0, box_w, 0, n_in, 0, box_h);  bx(0, box_w, s_in, s_out, 0, box_h);   // walls
            bx(0, wall_t, 0, s_out, 0, box_h);  bx(box_w - wall_t, box_w, 0, s_out, 0, box_h);
            // lid ledges, 45 degrees underneath; gap over the hub's USB-C input
            for (r = [[3, usbc_ty - 5], [usbc_ty + 5, s_in - 8]])
                hull() { bx(2, 3, r[0], r[1], lz - 1, lz); bx(2, 2.01, r[0], r[1], lz - 2, lz); }
            hull() { bx(39, 40, 3, s_in - 8, lz - 1, lz); bx(39.99, 40, 3, s_in - 8, lz - 2, lz); }
            // insert blocks; west one L-shaped so the YubiKey 5 adapter can be lowered past it
            bx(33, 40, s_in - 7, s_in, bz, lz);  south_chamfer(33, 40, s_in - 7, bz);
            bx(2, 6.3, s_in - 7, s_in, bz, lz);  south_chamfer(2, 6.3, s_in - 7, bz);
            bx(2, 13, s_in - 3.7, s_in, bz, lz); south_chamfer(2, 13, s_in - 3.7, bz);
            hub_hold();
            for (d = DRAWERS) drawer(d);
        }
        bx(yk4_opening[0], yk4_opening[1], -1, n_in + 1, yk4_opening[2], yk4_opening[3]);
        bx(yk5_recess[0], yk5_recess[1], s_in - 5, s_out + 1, yk5_recess[2], yk5_recess[3]);
        bx(-1, wall_t + 1, plug_opening[0], plug_opening[1], plug_opening[2], plug_opening[3]);
        bx(11.6, 30.4, 1.1, 2.2, lz + 0.1, lz + 1.3);                        // slot for the lid's tab
        for (p = INS) cy(p[0], p[1], lz - 4.2, lz + 0.2, insert_hole_d);
        for (d = DRAWERS) drawer_cuts(d);
    }
}

// ---------------------------------------------------------------- deck (sits on the hub sockets)
BOARDS = [[3.5, 6], [11.5, 6], [3.5, 28], [11.5, 28]];   // AO3401 / 2N7002 boards, 7 x 9
brd_top = deck_z1 + 0.6;                                 // board top face in its pocket
// lid ribs holding the boards down, x0 x1 ty0 ty1; the south-west one stops 0.5 short of the RP2040
LID_RIBS = [for (b = [[3.5, 6, 0], [11.5, 6, 0], [3.5, 28, 1], [11.5, 28, 1]])
    let(rt = b[2] == 0 ? [b[1] + 0.4, b[1] + 2.4] : [b[1] + 6.6, b[1] + 8.6],
        x1 = rt[1] > rp_t0 && rt[0] < rp_t1 ? min(b[0] + 6.4, rp_x0 - 0.5) : b[0] + 6.4)
    [b[0] + 0.6, x1, rt[0], rt[1]]];
WIRE_SLOTS = [[4, 18.5, 15.5, 17.9], [4, 18.5, 24.3, 27.5]];   // x0 x1 ty0 ty1 through the deck
// RP2040 cradle posts, x0 x1 ty0 ty1; the west pair sits east of the switch-board pockets and wire slots
RP_POSTS = [for (x = [uturn_x - 5.2, uturn_x + 6.5]) for (t = [rp_t0 + 1.2, rp_t0 + 18.2]) [x - 1, x + 1, t - 1, t + 1]];

module deck() {
    c0 = deck_z0 - 1; c1 = deck_z1 + 1.3;
    difference() {
        bx(3.4, 38.6, n_in + 0.5, s_in - 0.5, deck_z0, deck_z1);   // clear of the walls
        bx(notch_x0, notch_x1, sock_s - 1.4, sock_s + 8.5, c0, c1); // open notch round the U-turn adapter (A5)
        bx(2.0, 13.4, s_in - 7.4, s_in, c0, c1);                    // west insert block
        bx(32.6, 40, s_in - 7.4, s_in, c0, c1);                     // east insert block
        for (s = WIRE_SLOTS) bx(s[0], s[1], s[2], s[3], c0, c1);   // wire slots
        for (b = BOARDS) bx(b[0] - 0.15, b[0] + 7.15, b[1] - 0.15, b[1] + 9.15, deck_z0 + 0.6, deck_z1 + 0.4);   // board pockets
    }
    for (p = RP_POSTS) bx(p[0], p[1], p[2], p[3], deck_z1 - 0.01, rp_z);   // RP2040 cradle
}

// ---------------------------------------------------------------- lid (drops in 1 mm south, slides north)
module lid() {
    lz = lid_z0;
    difference() {
        union() {
            bx(2.3, 39.7, 2.3, s_in - 1, lz, box_h);      // 0.3 mm clear of the walls
            bx(12, 30, 1.3, 2.4, lz + 0.3, lz + 1.1);                            // tab into the north wall slot
            for (b = LID_RIBS) bx(b[0], b[1], b[2], b[3], brd_top, lz + 0.01);   // ribs holding the boards down
            for (x = [uturn_x - 5.5, uturn_x + 3.5]) bx(x, x + 2, rp_t0, rp_t0 + 2, rp_z + rp_pcb_t, lz + 0.01);   // RP2040 hold-down
            bx(3.3, 5.3, 20, 22, deck_z1, lz + 0.01);  bx(3.3, 5.3, 45, 47, deck_z1, lz + 0.01);   // deck hold-down
            bx(36.7, 38.7, 45, 47, deck_z1, lz + 0.01);
        }
        for (p = INS) cy(p[0], p[1], lz - 0.5, box_h + 0.5, screw_clear_d);
    }
}

// ---------------------------------------------------------------- knob and slide bar (print orientation)
module knob() {   // bottom on the bed; the wire slot faces +y
    k = knob_w / 2;
    difference() {
        bx(-k, k, -k, k, 0, knob_h);
        cy(0, 0, -1, knob_h + 1, knob_bore_d, 24);                          // the barrel is pressed in from the top
        bx(-0.7, 0.7, 0, k + 1, barrel_top(0) - knob_z0(0) - 1.3, knob_h + 1);    // wire slot, open at the top; its floor
                                                                            // catches the solder joint
        translate([0, 0, fil_z(0) - knob_z0(0)]) rotate([0, 90, 0]) cylinder(d = fil_d, h = knob_w + 2, center = true, $fn = 24);
    }
}

module bar() {   // flat on the bed; u runs along x, v along y
    pts = [[bar_u_down, bar_v_low], [bar_u_down + 1.5, bar_v_low],
           [bar_u_up - 1.5, bar_v_low + pin_lift], [bar_u_up, bar_v_low + pin_lift]];
    difference() {
        hull() for (u = [bar_r, bar_len - bar_r]) for (v = [bar_r, bar_h - bar_r]) cy(u, v, 0, bar_t, 2 * bar_r, 24);
        for (i = [0 : 2]) hull() for (p = [pts[i], pts[i + 1]]) cy(p[0], p[1], -1, bar_t + 1, slot_w, 24);
    }
}

// knob, filament and bar in place for one drawer; up = true shows the pin lifted
module lift_in_place(d, up = false) {
    pty = d[2]; s = d[5]; kc = d[7]; xf = pin_x - tower_w / 2; lz = up ? pin_lift : 0;
    translate([pin_x, pty, knob_z0(kc) + lz]) mirror([0, s > 0 ? 0 : 1, 0]) knob();
    color("white") translate([pin_x + knob_w / 2 + 0.15 - fil_len, pty, fil_z(kc) + lz]) rotate([0, 90, 0]) cylinder(d = fil_d, h = fil_len, $fn = 16);
    u = up ? bar_u_up : bar_u_down;
    multmatrix([[0, 0, 1, xf - bar_t - 0.05], [1, 0, 0, pty - u], [0, 1, 0, fil_z(kc) - bar_v_low], [0, 0, 0, 1]]) bar();
}

// the test piece: north drawer and tower, plus the north strip of the box with its pads and fences
module test_piece() {
    intersection() {
        body();
        union() { bx(-1, 24, -29, -0.01, -1, tower_top(yk4_kc) + 1); bx(-1, box_w + 1, -0.01, 12, -1, yk4_opening[3] + 2); }
    }
}

// ---------------------------------------------------------------- output
if (part == "body") out() body();
if (part == "test") out() test_piece();
if (part == "knob") knob();
if (part == "bar")  bar();
if (part == "test_assembly") out() { test_piece(); lift_in_place(DRAWERS[0], up = lift_up); }
if (part == "deck") out() translate([0, 0, -deck_z0]) deck();
if (part == "lid")  out() translate([0, 0, box_h]) mirror([0, 0, 1]) lid();   // top face on the bed
if (part == "assembly") out() { body(); deck(); lid(); for (d = DRAWERS) lift_in_place(d); }
