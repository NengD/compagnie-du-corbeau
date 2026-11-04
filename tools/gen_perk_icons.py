#!/usr/bin/env python3
"""Génère les icônes des talents de maîtrise (armes et armures) dans assets/perk_icons/ : silhouettes blanches 512x512 dessinées par code
(teintées au rendu par PerkIcon). Aucune ressource externe. Relancer ensuite `Godot --headless --import`.

    py tools/gen_perk_icons.py
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "perk_icons")
W = "#fff"


def line(x1, y1, x2, y2, w=30):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{W}" stroke-width="{w}" stroke-linecap="round"/>'


def poly(pts, fill=True, w=20):
    d = " ".join(f"{x},{y}" for x, y in pts)
    if fill:
        return f'<polygon points="{d}" fill="{W}" stroke="{W}" stroke-width="6" stroke-linejoin="round"/>'
    return f'<polygon points="{d}" fill="none" stroke="{W}" stroke-width="{w}" stroke-linejoin="round"/>'


def circ(x, y, r, fill=True, w=18):
    if fill:
        return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{W}"/>'
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="none" stroke="{W}" stroke-width="{w}"/>'


def path(d, fill=True, w=24):
    if fill:
        return f'<path d="{d}" fill="{W}" stroke="{W}" stroke-width="6" stroke-linejoin="round"/>'
    return f'<path d="{d}" fill="none" stroke="{W}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'


def rot(inner, deg, cx=256, cy=256, scale=1.0, dx=0, dy=0):
    return f'<g transform="translate({dx} {dy}) translate({cx} {cy}) rotate({deg}) scale({scale}) translate({-cx} {-cy})">{inner}</g>'


def star(cx, cy, r):
    pts = []
    for i in range(8):
        a = math.pi / 4 * i - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.38
        pts.append((round(cx + rr * math.cos(a), 1), round(cy + rr * math.sin(a), 1)))
    return poly(pts)


# --- Silhouettes d'objets (vue de face, centrées) ---
def sword():
    return poly([(256, 30), (292, 300), (220, 300)]) + poly([(160, 300), (352, 300), (352, 332), (160, 332)]) + line(256, 332, 256, 430, 34) + circ(256, 452, 24)


def axe():
    return line(240, 60, 240, 460, 30) + path("M255 80 C380 50 460 130 440 250 C400 205 335 200 255 235 Z")


def mace():
    spikes = "".join(poly([(256 + 62 * math.cos(a), 150 + 62 * math.sin(a)), (256 + 112 * math.cos(a), 150 + 112 * math.sin(a)),
                           (256 + 62 * math.cos(a + 0.5), 150 + 62 * math.sin(a + 0.5))]) for a in [i * math.pi / 4 for i in range(8)])
    return line(256, 200, 256, 470, 32) + circ(256, 150, 66) + spikes


def flail():
    balls = circ(150, 270, 20) + circ(200, 215, 20) + circ(255, 175, 20)
    spikes = "".join(poly([(360 + 58 * math.cos(a), 110 + 58 * math.sin(a)), (360 + 100 * math.cos(a), 110 + 100 * math.sin(a)),
                           (360 + 58 * math.cos(a + 0.55), 110 + 58 * math.sin(a + 0.55))]) for a in [i * math.pi / 3 for i in range(6)])
    return line(80, 470, 130, 320, 34) + balls + circ(360, 110, 56) + spikes


def club():
    return poly([(226, 50), (296, 50), (332, 150), (292, 462), (236, 462), (216, 150)])


def spear():
    return line(256, 150, 256, 480, 26) + poly([(256, 20), (310, 160), (256, 135), (202, 160)])


def halberd():
    return line(256, 60, 256, 480, 26) + poly([(256, 20), (280, 90), (232, 90)]) + path("M262 130 C370 110 430 170 415 255 C380 215 330 215 262 240 Z") + poly([(250, 150), (170, 190), (250, 215)])


def bow():
    return path("M150 60 C380 150 380 360 150 450", False, 28) + line(150, 60, 150, 450, 12) + line(150, 256, 420, 256, 18) + poly([(420, 256), (385, 232), (385, 280)])


def crossbow():
    return path("M70 190 Q256 40 442 190", False, 30) + line(70, 190, 442, 190, 10) + line(256, 140, 256, 470, 36) + line(256, 150, 256, 70, 16) + poly([(256, 40), (232, 90), (280, 90)])


def javelin():
    return rot(line(256, 110, 256, 450, 22) + poly([(256, 20), (292, 120), (256, 105), (220, 120)]) + poly([(256, 450), (300, 490), (256, 470), (212, 490)]) , 30)


def fist():
    knuckles = circ(170, 175, 38) + circ(240, 150, 38) + circ(310, 150, 38) + circ(378, 175, 38)
    return poly([(130, 180), (410, 180), (420, 340), (370, 440), (180, 440), (130, 340)]) + knuckles + path("M130 300 Q70 300 90 240 Q110 200 140 250", True)


def shield():
    return path("M256 40 L440 100 C440 280 380 410 256 480 C132 410 72 280 72 100 Z") + path("M256 40 L256 480", False, 1)


def shield_cut():
    return path("M256 40 L440 100 C440 280 380 410 256 480 C132 410 72 280 72 100 Z", False, 30) + line(256, 90, 256, 430, 24) + line(110, 210, 402, 210, 24)


def tunic():
    return path("M180 70 L256 110 L332 70 L450 140 L410 230 L370 205 L370 450 L142 450 L142 205 L102 230 L62 140 Z", False, 30)


def quilted():
    return tunic() + line(142, 270, 370, 270, 16) + line(142, 340, 370, 340, 16) + line(142, 410, 370, 410, 16) + line(256, 120, 256, 450, 16)


def mail():
    rings = "".join(circ(x, y, 17, False, 8) for y in range(230, 440, 46) for x in range(180, 340, 46))
    return tunic() + rings


def plates():
    return path("M170 70 L256 100 L342 70 L440 130 L400 210 L370 195 L370 460 L142 460 L142 195 L112 210 L72 130 Z", False, 30) + line(142, 260, 370, 260, 22) + line(142, 330, 370, 330, 22) + line(142, 400, 370, 400, 22) + circ(256, 170, 30)


def helm():
    return path("M110 300 C110 110 402 110 402 300 L402 380 L110 380 Z", False, 30) + line(256, 150, 256, 300, 34) + line(110, 300, 402, 300, 18)


def cloth():
    return path("M256 80 C300 80 330 110 330 150 L330 210 C400 250 420 330 380 450 L132 450 C92 330 112 250 182 210 L182 150 C182 110 212 80 256 80 Z", False, 30) + line(200, 300, 312, 300, 16)


def padded_hat():
    return path("M110 330 C110 140 402 140 402 330 Z", False, 30) + line(160, 250, 352, 250, 14) + line(150, 300, 362, 300, 14)


BASE = {
    "spec_fleau": flail, "spec_gourdin": club, "spec_hast": halberd, "spec_arbalete": crossbow, "spec_poings": fist,
    "ma_tissu": cloth, "ma_matelasse": quilted, "ma_mailles": mail, "ma_plates": plates, "ma_casque": helm,
}


def with_star(inner):
    return rot(inner, 0, scale=0.8, dx=-34, dy=26) + star(420, 92, 64)


EXPERT = {
    "ex_epee": lambda: rot(sword(), -35, scale=0.9) + rot(sword(), 35, scale=0.9),
    "ex_hache": lambda: with_star(axe()),
    "ex_masse": lambda: with_star(mace()),
    "ex_fleau": lambda: with_star(flail()),
    "ex_gourdin": lambda: with_star(club()),
    "ex_lance": lambda: rot(spear(), -25, scale=0.95) + spear() + rot(spear(), 25, scale=0.95),
    "ex_hast": lambda: with_star(halberd()),
    "ex_arbalete": lambda: with_star(crossbow()),
    "ex_javelot": lambda: rot(javelin(), -22, scale=0.9) + rot(javelin(), 14, scale=0.9),
    "ex_poings": lambda: with_star(fist()),
    "ex_bouclier": lambda: shield_cut() + star(256, 130, 46),
    "ex_tissu": lambda: with_star(cloth()),
    "ex_matelasse": lambda: with_star(quilted()),
    "ex_mailles": lambda: with_star(mail()),
    "ex_plates": lambda: with_star(plates()),
    "ex_casque": lambda: with_star(helm()),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    items = {k: f() for k, f in BASE.items()}
    items.update({k: f() for k, f in EXPERT.items()})
    for key, body in items.items():
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">{body}</svg>\n'
        with open(os.path.join(OUT, key + ".svg"), "w", encoding="utf-8") as f:
            f.write(svg)
    print(len(items), "icônes écrites dans", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
