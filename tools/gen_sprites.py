#!/usr/bin/env python3
"""Génère les calques SVG des figurines dans assets/sprites/, à partir de `function figure`
du prototype (prototype/corbeau.html), puis enrichis (visages, coiffures, barbes, accessoires…).

Les calques teintables (peau, cheveux, étoffe, manches, cuir) sont dessinés en blanc : le jeu les
colore par `modulate` (voir scenes/ui/figure.gd). Tous partagent le même viewBox, donc ils
se superposent sans décalage.

    py tools/gen_sprites.py
"""
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sprites")
OL = "#17110c"
W = "#ffffff"
VB = (-36, -64, 72, 82)  # x, y, largeur, hauteur (unités du prototype)
SCALE = 4  # résolution de rastérisation

DEFS = """<defs>
<linearGradient id="gSteel" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e6e8ea"/><stop offset=".45" stop-color="#9aa0a6"/><stop offset="1" stop-color="#4a4f55"/></linearGradient>
<linearGradient id="gWood" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#a06e3c"/><stop offset="1" stop-color="#5b3a1e"/></linearGradient>
<linearGradient id="gShade" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#000" stop-opacity=".42"/><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#fff" stop-opacity=".1"/></linearGradient>
<radialGradient id="gShield" cx=".38" cy=".32" r=".75"><stop offset="0" stop-color="#fff" stop-opacity=".2"/><stop offset=".6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".45"/></radialGradient>
</defs>"""


def write(name, body):
    x, y, w, h = VB
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w * SCALE}" height="{h * SCALE}" '
           f'viewBox="{x} {y} {w} {h}">{DEFS}{body}</svg>\n')
    with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8") as f:
        f.write(svg)


def path(d, fill="none", stroke=None, sw=1.0, op=None, extra=""):
    s = f'<path d="{d}" fill="{fill}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"'
    if op is not None:
        s += f' opacity="{op}"'
    return s + f' {extra}/>'


def shade(d, op=0.2):
    """Ombre portée simple : aplat noir translucide."""
    return path(d, "#000", op=op)


def light(d, op=0.5, sw=0.8):
    """Liseré de lumière : trait clair fin."""
    return path(d, "none", "#ffffff", sw, op)


def limb(d, c, w):
    return (f'<path d="{d}" fill="none" stroke="{OL}" stroke-width="{w + 2.2}" stroke-linecap="round"/>'
            f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round"/>')


def stick(x1, y1, x2, y2, c, w):
    return limb(f"M{x1},{y1} L{x2},{y2}", c, w)


def hand(x, y):
    return (f'<circle cx="{x}" cy="{y}" r="2.8" fill="{W}" stroke="{OL}" stroke-width="1"/>'
            f'<path d="M{x - 1.6},{y - 0.3} q1.6,-1.2 3.2,0 M{x - 1.4},{y + 1} q1.5,-1 3,0" stroke="{OL}" stroke-width=".5" fill="none" opacity=".7"/>'
            f'<path d="M{x - 2.2},{y + 1.4} Q{x},{y + 3.4} {x + 2.2},{y + 1.4} Q{x},{y + 2.4} {x - 2.2},{y + 1.4} Z" fill="#000" opacity=".2"/>')


# ---------------------------------------------------------------- torse
T = "M-12,10 L-13.5,-4 Q-13,-13 -6,-15.6 L6,-15.6 Q13,-13 13.5,-4 L12,10 Z"


def rings(x0, x1, y0, y1):
    """Rangées d'anneaux de mailles : petites arcades décalées."""
    s = ""
    row = 0
    y = y0
    while y < y1:
        x = x0 + (1.1 if row % 2 else 0)
        d = ""
        while x < x1:
            d += f"M{x:.1f},{y:.1f} q1.1,1.5 2.2,0 "
            x += 2.2
        s += d
        y += 1.6
        row += 1
    return s


def torso(kind):
    s = ""
    if kind == "mailles":
        s += (f'<path d="{T}" fill="url(#gSteel)"/>'
              f'<clipPath id="ct"><path d="{T}"/></clipPath>'
              f'<g clip-path="url(#ct)"><path d="{rings(-14, 14, -15, 11)}" stroke="#23272c" stroke-width=".45" fill="none" opacity=".75"/></g>'
              f'<rect x="-12.8" y="2.5" width="25.6" height="3" fill="#4a3220" stroke="{OL}" stroke-width=".6"/>'
              f'<rect x="-1" y="2.1" width="4" height="3.8" fill="#9a8a5a" stroke="{OL}" stroke-width=".6"/>'
              + path("M-6,-15.6 Q0,-10 6,-15.6", "#2a2e33", OL, .8, extra='opacity=".9"')
              + light("M-10,-12 Q-12,-6 -11.5,6", .35, .7))
    elif kind == "brigandine":
        s += f'<path d="{T}" fill="#5a2a22"/>'
        # lamelles rivetées
        for y in (-12, -6, 0, 6):
            s += path(f"M-12.8,{y} L12.8,{y}", "none", "#2a120e", .7, .8)
            for x in (-10, -5, 0, 5, 10):
                s += (f'<circle cx="{x}" cy="{y + 3}" r=".95" fill="#d9c9a0" stroke="{OL}" stroke-width=".3"/>'
                      f'<circle cx="{x - .25}" cy="{y + 2.75}" r=".3" fill="#fff" opacity=".7"/>')
        s += path("M0,-15.6 L0,10", "none", "#2a120e", 1.0, .7)
        s += path("M-6,-15.6 Q0,-11 6,-15.6", "#3a1c16", OL, .8)
    elif kind == "gambison":
        s += (f'<path d="{T}" fill="#b49a6c"/>'
              + path("M-8,-14 L-8.4,10 M-3.5,-15.6 L-3.8,10 M1,-15.6 L1,10 M5.5,-15.6 L5.8,10 M10,-13 L10.4,10", "none", "#6e5a3a", .7, .75)
              + path("M-13,-4 Q0,-2.5 13,-4 M-12.5,3 Q0,4.5 12.5,3", "none", "#6e5a3a", .7, .75)
              + path("M-12.5,-9 Q0,-7.5 12.5,-9", "none", "#6e5a3a", .5, .5)
              + path("M-5,-15.6 Q0,-11.5 5,-15.6 L5,-13.5 Q0,-9.5 -5,-13.5 Z", "#8a7448", OL, .6)
              + f'<circle cx="0" cy="-12.4" r=".7" fill="#e7d8b0"/><circle cx="0" cy="-7" r=".7" fill="#e7d8b0"/><circle cx="0" cy="-1" r=".7" fill="#e7d8b0"/>')
    else:  # tunique : étoffe teintée
        s += (f'<path d="{T}" fill="{W}"/>'
              + path("M-2.5,-15.6 L1.5,-8.5 L5.5,-15.6 Z", "#d9b08c", OL, .6)
              + path("M1.5,-8.5 L1.2,2", "none", OL, .5, .6)
              + path("M-9,-6 Q-6,-2 -8,6 M7,-5 Q9,-1 8,6 M-4,-4 Q-3,1 -5,5", "none", "#000", .8, .22)
              + f'<rect x="-12.8" y="2" width="25.6" height="3.2" fill="#3a2616" stroke="{OL}" stroke-width=".5"/>'
              f'<rect x="0" y="1.6" width="3.6" height="4" fill="#c9a24a" stroke="{OL}" stroke-width=".5"/>'
              f'<rect x="1" y="2.6" width="1.6" height="2" fill="none" stroke="{OL}" stroke-width=".4"/>')
    return (s + f'<path d="{T}" fill="url(#gShade)"/>'
            + shade("M-13.5,-4 Q-13,-13 -6,-15.6 L-8,-15.6 Q-12,-10 -12,10 L-12,10 Z", .0)
            + f'<path d="{T}" fill="none" stroke="{OL}" stroke-width="1.3"/>')


def pauldron(kind):
    """Épaulière du côté de l'arme (dessinée après le bras)."""
    if kind == "mailles":
        return (path("M4,-16 Q12,-18.5 15.6,-11 Q15,-7 11,-6 Q9,-12 4,-14 Z", "url(#gSteel)", OL, 1.0)
                + path("M6,-15 Q11,-16 14,-11", "none", "#23272c", .5, .6)
                + light("M6,-16.4 Q11,-17.6 14.6,-12.5", .6, .7))
    return (path("M4,-16 Q12,-19 16,-11 Q15.4,-6 10.5,-5.4 Q9.6,-11.5 4,-14 Z", "#6b3126", OL, 1.0)
            + path("M6.5,-14.5 Q12,-15.5 14.6,-10.5 M8,-12 Q11,-12.5 13,-9", "none", "#2a120e", .6, .7)
            + f'<circle cx="13.2" cy="-11.4" r=".9" fill="#d9c9a0" stroke="{OL}" stroke-width=".3"/>'
            + f'<circle cx="9" cy="-14.4" r=".9" fill="#d9c9a0" stroke="{OL}" stroke-width=".3"/>'
            + light("M6,-16.4 Q11.5,-18 15,-12.5", .45, .7))


def cape():
    """Cape dans le dos (teintée par l'étoffe), derrière le torse."""
    d = "M-9,-16 Q-18,-12 -20,6 Q-20,16 -14,17 L-8,14 L-6,-12 Z"
    return (path(d, W, OL, 1.2)
            + path("M-14,-12 Q-17,0 -16,14 M-10.5,-11 Q-12.5,2 -12,14", "none", "#000", .7, .3)
            + shade("M-9,-16 Q-18,-12 -20,6 L-17,6 Q-15,-8 -8,-13 Z", .15)
            + path("M-8,-16 Q-14,-17 -9,-12", "#8a7448", OL, .7))


def satchel():
    return (path("M-15,-1 L-8,-1.5 L-7.5,9 L-14.5,9.8 Z", W, OL, 1.0)
            + path("M-15,-1 Q-11,2.5 -7.8,-0.6", "none", OL, .7)
            + f'<rect x="-12" y="2.2" width="2" height="2.4" fill="#c9a24a" stroke="{OL}" stroke-width=".4"/>'
            + shade("M-14.5,9.8 L-7.5,9 L-7.5,6 L-14.6,7 Z", .22))


def bandolier():
    return (path("M-9,-15 L12.5,5 L10.2,7.4 L-11.6,-12.2 Z", W, OL, .9)
            + path("M-8.5,-13 L11.2,5.2", "none", "#000", .5, .25)
            + "".join(f'<rect x="{x}" y="{y}" width="1.8" height="3.2" rx=".5" fill="#6a4426" stroke="{OL}" stroke-width=".4" transform="rotate(-48 {x + .9} {y + 1.6})"/>'
                      for x, y in ((-5, -9), (-.8, -5.3), (3.4, -1.6), (7.5, 2.2)))
            + f'<circle cx="-9.4" cy="-13" r="1" fill="#c9a24a" stroke="{OL}" stroke-width=".4"/>')


def scarf():
    return (path("M-5,-16.5 Q1,-12 7,-16.8 L8.2,-14 Q2,-9.5 -6.2,-13.6 Z", W, OL, 1.0)
            + path("M-1,-13 Q1,-9 -2.4,-3 L0.4,-2 Q4,-8 2.6,-12 Z", W, OL, .9)
            + path("M-4,-15 Q1,-11.8 6.2,-15.4", "none", "#000", .6, .28))


# ---------------------------------------------------------------- tête
JAW = "M-6,-27 Q-6.5,-35 1,-35 Q8,-35 8,-28 L8.2,-23.5 Q8.3,-19.2 4.8,-18.4 Q-.5,-17.8 -3.4,-21 Q-6,-23.5 -6,-27 Z"


def head():
    return (
        path("M-2.8,-22 L-3,-14 L5.4,-14 L4.8,-22 Z", W, OL, 1.0)
        + shade("M-2.8,-20 Q1.2,-17.3 4.9,-20 L5.4,-14 L-3,-14 Z", .28)
        + f'<path d="{JAW}" fill="{W}" stroke="{OL}" stroke-width="1.2"/>'
        + path("M-3.4,-21 Q-.5,-17.8 4.8,-18.4 Q8.3,-19.2 8.2,-23.5 Q3.5,-19.8 -3.4,-21 Z", "#000", op=.16)
        + path("M-6,-27 Q-6.5,-35 1,-35 Q-3,-33 -3.2,-26 Q-3.4,-22 -3.4,-21 Q-6,-23.5 -6,-27 Z", "#000", op=.14)
        + path("M8,-29.2 Q11,-25.5 10.4,-24 Q9.8,-23 8.2,-23.5", W)
        + path("M8,-29.2 Q11,-25.5 10.4,-24 Q9.8,-23 8.2,-23.5", "none", OL, 1.0)
        + f'<ellipse cx="-1.8" cy="-26" rx="1.7" ry="2.6" fill="{W}" stroke="{OL}" stroke-width=".8"/>'
        + path("M-2.6,-27.2 Q-1,-27.6 -1,-25.6 Q-1.4,-24.6 -2,-24.6", "none", "#000", .5, .5)
        + f'<ellipse cx="4.6" cy="-23" rx="3" ry="2" fill="#c0504a" opacity=".2"/>'
        + f'<ellipse cx="5" cy="-29.7" rx="3.3" ry="1.2" fill="#000" opacity=".1"/>'
        + path("M-4,-33 Q0,-35.2 5,-34.2", "none", "#fff", .7, .45)
    )


def face(v):
    """Traits du visage (non teintés) : œil, sourcil, narine, bouche. v = expression 0..2."""
    eye_w, eye_h = (1.15, 1.15) if v != 2 else (1.3, 1.5)
    s = path(f"M2.9,-28 Q5,{-29.7 - (eye_h - 1.15)} 7.4,-28.2 Q5.2,{-26.7 + (eye_h - 1.15)} 2.9,-28 Z", "#efe6d2", OL, .5)
    s += f'<circle cx="5.8" cy="-28.1" r="{eye_w - .05}" fill="#3c2c1c"/><circle cx="5.9" cy="-28.1" r=".55" fill="{OL}"/>'
    s += '<circle cx="5.4" cy="-28.5" r=".28" fill="#fff"/>'
    s += path("M2.9,-28.2 Q5,-30 7.5,-28.4", "none", OL, .45)
    if v == 0:
        s += path("M2.6,-30.4 Q5,-31.8 7.8,-30.4", "none", "#2a1c12", 1.3)
        s += path("M5,-21.5 Q6.8,-21.1 8.1,-21.7", "none", "#4a2a20", .8)
    elif v == 1:  # grave, sourcils froncés
        s += path("M2.4,-31.6 L7.9,-29.6", "none", "#2a1c12", 1.6)
        s += path("M5,-20.8 Q6.7,-22 8.1,-21", "none", "#4a2a20", .85)
        s += path("M3.4,-27 Q4.6,-26.3 6.6,-26.8", "none", "#000", .5, .25)
    else:  # sournois
        s += path("M2.6,-31.2 Q5,-33.2 7.6,-30.8", "none", "#2a1c12", 1.2)
        s += path("M4.8,-21.8 Q6.8,-20.6 8.2,-22.6", "none", "#4a2a20", .85)
        s += path("M8,-22.8 q.5,.2 .4,.8", "none", "#4a2a20", .5)
    s += '<circle cx="8.9" cy="-24.4" r=".5" fill="#2a1410" opacity=".75"/>'
    s += path("M4,-17.5 Q6,-17 7.4,-18", "none", "#000", .5, .15)
    return s


MARKS = {
    "scar_1": (path("M2.2,-25.4 L7,-21.4", "none", "#8a3c36", 1.0)
               + path("M3.6,-24.8 l-.6,1.4 M5,-23.6 l-.6,1.4 M6.2,-22.6 l-.6,1.4", "none", "#3a1812", .5)),
    "scar_2": (path("M3.4,-33.4 L6.8,-26.2", "none", "#a04a40", 1.0)
               + path("M3.6,-32 l1.4,-.4 M4.6,-30 l1.4,-.4 M5.6,-28 l1.4,-.4", "none", "#3a1812", .5)),
    "scar_3": (path("M7,-23.4 L7.6,-18.8", "none", "#8a3c36", .95)
               + path("M6.4,-22.2 l1.4,.1 M6.6,-20.6 l1.4,.1", "none", "#3a1812", .5)),
    "bruise": (f'<ellipse cx="5.2" cy="-28" rx="3.8" ry="3" fill="#5a3a6a" opacity=".5"/>'
               f'<ellipse cx="5.2" cy="-28" rx="2.6" ry="2" fill="#6a4a30" opacity=".35"/>'),
    "patch": (path("M-6,-32 L3.4,-30 M3.4,-30 L8,-26.8", "none", OL, .9)
              + f'<ellipse cx="5.4" cy="-28" rx="3.1" ry="2.8" fill="#1d1a17" stroke="{OL}" stroke-width=".7"/>'
              + path("M3.5,-29.6 Q5,-30.4 6.6,-29.8", "none", "#fff", .5, .3)),
}


def band():
    return (path("M-6.4,-31.6 Q1,-34.8 8.2,-31.4 L8.3,-29 Q1,-32 -6.4,-29.4 Z", W, OL, .9)
            + path("M-6.2,-30.6 Q-10,-30 -11.6,-25.5 L-9.4,-25.2 Q-8.6,-28.5 -5.6,-29 Z", W, OL, .8)
            + path("M-6,-30 Q-8.5,-28 -9.6,-22.5 L-7.6,-22.6 Q-7,-26 -5.2,-28 Z", W, OL, .8)
            + path("M-4,-30.6 Q1,-32.8 6,-30.6", "none", "#000", .5, .25))


BEARDS = {
    1: path("M-1,-24 Q0,-18.2 4,-18.4 Q8,-18.8 8.6,-22 Q5,-20.6 2,-21.6 Z", W, op=.55),
    2: (f'<path d="M-2,-25 Q-3,-15 3,-13.5 Q9,-14 9,-21.5 Q6,-20 4,-21 Q1.5,-21.5 -2,-25 Z" fill="{W}" stroke="{OL}" stroke-width=".8"/>'
        + path("M5,-22.6 Q7.5,-23.4 9.3,-22.2", "none", W, 1.6)
        + path("M0,-22 Q1,-17 3,-15.5 M3,-21 Q4,-17 6,-15.4", "none", "#000", .5, .25)),
    3: (path("M4.6,-22.8 Q7.5,-23.8 9.6,-22.4", "none", W, 1.8)
        + path("M4.6,-22.8 Q7.5,-23.8 9.6,-22.4", "none", OL, .4)
        + path("M5,-20.8 L8.2,-21 L6.8,-16.5 Z", W, OL, .6)),
    4: (path("M-2.6,-25 Q-4.5,-11 2,-6 Q8.5,-8 9.8,-19.5 Q9,-22.2 8.4,-22.8 Q5,-21 3,-22 Q0,-22 -2.6,-25 Z", W, OL, .9)
        + path("M0,-21 Q-.6,-12 2.4,-7.5 M3.5,-19 Q3.5,-12 4.4,-7.6 M6.5,-19 Q6.8,-12 6.4,-8.6", "none", "#000", .55, .3)
        + path("M5,-22.6 Q7.5,-23.4 9.3,-22.2", "none", W, 1.6)),
    5: (path("M-3.2,-30 Q-4.4,-21 1.6,-18.6 L2.4,-22 Q0,-24.2 -.6,-28.6 Z", W, OL, .8)
        + path("M5,-22.6 Q7.6,-23.8 9.8,-22.2", "none", W, 1.4)
        + path("M5,-22.6 Q7.6,-23.8 9.8,-22.2", "none", OL, .35)
        + path("M-2.4,-27 Q-2.6,-22 .8,-19.8", "none", "#000", .5, .3)),
    6: (path("M4.6,-20.8 L8.6,-21.2 Q9.2,-16.6 6.6,-15 Q3.6,-17 4.6,-20.8 Z", W, OL, .7)
        + path("M-2.6,-26 Q-2,-20.4 3.6,-18.4", "none", W, 1.0)
        + path("M-2.6,-26 Q-2,-20.4 3.6,-18.4", "none", OL, .3)),
    7: (path("M-2.4,-25 Q-3,-15.5 2.4,-13.6 Q8.6,-14.4 8.8,-21.6 Q6,-20 4,-21 Q1.5,-21.5 -2.4,-25 Z", W, OL, .8)
        + path("M2.6,-14 L1.2,-6.5 M5.8,-14.4 L6.8,-7", "none", OL, 3.0)
        + path("M2.6,-14 L1.2,-6.5 M5.8,-14.4 L6.8,-7", "none", W, 1.9)
        + path("M2.6,-14 l.9,.5 M1.9,-11 l.9,.5 M1.5,-8.6 l.9,.5 M5.8,-14.4 l-.9,.5 M6.2,-11.2 l-.9,.5", "none", "#000", .4, .5)
        + f'<circle cx="1.1" cy="-6" r="1.1" fill="#c9a24a" stroke="{OL}" stroke-width=".4"/>'
        + f'<circle cx="6.9" cy="-6.5" r="1.1" fill="#c9a24a" stroke="{OL}" stroke-width=".4"/>'
        + path("M5,-22.6 Q7.5,-23.4 9.3,-22.2", "none", W, 1.6)),
}

HAIRS = {
    0: path("M-6.5,-24 Q-8.5,-35 1,-35.8 Q8.5,-35.7 8,-29.5 Q4.5,-32.5 0,-31.4 Q-3,-30.5 -3.5,-26 Z", W, OL, 1.0)
       + path("M-3,-34 Q1,-35.6 5,-34.6", "none", "#fff", .7, .4)
       + path("M-5,-30 Q-3,-33 0,-33.2 M-6,-27 Q-4,-30 -2,-31", "none", "#000", .5, .3),
    1: path("M-6.8,-17 Q-9.8,-36 1,-35.9 Q8.6,-35.7 8.2,-29.5 Q4,-32.8 -.5,-31.5 Q-3,-30 -2.6,-24 Q-3.2,-19 -6.8,-17 Z", W, OL, 1.0)
       + path("M-5.4,-30 Q-7.6,-24 -5.4,-18.5 M-3.8,-30 Q-5.4,-24 -4,-19.5", "none", "#000", .55, .3)
       + path("M-3,-34 Q1,-35.8 5,-34.6", "none", "#fff", .7, .4),
    2: path("M-6.3,-23 Q-7.8,-31 -3,-34 L-2,-31 Q-4.5,-29 -3.6,-23 Z", W, OL, .8)
       + path("M-6.8,-21 Q-8.2,-29 -5.2,-31.5 Q-4.6,-27 -3,-23.5 Z", W, OL, .6),
    3: path("M-6.5,-24 Q-8.8,-33 -4.4,-34.6 L-3.4,-38.4 L-.8,-35.6 L1.2,-39 L3.4,-36 L6,-37.6 L6.8,-34 Q8.8,-32 8,-29.5 Q4.5,-32.5 0,-31.4 Q-3,-30.5 -3.5,-26 Z", W, OL, 1.0)
       + path("M-2,-36 L-1,-33.5 M2.4,-37 L2.8,-34", "none", "#000", .5, .3),
    4: path("M-7,-22 Q-9.8,-35 1,-36.2 Q9,-36.2 8.6,-29 L8,-31.8 Q4,-32.6 1,-31.2 Q-2,-30.4 -3,-27 Q-4,-24 -7,-22 Z", W, OL, 1.0)
       + path("M-1,-34.6 Q1,-35.6 4.5,-35.4", "none", "#fff", .7, .45)
       + path("M1,-31.2 L.4,-33.4 M4,-32.3 L3.8,-34.4", "none", "#000", .45, .35),
    5: (path("M-6.5,-24 Q-8.5,-35 1,-35.8 Q8.5,-35.7 8,-29.5 Q4.5,-32.5 0,-31.4 Q-3,-30.5 -3.5,-26 Z", W, OL, 1.0)
        + f'<circle cx="-8.4" cy="-31.4" r="3.2" fill="{W}" stroke="{OL}" stroke-width=".9"/>'
        + path("M-10,-32.6 Q-8,-33.6 -6.6,-32 M-10.4,-30.4 Q-8.2,-31.4 -6.4,-29.8", "none", "#000", .5, .35)
        + path("M-7.4,-28.6 L-9.6,-24 L-8,-24.2 L-6,-27.6 Z", W, OL, .7)),
    6: path("M-6.5,-24 Q-8.8,-31.5 -3.6,-34.6 Q-1,-35.6 .6,-34.2 Q-2,-32.8 -2.8,-29 Q-3.4,-26 -3.5,-26 Z", W, OL, 1.0)
       + path("M-6.4,-24.5 Q-9.4,-26 -8.4,-29.8", "none", OL, .6),
}

HELMETS = {
    "casque": (
        f'<path d="M-8.6,-26.5 Q-9,-37.5 .8,-42 Q10,-38 10,-26.5 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1.2"/>'
        + path("M-8.8,-26.5 Q-6,-33 -2,-39 M1,-41.8 Q5,-34 4.6,-27", "none", "#4a4f55", .6, .55)
        + f'<rect x="-9" y="-29.4" width="19.2" height="3" fill="#6a7076" stroke="{OL}" stroke-width=".8"/>'
        + "".join(f'<circle cx="{x}" cy="-27.9" r=".62" fill="#d6d9dc" stroke="{OL}" stroke-width=".25"/>' for x in (-6.5, -2.5, 1.5, 5.5, 8.8))
        + f'<path d="M7.2,-27.5 L10,-27.5 L9.6,-19.4 Q8.4,-18.4 7.4,-19.4 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width=".9"/>'
        + path("M-8.6,-26.5 Q-9.5,-23 -8.2,-20 L-6,-21 Q-6.4,-24 -6,-26.5 Z", "#6a7076", OL, .7)
        + '<path d="M2,-39.6 Q6,-37.6 8,-31.4" stroke="#fff" stroke-width=".9" opacity=".55" fill="none"/>'
        + path("M-6.2,-37 Q-3,-40 .8,-40.4", "none", "#fff", .5, .4)
        + f'<circle cx=".8" cy="-41.6" r="1.1" fill="#6a7076" stroke="{OL}" stroke-width=".6"/>'),
    "heaume": (
        f'<path d="M-8.7,-16 L-9.2,-31 Q-8.7,-39.4 1,-39.6 Q10.8,-39.4 10.8,-31 L10.4,-16 Q1,-13.6 -8.7,-16 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1.3"/>'
        + path("M-9,-31 Q1,-33.4 10.7,-31", "none", "#5d6268", 1.3)
        + path("M1,-39.6 L1,-14.2", "none", "#5d6268", .8, .6)
        + path("M2,-28.4 L10.6,-28.4", "none", "#0d0907", 2.0)
        + path("M2,-26.8 L10.6,-26.8", "none", "#000", .6, .35)
        + path("M9.6,-37.8 L10,-16.6", "none", "#f0f2f4", .9, .55)
        + '<g fill="#0d0907"><circle cx="5.5" cy="-21.5" r=".72"/><circle cx="8" cy="-21.5" r=".72"/><circle cx="5.5" cy="-19" r=".72"/><circle cx="8" cy="-19" r=".72"/><circle cx="5.5" cy="-16.8" r=".72"/><circle cx="8" cy="-16.8" r=".72"/></g>'
        + "".join(f'<circle cx="{x}" cy="{y}" r=".6" fill="#d6d9dc" stroke="{OL}" stroke-width=".25"/>' for x, y in ((-6.6, -34), (-6.6, -26), (-6.6, -19.5), (-2.4, -36.4)))
        + path("M-8.7,-16 L-9,-12 Q1,-10 10.4,-12.4 L10.4,-16", "#5d6268", OL, .7)
        + shade("M-8.7,-31 L-9.2,-31 L-8.7,-16 Q-3,-15 -3,-16 Q-4.6,-24 -4.2,-31 Z", .2)),
    "capuchon": (
        f'<path fill-rule="evenodd" d="M-9.8,-14.6 Q-12,-31 -3,-37 Q-1,-42 3.4,-44 Q2,-40 4.6,-38 Q11.2,-35 10.4,-28.5 Q11.6,-22 9.8,-17 Q4,-12.6 -9.8,-14.6 Z M8.8,-25 a4.8,6.3 0 1,0 -9.6,0 a4.8,6.3 0 1,0 9.6,0 Z" fill="{W}" stroke="{OL}" stroke-width="1.1"/>'
        + path("M-8,-30 Q-4,-29 -2,-35 M-9.5,-22 Q-5,-21 -3.5,-25 M-8.6,-17 Q-5,-17 -3.6,-20", "none", OL, .6, .5)
        + path("M-3,-14.4 Q3,-12.6 9.6,-16.6", "none", "#000", .8, .3)
        + path("M0.4,-31.4 Q4,-34 8.6,-30.6", "none", "#fff", .7, .5)
        + shade("M8.8,-25 a4.8,6.3 0 0,1 -9.6,0 a4.2,5.4 0 0,0 9.6,0 Z", .25)
        + path("M7.5,-29 L10.4,-24.4 L7.6,-23.8", "#d9b08c", OL, 1.0)),
}

# ---------------------------------------------------------------- armes
# (arme, main x, main y)
HANDS = {"gourdin": (15.4, -1), "fourche": (11.4, -1), "lance": (13.4, -1), "hache": (13.6, -1),
         "masse": (14.3, -1), "epee": (14.5, -0.5), "arc": (20.5, -8),
         "arbalete": (16.5, -5), "hallebarde": (13.0, -1), "fleau": (14.0, -1), "javelot": (14.0, -1)}


def weapon(w):
    s = ""
    if w == "arc":
        s += (f'<path d="M17,-34 Q31,-8 17,18" fill="none" stroke="{OL}" stroke-width="4.6"/>'
              '<path d="M17,-34 Q31,-8 17,18" fill="none" stroke="url(#gWood)" stroke-width="2.8"/>'
              + path("M18,-31 Q29,-8 18,15", "none", "#fff", .5, .35)
              + '<path d="M17,-34 L17,18" stroke="#d8cfb8" stroke-width=".6"/>'
              + path("M19.5,-12 Q21.5,-8 19.5,-3.4", "#3a2818", OL, .5)
              + f'<circle cx="17" cy="-34.4" r="1" fill="#d8cfb8" stroke="{OL}" stroke-width=".4"/><circle cx="17" cy="18.4" r="1" fill="#d8cfb8" stroke="{OL}" stroke-width=".4"/>')
    elif w == "epee":
        s += (stick(13.3, 4, 14.6, -2, "#5a3a1e", 1.7)
              + path("M13,2.8 l2.2,.3 M12.8,.6 l2.2,.3", "none", OL, .5, .6)
              + f'<circle cx="13.2" cy="5.6" r="2" fill="url(#gSteel)" stroke="{OL}" stroke-width=".8"/>'
              + f'<path d="M13.5,-3.9 L16.3,-3.2 L23.4,-37.6 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1" stroke-linejoin="round"/>'
              + '<path d="M15,-4.4 L22.6,-34" stroke="#6d737a" stroke-width=".7"/>'
              + path("M14,-5 L22.2,-35", "none", "#fff", .5, .6)
              + stick(9.6, -4.8, 20, -2.2, "#8a9096", 2.0)
              + f'<circle cx="9.6" cy="-4.8" r="1.1" fill="#8a9096" stroke="{OL}" stroke-width=".5"/><circle cx="20" cy="-2.2" r="1.1" fill="#8a9096" stroke="{OL}" stroke-width=".5"/>')
    elif w == "lance":
        s += (stick(10, 12, 24, -42, "#7a5230", 2.3)
              + path("M13.5,0 L12.6,-3 M16,-9 L15.2,-12", "none", OL, .6, .6)
              + path("M23,-40 Q28,-38 27,-31.5 Q25,-35 22.4,-38 Z", "#8a3028", OL, .6)
              + f'<rect x="22.4" y="-42.6" width="3.6" height="2" rx=".6" fill="#9a8a5a" stroke="{OL}" stroke-width=".6" transform="rotate(-18 24 -41.6)"/>'
              + f'<path d="M24,-43 L27.6,-45.8 L26.4,-53.6 L22.2,-47.2 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1" stroke-linejoin="round"/>'
              + path("M24.4,-44 L26,-51", "none", "#fff", .6, .6))
    elif w == "hache":
        s += (stick(11, 9, 20, -26, "#7a5230", 2.5)
              + path("M13.4,1.5 L14.4,2 M15,-4 L16,-3.5", "none", OL, .6, .6)
              + f'<circle cx="11" cy="9.2" r="1.3" fill="#5a3a1e" stroke="{OL}" stroke-width=".6"/>'
              + f'<path d="M18.2,-22 L25,-30 Q32,-22.4 26.4,-12.6 L19.4,-17 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1.1" stroke-linejoin="round"/>'
              + path("M18.4,-19 L22.6,-23.4 L23.6,-17.5 Z", "#6a7076", OL, .6)
              + path("M25.6,-28.4 Q30,-22.4 26.2,-14.6", "none", "#f2f4f6", .9, .75)
              + path("M20,-19 L23.6,-17.6 M19.4,-21 L24,-25", "none", "#2a2e33", .5, .6))
    elif w == "masse":
        s += (stick(12, 7, 19, -17, "#5a3a1e", 2.3)
              + path("M13.6,1.5 l1.3,.5 M15.6,-5 l1.3,.5", "none", OL, .6, .6)
              + f'<path d="M19.6,-26.5 L21,-22.4 L25.2,-20.5 L21,-18.6 L19.6,-14.2 L18.2,-18.6 L14,-20.5 L18.2,-22.4 Z" fill="#6a7076" stroke="{OL}" stroke-width=".9"/>'
              + f'<circle cx="19.6" cy="-20.4" r="3.4" fill="url(#gSteel)" stroke="{OL}" stroke-width=".9"/>'
              + path("M17.6,-22 Q19.6,-23.8 21.6,-22.4", "none", "#fff", .6, .6)
              + f'<circle cx="19.6" cy="-20.4" r="1" fill="#2a2e33"/>'
              + f'<path d="M20.4,-28.4 L19.6,-26.4 L18.8,-28.4 Z" fill="#8a9096" stroke="{OL}" stroke-width=".6"/>')
    elif w == "gourdin":
        s += (f'<path d="M12.4,5 L15.2,5.8 L23.8,-15.5 Q22.2,-22 17.4,-18.6 Z" fill="url(#gWood)" stroke="{OL}" stroke-width="1.1" stroke-linejoin="round"/>'
              + path("M14,3 Q18,-5 21,-14 M16,4 Q20,-4 22.6,-12", "none", "#3a2414", .5, .5)
              + f'<circle cx="19.5" cy="-12" r=".95" fill="{OL}"/><circle cx="21" cy="-16.5" r=".85" fill="{OL}"/><circle cx="17.5" cy="-14" r=".75" fill="{OL}"/>'
              + f'<path d="M21.6,-18.4 l1,-1.2 M19,-17.6 l.4,-1.2" stroke="{OL}" stroke-width=".6"/>'
              + path("M13,5.4 Q14,5.8 15,5.2", "none", "#3a2414", 1.2)
              + light("M13.6,4 L21,-14", .35, .6))
    elif w == "arbalete":
        s += (f'<path d="M12,-7 L31,-5.4 L31,-2.4 L12,-3 Z" fill="url(#gWood)" stroke="{OL}" stroke-width="1.1" stroke-linejoin="round"/>'
              + f'<path d="M25,-24 Q35,-4 25,16" fill="none" stroke="{OL}" stroke-width="4.4" stroke-linecap="round"/>'
              + '<path d="M25,-24 Q35,-4 25,16" fill="none" stroke="url(#gWood)" stroke-width="2.6" stroke-linecap="round"/>'
              + '<path d="M25,-24 L19,-4 L25,16" fill="none" stroke="#d8cfb8" stroke-width=".6"/>'
              + f'<rect x="21" y="-6.8" width="7" height="3.4" rx=".8" fill="#6a7076" stroke="{OL}" stroke-width=".7"/>'
              + path("M13,-6 L30,-4.6", "none", "#fff", .5, .35)
              + f'<path d="M19,-4.6 L33,-4.6" stroke="{OL}" stroke-width="1.4"/><path d="M32,-6 L35.4,-4.6 L32,-3.2 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width=".6"/>')
    elif w == "hallebarde":
        s += (stick(9, 13, 23, -40, "#7a5230", 2.4)
              + path("M13,0 L12.2,-3 M16.5,-12 L15.7,-15 M19.6,-24 L18.8,-27", "none", OL, .6, .6)
              + f'<path d="M22.6,-37 L36,-42 Q37,-34 28,-30.4 L23.6,-31 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1.1" stroke-linejoin="round"/>'
              + path("M25,-36.6 L33,-39.4", "none", "#f2f4f6", .9, .7)
              + f'<path d="M23.4,-40.4 L24.4,-52 L21.6,-44 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1" stroke-linejoin="round"/>'
              + f'<path d="M21.8,-38 L16,-34.2 L21,-33 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width=".9" stroke-linejoin="round"/>'
              + f'<rect x="20.8" y="-39" width="4" height="2.4" rx=".6" fill="#6a7076" stroke="{OL}" stroke-width=".6" transform="rotate(-14 23 -38)"/>')
    elif w == "fleau":
        s += (stick(12, 6, 18, -14, "#5a3a1e", 2.2)
              + path("M13.6,1.5 l1.3,.5 M15.6,-5 l1.3,.5", "none", OL, .6, .6)
              + f'<circle cx="18.4" cy="-15.4" r="1.3" fill="#8a9096" stroke="{OL}" stroke-width=".6"/>'
              + f'<path d="M19,-16.4 Q24,-21 20,-24.4 Q15,-27 19,-30.4" fill="none" stroke="{OL}" stroke-width="2.4" stroke-linecap="round"/>'
              + '<path d="M19,-16.4 Q24,-21 20,-24.4 Q15,-27 19,-30.4" fill="none" stroke="#8a9096" stroke-width="1.1" stroke-linecap="round" stroke-dasharray="1.6 1.2"/>'
              + f'<path d="M19,-30 L20.4,-34 L22.6,-31.6 L26.4,-32 L24.6,-28.6 L27,-26 L23.4,-25.4 L21.4,-22.2 L19.8,-25.4 L16.4,-26 L18.6,-28.6 L17.4,-32 L21,-31.6 Z" fill="#6a7076" stroke="{OL}" stroke-width=".9" stroke-linejoin="round"/>'
              + f'<circle cx="21.2" cy="-28" r="3.6" fill="url(#gSteel)" stroke="{OL}" stroke-width=".9"/>'
              + path("M19.4,-29.6 Q21,-31.2 22.8,-29.8", "none", "#fff", .6, .6))
    elif w == "javelot":
        s += (stick(10, 8, 25, -30, "#7a5230", 2.0)
              + path("M13.2,0 L12.4,-3 M17,-9 L16.2,-12", "none", OL, .6, .6)
              + f'<path d="M24.6,-30.6 L28.2,-36 L26.4,-46 L22.6,-37 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1" stroke-linejoin="round"/>'
              + path("M25,-32 L26.4,-42", "none", "#fff", .6, .6)
              + path("M9.6,9.4 L7,13.6 L11.8,11.6 Z", "#8a3028", OL, .6)
              + f'<path d="M-6,-1 L-12,2 M-7,-6 L-14,-5" stroke="{OL}" stroke-width="0"/>')
    elif w == "fourche":
        prongs = "M19.6,-36.8 L27.2,-38.6 M19.6,-36.8 L18.2,-46 M23.4,-37.7 L23,-47.5 M27.2,-38.6 L28.2,-47"
        s += (stick(7, 13, 23, -38, "#8a6238", 2.1)
              + path("M9.5,6 l1.2,.5 M13,-4 l1.2,.5 M17,-16 l1.2,.5", "none", OL, .5, .6)
              + f'<rect x="18.8" y="-38.4" width="9" height="2.4" rx=".7" fill="#6a7076" stroke="{OL}" stroke-width=".7" transform="rotate(-13 23 -37.2)"/>'
              + f'<path d="{prongs}" stroke="{OL}" stroke-width="3.1" fill="none" stroke-linecap="round"/>'
              + f'<path d="{prongs}" stroke="#80868c" stroke-width="1.4" fill="none" stroke-linecap="round"/>'
              + path("M18.4,-45 L19.4,-38 M23.2,-46.4 L23.4,-38.6", "none", "#fff", .4, .5))
    return s


def arm(w):
    hx, hy = HANDS[w]
    if w == "arc":
        d = "M8,-13 Q14,-12 20,-8"
    else:
        d = f"M8,-13 Q{hx + 2},{(-13 + hy) / 2} {hx},{hy}"
    return (limb(d, W, 4.6)
            + path(d, "none", "#000", 1.1, .2, extra='transform="translate(0,1.3)"')
            + path(d, "none", "#fff", .7, .45, extra='transform="translate(0,-1.4)"')
            + path("M9,-12 q.6,2 2.4,2.4", "none", "#000", .5, .35))


def shield(kind, raised):
    cx, cy, r = (7, -5, 13.5) if raised else (-5, -1, 12)
    s = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{"#b8862e" if kind == "p" else "#7a2a20"}"/>'
    if kind == "p":
        s += (f'<path d="M{cx - r * .72},{cy - r * .32} L{cx},{cy + r * .42} L{cx + r * .72},{cy - r * .32}" '
              f'stroke="#1d1a17" stroke-width="{r * .32}" fill="none" stroke-linejoin="miter"/>')
    else:
        s += f'<path d="M{cx - r * .71},{cy - r * .71} A{r},{r} 0 0,1 {cx + r * .71},{cy + r * .71} Z" fill="#4a3326"/>'
    # planches et usure
    s += (f'<path d="M{cx - r * .9},{cy - r * .3} Q{cx},{cy - r * .2} {cx + r * .9},{cy - r * .35} '
          f'M{cx - r * .85},{cy + r * .4} Q{cx},{cy + r * .5} {cx + r * .88},{cy + r * .35} '
          f'M{cx - r * .4},{cy - r * .9} L{cx - r * .45},{cy + r * .9} M{cx + r * .45},{cy - r * .9} L{cx + r * .42},{cy + r * .9}" stroke="#000" stroke-width=".6" opacity=".25" fill="none"/>')
    s += (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#gShield)"/>'
          f'<circle cx="{cx}" cy="{cy}" r="{r - 1}" fill="none" stroke="#3a2818" stroke-width="2"/>'
          f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{OL}" stroke-width="1.2"/>')
    # rivets de la bordure
    for i in range(10):
        import math
        a = math.tau * i / 10
        s += f'<circle cx="{cx + (r - 1) * math.cos(a):.2f}" cy="{cy + (r - 1) * math.sin(a):.2f}" r=".55" fill="#c8c0a0" stroke="{OL}" stroke-width=".25"/>'
    s += (path(f"M{cx - r * .7},{cy - r * .55} A{r * .9},{r * .9} 0 0,1 {cx + r * .1},{cy - r * .88}", "none", "#fff", .8, .35)
          + f'<circle cx="{cx}" cy="{cy}" r="3.3" fill="url(#gSteel)" stroke="{OL}" stroke-width=".9"/>'
          + f'<circle cx="{cx - .8}" cy="{cy - .9}" r="1" fill="#fff" opacity=".45"/>')
    return s


def quiver():
    return (f'<path d="M-15,-19 L-10,-21 L-6.5,7 L-11.5,8 Z" fill="#6a4426" stroke="{OL}" stroke-width="1"/>'
            + path("M-13.6,-14 L-9.2,-15.4 M-12.6,-6 L-8.4,-7.4 M-11.8,1 L-7.6,0", "none", "#2a1a0e", .6, .6)
            + path("M-15,-17 Q-11,-16 -9.8,-19.4", "none", "#3a2616", 1.4)
            + '<path d="M-14.5,-19 L-16,-25 M-12.5,-20 L-12.8,-26.5 M-10.6,-20.6 L-9.4,-26" stroke="#d8cfb8" stroke-width="1.6" stroke-linecap="round"/>'
            + path("M-16,-25 l-1.2,-1.2 M-12.8,-26.5 l-1,-1.4 M-9.4,-26 l-.6,-1.6", "none", "#a03a2a", 1.2)
            + path("M-8.4,-15 L11,3.5", "none", OL, 1.6)
            + path("M-8.4,-15 L11,3.5", "none", "#6a4426", .8))


# ---------------------------------------------------------------- goules
def ghoul(big, variant):
    tone, dark = ("#5f6656", "#41473b") if big else ("#737a66", "#565c4c")

    def claws(x, y):
        d = f"M{x},{y} q3,1 4.5,5 M{x},{y} q1.2,2.4 1,6.4 M{x},{y} q-1,2.2 -3.4,5"
        return (f'<circle cx="{x}" cy="{y}" r="2.7" fill="{dark}" stroke="{OL}" stroke-width="1"/>'
                f'<path d="{d}" stroke="{OL}" stroke-width="2.6" fill="none" stroke-linecap="round"/>'
                f'<path d="{d}" stroke="#e6dcc0" stroke-width="1.1" fill="none" stroke-linecap="round"/>'
                + path(f"M{x - 1.5},{y - 1} q1.5,-1 3,0", "none", "#000", .5, .4))

    B = "M-14,10 Q-19,-5 -9,-15 Q1,-22 10,-16 Q15,-10 12,0 L10,10 Z"
    s = '<g transform="translate(-1,1) scale(1.3)">' if big else "<g>"
    s += limb("M-4,-10 Q-7,0 -2,9", dark, 4) + claws(-2, 9)
    s += f'<path d="{B}" fill="{tone}"/><path d="{B}" fill="url(#gShade)"/><path d="{B}" fill="none" stroke="{OL}" stroke-width="1.3"/>'
    # épine dorsale saillante, côtes et chairs déchirées
    s += (f'<path d="M-16,3 q-2,-2 .5,-4 M-15,-5 q-2,-2.5 1,-4.5 M-10.5,-11.5 q-1,-3 2,-4 M-4,-16 q0,-3 3,-3" stroke="{OL}" stroke-width="1.1" fill="none"/>'
          + "".join(f'<circle cx="{x}" cy="{y}" r="1" fill="{tone}" stroke="{OL}" stroke-width=".6"/>' for x, y in ((-15.4, 0), (-14.6, -7), (-10.2, -13.2), (-5, -17.6)))
          + path("M-3,-8 Q2,-6 7,-8 M-4,-4 Q1,-2 7,-4 M-4,0 Q1,2 7,0 M-3,4 Q1,6 6,4", "none", dark, 1.3)
          + path("M-3,-7.4 Q2,-5.4 7,-7.4 M-4,-3.4 Q1,-1.4 7,-3.4", "none", "#fff", .5, .25)
          + path("M2,-14 l3,5 l-2.4,1 l2.6,4.4", "#5a1e1a", OL, .6, .75)
          + path("M-9,-3 Q-6,0 -9,5 Q-12,2 -9,-3 Z", "#6a2a22", OL, .6, .6))
    s += f'<path d="M8,-17 L3,-24 L10,-19.5 Z" fill="{tone}" stroke="{OL}" stroke-width="1"/>'
    if variant == 1:  # oreille arrachée, crâne dégarni
        s += path("M2,-17.5 L1.4,-21 L4.5,-19 Z", "#6a2a22", OL, .6)
    else:
        s += path("M4,-21 L6.4,-18.2", "none", OL, .5)
    s += f'<path d="M6,-13 Q7,-22 15,-21.5 Q22,-20.5 22.5,-13 L25.5,-9 Q20,-4 12,-5 Q6,-6 6,-13 Z" fill="{tone}" stroke="{OL}" stroke-width="1.2"/>'
    s += path("M8,-18 Q11,-21 15,-20.4", "none", "#fff", .7, .3)
    s += path("M8.4,-14 Q9.5,-19 13,-20 M16,-21 l1,2 M19,-20 l.6,2.4", "none", dark, .7, .9)
    # mâchoire : fermée (0) ou grande ouverte et bavante (1)
    if variant == 1:
        s += (f'<path d="M11,-8 L25.5,-9.4 Q24,-4 13,-1 Z" fill="#2a0e0c" stroke="{OL}" stroke-width="1"/>'
              f'<path d="M11.4,-8.5 l1.2,2.4 l1.2,-2.4 l1.2,2.4 l1.2,-2.4 l1.2,2.4 l1.2,-2.4 l1.2,2.4 l1.2,-2.4 l1.2,2.2 l1,-2.3" fill="#e9e0c4" stroke="{OL}" stroke-width=".5"/>'
              f'<path d="M12,-1.6 Q18,-1 23,-5.4 L22.6,-3.2 Q18,.4 12.4,-.4 Z" fill="{dark}" stroke="{OL}" stroke-width="1"/>'
              f'<path d="M13,-1.6 l1,-2.4 l1,2.2 l1,-2.4 l1,2.2 l1,-2.2 l1,2 l1,-2.2" fill="#e9e0c4" stroke="{OL}" stroke-width=".4"/>'
              f'<path d="M16.4,.4 Q16,4 17,6.4" stroke="#bfe0a8" stroke-width=".9" fill="none" opacity=".6" stroke-linecap="round"/>')
    else:
        s += (f'<path d="M11,-8.5 L25.5,-9 Q23.5,-2.5 13,-2.2 Z" fill="{dark}" stroke="{OL}" stroke-width="1"/>'
              f'<path d="M12,-8.6 l1.2,2.2 l1.2,-2.2 l1.2,2.2 l1.2,-2.2 l1.2,2.2 l1.2,-2.2 l1.2,2.2 l1.2,-2.2 l1.2,2 l1,-2.1" fill="#e9e0c4" stroke="{OL}" stroke-width=".5"/>'
              f'<path d="M13.4,-3 l1,-1.9 l1,1.9 l1,-1.9 l1,1.9" fill="#e9e0c4" stroke="{OL}" stroke-width=".4"/>')
    # œil jaune creux, sourcil lourd ; variante : orbite vide
    s += path("M12,-17.4 Q17,-20.4 21.8,-16", "none", OL, 2.0)
    s += f'<ellipse cx="17.6" cy="-14.6" rx="3.4" ry="2.9" fill="#1a1410" opacity=".55"/>'
    if variant == 1:
        s += f'<circle cx="17.8" cy="-14.4" r="1.7" fill="#0d0907"/>'
        s += f'<circle cx="12.6" cy="-13.4" r="1.9" fill="#f1d34a" opacity=".25"/><circle cx="12.6" cy="-13.4" r="1" fill="#f4dc5c"/>'
    else:
        s += ('<circle cx="18" cy="-14.6" r="2.7" fill="#f1d34a" opacity=".28"/><circle cx="18" cy="-14.6" r="1.5" fill="#f4dc5c"/>'
              f'<rect x="17.7" y="-16" width=".7" height="2.8" fill="{OL}"/>')
    s += path("M23.5,-11 l1.2,.3 M24,-9.8 l1.1,.4", "none", OL, .5)
    s += limb("M6,-9 Q16,-2 19,7", tone, 4.2) + claws(19, 7)
    return s + "</g>"


# ---------------------------------------------------------------- orcs
def head_orc():
    jaw = "M-6.4,-27 Q-7,-35.4 1,-35.4 Q8.4,-35.4 8.4,-28.6 L8.8,-24 Q10.2,-21 9.8,-18.4 Q8,-16.2 4,-16.2 Q-1.6,-16.2 -4.2,-20 Q-6.4,-23 -6.4,-27 Z"
    return (
        path("M-3.8,-22 L-4.4,-13 L6.6,-13 L5.8,-22 Z", W, OL, 1.0)
        + shade("M-3.8,-19 Q1.4,-16 5.9,-19 L6.6,-13 L-4.4,-13 Z", .3)
        + path("M-4.4,-28.5 L-11,-34.4 L-9,-26.6 L-4.6,-23.6 Z", W, OL, .9)
        + path("M-5,-28 L-9,-31.4", "none", "#000", .5, .35)
        + f'<path d="{jaw}" fill="{W}" stroke="{OL}" stroke-width="1.3"/>'
        + path("M8.2,-28.6 Q11,-26 10.6,-24 Q10,-22.8 8.6,-23.2", W)
        + path("M8.2,-28.6 Q11,-26 10.6,-24 Q10,-22.8 8.6,-23.2", "none", OL, 1.0)
        + path("M-4.2,-20 Q-1.6,-16.2 4,-16.2 Q8,-16.2 9.8,-18.4 Q4,-18.4 -4.2,-20 Z", "#000", op=.2)
        + path("M-6.4,-27 Q-7,-35.4 1,-35.4 Q-3.4,-33 -3.6,-26 Q-3.8,-22 -4.2,-20 Q-6.4,-23 -6.4,-27 Z", "#000", op=.14)
        + '<ellipse cx="4.6" cy="-30.6" rx="4.6" ry="1.8" fill="#000" opacity=".22"/>'
        + '<ellipse cx="4.6" cy="-22.6" rx="3.2" ry="2" fill="#2a4a1a" opacity=".2"/>'
        + path("M-4,-33 Q0,-35.2 5,-34.2", "none", "#fff", .7, .4)
        + path("M-1,-34 l1.6,2.4 M2,-35 l.6,2.2", "none", "#000", .5, .25))


def face_orc(v):
    tusk = "#e8dcb8"
    s = f'<ellipse cx="5.6" cy="-28.2" rx="2.1" ry="1.5" fill="#e8c84a" stroke="{OL}" stroke-width=".5"/>'
    s += '<ellipse cx="5.9" cy="-28.2" rx=".55" ry="1.2" fill="#8a1a10"/>'
    if v == 1:  # balafre à travers l'œil
        s += path("M3.6,-30.6 L7.6,-26", "none", "#a04a40", 1.0)
        s += path("M4.4,-29.6 l1.2,-.6 M5.6,-28.2 l1.2,-.6 M6.8,-26.8 l1.2,-.6", "none", "#3a1812", .4)
    s += path("M1.4,-31.2 L8.6,-29.2", "none", "#1a120a", 2.3)
    s += path("M2.6,-24.8 q1.6,1 3,.4", "none", "#000", .5, .4)
    s += '<circle cx="9.6" cy="-25.2" r=".55" fill="#1a0e08"/>'
    if v == 0:
        s += path("M3.2,-21.4 Q7,-20.2 9.6,-21.8", "none", "#2a1410", 1.0)
        s += f'<path d="M6.4,-20.8 L7.2,-26 L8.8,-21 Z" fill="{tusk}" stroke="{OL}" stroke-width=".6"/>'
        s += f'<path d="M3,-19.6 L3.4,-23.4 L5,-19.8 Z" fill="{tusk}" stroke="{OL}" stroke-width=".6"/>'
    elif v == 1:
        s += path("M3.4,-21 Q7,-21.8 9.4,-21.2", "none", "#2a1410", 1.0)
        s += f'<path d="M6.6,-20.6 L7.4,-24.4 L8.8,-20.8 Z" fill="{tusk}" stroke="{OL}" stroke-width=".6"/>'
        s += f'<path d="M3,-19.6 L3.3,-21.6 L4.8,-19.8 Z" fill="{tusk}" stroke="{OL}" stroke-width=".6"/>'
    else:  # rictus, nombreuses dents
        s += path("M2.8,-21.6 Q7,-18.8 9.8,-22.2", "#2a0e0c", "#2a1410", 1.0)
        s += "".join(f'<path d="M{x},-20.6 l.5,1.5 l.5,-1.5" fill="{tusk}" stroke="{OL}" stroke-width=".3"/>' for x in (4.4, 5.6, 6.8, 8))
        s += f'<path d="M7.4,-20.6 L8.2,-26.4 L9.6,-21.6 Z" fill="{tusk}" stroke="{OL}" stroke-width=".6"/>'
        s += f'<path d="M2.6,-20.4 L3,-24.4 L4.4,-20.6 Z" fill="{tusk}" stroke="{OL}" stroke-width=".6"/>'
    return s


def orc_crown():
    return (path("M-7,-33.6 Q1,-37.6 9,-33.4 L9,-30.6 Q1,-34.6 -7,-30.8 Z", "#4a4f55", OL, 1.0)
            + "".join(path(f"M{x},-34.4 L{x + 1.6},-41 L{x + 3.2},-34.6 Z", "#6a7076", OL, .8) for x in (-6, -2, 2, 6))
            + f'<circle cx="2" cy="-33.4" r="1.2" fill="#b02a20" stroke="{OL}" stroke-width=".5"/>'
            + path("M-6,-32 Q1,-35.4 8,-32", "none", "#fff", .5, .35))


def orc_mantle():
    fur = "#5a4630"
    tufts = "".join(f'<path d="M{x},{y} l-.8,2.6 l1.8,-1.4 z" fill="#3a2c1c"/>' for x, y in ((-12, -10), (-8, -13), (-3, -15), (3, -15), (8, -14), (12, -11), (14, -6)))
    return (path("M-15,-8 Q-14,-16 -6,-17.6 L6,-17.6 Q14,-16 16.4,-7 Q10,-12 4,-10 Q-4,-9 -15,-8 Z", fur, OL, 1.2)
            + path("M-12,-11 Q-6,-14 0,-12 M2,-12 Q8,-14 14,-10", "none", "#2a1e12", .8, .6)
            + tufts
            + f'<path d="M-2,-11 L1,-8 L4,-11 L2.6,-6 L-.8,-6 Z" fill="#e6dcc0" stroke="{OL}" stroke-width=".6"/>'
            + path("M-6,-16 Q0,-14 6,-16", "none", "#fff", .6, .3))


# ---------------------------------------------------------------- squelettes
def skel_torso():
    s = path("M-9,-14 Q-11,0 -8,10 L8,10 Q11,0 10,-13 Z", "#1a1410", OL, 1.0)
    s += path("M-1,-16 L-1,10", "none", OL, 3.0) + path("M-1,-16 L-1,10", "none", W, 1.7)
    for i, y in enumerate((-12, -7.5, -3, 1.5, 6)):
        k = 1 - i * .08
        for sx in (1, -1):
            d = f"M-1,{y} Q{-1 + sx * 8 * k},{y - 2.4} {-1 + sx * 9.4 * k},{y + 3.4}"
            s += path(d, "none", OL, 2.6) + path(d, "none", W, 1.3)
    s += path("M7.6,-11 L7.4,3", "none", OL, 2.6) + path("M7.6,-11 L7.4,3", "none", W, 1.3)
    s += path("M-9.6,-14.4 Q0,-17.6 11.2,-13.4", "none", OL, 2.6) + path("M-9.6,-14.4 Q0,-17.6 11.2,-13.4", "none", W, 1.3)
    for x in (-9.6, 10.4):
        s += f'<circle cx="{x}" cy="-13.6" r="2.1" fill="{W}" stroke="{OL}" stroke-width=".8"/>'
    s += path("M-8.4,9.6 Q-1,5 6.6,9.4 L5,12.4 L-1,10 L-7,12.4 Z", W, OL, 1.0)
    s += "".join(f'<circle cx="-1" cy="{y}" r=".9" fill="{W}" stroke="{OL}" stroke-width=".4"/>' for y in (-14, -10, -5.5, -1, 3.5, 8))
    return s


def skel_rags():
    return (path("M-9.4,3 L10,2.4 L9.6,11 L5.6,8.6 L2.6,12.4 L-.4,9 L-4.4,12.6 L-6.4,9 L-9.6,11 Z", W, OL, 1.0)
            + path("M-8,4 Q0,6 8,3.6", "none", "#000", .6, .3)
            + path("M-9.6,-14 L-4.6,-15.6 L10,-1 L6.4,1.2 Z", W, OL, .9)
            + path("M-2,-12 l2,2 M2,-8 l2,2", "none", "#000", .6, .25))


def skel_skull(v):
    s = path("M-6,-28 Q-6.6,-36.4 1,-36.4 Q8.4,-36.4 8.4,-29.6 L8.6,-26.4 Q8.6,-24.4 6.8,-23.6 L-1.5,-23.2 Q-4.6,-24 -6,-28 Z", W, OL, 1.2)
    s += shade("M-6,-28 Q-6.6,-36.4 1,-36.4 Q-3,-34 -3.2,-27 Q-3.4,-24 -1.5,-23.2 Q-4.6,-24 -6,-28 Z", .18)
    s += path("M-3,-34.4 Q1,-36 5.4,-34.6", "none", "#fff", .7, .5)
    s += f'<ellipse cx="4.4" cy="-28.4" rx="2.5" ry="2.8" fill="#0d0907" stroke="{OL}" stroke-width=".6"/>'
    s += path("M8.2,-25.8 l-1.5,-2.8 l-1.4,2.8 Z", "#0d0907")
    s += path("M-1.8,-27.4 q1,2 3,.6", "none", "#000", .5, .4)
    teeth = (0, 1, 2, 3, 4) if v == 0 else (0, 1, 3)
    s += path("M-1.5,-23.6 L7,-23.6", "none", OL, .5)
    s += "".join(f'<rect x="{-1 + t * 1.6}" y="-24.2" width="1.1" height="1.7" fill="{W}" stroke="{OL}" stroke-width=".35"/>' for t in teeth)
    if v == 1:  # crâne fendu, mâchoire absente
        s += path("M-1,-35.8 L1.4,-31 L-.6,-29.4 L1.8,-26", "none", OL, .8)
        s += path("M-5.6,-30 L-4,-28.4 L-5.2,-26.6 Z", "#1a1410")
    else:
        s += path("M-2.5,-23 L6.4,-23 Q7,-19.4 3.8,-17.6 Q-1,-18 -2.5,-23 Z", W, OL, 1.0)
        s += "".join(f'<rect x="{-1.4 + t * 1.6}" y="-22.6" width="1.1" height="1.5" fill="{W}" stroke="{OL}" stroke-width=".3"/>' for t in range(5))
        s += shade("M-2.5,-21 L6.4,-21 Q6.6,-19 3.8,-17.6 Q-1,-18 -2.5,-21 Z", .2)
    s += "".join(f'<circle cx="{x}" cy="{y}" r="1.1" fill="{W}" stroke="{OL}" stroke-width=".7"/>' for x, y in ((.5, -17.4), (.9, -15.4)))
    return s


def skel_eyes():
    return ('<circle cx="4.4" cy="-28.4" r="2.5" fill="#6fe8d0" opacity=".22"/>'
            '<circle cx="4.4" cy="-28.4" r="1.1" fill="#a8f4e2"/><circle cx="4.1" cy="-28.7" r=".4" fill="#fff"/>')


def skel_arm(w):
    hx, hy = HANDS[w]
    if w == "arc":
        p0, p1, p2 = (8, -13), (14, -12), (20, -8)
    else:
        p0, p1, p2 = (8, -13), (hx + 2, (-13 + hy) / 2), (hx, hy)
    d = f"M{p0[0]},{p0[1]} Q{p1[0]},{p1[1]} {p2[0]},{p2[1]}"
    ex = .25 * p0[0] + .5 * p1[0] + .25 * p2[0]
    ey = .25 * p0[1] + .5 * p1[1] + .25 * p2[1]
    return (limb(d, W, 1.9)
            + f'<circle cx="{ex:.2f}" cy="{ey:.2f}" r="1.7" fill="{W}" stroke="{OL}" stroke-width=".8"/>'
            + f'<circle cx="{p0[0]}" cy="{p0[1]}" r="2" fill="{W}" stroke="{OL}" stroke-width=".8"/>')


def skel_hand(x, y):
    return (f'<circle cx="{x}" cy="{y}" r="2.1" fill="{W}" stroke="{OL}" stroke-width=".9"/>'
            + path(f"M{x - 1.6},{y - .4} q1.6,-1.2 3.2,0 M{x - 1.4},{y + .9} q1.5,-1 3,0", "none", OL, .45))


# ---------------------------------------------------------------- zombies
def zombie(big, variant):
    skin, dark = ("#7c8668", "#566049") if not big else ("#6a7458", "#454e3a")
    rag = "#6b6048" if not big else "#554c38"
    s = '<g transform="translate(-1,1) scale(1.3)">' if big else "<g>"
    s += limb("M-3,-10 Q8,-14 17,-9", dark, 3.6)
    s += (f'<circle cx="17.4" cy="-8.8" r="2.4" fill="{dark}" stroke="{OL}" stroke-width="1"/>'
          + path("M18,-9 l3.6,-.4 M18,-8 l3.6,.8 M17.4,-7 l3,2", "none", "#d8cfae", 1.1))
    B = "M-13,10 Q-17,-2 -8,-13 Q0,-20 9,-15 Q13,-9 11,-1 L9,10 Z"
    s += f'<path d="{B}" fill="{rag}"/><path d="{B}" fill="url(#gShade)"/><path d="{B}" fill="none" stroke="{OL}" stroke-width="1.3"/>'
    s += path("M-6,-14 L-2,-6 L-7,-3 L-3,5 L-9,8", "none", OL, .8, .8)
    s += path("M2,-12 l2,4 l-3,1 l3,5 l-2,3", "#5a1e1a", OL, .6, .8)
    s += path("M-12,5 Q-9,0 -5,3 Q-8,7 -12,5 Z", "#d8cfae", OL, .6)
    s += path("M-2,-3 Q2,-2 6,-4 M-2,0 Q2,1 6,-1", "none", "#d8cfae", 1.0, .8)
    s += path("M-14,10 L-12,7 L-9,10 L-6,7 L-3,10 L0,7 L4,10 L7,7 L9,10", "none", OL, 1.0)
    s += f'<path d="M5,-14 Q4,-23 11,-24 Q18,-24 18.6,-17 L20.6,-13.6 Q16,-9 10.8,-10 Q5,-10 5,-14 Z" fill="{skin}" stroke="{OL}" stroke-width="1.2"/>'
    s += path("M6,-19 Q9,-24 14,-23.4", "none", "#fff", .7, .3)
    s += path("M8,-23 l-2,-2 M12,-24 l.4,-2.6 M15,-22.4 l1.8,-2", "none", "#2a2a22", 1.0)
    if variant == 1:  # casque rouillé troué
        s += path("M4.4,-17 Q4,-25 11,-26.4 Q18,-26 18.6,-19 L11,-19.6 Z", "#6a5a48", OL, 1.0)
        s += path("M7,-22 l2,.6 M12.6,-24 l1.6,1.2", "none", "#3a2a1c", .8)
    s += f'<path d="M10,-11 L20.4,-13 Q20,-6.6 12.4,-5.2 Z" fill="{dark}" stroke="{OL}" stroke-width="1"/>'
    s += path("M10.6,-11.4 l1,1.8 l1,-1.8 l1,1.8 l1,-1.8 l1,1.8 l1,-1.8 l1,1.6", "#e0d8bc", OL, .4)
    s += path("M13,-5.6 Q13.4,-2.4 14.2,-1", "none", "#a8c890", .9, .6)
    s += '<ellipse cx="14.6" cy="-17" rx="3" ry="2.6" fill="#16100c" opacity=".7"/>'
    s += f'<circle cx="14.8" cy="-17" r="1.5" fill="#d8e0c8"/><circle cx="15" cy="-17" r=".6" fill="{OL}"/>'
    s += path("M10,-20 Q13,-21.8 17,-19.6", "none", OL, 1.4)
    s += path("M18,-15.4 l1.8,.6 l-.8,1.4 Z", "#2a1410")
    s += limb("M5,-9 Q14,-4 19,3", skin, 3.8)
    s += path("M6,-8 Q10,-9 13,-6", "none", "#d8cfae", 1.0, .8)
    s += (f'<circle cx="19.4" cy="3.4" r="2.5" fill="{dark}" stroke="{OL}" stroke-width="1"/>'
          + path("M20,3 l3.4,1 M19.6,4.4 l2.8,2.4 M18.6,5 l1.4,3.2", "none", "#d8cfae", 1.1))
    return s + "</g>"


# ---------------------------------------------------------------- tenues d'élite et bannière
def crest_plume():
    """Panache de casque (teinté) : s'enracine au sommet du casque et part vers l'arrière."""
    return (path("M-1.5,-40.6 Q-4,-53 -16,-49.6 Q-11,-48.6 -10,-44 Q-12,-45 -14.5,-44 Q-9,-41.5 -3,-39.4 Z", W, OL, 1.0)
            + path("M-3,-45 Q-8,-48 -12,-47.4 M-3.6,-42.4 Q-8,-44 -11.6,-43.6", "none", "#000", .6, .35)
            + path("M-3.6,-50 Q-8,-51.4 -13.4,-49.8", "none", "#fff", .6, .5)
            + f'<rect x="-3" y="-41.6" width="5.6" height="2.6" rx=".8" fill="#c9a24a" stroke="{OL}" stroke-width=".7"/>')


def circlet():
    """Cercle d'or des vétérans tête nue."""
    return (path("M-6.8,-31.2 Q1,-36.6 8.6,-31.6", "none", OL, 3.2)
            + path("M-6.8,-31.2 Q1,-36.6 8.6,-31.6", "none", "#c9a24a", 1.8)
            + path("M-5,-32.8 Q1,-36 6.4,-32.8", "none", "#fff", .5, .5)
            + f'<circle cx="1.2" cy="-35.2" r="1.1" fill="#b02a20" stroke="{OL}" stroke-width=".5"/>')


def pauldron_elite():
    """Épaulière de vétéran ou de chef : acier bordé d'or, hérissée d'une pointe."""
    return (path("M3,-16.4 Q12,-20 16.6,-11 Q16,-5.6 10.6,-4.8 Q9.4,-11.4 3,-14 Z", "url(#gSteel)", OL, 1.0)
            + path("M4.4,-15.4 Q12,-17.6 15.6,-11 M5.6,-13.4 Q11,-14.6 14.4,-10.4", "none", "#c9a24a", .9)
            + path("M11.6,-18.2 L14.4,-26 L15.2,-17 Z", "#c9a24a", OL, .8)
            + f'<circle cx="13.6" cy="-9.4" r="1" fill="#b02a20" stroke="{OL}" stroke-width=".4"/>'
            + light("M6,-17.4 Q11.5,-19 15.4,-13.2", .55, .7))


def cape_trim():
    """Liseré d'or le long du bord de la cape (fixe, non teinté)."""
    return (path("M-9,-16 Q-18,-12 -20,6 Q-20,16 -14,17", "none", "#c9a24a", 1.1, .9)
            + path("M-14,17 L-8,14", "none", "#c9a24a", 1.1, .9))


def war_paint():
    """Peinture de guerre rouge sur le visage (berserkers)."""
    return (path("M-2.4,-30.4 L3,-28.6 M-2.6,-27.2 L2.6,-25.4 M-2.4,-24 L2,-22.6", "none", "#a02a20", 1.3, .85)
            + path("M5.4,-33.4 L7.4,-29.4", "none", "#a02a20", 1.2, .8))


def bone_necklace():
    """Collier d'os autour du cou (berserkers, chefs de guerre)."""
    beads = ((-5, -15.2), (-2.6, -13.2), (0, -12.4), (2.6, -13), (5, -14.8))
    return (path("M-6.4,-16 Q0,-10.4 6.6,-15.8", "none", OL, 1.0)
            + "".join(f'<path d="M{x - .9},{y - 1.6} l1.8,0 l-.4,3.4 l-1,0 z" fill="#e6dcc0" stroke="{OL}" stroke-width=".4"/>' for x, y in beads))


def shield_banner(raised):
    """Écu aux couleurs de la compagnie : trois calques (champ, chevron, bossage) à teinter par `modulate`."""
    import math
    cx, cy, r = (7, -5, 13.5) if raised else (-5, -1, 12)
    rf = r - 2.1
    field = (f'<circle cx="{cx}" cy="{cy}" r="{rf}" fill="{W}"/>'
             + f'<path d="M{cx - r * .9},{cy - r * .3} Q{cx},{cy - r * .2} {cx + r * .9},{cy - r * .35} '
               f'M{cx - r * .85},{cy + r * .4} Q{cx},{cy + r * .5} {cx + r * .88},{cy + r * .35} '
               f'M{cx - r * .4},{cy - r * .9} L{cx - r * .45},{cy + r * .9} M{cx + r * .45},{cy - r * .9} L{cx + r * .42},{cy + r * .9}" '
               f'stroke="#000" stroke-width=".6" opacity=".22" fill="none"/>'
             + f'<circle cx="{cx}" cy="{cy}" r="{rf}" fill="url(#gShield)"/>')
    chev = (f'<path d="M{cx - r * .72},{cy - r * .32} L{cx},{cy + r * .42} L{cx + r * .72},{cy - r * .32}" '
            f'stroke="{W}" stroke-width="{r * .32}" fill="none" stroke-linejoin="miter"/>')
    boss = (f'<circle cx="{cx}" cy="{cy}" r="3.3" fill="url(#gSteel)" stroke="{OL}" stroke-width=".9"/>'
            f'<circle cx="{cx - .8}" cy="{cy - .9}" r="1" fill="#fff" opacity=".45"/>')
    return field, chev, boss


def main():
    os.makedirs(OUT, exist_ok=True)
    for k in ("tunique", "gambison", "mailles", "brigandine"):
        write("torso_" + k, torso(k))
    write("pauldron_mailles", pauldron("mailles"))
    write("pauldron_brigandine", pauldron("brigandine"))
    write("cape", cape())
    write("satchel", satchel())
    write("bandolier", bandolier())
    write("scarf", scarf())
    write("head", head())
    for v in range(3):
        write(f"face_{v}", face(v))
    for k, m in MARKS.items():
        write("mark_" + k, m)
    write("band", band())
    for i, b in BEARDS.items():
        write(f"beard_{i}", b)
    for i, h in HAIRS.items():
        write(f"hair_{i}", h)
    for k, h in HELMETS.items():
        write("helm_" + k, h)
    for w in HANDS:
        write("weapon_" + w, weapon(w))
        write("arm_" + w, arm(w))
        write("hand_" + w, hand(*HANDS[w]))
    write("arm_off", limb("M-9,-12 Q-15,-3 -13,6", W, 4.6)
          + path("M-9,-12 Q-15,-3 -13,6", "none", "#000", 1.1, .2, extra='transform="translate(1.2,0)"'))
    write("hand_off", hand(-13, 7).replace('r="2.8"', 'r="2.7"'))
    write("quiver", quiver())
    for kind in ("p", "e"):
        write(f"shield_{kind}", shield(kind, False))
        write(f"shield_{kind}_up", shield(kind, True))
    write("ghoul", ghoul(False, 0))
    write("ghoul_b", ghoul(False, 1))
    write("ghoul_big", ghoul(True, 0))
    write("ghoul_big_b", ghoul(True, 1))
    write("head_orc", head_orc())
    for v in range(3):
        write(f"face_orc_{v}", face_orc(v))
    write("orc_crown", orc_crown())
    write("orc_mantle", orc_mantle())
    write("skel_torso", skel_torso())
    write("skel_rags", skel_rags())
    for v in range(2):
        write(f"skel_skull_{v}", skel_skull(v))
    write("skel_eyes", skel_eyes())
    for w in HANDS:
        write("skel_arm_" + w, skel_arm(w))
        write("skel_hand_" + w, skel_hand(*HANDS[w]))
    write("skel_arm_off", limb("M-9,-12 Q-15,-3 -13,6", W, 1.9)
          + f'<circle cx="-14.4" cy="-3.4" r="1.7" fill="{W}" stroke="{OL}" stroke-width=".8"/>')
    write("skel_hand_off", skel_hand(-13, 7))
    write("zombie", zombie(False, 0))
    write("zombie_b", zombie(False, 1))
    write("zombie_big", zombie(True, 0))
    write("zombie_big_b", zombie(True, 1))
    write("crest_plume", crest_plume())
    write("circlet", circlet())
    write("pauldron_elite", pauldron_elite())
    write("cape_trim", cape_trim())
    write("war_paint", war_paint())
    write("bone_necklace", bone_necklace())
    for raised in (False, True):
        field, chev, boss = shield_banner(raised)
        suffix = "_up" if raised else ""
        write("shield_field" + suffix, field)
        write("shield_chev" + suffix, chev)
        write("shield_boss" + suffix, boss)
    print("calques écrits dans", OUT, "-", len(os.listdir(OUT)), "fichiers")


if __name__ == "__main__":
    main()
