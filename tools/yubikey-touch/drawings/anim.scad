// Parts for the assembly animation (drawings/animate.sh), each in its assembled place, one per render:
//   -D 'part="none"' -D 'item="..."'
// The pin lift parts (knob, filament, pogo pin, bar) are exported lifted, as they go in; the animation
// lowers them onto the buttons at the end.
include <views.scad>

item = "none";

module up_in_place(d, what) {   // one piece of the pin lift for drawer d, lifted (bar pushed north)
    pty = d[2]; s = d[5]; xf = pin_x - tower_w / 2;
    translate([0, 0, d[7]]) {
        if (what == "knob") translate([pin_x, pty, knob_z0 + pin_lift]) mirror([0, s > 0 ? 0 : 1, 0]) knob();
        if (what == "fil") translate([xf - bar_t, pty, fil_z + pin_lift]) rotate([0, 90, 0])
            cylinder(d = fil_d, h = pin_x + knob_w / 2 - xf + bar_t, $fn = 16);
        if (what == "bar") multmatrix([[0, 0, 1, xf - bar_t - 0.05], [1, 0, 0, pty - bar_u_up], [0, 1, 0, fil_z - bar_v_low], [0, 0, 0, 1]]) bar();
        if (what == "pogo") {
            cy(pin_x, pty, barrel_top + pin_lift - 10.4, barrel_top + pin_lift, 1.02, 16);
            cy(pin_x, pty, pad_z + pin_lift - pin_press, barrel_top + pin_lift - 10.4, 0.74, 16);
        }
    }
}
module disk(d) { k = tunnel_z0 + d[7]; cy(pin_x, d[2], k + 3.3, k + 3.4, btn_d, 48); }

out() {
    if (item == "body")    body();
    if (item == "deck")    deck();
    if (item == "lid")     lid();
    if (item == "hub")     hub();
    if (item == "sockets") sockets();
    if (item == "adapter") yk5_adapter();
    if (item == "uturn")   uturn();
    if (item == "usbin")   usb_in();
    if (item == "rp2040")  { rp2040(); bx(hub_x1 - 15.5, hub_x1 - 2, s_face - 20, s_face - 4, mcu_bot + 1, mcu_bot + 2.2); }
    if (item == "boards")  boards();
    if (item == "yk4")     yk4();
    if (item == "yk5")     yk5();
    if (item == "disk4")   disk(DRAWERS[0]);
    if (item == "disk5")   disk(DRAWERS[1]);
    for (i = [0 : 1]) for (w = ["knob", "fil", "bar", "pogo"])
        if (item == str(w, i == 0 ? "4" : "5")) up_in_place(DRAWERS[i], w);
}
