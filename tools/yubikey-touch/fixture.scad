// YubiKey touch fixture, rev I2: body, deck, lid, plus a knob and a slide bar per pin. No glue.
//
// Render one part:  openscad -D 'part="body"' -o body.stl fixture.scad
// Parts: "body", "deck", "lid" (turned over for printing), "knob", "bar" (print one of each per pin),
//        "test" (north end: wall, hub seat, YubiKey 4 drawer and tower), "assembly" (for looking at).
//
// Rev G: the layout comes from the parts in hand, measured with calipers (hub board, sockets,
// adapters, keys). Both pins sit over the buttons, the hub (it has no mounting holes) rests on corner
// pads between fences, the box is tall enough for the U-turn adapter and the RP2040 above the hub,
// and the slide bar is thicker (the rev F bar broke coming off the plate).
//
// Rev H, from the printed rev G body: the hub with its adapters had no room to drop in (the box was
// exactly as long as they are, and the fences 0.15 mm from the board), so the box is 1 mm longer and
// 1 mm wider, the fences are 0.5 mm away, and the end walls have shallow pockets so each key still
// plugs all the way in. The YubiKey 5 adapter hung from its socket at no set height, so the key had
// to find it blind: a cradle at the south wall now holds its USB-C end where the key plugs in straight.
//
// Rev I, from the printed rev H parts:
//  - The lid came out as a mirror image, because it was turned over for printing with a mirror. It is
//    now turned over with a rotation.
//  - The slide bar was as big as the sleeve it runs in. The bar is smaller; the sleeve opening is the
//    same, so the new bar also fits a rev H body.
//  - Thin places on the towers broke. The tower and sleeve walls are thicker, and the sloped rib is
//    built around the wire channel, which had almost no plastic around it.
//  - The switch boards lay loose in shallow pockets. They now slide into drawers on the deck, and the
//    lid's board ribs are gone.
//  - The RP2040 supports were several mm too high. mcu_z has to be measured again; until then the
//    deck has no supports and the lid no hold-down for it (mcu_support).
//
// Rev I2 (lid and deck only), from the first rev I print: the lid's two deck hold-downs were 2 mm square
// posts, 17 mm tall. Each layer of them took under 2 s and the nozzle hopped between them, so they came
// out lumpy with a curtain of strings between them, and more strings crossed the deck's drawers.
//  - The lid has one hold-down, a cross-shaped column over the hub socket that nothing plugs into.
//  - The deck's centre rail runs through and joins the two drawer blocks.
//  - Rule for these two parts: above its plate a part is one closed outline, so the nozzle never has to
//    cross open air, and nothing tall is thinner than a wall of four lines.
//
// Pin lift: the pogo pin sits in a square knob that slides straight up and down in a square hole in
// the tower, so it can't turn and twist the wire. A 1.75 mm filament piece crosses the knob, rests on
// top of the pin barrel, and runs in a slanted slot in a slide bar held in a sleeve on the tower's
// west face. Bar pushed south: pin pressed onto the button. Bar pushed north: pin lifted pin_lift mm
// so the key slides freely. The flat ends of the slot hold the bar where it is left.
// The wire is soldered to the pin outside the fixture, never in place: it leaves the knob through a side
// slot and runs down a slot in the tower wall that is open at the top, then through a channel into the box.
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
mcu_z       = 15.4;   // RP2040 board bottom above the hub board top (MEASURE again: the rev H supports,
                      // built to this, held the board several mm too high)
mcu_t       = 1.6;    // RP2040 board thickness (MEASURE; the lid's hold-down clears a board this thick)
mcu_support = false;  // supports under the RP2040 on the deck and a hold-down over it on the lid: true once
                      // mcu_z and mcu_t are measured
usbc_from_n = 17.0;   // middle of the hub's USB-C input from the board's north edge (MEASURE: from a photo; the wall hole is wide)
// keys: YubiKey 4 (USB-A) and YubiKey 5C NFC, button 10 mm across
yk4_btn     = 12.8;   // YubiKey 4 plugged into the hub: socket face -> start of the button
yk5_btn     = 14.7;   // YubiKey 5 plugged into its adapter: adapter face -> start of the button
btn_d       = 10;
yk4_plug_gap = 0.45;  // YubiKey 4 lying flat, button up: gap under its plug (MEASURE)
yk5_plug_gap = -0.6;  // YubiKey 5 + adapter lying flat: adapter's A plug bottom above the key's bottom (MEASURE)
yk5_neck    = [11.0, 3.7];   // hole in the south wall for the YubiKey 5's plug neck, width x height (MEASURE)
yk5_ad      = [14.5, 7.0];   // YubiKey 5 adapter body, width x height
yk5_ad_drop = 1.4;    // its bottom below the bottom of its A plug: in the rev G body, with the key flat on its
                      // floor, its top was 19.8 below the wall top (30.75), so its bottom sat at 3.95

// ---------------------------------------------------------------- key drawers and pins
pin_x       = 11.9;    // drawer centre line, also the key centre line and the near sockets' middle
tunnel_x0 = 2.75;  tunnel_x1 = 21.05;   // 18.3 wide, YubiKey body 17.8
tunnel_z0 = 4.6;   tunnel_z1 = 9.8;     // 5.2 tall, YubiKey body 3.3 (in the drawer's own frame)

// pogo pin P75 (barrel 1.02 mm)
pin_len     = 16.5;    // barrel top to tip, plunger fully out (measured)
pad_z       = 7.6;     // height of the touch disk in the tunnel: key on the floor, 3.3 thick, 0.3 dip
pin_press   = 1.0;     // how far the plunger is pushed in when the pin is down on the disk
pin_lift    = 2.5;     // how far the bar lifts the pin; the tip then clears the key by ~1.2 mm
channel_d   = 2.0;     // touch-wire channel (30 AWG). Rev H: 1.6, which had to be drilled clear
channel_wall = 1.2;    // plastic around the channel, at least (rev H: under 0.4 for most of its length)

// knob
knob_w      = 3.6;     // square knob, in a knob_w + 0.3 square hole
knob_bore_d = 1.4;     // loose on the 1.02 barrel, so the tip passes; the solder joint rests on the slot floor
fil_d       = 1.75;    // filament cross pin
fil_len     = 9;       // ... and its length: from the far wall of the knob's hole to the sleeve's outer wall
tower_w     = 9;       // square tower: walls 2.55 around the knob's hole (rev H: 7, walls 1.55)
barrel_top  = pad_z - pin_press + pin_len;   // 23.1 with the values above
fil_z       = barrel_top + fil_d / 2 + 0.03;   // the filament sits right on top of the barrel

// Slide bar and the sleeve it runs in. The pin's spring pushes the filament up, so with the pin down the
// bar's top edge presses on the sleeve roof; with the pin up the bar rests on the sleeve floor. The slot
// is placed for those two positions, so the pin presses pin_press and lifts pin_lift whatever the play.
// Rev H: the bar (13 x 8.5 x 2.4) left 0.3 and 0.25 mm in this opening, and its first printed layer
// spreads by about that much.
bar_t       = 2.0;     // slide bar: 15 long x 8.3 tall x 2.0 thick
bar_len     = 15;
bar_h       = 8.3;
sleeve_w    = 2.65;    // sleeve opening across (as in rev G and H): the bar has 0.65 to spare
sleeve_play = 0.5;     // room for the bar up and down in the sleeve
bar_rise    = pin_lift + sleeve_play;      // how much the slot rises along the bar (3.0)
bar_v0      = (bar_h - bar_rise) / 2;      // slot height from the bar's bottom edge at its low end (2.65);
                                           // the bar is then the same turned end for end
bar_trim    = 0;       // to press harder or softer, move the slot in the bar and reprint only the bar:
                       // +0.3 presses 0.3 mm harder (and lifts 0.3 less). The sleeve does not change
bar_v_low   = bar_v0 - bar_trim;
bar_u_down  = 3.5;     // slot positions along the bar where the filament rests (flat ends)
bar_u_up    = bar_len - bar_u_down;
slot_w      = 1.95;
sleeve_z1   = fil_z + bar_h - bar_v0;           // underside of the sleeve roof (as in rev H)
sleeve_z0   = sleeve_z1 - bar_h - sleeve_play;  // sleeve floor (as in rev H)
sleeve_wall = 1.6;     // sleeve outer wall and roof (rev H: 0.8)
sleeve_floor = 1.2;    // (rev H: 0.8)
fil_slot_w  = 2.4;     // width of the slots the filament moves in (rev H: 2.0, which had to be cleared)
knob_z0     = barrel_top - 10.15;   // knob bottom when the pin is down
tower_top   = sleeve_z1 + sleeve_wall;
knob_h      = tower_top - knob_z0 + 1.5;          // sticks out 1.5 mm above the tower when down, 4 mm when up

// ---------------------------------------------------------------- box layout (derived)
wall    = 2;
box_w   = 43;     // rev G: 42
slack   = 1.0;    // room along the box for the hub with its adapters (rev G: none, a hard push)
fit     = 0.5;    // gap between the hub board and its fences (rev G: 0.15)
hub_x0  = pin_x - sock_near;      // board west edge, the USB-C side (2.7)
hub_x1  = hub_x0 + hub_we;        // board east edge (38.2); the RP2040 lines up with it
far_x   = hub_x1 - sock_near;     // middle of the far A sockets (29.0): the U-turn goes south here
n_in    = wall;                   // inside of the north wall
n_face  = n_in + slack / 2;       // north socket faces, in the middle of their travel (2.5)
hub_t0  = n_face + sock_out;      // board north edge (5.35)
hub_t1  = hub_t0 + hub_ns;        // board south edge (37.65)
s_face  = hub_t1 + sock_out;      // south socket faces (40.5)
yk5_face = s_face + adapter_out;  // YubiKey 5 adapter face, in the middle of its travel (65.5)
a_face  = yk5_face + slack / 2;   // inside of the south wall (66.0)
box_l   = a_face + wall;          // 68.0
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
deck_t0    = 2.5;                                      // the deck's north and south edges: it ends before the
deck_t1    = s_face - slack / 2 - 0.3;                 // U-turn and the adapter, wherever the hub sits

// the pins sit over the middle of each button with the hub in the middle of its travel, so they are at
// most slack / 2 off whichever end it rests against
pin_ty_yk4 = n_face - (yk4_btn + btn_d / 2);   // -15.3: over the YubiKey 4 button
pin_ty_yk5 = yk5_face + yk5_btn + btn_d / 2;   //  85.2: over the YubiKey 5 button

// M2 heat-set insert 3.5 OD x 3: hole 3.2, pressed in with the Pinecil at ~220 C (PLA)
insert_hole_d = 3.2;
screw_clear_d = 2.3;
INS = [[4.2, a_face - 2.8], [box_w - 5.5, a_face - 3.5]];

// ---------------------------------------------------------------- helpers
module bx(x0, x1, t0, t1, z0, z1) { translate([x0, t0, z0]) cube([x1 - x0, t1 - t0, z1 - z0]); }
module cy(x, t, z0, z1, d, fn = $fn) { translate([x, t, z0]) cylinder(d = d, h = z1 - z0, $fn = fn); }
module rod(p1, p2, d) { hull() { translate(p1) sphere(d = d, $fn = 16); translate(p2) sphere(d = d, $fn = 16); } }
module out() { mirror([0, 1, 0]) children(); }

// ---------------------------------------------------------------- body
DRAWERS = [  // t0, t1, pin ty, thin slice at the end wall's outer face ty0..ty1 (the rib ends there),
             // s (+1 north drawer, -1 south), channel exit in the box, dz
    [-28, 0, pin_ty_yk4, -0.02, 0.0, 1, [20, n_in + 0.6, 16.5], 0],        // exit above the deck's drawers
    [box_l, box_l + 28, pin_ty_yk5, box_l, box_l + 0.02, -1, [20, a_face - 0.6, 14.0], yk5_dz]];

// the wire channel runs from the tower's box-side wall (inside the wire slot) to its exit in the box
function chan_p1(d) = [pin_x, d[2] + d[5] * (knob_w / 2 + 1.1), barrel_top - 0.4];
function chan_at(d, ty) = let(p1 = chan_p1(d)) p1 + (d[6] - p1) * (ty - p1[1]) / (d[6][1] - p1[1]);

// sloped rib from the tower to the end wall, built around the wire channel: its sides and top are
// channel_wall away from the channel all the way (rev H's rib ran beside the channel, not around it)
module rib(d) {
    s = d[5]; p1 = chan_p1(d); u = (d[6] - p1) / norm(d[6] - p1);
    cover = channel_d / 2 + channel_wall;
    hw = cover * norm([u[0], u[1]]) / abs(u[1]);    // half width
    ht = cover * norm([u[1], u[2]]) / abs(u[1]);    // height above the channel's middle line
    ta = d[2] + s * tower_w / 2;                    // the tower's box-side face
    hull() for (e = [[ta - s * 0.02, ta, ta], [d[3], d[4], s > 0 ? d[4] : d[3]]]) {
        c = chan_at(d, e[2]);
        bx(c[0] - hw, c[0] + hw, min(e[0], e[1]), max(e[0], e[1]), 11.8, c[2] + ht);
    }
}

module drawer(d) {
    t0 = d[0]; t1 = d[1]; pty = d[2];
    if (d[7] > 0) bx(0.75, 23.05, t0, t1, 0, d[7] + 0.01);     // raises the drawer
    translate([0, 0, d[7]]) {
        bx(0.75, 23.05, t0, t1, 0, tunnel_z0);                      // floor
        bx(0.75, tunnel_x0, t0, t1, tunnel_z0, tunnel_z1);          // rails
        bx(tunnel_x1, 23.05, t0, t1, tunnel_z0, tunnel_z1);
        bx(0.75, 23.05, t0, t1, tunnel_z1, 11.8);                   // roof
        tw = tower_w / 2; xf = pin_x - tw;                          // xf: west face of the tower
        bx(pin_x - tw, pin_x + tw, pty - tw, pty + tw, 11.8, tower_top);   // square pin tower
        sx = xf - sleeve_w - sleeve_wall; sb = sleeve_z0 - sleeve_floor;   // sleeve: outer face, underside
        bx(sx, xf, pty - tw, pty + tw, sb, tower_top);              // sleeve for the slide bar
        hull() {                                                    // 45 degrees under the sleeve
            bx(sx, xf, pty - tw, pty + tw, sb - 0.01, sb);
            bx(xf - 0.01, xf, pty - tw, pty + tw, sb - (xf - sx), sb);
        }
        rib(d);
    }
}

module drawer_cuts(d) {
    pty = d[2]; s = d[5];
    tw = tower_w / 2; xf = pin_x - tw; kh = knob_w / 2 + 0.15; fw = fil_slot_w / 2;
    // the filament's travel: from the pin pressed to the pin lifted with the bar still up against the roof
    fz0 = fil_z - slot_w / 2 - 0.1; fz1 = fil_z + bar_rise + slot_w / 2 + 0.1;
    translate([0, 0, d[7]]) {
        cy(pin_x, pty, 9.0, 12.1, 2.2, 24);                         // hole in the tunnel roof for the plunger
        bx(pin_x - kh, pin_x + kh, pty - kh, pty + kh, 12.0, tower_top + 1);   // square hole for the knob
        w = s > 0 ? [pty + kh - 0.1, pty + tw + 0.1] : [pty - tw - 0.1, pty - kh + 0.1];
        // wire slot on the box side, open at the top: the wire, soldered to the pin on the bench, slides down it
        // with the knob (a closed window pinched the wire between the knob and the wall above it)
        bx(pin_x - 0.8, pin_x + 0.8, w[0], w[1], barrel_top - 1.6, tower_top + 1);
        rod(chan_p1(d), d[6], channel_d);                           // wire channel to the box
        bx(xf - 0.1, pin_x - kh + 0.1, pty - fw, pty + fw, fz0, fz1);   // filament slot, west wall
        bx(xf - sleeve_w, xf + 0.01, pty - tw - 1, pty + tw + 1, sleeve_z0, sleeve_z1);   // inside of the sleeve
        bx(xf - sleeve_w - sleeve_wall - 0.1, xf - sleeve_w + 0.1, pty - fw, pty + fw, fz0, fz1);   // window: push the filament in here
    }
}

// 45 degree support under a block that hangs off the inside of the south wall
module south_chamfer(x0, x1, t0, zb) {
    hull() { bx(x0, x1, t0, a_face, zb - 0.01, zb); bx(x0, x1, a_face - 0.01, a_face, zb - (a_face - t0), zb); }
}

// the hub has no mounting holes: it sits on four corner pads between low fences. Along the box it is
// held between the north wall (far north socket) and the south wall (YubiKey 5 adapter face), with
// slack mm to spare; the deck on top of the sockets holds it down
module hub_seat() {
    hb = hub_top - hub_t;      // board underside
    ft = hub_top + 1;          // fences reach 1 mm above the board top
    for (x = [hub_x0 + 0.2, hub_x1 - 2.4]) for (t = [hub_t0 + 0.2, hub_t1 - 2.4]) bx(x, x + 2.2, t, t + 2.2, 1, hb);
    for (t = [hub_t0 + 0.5, hub_t1 - 3.5]) {
        bx(1, hub_x0 - fit, t, t + 3, 1, ft);                      // west, clear of the USB-C hole
        bx(hub_x1 + fit, box_w - 1, t, t + 3, 1, ft);              // east
    }
    sf = hub_t1 + slack / 2 + fit;                                 // clear of the board at the south end of its travel
    for (x = [[hub_x0, hub_x0 + 2.4], [pin_x + 7.0, far_x - 7.0], [hub_x1 - 2.4, hub_x1]])
        bx(x[0], x[1], sf, sf + 1.35, 1, ft);                      // south, between the sockets
}

// the YubiKey 5 adapter's USB-C end rests on a seat between two guides, at the height and place where
// the key, lying on its drawer floor, plugs in straight. The guides have 45 degree lead-ins at the top.
module yk5_cradle() {
    ab = plug_bot - yk5_ad_drop;                                   // adapter bottom (3.95)
    x0 = pin_x - yk5_ad[0] / 2 - 0.4; x1 = pin_x + yk5_ad[0] / 2 + 0.4;   // 0.4 mm clear each side
    t0 = a_face - 9;  t1 = a_face + 0.01;
    gz = ab + 2.5;                                                 // guide tops
    bx(wall - 0.01, x1 + 1.8, t0, t1, 1, ab - 0.1);                // seat
    hull() { bx(wall - 0.01, x0, t0, t1, 1, gz - 1);  bx(wall - 0.01, x0 - 1, t0, t1, gz - 0.01, gz); }   // west guide
    hull() { bx(x1, x1 + 1.8, t0, t1, 1, gz - 1);     bx(x1 + 1, x1 + 1.8, t0, t1, gz - 0.01, gz); }      // east guide
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
            yk5_cradle();
            for (d = DRAWERS) drawer(d);
        }
        // YubiKey 4 plug into the north socket (the hole is a little bigger than the socket)
        bx(5.0, 18.8, -1, wall + 1, tunnel_z0 - 0.2, deck_z0 + 0.3);
        // YubiKey 5 plug neck through the south wall; the adapter face bears on the wall
        k5 = tunnel_z0 + yk5_dz;
        bx(pin_x - yk5_neck[0] / 2, pin_x + yk5_neck[0] / 2, a_face - 1, box_l + 1, k5 - 0.2, k5 - 0.2 + yk5_neck[1]);
        // pockets, slack deep, in the outside of the end walls around the key openings: the hub can sit
        // slack mm away from either wall, and each key body then goes that far into its wall
        bx(tunnel_x0, tunnel_x1, 0, slack, tunnel_z0, tunnel_z1);
        bx(tunnel_x0, tunnel_x1, box_l - slack, box_l, k5, tunnel_z1 + yk5_dz);
        // the laptop's USB-C plug into the hub (wide, so the plug's body fits too)
        bx(-1, wall + 1, usbc_t - 7.5, usbc_t + 7.5, hub_top - 2.5, hub_top + 5.5);
        bx(11.6, 30.4, 1.1, 2.2, lid_z + 0.1, lid_z + 1.3);                     // slot for the lid's tab
        for (p = INS) cy(p[0], p[1], lid_z - 4.2, lid_z + 0.2, insert_hole_d);
        for (d = DRAWERS) drawer_cuts(d);
    }
}

// ---------------------------------------------------------------- deck (sits on the hub sockets)
brd    = [7.5, 10.0, 1.4];                                  // AO3401 / 2N7002 boards: across, along the box, thick
BOARDS = [[3.8, 5], [12.9, 5], [3.8, 28], [12.9, 28]];    // their north-west corners; north pair, south pair
MCU_POSTS = [[22, 18.5], [37, 18.5]];                     // under the RP2040's far end

// Each switch board slides into a drawer, transistor end first, from the middle of the deck. Two rails
// guide its long edges. Over the first lip_len mm the rails lean in over the board, and so does the end
// stop, so the board can't lift; the lips stop short of the three pads and their wires. At the mouth the
// board's tail drops behind a low sill, which keeps it from sliding back out: lift the tail to remove it.
// The floor is lower under the pads, for the solder joints, but stays closed over the hub's sockets.
// All overhangs are 45 degrees.
rail_w  = 1.2;    // rails, and the gap between the two boards of a pair
rail_h  = 3.2;    // rail height where it carries a lip; brd[2] + 0.4 along the rest
side_gap = 0.2;   // board to rail, each side
end_gap = 0.15;   // board to end stop, and board to sill
lip     = 1.0;    // how far a lip reaches in from its rail (0.8 over the board)
lip_len = 6;      // lips run this far from the end stop
lip_gap = 0.35;   // lip above the board's top edge
sill_h  = 0.4;
sill_l  = 1.0;
drawer_l = brd[1] + 2 * end_gap + sill_l;   // end stop face to the sill's outer face (11.3)

module board_drawer(b, north, cut = false) {
    ts = north ? b[1] - end_gap : b[1] + brd[1] + end_gap;    // face of the end stop
    dir = north ? 1 : -1;                                     // toward the mouth
    xa = b[0] - side_gap; xb = b[0] + brd[0] + side_gap;      // inner faces of the rails
    F = deck_z1; h0 = brd[2] + lip_gap - side_gap;            // floor; where the lips start to lean in
    module vb(x0, x1, v0, v1, z0, z1) { bx(x0, x1, min(ts + dir * v0, ts + dir * v1), max(ts + dir * v0, ts + dir * v1), z0, z1); }
    if (cut) {
        vb(b[0] + 0.3, b[0] + brd[0] - 0.3, drawer_l - sill_l - 3, drawer_l - sill_l, F - 0.6, F + 0.01);   // relief under the pads
    } else {
        back = north ? ts - deck_t0 : deck_t1 - ts;           // the end stop reaches the deck's edge
        vb(xa - rail_w, xb + rail_w, -back, 0, F, F + rail_h);                                     // end stop
        hull() { vb(xa, xb, 0, 0.01, F + h0, F + rail_h); vb(xa, xb, lip - 0.01, lip, F + h0 + lip, F + rail_h); }
        for (r = [[xa - rail_w, xa, 1], [xb, xb + rail_w, -1]]) {                                  // rails and their lips
            vb(r[0], r[1], 0, lip_len, F, F + rail_h);
            vb(r[0], r[1], lip_len, drawer_l, F, F + brd[2] + 0.4);
            e = r[2] > 0 ? r[1] : r[0];                                                            // the rail's inner face
            hull() { vb(min(e, e + r[2] * 0.01), max(e, e + r[2] * 0.01), 0, lip_len, F + h0, F + rail_h);
                     vb(min(e + r[2] * (lip - 0.01), e + r[2] * lip), max(e + r[2] * (lip - 0.01), e + r[2] * lip),
                        0, lip_len, F + h0 + lip, F + rail_h); }
        }
        vb(xa, xb, drawer_l - sill_l, drawer_l, F, F + sill_h);                                    // sill
    }
}

module deck() {
    s1 = BOARDS[0][1] - end_gap + drawer_l;               // the north drawers' sills end here (16.15)
    s2 = BOARDS[2][1] + brd[1] + end_gap - drawer_l;      // the south drawers' sills start here (26.85)
    // The rail between the two boards of a pair runs on at full height across the middle of the deck and joins
    // the north drawers to the south ones. Above its plate the deck is then one closed outline, so the nozzle
    // can go from any rail to any other without crossing a drawer (rev I as first printed: two separate
    // drawer blocks, and strings across the drawers). The wire slots lie either side of this rail.
    sp0 = BOARDS[0][0] + brd[0] + side_gap; sp1 = sp0 + rail_w;       // 11.5 .. 12.7
    difference() {
        union() {
            bx(2.4, 38.6, deck_t0, deck_t1, deck_z0, deck_z1);
            for (i = [0 : 3]) board_drawer(BOARDS[i], i < 2);
            bx(sp0, sp1, BOARDS[0][1] - end_gap + lip_len, BOARDS[2][1] + brd[1] + end_gap - lip_len, deck_z1, deck_z1 + rail_h);
        }
        bx(2.3, 3.5, usbc_t - 6.5, usbc_t + 6.5, deck_z0 - 1, deck_z1 + 1);   // notch for the laptop's USB plug adapter
        bx(2.3, 3.6, usbc_t - 6.5, usbc_t + 6.5, deck_z1, deck_z1 + rail_h + 1);   // ... and no rail above it
        for (x = [[4, sp0 - 0.4], [sp1 + 0.4, 18.5]]) {                       // wire slots, right behind the sills
            bx(x[0], x[1], s1, s1 + 2.4, deck_z0 - 1, deck_z1 + 1);
            bx(x[0], x[1], s2 - 3.2, s2, deck_z0 - 1, deck_z1 + 1);
        }
        for (i = [0 : 3]) board_drawer(BOARDS[i], i < 2, cut = true);
    }
    // the RP2040 rests on these. They are thin posts, like the ones that printed badly on the lid: before
    // switching them on, build them as one wall joined to the drawers' east rail
    if (mcu_support) for (p = MCU_POSTS) bx(p[0] - 1, p[0] + 1, p[1] - 1, p[1] + 1, deck_z1, mcu_bot - 0.2);
}

// ---------------------------------------------------------------- lid (drops in 1 mm south, slides north)
// One hold-down keeps the deck on the hub's sockets: a cross-shaped column over the unused north-east
// socket, which the deck rests on right there. It is the only thing that stands up from the lid, so above
// the plate every layer is one closed outline and the nozzle never has to leave it. (Rev I as first
// printed had two 2 mm square posts, 17 mm tall and 36 mm apart: each layer took under 2 s and the nozzle
// hopped between them, which gave lumpy posts and a curtain of strings.) Pressing the deck down also keeps
// the hub on its pads; nothing else holds either of them.
hold_c    = [far_x + 0.5, n_face + 5.5];   // centre: over the north-east socket (29.5, 8.0)
hold_arm  = [11, 9];                       // the cross's size, west-east and along the box
hold_t    = 1.8;                           // its walls: four 0.45 mm lines
hold_gap  = 0.3;                           // the deck can lift this far; the lid is then 18.8 mm high, 94 layers
hold_root = 1.0;                           // the cross flares out this much where it meets the lid
module hold_bar(x0, x1, t0, t1, z0) {      // one bar of the cross
    bx(x0, x1, t0, t1, z0, lid_z);
    hull() { bx(x0, x1, t0, t1, lid_z - hold_root, lid_z - hold_root + 0.01);
             bx(x0 - hold_root, x1 + hold_root, t0 - hold_root, t1 + hold_root, lid_z - 0.01, lid_z); }
}
module hold_down() {
    z0 = deck_z1 + hold_gap;
    hold_bar(hold_c[0] - hold_arm[0] / 2, hold_c[0] + hold_arm[0] / 2, hold_c[1] - hold_t / 2, hold_c[1] + hold_t / 2, z0);
    hold_bar(hold_c[0] - hold_t / 2, hold_c[0] + hold_t / 2, hold_c[1] - hold_arm[1] / 2, hold_c[1] + hold_arm[1] / 2, z0);
    // with the RP2040 measured, the cross's south arm runs on over the RP2040's far end and holds it down
    if (mcu_support) bx(hold_c[0] - hold_t / 2, hold_c[0] + hold_t / 2, hold_c[1] + hold_arm[1] / 2 - 0.01, 18.5,
                        mcu_bot + mcu_t + 0.1, lid_z);
}

module lid() {
    difference() {
        union() {
            hull() {                                                       // 0.3 mm clear of the walls; the top
                bx(2.3, box_w - 2.3, 2.3, a_face - 1, lid_z, lid_z + 1.7);     // edge is chamfered, because it
                bx(2.6, box_w - 2.6, 2.6, a_face - 1.3, lid_z + 1.99, lid_z + 2);   // prints on the bed and spreads
            }
            // two tabs into the north wall slot, near its ends, where the slot's bridged roof sags least. Their
            // tops slope at 45 degrees, so they print without support when the lid lies top down
            for (x = [12.2, 26.8]) hull() {
                bx(x, x + 3, 2.29, 2.3, lid_z + 0.3, lid_z + 1.5);
                bx(x, x + 3, 1.5, 1.51, lid_z + 0.3, lid_z + 0.7);
            }
            hold_down();
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
    c = 0.3;     // chamfer on every edge and around the slot: the first printed layer spreads
    pts = [[bar_u_down, bar_v_low], [bar_u_down + 1.5, bar_v_low],
           [bar_u_up - 1.5, bar_v_low + bar_rise], [bar_u_up, bar_v_low + bar_rise]];
    outline = [[1, 0], [bar_len - 1, 0], [bar_len, 1], [bar_len, bar_h - 1],     // ends tapered 1 mm, so the bar
               [bar_len - 1, bar_h], [1, bar_h], [0, bar_h - 1], [0, 1]];        // finds its way into the sleeve
    difference() {
        hull() {
            translate([0, 0, c]) linear_extrude(bar_t - 2 * c) polygon(outline);
            linear_extrude(bar_t) offset(delta = -c) polygon(outline);
        }
        for (i = [0 : 2]) {
            hull() for (p = [pts[i], pts[i + 1]]) cy(p[0], p[1], -1, bar_t + 1, slot_w, 24);
            hull() for (p = [pts[i], pts[i + 1]]) translate([p[0], p[1], -0.01]) cylinder(d1 = slot_w + 2 * c, d2 = slot_w, h = c, $fn = 24);
            hull() for (p = [pts[i], pts[i + 1]]) translate([p[0], p[1], bar_t - c + 0.01]) cylinder(d1 = slot_w, d2 = slot_w + 2 * c, h = c, $fn = 24);
        }
    }
}

// one piece of the pin lift for a drawer, in its place: "knob", "fil" (the filament cross pin) or "bar";
// up = true shows the pin lifted
module lift_part(d, what, up = false) {
    pty = d[2]; s = d[5]; xf = pin_x - tower_w / 2; lz = up ? pin_lift : 0;
    translate([0, 0, d[7]]) {
        if (what == "knob") translate([pin_x, pty, knob_z0 + lz]) mirror([0, s > 0 ? 0 : 1, 0]) knob();
        if (what == "fil") color("white") translate([pin_x + knob_w / 2 + 0.15 - fil_len, pty, fil_z + lz])
            rotate([0, 90, 0]) cylinder(d = fil_d, h = fil_len, $fn = 16);
        if (what == "bar") {
            bz = up ? sleeve_z0 : sleeve_z1 - bar_h;     // on the sleeve floor when lifted, up against its roof when pressed
            u = up ? bar_u_up : bar_u_down;
            multmatrix([[0, 0, 1, xf - (sleeve_w + bar_t) / 2], [1, 0, 0, pty - u], [0, 1, 0, bz], [0, 0, 0, 1]]) bar();
        }
    }
}
module lift_in_place(d, up = false) { for (w = ["knob", "fil", "bar"]) lift_part(d, w, up); }

// ---------------------------------------------------------------- output
TEST = [-1, box_w + 1, -29, 12, -1, max(tower_top, box_h) + 1];   // north end: wall, hub seat, drawer
module test_piece() { intersection() { body(); bx(TEST[0], TEST[1], TEST[2], TEST[3], TEST[4], TEST[5]); } }

// out() turns the model's (x, ty, z) into the real, right-handed part. After out(), only rotate() and
// translate() may follow: a mirror() there prints the mirror image of the part (rev H's lid).
if (part == "body") out() body();
if (part == "test") out() test_piece();
if (part == "knob") knob();
if (part == "bar")  bar();
if (part == "test_assembly") out() { test_piece(); lift_in_place(DRAWERS[0], up = lift_up); }
if (part == "deck") out() translate([0, 0, -deck_z0]) deck();
if (part == "lid")  translate([0, 0, lid_z + 2]) rotate([180, 0, 0]) out() lid();   // turned over: top face on the bed
if (part == "assembly") out() { body(); deck(); lid(); for (d = DRAWERS) lift_in_place(d); }
