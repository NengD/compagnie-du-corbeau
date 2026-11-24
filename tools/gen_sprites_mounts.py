#!/usr/bin/env python3
"""Monture : cheval (appelé par gen_sprites.py, après gen_sprites_more).

Convention : `mount_horse` = robe teintée par `modulate` (dessinée en blanc/gris clair) ; `mount_horse_fx` = crinière, queue, sabots,
bride et œil (non teinté, derrière le cavalier) ; `mount_horse_front` = tapis de selle et sangle (teinté par la couleur de l'homme,
devant le cavalier). Même viewBox que tous les calques : le cheval occupe x -28..32, sol à y = 14. Le cavalier humain est réduit et
posé sur la selle par scenes/ui/figure.gd (MOUNT_RIDER_*).
"""
from gen_sprites import OL, W, path, shade, limb, write

COAT = "#e8e4dc"
COAT_D = "#bdb7ac"


def _horse_body():
    s = ""
    # jambes éloignées (sombres)
    s += limb("M-17,4 Q-19,9 -18,14.4", COAT_D, 3.6) + limb("M12,4 Q14,9 13,14.4", COAT_D, 3.6)
    # corps
    body = "M-22,-4 Q-23,-13 -10,-14 Q4,-15 14,-12 L16,-5 Q14,4 4,6 Q-8,8 -18,5 Q-22,3 -22,-4 Z"
    s += f'<path d="{body}" fill="{COAT}"/><path d="{body}" fill="url(#gShade)"/>'
    s += path("M-20,-8 Q-10,-12 2,-11", "none", "#fff", .8, .35)
    s += path("M-18,-1 Q-8,1 6,0", "none", "#000", .8, .15)
    s += f'<path d="{body}" fill="none" stroke="{OL}" stroke-width="1.3"/>'
    # jambes proches
    s += limb("M-11,4 Q-13,9 -12,14.4", COAT, 3.9) + limb("M8,4 Q10,9 9,14.4", COAT, 3.9)
    # encolure et tête
    s += path("M10,-13 Q16,-24 22,-26 L30,-21 Q33,-17 31,-13 L28,-9 Q25,-6 21,-8 Q16,-6 13,-3 Z", COAT, OL, 1.3)
    s += path("M14,-14 Q18,-22 23,-24", "none", "#fff", .8, .35)
    s += shade("M13,-3 Q16,-6 21,-8 Q25,-6 28,-9 Q22,-7 14,-5 Z", .22)
    s += path("M26,-14 Q31,-14 32,-10 Q31,-7 27,-8 Z", COAT_D, OL, 1.0)  # museau
    s += path("M19,-27 L19.6,-33 L22.6,-27 Z", COAT, OL, 1.0)  # oreille
    return s


def horse_body():
    return f'<g transform="translate(0,0)">{_horse_body()}</g>'


def horse_fx():
    s = ""
    # queue et crinière
    s += path("M-22,-6 Q-31,-4 -31,6 Q-28,0 -24,1 Q-26,-1 -22,-3 Z", "#3a2a1e", OL, 1.1)
    s += path("M12,-14 Q9,-22 15,-27 L19,-26 Q15,-22 17,-15 Z", "#3a2a1e", OL, 1.0)
    # sabots
    s += path("M-14,14.4 l4,.2 l0,1.6 l-4.4,0 Z M7,14.4 l4,.2 l0,1.6 l-4.4,0 Z", "#2a2420", OL, .8)
    s += path("M-20,14.4 l3.6,.2 l0,1.4 l-4,0 Z M11,14.4 l3.6,.2 l0,1.4 l-4,0 Z", "#201a16", OL, .8)
    # œil, narine, bride
    s += f'<ellipse cx="25.6" cy="-18" rx="1.2" ry=".9" fill="#1a1008"/>'
    s += '<circle cx="31" cy="-10.6" r=".7" fill="#1a1008"/>'
    s += path("M21,-22 L27,-12 M27,-12 L31,-12.6", "none", "#4a3220", 1.1)
    s += f'<circle cx="27" cy="-12" r=".9" fill="#b89a52" stroke="{OL}" stroke-width=".3"/>'
    s += path("M14,-12 Q12,-6 13,-3", "none", "#4a3220", 1.0)  # rêne
    return s


def horse_front():
    """Tapis de selle (teinté) et selle de cuir, sur le dos du cheval, devant les jambes du cavalier."""
    s = ""
    s += path("M-12,-12.4 Q-3,-14.4 6,-12.4 L7,-1 Q-3,1.4 -13,-1 Z", W, OL, 1.1)
    s += path("M-12.2,-3 L6.8,-3", "none", "#000", .6, .3)
    s += path("M-8,-14 Q-2,-17.6 4,-14 L4,-11.4 Q-2,-13 -8,-11.4 Z", "#5a3a22", OL, 1.0)  # selle
    s += path("M-3,-1 Q-1,6 -2,9", "none", "#4a3220", 1.2)  # sangle
    s += f'<path d="M-2.6,9 l2.6,0 l-.4,2.6 l-2,0 Z" fill="#9a968a" stroke="{OL}" stroke-width=".6"/>'  # étrier
    return s


def main_mounts():
    write("mount_horse", horse_body())
    write("mount_horse_fx", horse_fx())
    write("mount_horse_front", horse_front())


if __name__ == "__main__":
    main_mounts()
