// 2D views of the fixture for drawings/make.sh: a top view and a cut along the key centre line,
// each as a separate layer (body, lid and deck, bought parts, pin lift), plus the numbers they show.
// Render with -D 'part="none"' -D 'view="..."'.
include <../fixture.scad>

view = "echo";

// ---------------------------------------------------------------- bought parts (sizes from calipers)
module hub()     { bx(hub_x0, hub_x1, hub_t0, hub_t1, hub_top - hub_t, hub_top); }
module sockets() { for (xc = [pin_x, far_x]) { bx(xc - 6.5, xc + 6.5, n_face, n_face + 11, hub_top - 2.1, hub_top + 3.6);
                                            bx(xc - 6.5, xc + 6.5, s_face - 11, s_face, hub_top - 2.1, hub_top + 3.6); }
                   bx(hub_x0, hub_x0 + 7.5, usbc_t - 4.5, usbc_t + 4.5, hub_top, hub_top + 3.3); }
module yk5_adapter() { ab = plug_bot - yk5_ad_drop;
                   bx(pin_x - yk5_ad[0] / 2, pin_x + yk5_ad[0] / 2, s_face, yk5_face, ab, ab + yk5_ad[1]); }
module uturn()   { bx(far_x - 7, far_x + 7, s_face, s_face + 12.1, plug_bot - uturn_below, uturn_top); }
module rp2040()  { bx(hub_x1 - 17.5, hub_x1, s_face - 23.5, s_face, mcu_bot, mcu_bot + 1); }
module usb_in()  { bx(-12, hub_x0, usbc_t - 6, usbc_t + 6, hub_top + 1.6 - 3, hub_top + 1.6 + 3); }
module yk4()     { k = tunnel_z0; bx(pin_x - 8.9, pin_x + 8.9, n_face - 3.1 - 33, n_face - 3.1, k + 0.01, k + 3.3);
                   bx(pin_x - 6, pin_x + 6, n_face - 3.1, n_face + 8.8, k + yk4_plug_gap, k + yk4_plug_gap + 2.3); }
module yk5()     { k = tunnel_z0 + yk5_dz; bx(pin_x - 8.9, pin_x + 8.9, yk5_face + 4.8, yk5_face + 37.8, k + 0.01, k + 3.3);
                   bx(pin_x - 5, pin_x + 5, yk5_face + 0.01, yk5_face + 4.8, k + 0.3, k + 3.0); }
module boards()  { for (b = BOARDS) bx(b[0], b[0] + brd[0], b[1], b[1] + brd[1], deck_z1 - 0.6, deck_z1 - 0.6 + brd[2]); }
module bought()  { hub(); sockets(); yk5_adapter(); uturn(); rp2040(); usb_in(); boards(); }
module keys()    { yk4(); yk5(); }
module pogo(d)   { translate([0, 0, d[7]]) {                    // barrel, plunger pressed onto the button
                     cy(pin_x, d[2], barrel_top - 10.4, barrel_top, 1.02, 16);
                     cy(pin_x, d[2], pad_z, barrel_top - 10.4, 0.74, 16); } }
module lift()    { for (d = DRAWERS) { lift_in_place(d); pogo(d); } }

// a cut along the key centre line (x = pin_x), seen from the east: (ty, z)
module cut() { projection(cut = true) rotate([0, 0, 90]) rotate([0, 90, 0]) translate([-pin_x, 0, 0]) out() children(); }
// the top view: (x, ty); and a cut through it at z, to show the walls, fences, cradle and rails
module top() { projection() out() children(); }
module top_cut(z) { projection(cut = true) translate([0, 0, -z]) out() children(); }

// a side view (not a cut) for the parts beyond the cut, drawn dashed
module side() { projection() rotate([0, 0, 90]) rotate([0, 90, 0]) translate([-pin_x, 0, 0]) out() children(); }

if (view == "top_body")    top() body();
if (view == "top_floor")   top_cut(6) body();
if (view == "top_hub")     top() { hub(); sockets(); }
if (view == "top_adapter") top() yk5_adapter();
if (view == "top_uturn")   top() uturn();
if (view == "top_rp2040")  top() rp2040();
if (view == "top_usbin")   top() usb_in();
if (view == "top_keys")    top() keys();
if (view == "top_lift")    top() lift();
if (view == "cut_body")    cut() body();
if (view == "cut_cover")   cut() { deck(); lid(); }
if (view == "cut_hub")     cut() { hub(); sockets(); }
if (view == "cut_adapter") cut() yk5_adapter();
if (view == "cut_keys")    cut() keys();
if (view == "cut_lift")    cut() lift();
if (view == "side_uturn")  side() uturn();
if (view == "side_rp2040") side() rp2040();

if (view == "echo") {
    echo(str("DIM ", "box_w=", box_w, " box_l=", box_l, " box_h=", box_h, " wall=", wall, " slack=", slack, " fit=", fit,
             " hub_x0=", hub_x0, " hub_x1=", hub_x1, " hub_t0=", hub_t0, " hub_t1=", hub_t1, " hub_top=", hub_top,
             " n_face=", n_face, " s_face=", s_face, " yk5_face=", yk5_face, " a_face=", a_face,
             " pin_x=", pin_x, " pin_ty_yk4=", pin_ty_yk4, " pin_ty_yk5=", pin_ty_yk5,
             " yk4_btn=", yk4_btn, " yk5_btn=", yk5_btn, " btn_d=", btn_d, " sock_out=", sock_out,
             " hub_ns=", hub_ns, " hub_we=", hub_we, " adapter_out=", adapter_out,
             " deck_z0=", deck_z0, " deck_z1=", deck_z1, " lid_z=", lid_z, " mcu_bot=", mcu_bot, " mcu_z=", mcu_z,
             " uturn_top=", uturn_top, " uturn_h=", uturn_h, " tower_top=", tower_top, " yk5_dz=", yk5_dz,
             " ad_bot=", plug_bot - yk5_ad_drop, " pin_lift=", pin_lift, " drawer_n=", DRAWERS[0][0],
             " drawer_s=", DRAWERS[1][1]));
    cube(1);
}
