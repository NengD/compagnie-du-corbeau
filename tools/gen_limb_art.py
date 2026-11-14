#!/usr/bin/env python3
"""Art original des emplacements « Bras » et « Jambes » (Data.ARMS / Data.LEGS) : calques de figurine (assets/sprites/) et icônes
d'objets (assets/icons_items/). Aucune ressource externe : tout est dessiné ici (licence du projet).

Calques (une famille d'armure = un dessin ; voir Figure.add_limb_layers) :
  limb_off_<fam>        brassard du bras libre (sans bouclier), dessiné juste après `arm_off`
  limb_arm_<fam>_<pose> brassard du bras armé, `pose` = std | bow | xbow (position de la main), dessiné après le bras armé
  limb_legs_<fam>       jambières / grèves, dessinées après les bottes
  `fam` = tissu | matelasse | mailles | plates.

Appelé par tools/gen_sprites.py, ou seul :  py tools/gen_limb_art.py   puis   godot --headless --import
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS_ITEMS = os.path.join(ROOT, "assets", "icons_items")

FAMILIES = ["tissu", "matelasse", "mailles", "plates"]
# clé de Data.ARMS / Data.LEGS -> famille d'apparence (celle de Data.ARMOR_FAMILIES)
ARMS_LOOK = {"manchettes": "tissu", "brassards_cuir": "matelasse", "manicles_cloutees": "matelasse", "manches_mailles": "mailles",
             "epaulieres_fer": "plates", "garde_bras_plaques": "plates", "brassards_orques": "plates", "bandelettes_rouillees": "mailles"}
LEGS_LOOK = {"bandes_toile": "tissu", "jambieres_cuir": "matelasse", "guetres_cloutees": "matelasse", "chausses_mailles": "mailles",
             "greves_fer": "plates", "greves_genouilleres": "plates", "jambieres_orques": "plates", "chausses_rouillees": "mailles"}
POSES = {"std": ((8, -13), (16, -7), (14, -1)), "bow": ((8, -13), (14, -12), (20, -8)), "xbow": ((8, -13), (17, -9), (16.5, -5))}
OFF_ARM = ((-9, -12), (-15, -3), (-13, 6))


def _bez(p0, p1, p2, t):
    return ((1 - t) ** 2 * p0[0] + 2 * t * (1 - t) * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * t * (1 - t) * p1[1] + t * t * p2[1])


def _seg(curve, t0, t1, n=6):
    pts = [_bez(*curve, t0 + (t1 - t0) * i / n) for i in range(n + 1)]
    return "M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in pts)


# ====================================================================== calques de figurine
def bracer(curve, fam, g):
    """Brassard sur l'avant-bras (courbe de l'avant-bras `curve`)."""
    OL, path, light, rings = g.OL, g.path, g.light, g.rings
    seg = _seg(curve, 0.42, 0.88)
    out = ""
    if fam == "tissu":
        out += f'<path d="{seg}" fill="none" stroke="{OL}" stroke-width="7" stroke-linecap="round"/>'
        out += f'<path d="{seg}" fill="none" stroke="#cdbf9b" stroke-width="4.8" stroke-linecap="round"/>'
        for t in (0.5, 0.62, 0.74):
            x, y = _bez(*curve, t)
            out += path(f"M{x - 2.7:.2f},{y - .6:.2f} L{x + 2.7:.2f},{y + .9:.2f}", "none", "#8a7c58", .6, .8)
    elif fam == "matelasse":
        out += f'<path d="{seg}" fill="none" stroke="{OL}" stroke-width="7.4" stroke-linecap="round"/>'
        out += f'<path d="{seg}" fill="none" stroke="#6e4a2c" stroke-width="5.2" stroke-linecap="round"/>'
        for t in (0.5, 0.66, 0.82):
            x, y = _bez(*curve, t)
            out += path(f"M{x - 2.8:.2f},{y - .8:.2f} L{x + 2.8:.2f},{y + 1:.2f}", "none", "#3a2616", .8, .85)
            out += f'<circle cx="{x:.2f}" cy="{y:.2f}" r=".6" fill="#d9c9a0" stroke="{OL}" stroke-width=".2"/>'
    elif fam == "mailles":
        out += f'<path d="{seg}" fill="none" stroke="{OL}" stroke-width="7.6" stroke-linecap="round"/>'
        out += f'<path d="{seg}" fill="none" stroke="#8f959b" stroke-width="5.4" stroke-linecap="round"/>'
        x, y = _bez(*curve, 0.65)
        out += f'<path d="{rings(x - 3, x + 3, y - 4, y + 4)}" stroke="#23272c" stroke-width=".4" fill="none" opacity=".8"/>'
        out += path(_seg(curve, 0.45, 0.85), "none", "#fff", .5, .45)
    else:  # plates : manchon d'acier à rebords
        out += f'<path d="{seg}" fill="none" stroke="{OL}" stroke-width="8" stroke-linecap="round"/>'
        out += f'<path d="{seg}" fill="none" stroke="#9aa0a6" stroke-width="5.8" stroke-linecap="round"/>'
        out += path(_seg(curve, 0.44, 0.86), "none", "#e6e8ea", 1.1, .75)
        for t in (0.46, 0.84):
            x, y = _bez(*curve, t)
            out += path(f"M{x - 3:.2f},{y - .9:.2f} L{x + 3:.2f},{y + 1.1:.2f}", "none", "#4a4f55", 1.0, .9)
            out += f'<circle cx="{x:.2f}" cy="{y:.2f}" r=".55" fill="#e6e8ea" stroke="{OL}" stroke-width=".2"/>'
    return out


def legs_layer(fam, g):
    """Jambières : deux jambes (x0, x1) comme les grèves d'origine (gen_sprites_more.greaves)."""
    OL, path, rings = g.OL, g.path, g.rings
    out = ""
    for x0, x1 in ((-8.6, -0.6), (1.8, 9.8)):
        cx = (x0 + x1) / 2
        if fam == "tissu":
            out += path(f"M{x0 + .2},11.2 L{x1 - .2},11.2 L{x1 + .3},16 L{x0 - .6},16 Z", "#cdbf9b", OL, .9)
            for y in (12.4, 13.8, 15.1):
                out += path(f"M{x0 - .2},{y} L{x1},{y + .5}", "none", "#8a7c58", .6, .8)
        elif fam == "matelasse":
            out += path(f"M{x0 + .1},8.2 L{x1 - .1},8.2 L{x1 + .3},15.8 L{x0 - .7},15.8 Z", "#6e4a2c", OL, .9)
            out += path(f"M{x0},11 L{x1},11.4 M{x0 - .3},14 L{x1 + .1},14.4", "none", "#3a2616", .8, .85)
            out += f'<circle cx="{cx:.1f}" cy="12.6" r=".6" fill="#d9c9a0" stroke="{OL}" stroke-width=".2"/>'
            out += path(f"M{x0 + .9},8.6 L{x0 + .5},15", "none", "#fff", .5, .3)
        elif fam == "mailles":
            p = f"M{x0 + .1},7.6 L{x1 - .1},7.6 L{x1 + .3},15.8 L{x0 - .7},15.8 Z"
            out += path(p, "url(#gSteel)", OL, .9)
            cid = f"cl{int(x0 * 10) + 100}"
            out += f'<clipPath id="{cid}"><path d="{p}"/></clipPath><g clip-path="url(#{cid})"><path d="{rings(x0 - 1, x1 + 1, 7.5, 16)}" stroke="#23272c" stroke-width=".4" fill="none" opacity=".8"/></g>'
            out += path(f"M{x0 + .9},8 L{x0 + .5},15", "none", "#fff", .5, .45)
        else:  # plates : grève d'acier à genouillère
            out += path(f"M{x0 + .2},10.2 L{x1 - .2},10.2 L{x1 + .3},15.8 L{x0 - .7},15.8 Z", "url(#gSteel)", OL, .9)
            out += path(f"M{x0 + .9},11 L{x0 + .5},15.2", "none", "#fff", .6, .55)
            out += path(f"M{x0},13 L{x1 + .1},13.4", "none", "#4a4f55", .7, .8)
            out += f'<ellipse cx="{cx:.1f}" cy="9.6" rx="3.9" ry="2.7" fill="url(#gSteel)" stroke="{OL}" stroke-width=".9"/>'
            out += path(f"M{cx - 2:.1f},8.6 Q{cx:.1f},7.5 {cx + 2:.1f},8.6", "none", "#fff", .5, .65)
    return out


def main_sprites():
    import gen_sprites as g
    for fam in FAMILIES:
        g.write(f"limb_off_{fam}", bracer(OFF_ARM, fam, g))
        for pose, curve in POSES.items():
            g.write(f"limb_arm_{fam}_{pose}", bracer(curve, fam, g))
        g.write(f"limb_legs_{fam}", legs_layer(fam, g))


# ====================================================================== icônes d'objets (512 × 512, même facture que gen_equip_art)
GRAD = ('<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f3e2ad"/>'
        '<stop offset="1" stop-color="#c8a24c"/></linearGradient></defs>')
INK = "#17100a"


def _icon(shape, details="", extra_shapes=""):
    s = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">{GRAD}'
         f'<g fill="{INK}" stroke="{INK}" stroke-width="24" stroke-linejoin="round" stroke-linecap="round"><path d="{shape}"/>{extra_shapes}</g>'
         f'<g fill="url(#g)"><path d="{shape}"/></g>'
         f'<g fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round">{details}</g></svg>\n')
    return s


# tube de brassard : évasé au coude (haut), resserré au poignet (bas)
ARM_TUBE = "M168 110 Q256 84 344 110 L324 318 Q318 372 296 404 L216 404 Q194 372 188 318 Z"
LEG_TUBE = "M176 92 Q256 70 336 92 L322 300 Q318 372 306 432 L206 432 Q194 372 190 300 Z"


def arm_icon(key, fam):
    d = ""
    extra = ""
    shape = ARM_TUBE
    if fam == "tissu":
        d = "".join(f'<path d="M{180 + i * 2} {150 + i * 52} L{338 - i * 2} {170 + i * 52}"/>' for i in range(5))
    elif fam == "matelasse":
        d = ('<path d="M186 160 L330 160 M190 230 L326 230 M198 300 L318 300"/>'
             '<path d="M256 112 L256 400" stroke-dasharray="14 16"/>')
        if key == "manicles_cloutees":
            d += "".join(f'<circle cx="{x}" cy="{y}" r="9"/>' for x in (214, 256, 298) for y in (190, 265, 340))
    elif fam == "mailles":
        d = "".join(f'<path d="M{190 + c * 28} {r * 34 + 140} q14 22 28 0"/>' for r in range(8) for c in range(0, 5) if (r % 2 == 0 or c < 4))
    else:
        d = ('<path d="M176 160 Q256 140 336 160 M184 236 Q256 216 328 236 M196 312 Q256 296 316 312"/>'
             '<path d="M214 130 L228 392 M298 130 L284 392"/>')
        if key == "epaulieres_fer":  # coque d'épaule au-dessus du tube
            extra = '<path d="M128 142 Q256 28 384 142 L350 196 Q256 128 162 196 Z"/>'
            shape = ARM_TUBE + " M128 142 Q256 28 384 142 L350 196 Q256 128 162 196 Z"
            d += '<path d="M178 150 Q256 84 334 150"/>'
        if key == "brassards_orques":
            d += '<path d="M256 118 L276 80 L296 124 M216 124 L236 84 L256 118"/>'
    return _icon(shape, d, extra)


def leg_icon(key, fam):
    d = ""
    shape = LEG_TUBE
    if fam == "tissu":
        d = "".join(f'<path d="M{184 + i * 2} {190 + i * 48} L{326 - i * 2} {210 + i * 48}"/>' for i in range(5))
    elif fam == "matelasse":
        d = ('<path d="M190 170 L322 170 M192 250 L320 250 M196 330 L316 330"/>'
             '<path d="M256 96 L256 428" stroke-dasharray="14 16"/>')
        if key == "guetres_cloutees":
            d += "".join(f'<circle cx="{x}" cy="{y}" r="9"/>' for x in (226, 286) for y in (210, 290, 370))
    elif fam == "mailles":
        d = "".join(f'<path d="M{196 + c * 28} {r * 34 + 120} q14 22 28 0"/>' for r in range(9) for c in range(0, 5) if (r % 2 == 0 or c < 4))
    else:
        d = ('<path d="M196 236 Q256 220 316 236 M200 320 Q256 304 312 320"/>'
             '<path d="M222 250 L226 420 M292 250 L286 420"/>')
        shape = LEG_TUBE + " M168 76 Q256 40 344 76 L338 168 Q256 138 174 168 Z"  # genouillère
        d += '<path d="M184 100 Q256 72 328 100"/>'
        if key == "jambieres_orques":
            d += '<path d="M256 176 L276 138 L296 182"/>'
    return _icon(shape, d)


def main_icons(out=ICONS_ITEMS):
    os.makedirs(out, exist_ok=True)
    for key, fam in ARMS_LOOK.items():
        with open(os.path.join(out, f"arms_{key}.svg"), "w", encoding="utf-8") as f:
            f.write(arm_icon(key, fam))
    for key, fam in LEGS_LOOK.items():
        with open(os.path.join(out, f"legs_{key}.svg"), "w", encoding="utf-8") as f:
            f.write(leg_icon(key, fam))


def main():
    main_sprites()
    main_icons()


if __name__ == "__main__":
    main()
    print("calques et icônes de bras / jambes écrits")
