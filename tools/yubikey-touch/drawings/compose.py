"""Compose layout.svg from the OpenSCAD 2D views in build/ and the numbers in build/dims.txt.

The plan (lid off, seen from above) sits above a cut along the key centre line; both run
north -> south from left to right on the same scale, so a part lines up in the two views.
"""
import re
import sys
from pathlib import Path

build, out = Path(sys.argv[1]), Path(sys.argv[2])
D = {k: float(v) for k, v in (kv.split("=") for kv in (build / "dims.txt").read_text().split())}

S = 5.0                                   # px per mm
TY0, TY1 = D["drawer_n"], D["drawer_s"]   # north and south ends of the drawers
PX0 = 60                                  # page x of TY0
W = PX0 + (TY1 - TY0) * S + 260
PLAN_Y = 150 + D["box_w"] * S             # page y of x = 0 (the plan has east up)
CUT_Y = PLAN_Y + 250 + D["box_h"] * S     # page y of z = 0
H = CUT_Y + 95

def px(ty): return PX0 + (ty - TY0) * S
def plan_y(x): return PLAN_Y - x * S
def cut_y(z): return CUT_Y - z * S
def f(v): return f"{v:.2f}".rstrip("0").rstrip(".")

def paths(view):
    p = build / f"{view}.svg"
    return re.findall(r'd="([^"]+)"', p.read_text()) if p.exists() else []

# fills and outlines; stroke widths are in mm (the layers are scaled by S)
STYLE = {
    "body":   ('#d5d9df', '#59616e', None, 1.0),
    "floor":  ('#b4bac4', '#59616e', None, 1.0),
    "cover":  ('#eef0f3', '#8a929e', '0.9 0.6', 0.6),
    "bought": ('#a9cbf2', '#2f6db5', None, 0.8),
    "behind": ('none', '#2f6db5', '0.9 0.6', 1.0),
    "keys":   ('#3d424a', '#1f2328', None, 0.85),
    "lift":   ('#f2a65a', '#a85c12', None, 1.0),
}

def layer(view, style, transform):
    ds = paths(view)
    if not ds:
        return ""
    fill, stroke, dash, opacity = STYLE[style]
    dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<g transform="{transform}"><path d="{" ".join(d.strip() for d in ds)}" fill="{fill}" '
            f'fill-opacity="{opacity}" stroke="{stroke}" stroke-width="{1.2 / S:.3f}"{dash_attr} '
            'stroke-linejoin="round" fill-rule="evenodd"/></g>')

plan_t = f"matrix(0,{-S},{S},0,{PX0 - TY0 * S},{PLAN_Y})"
cut_t = f"matrix({S},0,0,{S},{PX0 - TY0 * S},{CUT_Y})"

el = []
RED, GREY, INK = "#b3261e", "#59616e", "#1f2328"
def text(x, y, s, size=12, anchor="start", weight="400", color=INK):
    el.append(f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" text-anchor="{anchor}" '
              f'font-weight="{weight}" fill="{color}">{s}</text>')
def line(x1, y1, x2, y2, color=GREY, w=1.0, arrows=False):
    extra = ' marker-start="url(#a)" marker-end="url(#a)"' if arrows else ""
    el.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{color}" stroke-width="{w}"{extra}/>')
def dim_h(y, x1, x2, label, ext_to=None):
    """Horizontal dimension at page y from x1 to x2; extension lines run from y to ext_to."""
    if ext_to is not None:
        for x in (x1, x2):
            line(x, ext_to, x, y + (5 if y > ext_to else -5), color="#a6adb7", w=0.8)
    line(x1, y, x2, y, color=RED, arrows=True)
    text((x1 + x2) / 2, y - 5, label, anchor="middle", color=RED)
def dim_v(x, y1, y2, label, ext_to=None, label_y=None):
    if ext_to is not None:
        for y in (y1, y2):
            line(ext_to, y, x + (5 if x > ext_to else -5), y, color="#a6adb7", w=0.8)
    line(x, y1, x, y2, color=RED, arrows=True)
    text(x + 7, ((y1 + y2) / 2 if label_y is None else label_y) + 4, label, color=RED)
def callout(ax, ay, tx, ty, label, anchor="start"):
    line(ax, ay, tx, ty, color=GREY, w=0.8)
    el.append(f'<circle cx="{ax:.1f}" cy="{ay:.1f}" r="2.2" fill="{GREY}"/>')
    text(tx + (4 if anchor == "start" else -4), ty + 4, label, anchor=anchor)

# ---------------------------------------------------------------- titles
text(20, 34, "YubiKey touch fixture, rev I: layout (mm)", size=20, weight="700")
text(20, 56, "Generated from fixture.scad by drawings/make.sh. North, the YubiKey 4 end, is on the left.", color=GREY)
top = plan_y(D["box_w"])
text(20, top - 72, "Plan: lid off, seen from above, east up", size=14, weight="700")

# ---------------------------------------------------------------- plan
for view, style in [("top_body", "body"), ("top_floor", "floor"), ("top_usbin", "bought"), ("top_hub", "bought"),
                    ("top_adapter", "bought"), ("top_uturn", "bought"), ("top_rp2040", "bought"),
                    ("top_keys", "keys"), ("top_lift", "lift")]:
    el.append(layer(view, style, plan_t))

drawer_east = plan_y(23.05)
dim_h(top - 16, px(TY0), px(0), f"drawer {f(-TY0)}", ext_to=drawer_east)
dim_h(top - 16, px(0), px(D["box_l"]), f"box {f(D['box_l'])}", ext_to=top)
dim_h(top - 16, px(D["box_l"]), px(TY1), f"drawer {f(TY1 - D['box_l'])}", ext_to=drawer_east)
dim_v(px(TY1) + 18, PLAN_Y, top, f(D["box_w"]), ext_to=px(D["box_l"]), label_y=top + 14)

# the pins, measured from the faces the keys plug into; below the plan, past the laptop plug adapter
yb = plan_y(-12) + 30
face_x = plan_y(D["pin_x"])
dim_h(yb, px(D["pin_ty_yk4"]), px(D["n_face"]), f(D["n_face"] - D["pin_ty_yk4"]), ext_to=face_x)
dim_h(yb, px(D["n_face"]), px(D["s_face"]), f"hub with sockets {f(D['s_face'] - D['n_face'])}", ext_to=face_x)
dim_h(yb, px(D["s_face"]), px(D["yk5_face"]), f"adapter {f(D['adapter_out'])}", ext_to=face_x)
dim_h(yb, px(D["yk5_face"]), px(D["pin_ty_yk5"]), f(D["pin_ty_yk5"] - D["yk5_face"]), ext_to=face_x)
text(px(TY0), yb + 20, "YubiKey 4 pin: over the button centre", color=GREY, size=11)
text(px(TY1), yb + 20, "YubiKey 5 pin: over the button centre", color=GREY, size=11, anchor="end")
text(px((D["n_face"] + D["yk5_face"]) / 2), yb + 42,
     f"The hub with its adapters can move {f(D['slack'])} between the end walls; the pins sit over the buttons "
     "in the middle of that travel.", color=GREY, size=11, anchor="middle")

lx = px(TY1) + 52
callout(px((D["hub_t0"] + D["hub_t1"]) / 2 - 6), plan_y(D["hub_x0"] + 6), lx, top + 4,
        f"hub {f(D['hub_ns'])} x {f(D['hub_we'])}")
text(lx + 4, top + 22, f"on 4 corner pads, fences {f(D['fit'])} away", size=11, color=GREY)
callout(px(D["s_face"] - 8), plan_y(D["hub_x1"] - 6), lx, top + 50, "RP2040-Zero, over the hub")
callout(px(D["s_face"] + 6), plan_y(29), lx, top + 76, "U-turn adapter to the RP2040")
callout(px(D["s_face"] + 18), plan_y(D["pin_x"]), lx, top + 102, "YubiKey 5 adapter,")
text(lx + 4, top + 120, "its USB-C end in the cradle", size=11, color=GREY)
callout(px(D["hub_t0"] + 17), plan_y(-6), lx, PLAN_Y + 30, "plug for the laptop")
callout(px(D["pin_ty_yk4"]), plan_y(D["pin_x"] + 4), px(TY0) + 10, top - 44, "pin holder and slide bar", anchor="start")

# ---------------------------------------------------------------- cut
ct = cut_y(D["box_h"])
text(20, ct - 62, "Cut along the key centre line, seen from the east", size=14, weight="700")
for view, style in [("cut_cover", "cover"), ("side_uturn", "behind"), ("side_rp2040", "behind"), ("cut_body", "body"),
                    ("cut_hub", "bought"), ("cut_adapter", "bought"), ("cut_keys", "keys"), ("cut_lift", "lift")]:
    el.append(layer(view, style, cut_t))
line(px(TY0) - 10, cut_y(0), px(TY1) + 10, cut_y(0), color=GREY, w=1.5)

# heights: ticks at the right, labels spread apart so they never overlap
hx = px(TY1) + 18
marks = sorted([
    (D["box_h"], "box top"), (D["lid_z"], "lid underside"), (D["uturn_top"], f"U-turn top ({f(D['uturn_h'])} tall)"),
    (D["mcu_bot"], f"RP2040 board ({f(D['mcu_z'])} above the hub)"), (D["deck_z1"], "deck top"),
    (D["hub_top"], "hub board top"), (D["ad_bot"], "YubiKey 5 adapter seat"), (0, "bed"),
], reverse=True)
last = -1e9
for z, label in marks:
    y = cut_y(z)
    ly = max(y, last + 16)
    last = ly
    line(hx - 6, y, hx, y, color=RED)
    line(hx, y, hx + 16, ly, color=RED, w=0.6)
    text(hx + 20, ly + 4, f"{f(z)}  {label}", size=11, color=RED)
line(hx - 3, cut_y(0), hx - 3, cut_y(D["box_h"]), color=RED)

callout(px(D["pin_ty_yk4"]) + 2, cut_y(D["tower_top"] - 2), px(TY0) + 6, ct - 30, "tower: pin holder, bar, pogo pin")
callout(px(D["s_face"] + 2), cut_y(D["uturn_top"] - 3), px(D["s_face"]) - 40, ct - 30, "U-turn and RP2040 (behind the cut)")
callout(px(24), cut_y(D["lid_z"] + 1), px(22), ct - 12, "lid")
callout(px(14), cut_y(D["deck_z1"] - 0.6), px(4), ct - 12, "deck")
callout(px(D["pin_ty_yk4"] - 6), cut_y(D["hub_top"] - 1.2), px(TY0) + 6, cut_y(0) + 28, "YubiKey 4")
callout(px(D["hub_t0"] + 10), cut_y(D["hub_top"] - 0.8), px(D["hub_t0"] + 2), cut_y(0) + 28, "hub and its sockets")
callout(px(D["s_face"] + 12), cut_y(D["ad_bot"] + 1), px(D["s_face"] + 4), cut_y(0) + 46, "YubiKey 5 adapter on its cradle")
callout(px(D["pin_ty_yk5"] + 6), cut_y(D["hub_top"] + 0.2), px(TY1) - 4, cut_y(0) + 28,
        f"YubiKey 5, drawer {f(D['yk5_dz'])} higher", anchor="end")

# ---------------------------------------------------------------- legend
lx, ly = 20, H - 20
for name, label in [("body", "printed body"), ("cover", "deck and lid"), ("bought", "hub, adapters, RP2040"),
                    ("behind", "behind the cut"), ("keys", "YubiKeys"), ("lift", "pin lift")]:
    fill, stroke, dash, op = STYLE[name]
    da = f' stroke-dasharray="{dash.replace(" ", ",")}"' if dash else ""
    el.append(f'<rect x="{lx}" y="{ly - 11}" width="16" height="12" fill="{fill}" fill-opacity="{op}" stroke="{stroke}" stroke-width="1.2"{da}/>')
    text(lx + 22, ly, label)
    lx += 40 + 6.6 * len(label)

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W:.0f}" height="{H:.0f}" viewBox="0 0 {W:.0f} {H:.0f}" font-family="system-ui, -apple-system, Segoe UI, Helvetica, Arial, sans-serif">
<title>YubiKey touch fixture, rev I: layout</title>
<defs><marker id="a" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M 0 2 L 5 5 L 0 8" fill="none" stroke="{RED}" stroke-width="1.5"/></marker></defs>
<rect width="100%" height="100%" fill="#ffffff"/>
{chr(10).join(e for e in el if e)}
</svg>
'''
out.write_text(svg)
