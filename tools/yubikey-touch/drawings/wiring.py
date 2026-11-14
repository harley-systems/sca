"""Write wiring.svg: how the laptop, hub, adapters, keys, RP2040 and the power switches connect."""
import sys
from pathlib import Path

out = Path(sys.argv[1])
W, H = 980, 700
INK, GREY, BLUE, ORANGE, RED, GREEN = "#1f2328", "#59616e", "#2f6db5", "#a85c12", "#b3261e", "#2e7d32"
el = []

def text(x, y, s, size=12, anchor="start", weight="400", color=INK):
    el.append(f'<text x="{x}" y="{y}" font-size="{size}" text-anchor="{anchor}" font-weight="{weight}" fill="{color}">{s}</text>')
def box(x, y, w, h, title, sub=None, fill="#eef4fc", stroke=BLUE, dash=False):
    d = ' stroke-dasharray="5 4"' if dash else ""
    el.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{fill}" stroke="{stroke}" stroke-width="1.4"{d}/>')
    text(x + w / 2, y + (h / 2 + 4 if not sub else h / 2 - 3), title, anchor="middle", weight="600")
    if sub:
        text(x + w / 2, y + h / 2 + 13, sub, size=11, anchor="middle", color=GREY)
def wire(points, color=INK, w=1.6, dash=False, arrow=False):
    d = ' stroke-dasharray="6 4"' if dash else ""
    a = ' marker-end="url(#arr)"' if arrow else ""
    pts = " ".join(f"{x},{y}" for x, y in points)
    el.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="{w}"{d}{a} stroke-linejoin="round"/>')
def dot(x, y, color=INK):
    el.append(f'<circle cx="{x}" cy="{y}" r="3.2" fill="{color}"/>')
def label(x, y, s, color=GREY, anchor="start", size=11):
    text(x, y, s, size=size, anchor=anchor, color=color)

text(20, 34, "YubiKey touch fixture: wiring", size=20, weight="700")
text(20, 56, "USB in blue. Touch lines in orange, power switching in red (planned, not built yet). "
     "Ground is shared through the USB cables.", color=GREY)

# ---------------------------------------------------------------- USB tree
box(20, 100, 130, 54, "Laptop", "USB-A port", fill="#f4f5f7", stroke=GREY)
box(185, 104, 130, 46, "A-C Forward", "adapter", fill="#ffffff")
wire([(150, 127), (185, 127)], BLUE, 2.2)
box(360, 84, 170, 330, "", fill="#eef4fc")
text(445, 108, "USB 2.0 hub board", anchor="middle", weight="700")
text(445, 124, "4 x USB-A, USB-C in", size=11, anchor="middle", color=GREY)
wire([(315, 127), (360, 127)], BLUE, 2.2)
label(366, 145, "USB-C in", BLUE)

ports = [(175, "north near"), (245, "south near"), (330, "south far"), (390, "north far")]
for y, name in ports:
    el.append(f'<rect x="512" y="{y - 9}" width="18" height="18" fill="#ffffff" stroke="{BLUE}" stroke-width="1.2"/>')
    label(506, y + 4, name, BLUE, anchor="end")
label(540, 394, "free", GREY)

# YubiKey 4: straight into the north near socket, power through switch 4
box(560, 150, 110, 50, "switch 4", "VBUS only", fill="#fdeeee", stroke=RED, dash=True)
wire([(530, 175), (560, 175)], BLUE, 2.2)
box(790, 150, 170, 50, "YubiKey 4", "USB-A, in the north drawer", fill="#e9eaec", stroke=INK)
wire([(670, 175), (790, 175)], BLUE, 2.2)
# YubiKey 5: through the C-A Forward adapter, power through switch 5
box(560, 220, 110, 50, "switch 5", "VBUS only", fill="#fdeeee", stroke=RED, dash=True)
wire([(530, 245), (560, 245)], BLUE, 2.2)
box(676, 226, 82, 38, "C-A Fwd", None, fill="#ffffff")
wire([(670, 245), (676, 245)], BLUE, 2.2)
box(790, 220, 170, 50, "YubiKey 5C NFC", "USB-C, in the south drawer", fill="#e9eaec", stroke=INK)
wire([(758, 245), (790, 245)], BLUE, 2.2)
# RP2040: through the U-turn
box(560, 312, 110, 36, "U-turn", None, fill="#ffffff")
wire([(530, 330), (560, 330)], BLUE, 2.2)
box(790, 300, 170, 160, "", fill="#f1f7ee", stroke=GREEN)
text(875, 322, "RP2040-Zero", anchor="middle", weight="700")
text(875, 338, "serial port \"YubiKey touch\"", size=11, anchor="middle", color=GREY)
wire([(670, 330), (790, 330)], BLUE, 2.2)
label(796, 326, "USB-C", BLUE)
pins = [(368, "GP0"), (388, "GP1"), (408, "GP2"), (428, "GP3"), (448, "GND")]
for y, p in pins:
    el.append(f'<rect x="782" y="{y - 5}" width="10" height="10" fill="#ffffff" stroke="{GREEN}"/>')
    label(798, y + 4, p, INK)

# touch lines: GP0 and GP1 straight to the pogo pins on the touch disks
wire([(782, 368), (772, 368), (772, 211), (898, 211), (898, 200)], ORANGE, 2)
dot(898, 200, ORANGE)
label(904, 214, "pogo pin", ORANGE)
wire([(782, 388), (740, 388), (740, 283), (898, 283), (898, 270)], ORANGE, 2)
dot(898, 270, ORANGE)
label(904, 286, "pogo pin", ORANGE)
label(846, 368 + 4, "touch YubiKey 4", ORANGE)
label(846, 388 + 4, "touch YubiKey 5", ORANGE)
# power: GP2 and GP3 to the 2N7002 gates in the switches
# power: GP2 and GP3 go to the 2N7002 gates in the switches (shown by name, not drawn across)
wire([(615, 150), (615, 138)], RED, 1.6, dash=True)
label(621, 141, "from GP2", RED)
wire([(615, 270), (615, 284)], RED, 1.6, dash=True)
label(621, 292, "from GP3", RED)
for y in (408, 428):
    wire([(782, y), (760, y)], RED, 1.6, dash=True)
label(846, 408 + 4, "power: switch 4", RED)
label(846, 428 + 4, "power: switch 5", RED)
label(846, 448 + 4, "to the switches", GREY)

# ---------------------------------------------------------------- one power switch
y0 = 500
text(20, y0 - 16, "One power switch (two are built: one per key). High on the GPIO = key powered.", size=14, weight="700")
el.append(f'<rect x="20" y="{y0}" width="940" height="180" rx="6" fill="#fffafa" stroke="{RED}" stroke-dasharray="5 4"/>')
# hub 5 V -> AO3401 source; drain -> key VBUS
label(40, y0 + 46, "hub 5 V (the port's VBUS", INK, size=12)
label(40, y0 + 62, "trace, cut off its socket)", INK, size=12)
wire([(210, y0 + 52), (330, y0 + 52)], RED, 2)
box(330, y0 + 22, 150, 60, "AO3401", "P-channel, SOT-23 board", fill="#ffffff", stroke=RED)
label(316, y0 + 46, "S (2)", RED, anchor="end")
label(494, y0 + 46, "D (3)", RED)
wire([(480, y0 + 52), (640, y0 + 52)], RED, 2)
label(650, y0 + 46, "to the key's socket VBUS pin", INK, size=12)
label(650, y0 + 62, "(the key's 5 V)", GREY)
# 10k gate pull-up between gate and source
wire([(405, y0 + 82), (405, y0 + 112), (260, y0 + 112), (260, y0 + 52)], RED, 1.6)
dot(260, y0 + 52, RED)
el.append(f'<rect x="300" y="{y0 + 104}" width="56" height="16" fill="#ffffff" stroke="{RED}" stroke-width="1.4"/>')
text(328, y0 + 116, "10k", size=11, anchor="middle", color=RED)
label(411, y0 + 98, "G (1)", RED)
label(196, y0 + 132, "the 10k holds the gate at the source: off by default", GREY)
# gate -> 2N7002 drain; source -> GND; gate <- GPx
wire([(405, y0 + 112), (560, y0 + 112), (560, y0 + 122)], RED, 1.6)
dot(405, y0 + 112, RED)
box(520, y0 + 122, 150, 50, "2N7002", "N-channel, SOT-23 board", fill="#ffffff", stroke=RED)
label(566, y0 + 118, "D (3)", RED)
wire([(670, y0 + 147), (760, y0 + 147)], RED, 1.6)
label(680, y0 + 141, "G (1)", RED)
label(766, y0 + 151, "GP2 or GP3 on the RP2040", INK, size=12)
wire([(520, y0 + 160), (470, y0 + 160)], INK, 1.6)
label(462, y0 + 164, "S (2) to GND", INK, anchor="end", size=12)

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="system-ui, -apple-system, Segoe UI, Helvetica, Arial, sans-serif">
<title>YubiKey touch fixture: wiring</title>
<defs><marker id="arr" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M 0 1 L 9 5 L 0 9 z" fill="{INK}"/></marker></defs>
<rect width="100%" height="100%" fill="#ffffff"/>
{chr(10).join(el)}
</svg>
'''
out.write_text(svg)
