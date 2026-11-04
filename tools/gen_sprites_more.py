#!/usr/bin/env python3
"""Calques supplémentaires (appelés par gen_sprites.py) : tenues (capes, manteaux, tabards, bottes, jupes de mailles),
états d'usure (déchirures, bosses, fentes, ébréchures) et monstres (loup, ogre, troll, cavalier de loup).

Convention des monstres : un calque `<nom>` teinté par `modulate` (fourrure / chair, dessiné en blanc et gris clair),
un calque `<nom>_fx` jamais teinté (yeux, dents, griffes, armes, équipement), et pour le cavalier `wolf_rider_orc`
(le cavalier, teinté par la peau d'orc). Les variantes `_big` sont plus grandes (chefs, bêtes alpha).
"""
import math

from gen_sprites import OL, W, path, shade, light, limb, rings, write, T


# ---------------------------------------------------------------- tenues
def legs():
    """Jambes (culotte teintée par l'étoffe) derrière le torse."""
    return (path("M-8,6 L-9,18 L0,18 L0.5,6 Z", W, OL, 1.0)
            + path("M2,6 L2,18 L10,18 L9.4,6 Z", W, OL, 1.0)
            + path("M-8,10 Q-4,11 0,10 M3,10 Q6,11 9.4,10", "none", "#000", .6, .3))


def boots():
    """Bottes de cuir (teintées) : tige et revers."""
    one = lambda x0, x1: (path(f"M{x0},12.4 L{x1},12.4 L{x1 + .6},18 L{x0 - 1.2},18 Z", W, OL, 1.0)
                          + path(f"M{x0 - .4},13.2 Q{(x0 + x1) / 2},14.6 {x1 + .2},13.2 L{x1 + .2},14.8 Q{(x0 + x1) / 2},16 {x0 - .4},14.8 Z", W, OL, .7)
                          + path(f"M{x0 + .6},12.6 L{x0 + .5},17.6", "none", "#fff", .5, .35)
                          + shade(f"M{x0 - 1},16.4 L{x1 + .6},16.4 L{x1 + .6},18 L{x0 - 1.2},18 Z", .3))
    return one(-8.6, -0.4) + one(1.8, 9.8)


def greaves():
    """Jambières d'acier (non teintées) sur le devant des bottes."""
    one = lambda x0, x1: (path(f"M{x0},10.6 L{x1},10.6 L{x1 + .2},15.6 L{x0 - .4},15.6 Z", "url(#gSteel)", OL, .9)
                          + path(f"M{x0 + .6},11.4 L{x0 + .8},15", "none", "#fff", .5, .5)
                          + f'<circle cx="{(x0 + x1) / 2:.1f}" cy="12.2" r=".55" fill="#d6d9dc" stroke="{OL}" stroke-width=".25"/>')
    return one(-8.4, -0.8) + one(2.0, 9.6)


def skirt_mail():
    """Jupe de mailles sous le haubert."""
    d = "M-12.4,7.5 L12.4,7.5 L13.4,16.4 Q9,18 6,16.6 Q3,18.2 0,16.8 Q-3,18 -6,16.6 Q-10,18 -13.4,16.4 Z"
    return (f'<path d="{d}" fill="url(#gSteel)"/>'
            + f'<clipPath id="cs"><path d="{d}"/></clipPath>'
            + f'<g clip-path="url(#cs)"><path d="{rings(-14, 14, 7, 18)}" stroke="#23272c" stroke-width=".45" fill="none" opacity=".75"/></g>'
            + f'<path d="{d}" fill="url(#gShade)"/>'
            + f'<path d="{d}" fill="none" stroke="{OL}" stroke-width="1.1"/>')


def skirt_lamel():
    """Lanières de cuir rivetées sous la brigandine (pteruges)."""
    s = ""
    for i, x in enumerate((-12.4, -8.2, -4, .2, 4.4, 8.6)):
        s += (path(f"M{x},7.5 L{x + 4.2},7.5 L{x + 4},16.6 Q{x + 2},17.8 {x + .2},16.6 Z", "#5a2a22", OL, .9)
              + f'<circle cx="{x + 2.1}" cy="9.4" r=".6" fill="#d9c9a0" stroke="{OL}" stroke-width=".25"/>')
    return s + path("M-12.4,7.6 L12.4,7.6", "none", "#2a120e", .9)


def tabard(trim=False):
    """Tabard de compagnie : panneau avant (teinté par la couleur principale) ; `trim` = liseré et chevron (couleur secondaire)."""
    d = "M-12.6,-13.6 Q0,-10.4 12.6,-13.6 L12.2,15.6 L6.4,13 L.6,16 L-5.2,13 L-12.2,15.6 Z"
    if not trim:
        return (f'<path d="{d}" fill="{W}"/>'
                + path("M-9,-8 Q-8.6,2 -9.4,12 M8,-9 Q8.4,2 8,12", "none", "#000", .6, .22)
                + f'<path d="{d}" fill="url(#gShade)"/>'
                + f'<path d="{d}" fill="none" stroke="{OL}" stroke-width="1.1" stroke-linejoin="round"/>')
    return (path("M-12.2,12.6 L-6.2,10.2 L.4,13.4 L6.6,10.4 L12,12.6 L12.2,15.6 L6.4,13 L.6,16 L-5.2,13 L-12.2,15.6 Z", W)
            + path("M-12.6,-13.6 Q0,-10.4 12.6,-13.6", "none", W, 1.6)
            + path("M-3.2,-6.4 L0.4,-1 L4,-6.4", "none", W, 1.9))


def cape_short():
    """Cape courte sur les épaules (teintée), derrière le torse."""
    d = "M-9,-16 Q-17,-13 -18,-2 Q-18,5 -14,6 L-8,4 L-6,-12 Z"
    return (path(d, W, OL, 1.2)
            + path("M-13,-11 Q-15,-3 -14,4 M-10,-11 Q-11.5,-2 -11,4", "none", "#000", .7, .3)
            + shade("M-9,-16 Q-17,-13 -18,-2 L-15.5,-2 Q-14,-10 -8,-13 Z", .15)
            + path("M-8,-16 Q-13,-17 -9,-12", "#8a7448", OL, .7))


def cloak_long():
    """Manteau long (teinté), pan qui descend jusqu'aux bottes."""
    d = "M-9,-16 Q-21,-10 -24,9 Q-23,19 -14,18.4 L-6,17 L-6,-12 Z"
    return (path(d, W, OL, 1.2)
            + path("M-15,-11 Q-19,2 -18,17 M-11,-11 Q-13,3 -12.4,17.4", "none", "#000", .8, .3)
            + path("M-24,9 Q-20,11 -17,9 Q-14,12 -11,10", "none", "#000", .6, .22)
            + shade("M-9,-16 Q-21,-10 -24,9 L-21,9 Q-19,-6 -8,-13 Z", .15)
            + path("M-24,9 Q-23,19 -14,18.4", "none", "#8a7448", 1.0, .6))


def cloak_front():
    """Collet de manteau sur les épaules, devant le torse (teinté), avec fermoir doré."""
    return (path("M-10.5,-16.4 Q0,-12 10.8,-16.6 L12.2,-10.6 Q0,-6.2 -12,-10.6 Z", W, OL, 1.0)
            + path("M-8,-13 Q0,-10 8,-13.4", "none", "#000", .6, .28)
            + f'<circle cx="3.6" cy="-11.4" r="1.2" fill="#c9a24a" stroke="{OL}" stroke-width=".45"/>'
            + path("M-9,-15 Q0,-11.6 9.4,-15.4", "none", "#fff", .5, .4))


def hood_down():
    """Capuche tombante : le tas d'étoffe autour du cou (teinté), derrière la tête."""
    return (path("M-13,-12.6 Q-12,-20 -5,-21 Q1,-21 2,-17 Q0.6,-12 -4.6,-10.4 Q-10,-9.6 -13,-12.6 Z", W, OL, 1.1)
            + path("M-9.6,-17.6 Q-7,-14.4 -8.4,-11.4 M-5,-18.6 Q-3,-15.6 -4.6,-11.4", "none", "#000", .6, .3)
            + path("M-8,-20 Q-4,-21.4 0.4,-19", "none", "#fff", .6, .4)
            + shade("M-13,-12.6 Q-10,-9.6 -4.6,-10.4 Q0.6,-12 2,-17 Q-4,-12 -13,-12.6 Z", .2))


# ---------------------------------------------------------------- usure
def dmg_body(level):
    """Déchirures du vêtement/de l'armure du corps. 1 : entailles ; 2 : grande déchirure, pièces manquantes."""
    s = (path("M-8,-9 L-4.6,-4 L-6.6,-2 L-2.6,3", "none", "#14100c", 1.1, .85)
         + path("M5,-10 L6.6,-5.4 L4.4,-3.8", "none", "#14100c", .9, .85)
         + path("M-12.4,8 L-10.4,5.4 L-8.4,8.4 L-6.2,5.6", "none", "#14100c", .9, .8))
    if level >= 2:
        s += (path("M-1,-12 L4.4,-6.8 L1.4,-3.4 L6.8,1.6 L2.4,5 L-1.8,1.2 L1,-2.8 L-3.6,-7 Z", "#1c1612", OL, .7, .95)
              + path("M-0.4,-10.4 L3.6,-6.6 M2,-2.6 L5.6,1.2", "none", "#7a6a56", .5, .6)
              + path("M-12.8,1 L-9.4,3.6 L-12.2,6.2 Z", "#1c1612", OL, .5, .9)
              + path("M8.4,-3 q1.4,.8 .6,3.6 q-1.8,-.6 -.6,-3.6 Z", "#8a1a14", None, 0, .55))
    return s


def dmg_helm():
    """Bosses et éraflures sur le casque (au-dessus du casque, non teinté)."""
    return (path("M-3,-35.6 Q-1,-36.4 0.6,-35.4 Q-0.6,-33.6 -3,-35.6 Z", "#000", None, 0, .45)
            + path("M4.6,-33.2 Q6.6,-32.2 6,-30.2 Q4.2,-30.8 4.6,-33.2 Z", "#000", None, 0, .4)
            + path("M-6.4,-31 L-3.4,-34.4 M-5.4,-30 L-2.6,-33", "none", "#e9eced", .6, .6)
            + path("M0,-38.4 L2.4,-35.6 L1,-34.2", "none", "#14100c", .7, .8))


def dmg_shield(level, raised):
    """Bouclier fendu (1) puis éclaté (2). Même position que shield()."""
    cx, cy, r = (7, -5, 13.5) if raised else (-5, -1, 12)
    s = path(f"M{cx - r * .15},{cy - r * .98} L{cx + r * .1},{cy - r * .5} L{cx - r * .12},{cy - r * .1} L{cx + r * .16},{cy + r * .35}",
             "none", "#14100c", 1.1, .95)
    s += path(f"M{cx - r * .3},{cy - r * .52} l-1.6,.4 M{cx + r * .22},{cy + r * .18} l1.6,.5", "none", "#14100c", .6, .8)
    if level >= 2:
        s += (path(f"M{cx + r * .5},{cy - r * .8} L{cx + r * .96},{cy - r * .3} L{cx + r * .7},{cy + r * .1} L{cx + r * .32},{cy - r * .1} L{cx + r * .5},{cy - r * .5} Z",
                   "#1c1612", OL, .8, .95)
              + path(f"M{cx - r * .96},{cy + r * .2} L{cx - r * .6},{cy + r * .5} L{cx - r * .86},{cy + r * .7} Z", "#1c1612", OL, .6, .95)
              + path(f"M{cx - r * .5},{cy + r * .6} L{cx - r * .1},{cy + r * .8}", "none", "#14100c", .9, .9))
    return s


BLADE_CHIPS = {  # arme -> encoches sur la lame ou le fer (ébréchures)
    "epee": path("M19.4,-18 l2,-.4 l-1.2,1.8 M17.6,-10 l1.8,-.2 l-1,1.6 M21.4,-27 l1.6,.2", "none", "#14100c", 1.1, .9),
    "hache": path("M27.2,-21.4 l-2,.4 l.8,1.4 l-1.8,.4 M26.2,-16.6 l-1.8,.2 l.6,1.2", "none", "#14100c", 1.1, .9),
    "lance": path("M25.6,-47.4 l1.2,.8 l-1.2,.8 M22.8,-46 l.8,1", "none", "#14100c", 1.0, .9),
    "hallebarde": path("M33.4,-38.6 l-1.8,.2 l.8,1.6 M35.8,-38.8 l-1.2,1.4", "none", "#14100c", 1.1, .9),
    "javelot": path("M26.6,-42 l1,.6 l-1.2,.8", "none", "#14100c", 1.0, .9),
    "fourche": path("M18.2,-45 l1.2,.2 M23,-46.4 l.8,.8", "none", "#14100c", 1.0, .9),
    "masse": path("M13.2,-20.6 l1.8,.4 M25.6,-20.4 l-1.6,.6", "none", "#14100c", 1.0, .9),
    "fleau": path("M24.4,-28.6 l1.8,.2 M18,-30.6 l1.6,.6", "none", "#14100c", 1.0, .9),
    "gourdin": path("M21.4,-17.4 l1.6,.8 M22.8,-12.6 l1.4,-.4", "none", "#14100c", 1.0, .9),
}


# ---------------------------------------------------------------- monstres
FUR = "#e2ddd2"     # fourrure claire (teintée)
FUR_D = "#b4aea2"   # fourrure sombre
FLESH = "#efe6dc"
FLESH_D = "#c4b8aa"


def _wrap(body, big, k=1.18, ox=0.0, oy=0.0):
    """Applique l'échelle de la variante `_big`, ancrée sur le sol (y = 14)."""
    if not big:
        return body
    return f'<g transform="translate({ox + 0:.2f},{oy + 14 * (1 - k):.2f}) scale({k})">{body}</g>'


def _wolf_body(sx=0.0, sy=0.0, scale=1.0):
    """Corps du loup (teinté). (sx, sy) : décalage ; scale : taille."""
    s = f'<g transform="translate({sx},{sy}) scale({scale})">'
    # pattes arrière/avant éloignées (sombres)
    s += limb("M-14,3 Q-17,9 -15,14", FUR_D, 4.2) + limb("M10,2 Q13,9 12,14", FUR_D, 4.0)
    # queue
    s += path("M-22,-2 Q-31,-12 -35,-3 Q-31,-6 -26,3 Z", FUR, OL, 1.2)
    s += path("M-30,-7 Q-32,-5 -30,-4", "none", "#000", .6, .3)
    # corps
    body = "M-24,3 Q-23,-11 -9,-14 Q5,-17 13,-11 L15,3 Q9,8 -5,8 Q-18,10 -24,3 Z"
    s += f'<path d="{body}" fill="{FUR}"/><path d="{body}" fill="url(#gShade)"/>'
    s += path("M-20,-6 Q-12,-9 -4,-8 M-18,-1 Q-10,-3 -2,-2 M2,-9 Q8,-9 12,-5", "none", "#000", .8, .22)
    s += path("M-20,-10 Q-10,-15 4,-15 Q9,-14.4 12,-11", "none", "#fff", .8, .35)
    s += f'<path d="{body}" fill="none" stroke="{OL}" stroke-width="1.3"/>'
    # hérissement de l'échine
    s += path("M-18,-11 l1.2,-3 l1.4,2.6 l1.6,-3.2 l1.4,2.8 l1.8,-3.2 l1.2,2.8 l1.6,-2.6", "none", OL, 1.0)
    # pattes arrière/avant proches
    s += limb("M-8,3 Q-12,9 -9,14", FUR, 4.4) + limb("M4,3 Q7,9 5,14", FUR, 4.4)
    s += path("M-12,14 l4,.4 M2,14 l4,.4", "none", OL, 1.4)
    # cou + tête
    s += path("M9,-12 Q17,-22 24,-17 L31,-9 Q33,-5 28,-3 L19,-1 Q12,0 11,-5 Z", FUR, OL, 1.3)
    s += path("M13,-14 Q18,-19 23,-16", "none", "#fff", .8, .35)
    s += path("M25,-9.4 L33,-8.4 Q33.6,-5.6 30,-4 L24,-3.6 Z", FUR_D, OL, 1.1)  # museau
    s += path("M16,-18 L17.6,-27 L21.4,-19 Z", FUR, OL, 1.1)  # oreilles
    s += path("M21,-18.6 L24.4,-26 L26,-17 Z", FUR, OL, 1.1)
    s += path("M17.6,-24 L18.2,-20 M24.2,-22.6 L24.4,-19.8", "none", "#000", .6, .4)
    s += path("M13,-6 Q16,-2 14,3", "none", "#000", .8, .2)  # fanon du cou
    return s + "</g>"


def _wolf_fx(sx=0.0, sy=0.0, scale=1.0, snarl=True):
    s = f'<g transform="translate({sx},{sy}) scale({scale})">'
    s += '<ellipse cx="23" cy="-13.4" rx="2.6" ry="2" fill="#f0c840" opacity=".35"/>'
    s += f'<ellipse cx="23" cy="-13.4" rx="1.7" ry="1.1" fill="#f6d450" stroke="{OL}" stroke-width=".4"/>'
    s += f'<rect x="22.6" y="-14.4" width=".8" height="2.1" fill="{OL}"/>'
    s += path("M19.4,-16.6 L26,-15", "none", OL, 1.4)  # arcade sourcilière
    s += '<circle cx="32.6" cy="-8" r="1.2" fill="#1a0e0a"/>'
    if snarl:
        s += path("M23.6,-3.6 L33,-5.4", "none", "#1a0a08", 1.4)
        s += f'<path d="M24.6,-4 l1,2.8 l1,-2.6 l1.2,2.4 l1,-2.4 l1.2,2 l.9,-2.2" fill="#f4eed8" stroke="{OL}" stroke-width=".4"/>'
        s += path("M26,-5.4 L27.6,-8.8 L28.4,-5.6 Z", "#f4eed8", OL, .4)
        s += path("M28.4,-3 Q29,-.4 28,1", "none", "#bfe0a8", .7, .5)
    # griffes
    s += path("M-9,14 l1.6,1.8 M-7,14 l.4,2 M5,14 l1.6,1.8 M7,14 l.4,2", "none", "#efe6d0", 1.0)
    return s + "</g>"


def wolf(big):
    return _wrap(_wolf_body(), big, 1.22), _wrap(_wolf_fx(), big, 1.22)


def wolf_rider(big):
    # loup légèrement plus petit, cavalier orc par-dessus
    body = _wolf_body(0, 5, .92)
    fx_w = _wolf_fx(0, 5, .92)
    rider = (path("M-9,-4 Q-11,-18 -3,-24 L5,-24 Q9,-18 7,-4 Z", W, OL, 1.2)  # torse
             + path("M-3,-23 Q0,-26.4 5,-23.6", "none", "#000", .6, .3)
             + path("M-10,-10 Q-14,-6 -12,-1 Q-8,-3 -6,-8 Z", W, OL, 1.0)  # bras arrière
             + path("M1,-22 Q4,-16 10,-17 L13,-12 Q6,-10 3,-14 Z", W, OL, 1.1)  # bras de l'arme
             + path("M-1,-24.6 L-1.6,-31 Q-1,-38 6.2,-38 Q12.6,-37.6 12.6,-31 L14.2,-27.4 Q13.8,-23.6 9.6,-23.6 Q3,-23.4 -1,-24.6 Z", W, OL, 1.2)  # tête
             + path("M-1.4,-32.6 L-8,-38.4 L-5.4,-30.6 Z", W, OL, .9)  # oreille
             + path("M3,-36 Q7,-37.8 11,-36", "none", "#fff", .6, .4)
             + shade("M-1,-24.6 Q3,-23.4 9.6,-23.6 Q13.8,-23.6 14.2,-27.4 Q8,-25 -1,-26 Z", .22))
    rider_fx = (
        # pagne + ceinture + plaque de cuir
        path("M-9,-5 L7,-5 L8,2 L-10,2 Z", "#5a4630", OL, 1.0)
        + path("M-8,-12 Q0,-9 6,-12 L6.4,-7 Q0,-4.6 -8.4,-7 Z", "#6b4a2a", OL, .9)
        + f'<circle cx="-2" cy="-9" r="1" fill="#9a8a5a" stroke="{OL}" stroke-width=".3"/><circle cx="2.4" cy="-9.4" r="1" fill="#9a8a5a" stroke="{OL}" stroke-width=".3"/>'
        # visage
        + path("M3,-33 L10.8,-31", "none", "#1a120a", 2.0)
        + '<ellipse cx="8.4" cy="-30.2" rx="1.8" ry="1.3" fill="#e8c84a"/><ellipse cx="8.7" cy="-30.2" rx=".5" ry="1" fill="#8a1a10"/>'
        + path("M8.4,-26.2 Q11,-25.6 12.6,-27", "none", "#2a1410", .9)
        + f'<path d="M10,-26.4 L10.8,-30 L12.2,-26.4 Z" fill="#e8dcb8" stroke="{OL}" stroke-width=".5"/>'
        # lance dans la main
        + limb("M11,-14 L26,-48", "#7a5230", 2.2)
        + f'<path d="M26,-48 L28.6,-51.4 L26.8,-60 L24,-52 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width=".9" stroke-linejoin="round"/>'
        + path("M25,-47 Q29,-45 28,-39.6 Q25.6,-43 23.4,-45.4 Z", "#8a3028", OL, .5)
        + f'<circle cx="11.6" cy="-14.4" r="2.2" fill="#6a8a46" stroke="{OL}" stroke-width=".8"/>'
        # sangle
        + path("M-4,2 Q0,6 4,4", "none", OL, 1.6) + path("M-4,2 Q0,6 4,4", "none", "#6b4a2a", .8))
    # le cavalier est dessiné entre le loup et ses détails, hors teinte de fourrure : couche séparée
    orc_layer = rider
    g_big = lambda b: _wrap(b, big, 1.15)
    return g_big(body), g_big(fx_w + rider_fx), g_big(orc_layer)


def ogre(big):
    k = 1.0
    body = (
        # jambes
        limb("M-6,6 L-7,14", FLESH_D, 7) + limb("M7,6 L8,14", FLESH_D, 7)
        + path("M-12,12 l8,.6 M4,12 l8,.6", "none", OL, 1.6)
    )
    torso = "M-17,14 Q-26,-6 -13,-22 Q0,-30 14,-22 Q24,-12 19,14 Z"
    body += f'<path d="{torso}" fill="{FLESH}"/><path d="{torso}" fill="url(#gShade)"/>'
    body += path("M-14,-4 Q0,2 16,-3 M-12,3 Q0,8 14,3", "none", "#000", .9, .25)  # plis du ventre
    body += path("M-6,-18 Q0,-14 8,-18", "none", "#000", .8, .3)
    body += path("M-18,-10 Q-12,-24 4,-27", "none", "#fff", .8, .3)
    body += f'<path d="{torso}" fill="none" stroke="{OL}" stroke-width="1.5"/>'
    # bras arrière
    body += limb("M-10,-16 Q-18,-6 -14,6", FLESH_D, 6.4)
    # bras avant, levé vers la massue
    body += limb("M9,-18 Q22,-16 24,-3", FLESH, 7.2)
    body += path("M10,-20 Q20,-19 24,-10", "none", "#fff", .8, .3)
    # tête : petite, mâchoire lourde
    body += f'<path d="M3,-26 Q2,-38 11,-40 Q20,-40 21,-30 L24.4,-26 Q24,-19 17,-19.4 Q8,-18 4,-23 Z" fill="{FLESH}" stroke="{OL}" stroke-width="1.4"/>'
    body += path("M5,-30 Q8,-36 14,-37", "none", "#fff", .7, .35)
    body += path("M4.4,-33 L-.6,-34.4 L2,-29 Z", FLESH, OL, 1.0)  # oreille
    body += f'<path d="M14,-23 L24.4,-26.4 Q24.6,-19 17,-18.8 Z" fill="{FLESH_D}" stroke="{OL}" stroke-width="1"/>'
    body += f'<ellipse cx="14.4" cy="-30.6" rx="3.4" ry="2.4" fill="#000" opacity=".16"/>'
    fx = (
        # pagne de peau, ceinture à crâne
        path("M-14,3 L16,2 L19,13 L12,10 L4,14 L-3,10 L-10,14 L-17,12 Z", "#6b4a2a", OL, 1.1)
        + path("M-14,2.4 Q0,6 16,2", "none", OL, 3.2) + path("M-14,2.4 Q0,6 16,2", "none", "#3a2616", 2.0)
        + f'<path d="M-1,1 L3,1.4 L2.6,5.4 L-.6,5.4 Z" fill="#e6dcc0" stroke="{OL}" stroke-width=".6"/>'
        # yeux et canines
        + path("M10,-33 L19,-31.4", "none", "#1a120a", 2.4)
        + '<circle cx="16.4" cy="-30" r="1.6" fill="#f2d24a"/><circle cx="16.6" cy="-30" r=".7" fill="#8a1a10"/>'
        + path("M12,-21 Q18,-20 23,-22.6", "none", "#2a0e0c", 1.6)
        + f'<path d="M14,-21.6 L13.4,-27 L16.4,-21.4 Z M20.6,-22 L21,-27.4 L23.4,-22.6 Z" fill="#e8dcb8" stroke="{OL}" stroke-width=".6"/>'
        # poing et massue en bois cloutée
        + f'<circle cx="24.6" cy="-2" r="4.2" fill="#d8bda0" stroke="{OL}" stroke-width="1.1"/>'
        + f'<path d="M23,-2 L27,0 L35,-38 Q31,-46 24,-41 Z" fill="url(#gWood)" stroke="{OL}" stroke-width="1.3" stroke-linejoin="round"/>'
        + path("M25,-6 Q29,-18 32,-32 M27,-4 Q31,-14 33.4,-26", "none", "#3a2414", .6, .55)
        + f'<circle cx="29" cy="-30" r="1.1" fill="#8a9096" stroke="{OL}" stroke-width=".5"/><circle cx="32" cy="-36" r="1.1" fill="#8a9096" stroke="{OL}" stroke-width=".5"/><circle cx="27" cy="-37" r="1.1" fill="#8a9096" stroke="{OL}" stroke-width=".5"/>'
        + path("M26,-12 Q28,-22 31,-30", "none", "#fff", .5, .3))
    k = 1.22 if big else 1.0
    return _scale_ground(body, k), _scale_ground(fx, k)


def _scale_ground(b, k):
    if k == 1.0:
        return b
    return f'<g transform="translate({-2 * (k - 1) * 6:.2f},{14 * (1 - k):.2f}) scale({k})">{b}</g>'


def troll(big):
    SK = "#efe8dc"
    body = (
        limb("M-7,5 L-9,14", "#b0a898", 6.6) + limb("M7,5 L9,14", "#b0a898", 6.6)
        + path("M-14,13.4 l8,.8 M4,13.4 l8,.8", "none", OL, 1.6)
    )
    torso = "M-18,12 Q-26,-8 -14,-20 Q-2,-28 11,-22 Q20,-14 16,12 Z"  # dos voûté
    body += f'<path d="{torso}" fill="{SK}"/><path d="{torso}" fill="url(#gShade)"/>'
    body += path("M-20,-6 Q-16,-20 -4,-24 M-14,-18 Q-8,-22 0,-22", "none", "#fff", .8, .3)
    body += path("M-12,-6 Q-4,-2 6,-6 M-10,2 Q-2,6 8,1", "none", "#000", .8, .25)
    body += f'<path d="{torso}" fill="none" stroke="{OL}" stroke-width="1.5"/>'
    # bras démesurés, longs, qui pendent
    body += limb("M-8,-16 Q-18,-2 -14,12", "#b0a898", 6.0)
    body += limb("M8,-17 Q22,-8 21,10", SK, 6.4)
    body += path("M10,-18 Q20,-12 21,-2", "none", "#fff", .7, .3)
    # tête : en avant, grand nez
    body += f'<path d="M4,-22 Q2,-34 12,-36 Q22,-35 23,-27 L26,-22 Q25,-15 17,-15 Q8,-14 5,-18 Z" fill="{SK}" stroke="{OL}" stroke-width="1.4"/>'
    body += path("M6,-28 Q9,-34 15,-34.6", "none", "#fff", .7, .35)
    body += path("M20,-28 Q28.6,-27 28,-22 Q27,-19.4 22,-21 Z", SK, OL, 1.2)  # gros nez
    body += path("M5,-28.6 L-2,-31.6 L1.4,-24.6 Z", SK, OL, 1.0)  # oreille
    body += path("M4,-24 Q8,-20 14,-20", "none", "#000", .7, .3)
    # touffes de mousse (sur la chair : teintées avec le reste)
    body += path("M-12,-22 q2,-4 5,-1 q2,-3 5,0 q-2,3 -5,2 q-3,2 -5,-1 Z", SK, OL, .7)
    fx = (
        # mousse et lichen vert
        "".join(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="#5f7a3a" stroke="{OL}" stroke-width=".6"/>'
                for x, y, rx, ry in ((-14, -14, 4.4, 2.6), (-8, -21, 3.6, 2.2), (-17, 0, 3, 2), (4, -23, 3.4, 2), (13, -13, 2.6, 1.8)))
        + path("M-16,-15 q2,-2 4,0 M-10,-22 q2,-2 3,0", "none", "#a8c870", .6, .7)
        # pagne en haillons
        + path("M-14,4 L14,3 L16,11 L10,8.6 L3,12 L-3,9 L-9,12 L-15,9.6 Z", "#4a3a28", OL, 1.0)
        + path("M-14,3.4 Q0,7 14,3", "none", OL, 2.6) + path("M-14,3.4 Q0,7 14,3", "none", "#6b4a2a", 1.4)
        # visage
        + path("M13,-30 L21,-28.8", "none", "#1a120a", 2.2)
        + '<circle cx="17.6" cy="-27.4" r="1.5" fill="#d8e060"/><circle cx="17.8" cy="-27.4" r=".6" fill="#1a1a08"/>'
        + path("M12,-18 Q18,-17 23.6,-19.4", "none", "#2a0e0c", 1.6)
        + f'<path d="M14.6,-18.6 L14,-23.6 L16.8,-18.4 M20.6,-19 L21.2,-23.8 L23.4,-19.6" fill="#e0d6b8" stroke="{OL}" stroke-width=".55"/>'
        + '<circle cx="26" cy="-22.2" r=".6" fill="#2a1a10"/>'
        # griffes
        + f'<circle cx="21" cy="11.6" r="3.6" fill="#a8a090" stroke="{OL}" stroke-width="1"/>'
        + f'<path d="M19.4,13.4 l-.8,4 M21.4,14 l0,4.2 M23.2,13 l1.4,3.6" stroke="#2a2218" stroke-width="1.5" stroke-linecap="round"/>'
        + f'<circle cx="-14" cy="12.8" r="3.2" fill="#8a8272" stroke="{OL}" stroke-width="1"/>'
        + f'<path d="M-15.6,14.6 l-.8,3.4 M-13.4,15 l0,3.6 M-11.6,14 l1.2,3" stroke="#2a2218" stroke-width="1.4" stroke-linecap="round"/>')
    k = 1.2 if big else 1.0
    return _scale_ground(body, k), _scale_ground(fx, k)


def main_more():
    for i in (1, 2):
        write(f"dmg_body_{i}", dmg_body(i))
    write("dmg_helm", dmg_helm())
    for lv in (1, 2):
        write(f"dmg_shield_{lv}", dmg_shield(lv, False))
        write(f"dmg_shield_{lv}_up", dmg_shield(lv, True))
    for w, d in BLADE_CHIPS.items():
        write("dmg_blade_" + w, d)
    write("legs", legs())
    write("boots", boots())
    write("greaves", greaves())
    write("skirt_mailles", skirt_mail())
    write("skirt_brigandine", skirt_lamel())
    write("tabard", tabard(False))
    write("tabard_trim", tabard(True))
    write("cape_short", cape_short())
    write("cloak_long", cloak_long())
    write("cloak_front", cloak_front())
    write("hood_down", hood_down())
    for big in (False, True):
        sfx = "_big" if big else ""
        b, f = wolf(big)
        write("wolf" + sfx, b)
        write("wolf" + sfx + "_fx", f)
        b, f, o = wolf_rider(big)
        write("wolf_rider" + sfx, b)
        write("wolf_rider" + sfx + "_fx", f)
        write("wolf_rider" + sfx + "_orc", o)
        b, f = ogre(big)
        write("ogre" + sfx, b)
        write("ogre" + sfx + "_fx", f)
        b, f = troll(big)
        write("troll" + sfx, b)
        write("troll" + sfx + "_fx", f)
