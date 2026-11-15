// Parts for the assembly animation (drawings/animate.sh), each in its assembled place, one per render:
//   -D 'part="none"' -D 'item="..."'
// The pin lift parts (knob, filament, pogo pin, bar) are exported lifted, as they go in; the animation
// lowers them onto the buttons at the end.
include <views.scad>

item = "none";

module pogo_up(d) {   // the pogo pin, lifted
    translate([0, 0, d[7]]) {
        cy(pin_x, d[2], barrel_top + pin_lift - 10.4, barrel_top + pin_lift, 1.02, 16);
        cy(pin_x, d[2], pad_z + pin_lift - pin_press, barrel_top + pin_lift - 10.4, 0.74, 16);
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
    if (item == "rp2040")  rp2040();
    if (item == "boards_n") boards_n();
    if (item == "boards_s") boards_s();
    if (item == "yk4")     yk4();
    if (item == "yk5")     yk5();
    if (item == "disk4")   disk(DRAWERS[0]);
    if (item == "disk5")   disk(DRAWERS[1]);
    for (i = [0 : 1]) {
        for (w = ["knob", "fil", "bar"]) if (item == str(w, i == 0 ? "4" : "5")) lift_part(DRAWERS[i], w, up = true);
        if (item == str("pogo", i == 0 ? "4" : "5")) pogo_up(DRAWERS[i]);
    }
}
