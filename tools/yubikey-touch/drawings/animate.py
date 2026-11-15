"""Blender script for the assembly animation: blender -b -P animate.py -- <stl dir> <frames dir> [WxH] [transparent]

The frames are 1280x720 on white unless a size is given; "transparent" leaves the background out (the explainer
video puts the frames on its own background).

Each STL is already in its assembled place (drawings/anim.scad), so a part's location is its offset from
there. Parts arrive in the README's build order along paths that keep them clear of the parts already in.
Blender's axes are OpenSCAD's: x east, y north, z up, in mm.
"""
import math
import sys
import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
stl_dir, frames_dir = args[:2]
size = next((a for a in args[2:] if "x" in a), "1280x720")
transparent = "transparent" in args[2:]
FPS, END = 30, 900

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.fps = FPS
sc.frame_start, sc.frame_end = 1, END

COLOURS = {
    "body": (0.66, 0.68, 0.72), "deck": (0.80, 0.82, 0.85), "lid": (0.80, 0.82, 0.85),
    "hub": (0.10, 0.42, 0.24), "sockets": (0.78, 0.79, 0.80), "adapter": (0.12, 0.12, 0.13),
    "uturn": (0.12, 0.12, 0.13), "usbin": (0.12, 0.12, 0.13), "rp2040": (0.13, 0.27, 0.55),
    "boards_n": (0.10, 0.42, 0.24), "boards_s": (0.10, 0.42, 0.24), "yk4": (0.08, 0.08, 0.09), "yk5": (0.08, 0.08, 0.09),
    "disk4": (0.83, 0.66, 0.22), "disk5": (0.83, 0.66, 0.22),
    "knob4": (0.95, 0.55, 0.15), "knob5": (0.95, 0.55, 0.15), "bar4": (0.95, 0.55, 0.15),
    "bar5": (0.95, 0.55, 0.15), "fil4": (0.95, 0.95, 0.93), "fil5": (0.95, 0.95, 0.93),
    "pogo4": (0.85, 0.70, 0.25), "pogo5": (0.85, 0.70, 0.25),
}
bpy.context.preferences.edit.keyframe_new_interpolation_type = "BEZIER"   # eased moves; hide_render steps anyway
obj = {}
imp = bpy.ops.wm.stl_import if hasattr(bpy.ops.wm, "stl_import") else bpy.ops.import_mesh.stl
for name, rgb in COLOURS.items():
    imp(filepath=f"{stl_dir}/{name}.stl")
    o = bpy.context.selected_objects[0]
    o.name = name
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    o.data.materials.append(m)
    obj[name] = o

base = {}   # where an object's own origin sits, for the parts that also turn (see pivot)

def at(names, frame, offset):
    for n in names:
        o = obj[n]
        o.location = base.get(n, Vector((0, 0, 0))) + Vector(offset)
        o.keyframe_insert("location", frame=frame)

def pivot(name, point):
    """Turn this object about point (mm, in the model) from now on."""
    obj[name].data.transform(Matrix.Translation(-Vector(point)))
    base[name] = Vector(point)

def tilt(names, frame, degrees):
    """Tail up by this angle, about the east-west line through the pivot."""
    for n in names:
        obj[n].rotation_euler = (math.radians(degrees), 0, 0)
        obj[n].keyframe_insert("rotation_euler", frame=frame)

def show_from(names, frame):
    for n in names:
        o = obj[n]
        for f, hidden in ((1, True), (frame, False)):
            o.hide_render = hidden
            o.keyframe_insert("hide_render", frame=f)

def move(names, f0, f1, start, end=(0, 0, 0)):
    """Appear at f0 at start (an offset from the assembled place) and travel straight to end by f1."""
    show_from(names, f0)
    at(names, 1, start)
    at(names, f0, start)
    at(names, f1, end)

# 1. hub with the YubiKey 5 adapter and the U-turn, down onto the pads; then the laptop plug from the west
move(["hub", "sockets", "adapter", "uturn"], 30, 110, (0, 0, 70))
move(["usbin"], 120, 170, (-45, 0, 0))
# 2. the deck, then the switch boards into their drawers
move(["deck"], 175, 235, (0, 0, 60))
# Each pair comes down nose first in the middle of the deck, lands its nose on the drawer floor, and is pushed
# home under the lips with its belly riding on the sill; then the tail drops behind the sill.
DECK_TOP, SILL, REACH = 11.65, 0.43, 10.15    # deck top; sill height plus a hair; nose (home) to the sill's inner edge
bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
for name, home_y, south in (("boards_n", -5.0, -1), ("boards_s", -38.0, 1)):   # south: which way y runs toward the mouth
    pivot(name, (0, home_y, DECK_TOP))
    show_from([name], 240)
    steps = [(240, 8.0, 25, 12.0), (256, 8.0, 0.02, 12.0)]                    # frame, nose from home, height, tilt
    for i, back in enumerate((7, 6, 5, 4, 3, 2, 1, 0.3, 0)):
        steps.append((259 + 3 * i, back, 0.02, math.degrees(math.asin(SILL / (REACH - back)))))
    steps.append((288, 0, 0, 0))
    at([name], 1, (0, south * 8.0, 25)); tilt([name], 1, -south * 12.0)
    for frame, back, height, angle in steps:
        at([name], frame, (0, south * back, height))
        tilt([name], frame, -south * angle)
bpy.context.preferences.edit.keyframe_new_interpolation_type = "BEZIER"
# 3. the RP2040: down north of the U-turn, then south onto its plug
move(["rp2040"], 295, 345, (0, 8, 50), (0, 8, 0))
at(["rp2040"], 375, (0, 0, 0))
# 4. pin lifts, lifted: bars into their sleeves from the open ends, knobs with their pins from above,
#    filament cross pins from the west
move(["bar4"], 380, 430, (0, 20, 0))
move(["bar5"], 380, 430, (0, -20, 0))
move(["knob4", "pogo4", "knob5", "pogo5"], 440, 490, (0, 0, 40))
move(["fil4", "fil5"], 495, 530, (-30, 0, 0))
# 5. the keys slide in along their drawers under the lifted pins
move(["yk4", "disk4"], 540, 620, (0, 45, 0))
move(["yk5", "disk5"], 540, 620, (0, -45, 0))
# 6. bars pushed south: the pins come down onto the buttons
for n in ("bar4", "bar5"):
    at([n], 640, (0, 0, 0))
    at([n], 680, (0, -8, 0.5))     # the pin's spring pushes the bar up against the roof of its sleeve
for n in ("knob4", "pogo4", "fil4", "knob5", "pogo5", "fil5"):
    at([n], 640, (0, 0, 0))
    at([n], 680, (0, 0, -2.5))
# 7. the lid drops in 1 mm south and slides north under the wall slot
move(["lid"], 700, 760, (0, -1, 40), (0, -1, 0))
at(["lid"], 790, (0, 0, 0))

sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light, sh.color_type, sh.show_cavity, sh.show_shadows = "STUDIO", "MATERIAL", True, True
sh.background_type = "WORLD"
sc.view_settings.view_transform = "Standard"   # so the white background stays white
sc.render.resolution_x, sc.render.resolution_y = (int(n) for n in size.split("x"))
if transparent:
    sc.render.film_transparent = True
    sc.render.image_settings.color_mode = "RGBA"
w = bpy.data.worlds.new("w"); sc.world = w; w.color = (1, 1, 1)
bpy.ops.object.camera_add()
cam = bpy.context.object
sc.camera = cam
target = Vector((22, -39, 4))
cam.location = target + Vector((-80, -45, 150))   # from the west and a little south, about 58 degrees down
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.type, cam.data.ortho_scale, cam.data.clip_end = "ORTHO", 182, 2000
sc.render.image_settings.file_format = "PNG"
sc.render.filepath = f"{frames_dir}/f_"
bpy.ops.render.render(animation=True)
