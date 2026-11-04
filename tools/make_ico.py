"""Assemble assets/app_icon.ico à partir des PNG de assets/icons_png (bibliothèque standard seulement).
Usage : py tools/make_ico.py"""
import os, struct

SIZES = [16, 32, 48, 64, 128, 256]
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
pngs = []
for s in SIZES:
    with open(os.path.join(root, "icons_png", f"icon_{s}.png"), "rb") as f:
        pngs.append((s, f.read()))
out = struct.pack("<HHH", 0, 1, len(pngs))
offset = 6 + 16 * len(pngs)
entries, data = b"", b""
for s, png in pngs:
    dim = 0 if s >= 256 else s
    entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(png), offset + len(data))
    data += png
with open(os.path.join(root, "app_icon.ico"), "wb") as f:
    f.write(out + entries + data)
print("app_icon.ico :", len(out + entries + data), "octets")
