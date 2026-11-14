#!/usr/bin/env python3
"""Calques de variété et d'équipement visible (appelés par gen_sprites.py, après gen_sprites_more).

- Brigands : casque de fortune, bandeau de visage, chapeau de feutre, justaucorps clouté, col de fourrure.
- Orcs : peintures de guerre de clan (3 motifs), épaulière à pointes, gilet de peau.
- Morts-vivants : plastron rouillé, linceul, couronne rouillée, mailles en lambeaux.
- Équipement porté : arme de rechange dans le dos (épée, hache, masse, lance, arc, arbalète), bouclier dans le dos,
  carquois à carreaux, étendard de la compagnie (hampe, drap et liseré à teinter), pièces d'armure distinctes
  (gorgerin, épaulière gauche, camail, genouillères).

Même convention que les autres : les calques teintables sont dessinés en blanc, les autres gardent leurs couleurs.
"""
from gen_sprites import OL, W, path, shade, light, limb, stick, write


# ---------------------------------------------------------------- brigands
def helm_pot():
    """Casque de fortune : marmite cabossée rivetée, sangle de cuir."""
    return (path("M-8.6,-27 Q-9.4,-38 .6,-40.2 Q10.6,-38 10.2,-27 Z", "#6e6a62", OL, 1.2)
            + path("M-9.6,-27.6 L11.2,-27.6 L10.6,-25.4 L-9,-25.4 Z", "#55524a", OL, .9)
            + path("M-6,-37 Q-2,-40 3,-39.4", "none", "#fff", .7, .45)
            + path("M2.4,-36 l2.6,1.6 M-4,-33 l1.8,2.4", "none", "#2a2824", .7, .6)
            + f'<circle cx="6.4" cy="-31.6" r=".8" fill="#9a968a" stroke="{OL}" stroke-width=".3"/>'
            + f'<circle cx="-4.6" cy="-31" r=".8" fill="#9a968a" stroke="{OL}" stroke-width=".3"/>'
            + path("M-8.6,-27 L-9,-21 M10,-27 L9.6,-20", "none", "#5a3e24", 1.2)
            + f'<ellipse cx="0.4" cy="-40.4" rx="3.4" ry="1.1" fill="#4a4741" stroke="{OL}" stroke-width=".6"/>')


def bandana_face():
    """Foulard noué sur le bas du visage (teinté), nœud qui pend derrière."""
    return (path("M-3.6,-25.4 Q1.6,-23 8.4,-25 L9.2,-21 Q4,-17.4 -2,-19.4 Q-4.6,-22 -3.6,-25.4 Z", W, OL, 1.0)
            + path("M-2,-23 Q3,-21 8,-23", "none", "#000", .6, .3)
            + path("M-3.4,-24 Q-8,-24.6 -9.8,-21.4 L-7.8,-18.8 L-5,-21 Z", W, OL, .8)
            + path("M-9.4,-21 l-2.6,3.6 M-8.4,-19.6 l-1.2,3.8", "none", OL, 1.4))


def hat_felt():
    """Chapeau de feutre à large bord, un peu avachi (teinté)."""
    return (path("M-12,-31.4 Q1,-35 13.4,-30.6 Q14,-28.6 11.6,-28 Q1,-31 -10.6,-28.4 Q-13.4,-28.6 -12,-31.4 Z", W, OL, 1.0)
            + path("M-7.4,-30.4 Q-8.4,-38.6 -1,-40.2 Q4,-41 7,-37.4 Q9,-34 8.6,-30.2 Q1,-33 -7.4,-30.4 Z", W, OL, 1.0)
            + path("M-7.2,-32.2 Q1,-34.8 8.6,-32.2", "none", "#000", 1.6, .35)
            + path("M-4,-38 Q0,-40 4,-38.6", "none", "#fff", .6, .4)
            + path("M5,-32.6 Q10,-40 14,-38 Q10,-38.6 7.4,-33.4 Z", "#b8a46a", OL, .6))


def torso_studded():
    """Justaucorps de cuir clouté (teinté par le cuir) posé sur le torse."""
    T = "M-12,10 L-13.5,-4 Q-13,-13 -6,-15.6 L6,-15.6 Q13,-13 13.5,-4 L12,10 Z"
    s = path("M-12,9 L-13.2,-4 Q-12.6,-12.6 -6,-15 L-2,-12 L2,-12 L6,-15 Q12.6,-12.6 13.2,-4 L11.8,9 Z", W, OL, 1.1)
    s += path("M-2,-12 L-1.4,9 M2,-12 L1.4,9", "none", "#000", .8, .4)
    s += path("M-12.4,-1 Q0,1.5 12.4,-1", "none", "#000", .7, .3)
    for y in (-10, -4, 2, 7):
        for x in (-9, -5.5, 5.5, 9):
            s += f'<circle cx="{x}" cy="{y}" r=".75" fill="#c8c0a0" stroke="{OL}" stroke-width=".3"/>'
    s += f'<path d="{T}" fill="url(#gShade)"/>'
    return s


def fur_collar():
    """Col et épaules de fourrure (brun fixe)."""
    fur = "#6a5238"
    tufts = "".join(f'<path d="M{x},{y} l-.9,2.6 l1.9,-1.2 z" fill="#3e2e1e"/>' for x, y in ((-13, -9), (-9, -13), (-4, -15.4), (3, -15.4), (8, -14), (12, -10), (14.4, -5)))
    return (path("M-15.4,-6 Q-15,-15.6 -6,-17.6 L6.6,-17.6 Q15,-16 16.6,-5.6 Q10,-10 4,-8.6 Q-4,-8 -15.4,-6 Z", fur, OL, 1.1)
            + path("M-12,-10 Q-6,-13 0,-11 M2,-11 Q8,-13 14,-9", "none", "#2a1e12", .8, .6)
            + tufts
            + path("M-6,-16.4 Q0,-14.2 6.4,-16.4", "none", "#fff", .6, .3))


# ---------------------------------------------------------------- orcs
def paint_orc(v):
    """Peintures de guerre de clan (non teintées)."""
    if v == 1:  # clan de la Main blanche : trois bandes blanches et paume
        return (path("M-2.6,-32 L3,-29.8 M-2.8,-29 L2.6,-26.8 M-2.4,-26 L2,-24.4", "none", "#efe8d4", 1.5, .95)
                + path("M-5.2,-24 Q-4,-21 -5.6,-18.6", "none", "#efe8d4", 1.2, .85))
    if v == 2:  # clan du Corbeau : moitié du visage bleu-noir, ligne d'ocre
        return (path("M-6,-34 Q-1,-35 3,-30 Q1,-24 -2,-19 Q-5,-20 -6.2,-27 Z", "#233048", None, 1, .8)
                + path("M3,-30.4 Q1.4,-25 -1.6,-19.6", "none", "#d8b04a", 1.0, .9))
    if v == 3:  # clan du Sang : empreinte de main rouge sur la joue
        return (path("M3.6,-23.4 q1.6,-1.2 3.4,-.4 q1,1 .6,2.6 q-.8,1.2 -2.4,1.2 q-2,-.4 -1.6,-3.4 Z", "#a02a20", None, 1, .9)
                + path("M4.4,-24 l-.4,-1.8 M5.6,-24.2 l.1,-2 M6.8,-23.8 l.6,-1.8", "none", "#a02a20", .8, .9)
                + path("M-2,-31 L3.4,-29.4", "none", "#a02a20", 1.2, .85))
    return ""


def orc_spikes():
    """Épaulière à pointes d'os et de fer."""
    return (path("M3.4,-16.4 Q11,-19.6 16,-12 Q15.4,-6.6 10.4,-6 Q9.2,-11.6 3.4,-14 Z", "#4a4f55", OL, 1.0)
            + path("M9,-18 L11.4,-27 L13.4,-17 Z", "#d8d0b8", OL, .8)
            + path("M13.6,-14.4 L21,-17 L15.4,-10.6 Z", "#d8d0b8", OL, .8)
            + path("M5.4,-15.4 L5,-22.4 L8,-16 Z", "#8a9096", OL, .7)
            + f'<circle cx="12.6" cy="-9.4" r=".9" fill="#9a8a5a" stroke="{OL}" stroke-width=".4"/>'
            + light("M5.6,-16.6 Q11,-18.6 15.2,-13", .5, .7))


def orc_hide():
    """Gilet de peau cousu à la va-vite (teinté), laçage de cuir."""
    return (path("M-12,9 L-13.4,-3 Q-12.8,-12.6 -6,-15 L-1,-9 L2,-9 L6.6,-15 Q12.8,-12.6 13.4,-3 L11.8,9 Z", W, OL, 1.1)
            + path("M0,-9 L0.2,8", "none", OL, .8)
            + path("M-1.6,-7 L1.8,-5.4 M-1.8,-3 L2,-1.4 M-1.8,1 L2,2.6 M-1.6,5 L1.8,6.4", "none", "#5a3e24", .8)
            + path("M-8,-8 q2,2 1,5 M7,-6 q-2,3 -.6,6 M-5,2 q2,1 1.4,4", "none", "#000", .6, .3)
            + f'<path d="M-12,9 L11.8,9" stroke="{OL}" stroke-width=".8"/>')


# ---------------------------------------------------------------- morts-vivants
def skel_plate():
    """Plastron rouillé (teinté de rouille) sur les côtes."""
    return (path("M-9.4,-14 Q-11.6,0 -8.6,9 Q0,12 9.4,8.6 Q11.2,0 10.2,-13.4 Q0,-17 -9.4,-14 Z", W, OL, 1.2)
            + path("M0,-15.6 L0,10", "none", "#000", .8, .4)
            + path("M-8,-8 Q0,-6 9,-8 M-9,-1 Q0,1 10,-1.6", "none", "#000", .8, .35)
            + path("M-5,-12 l1.6,3 M4,-4 l2.4,2 M-6,3 l2,2.4", "none", "#5a2a14", 1.2, .55)
            + f'<path d="M-9.4,-14 Q-11.6,0 -8.6,9 L-5,9 Q-7,0 -5.6,-14 Z" fill="#000" opacity=".16"/>'
            + light("M-7,-13.4 Q-9.4,-3 -7.4,6", .4, .6))


def skel_shroud():
    """Linceul à capuche (teinté) : le visage reste visible par l'ouverture."""
    return (f'<path fill-rule="evenodd" d="M-10,-12 Q-12.4,-28 -4,-37 Q0,-42 5.4,-39.4 Q11.6,-36 11,-28 Q12.4,-20 10.4,-12 Q2,-8 -10,-12 Z '
            f'M8.8,-27.6 a5.2,5.8 0 1,0 -10.4,0 a5.2,5.8 0 1,0 10.4,0 Z" fill="{W}" stroke="{OL}" stroke-width="1.1"/>'
            + path("M-8,-26 Q-5,-25 -3,-31 M-9,-18 Q-5,-17 -3.6,-21", "none", OL, .6, .5)
            + path("M-3,-11 Q3,-9 9.4,-12.4", "none", "#000", .8, .3)
            + path("M-1,-35 Q3,-38.4 8,-35", "none", "#fff", .6, .4)
            + path("M-9,-10 l-1,4 l2,-1.4 l1,3 l1.6,-3 M4,-8.4 l.6,3.4 l1.8,-2.4", "none", OL, .7, .8))


def skel_crown():
    """Couronne rouillée aux pointes cassées (couleur fixe)."""
    return (path("M-5.8,-34.4 Q1,-37 8,-34.6 L8,-31.8 Q1,-34.6 -5.8,-32 Z", "#7a6238", OL, 1.0)
            + path("M-5.4,-35 L-4.4,-40.4 L-2.4,-36.2 L0,-41.6 L2.2,-36.4 L4.6,-39.4 L6,-35.4 L7.6,-36 L7.4,-34.4 Q1,-37 -5.6,-34.6 Z", "#8a7040", OL, .8)
            + f'<circle cx="0" cy="-33.2" r=".9" fill="#6a1a1a" stroke="{OL}" stroke-width=".4"/>'
            + path("M-4,-35.4 Q0,-36.4 5,-35.6", "none", "#fff", .5, .4))


def skel_chain():
    """Mailles en lambeaux sur les côtes (teinté de rouille)."""
    from gen_sprites import rings
    return (path("M-9.4,-14 L10.4,-13.4 L9,-3 L5.4,-1 L3,-6 L-.4,-.6 L-3,-5 L-7.6,0 L-9,-6 Z", W, OL, 1.0)
            + f'<g opacity=".7"><path d="{rings(-9, 10, -13, -1)}" stroke="#23272c" stroke-width=".45" fill="none"/></g>'
            + path("M-9,-6 L-10,-1", "none", OL, .8))


# ---------------------------------------------------------------- équipement dans le dos
def back_sword():
    return (path("M-19,12 L-8,-21", "none", OL, 4.2)
            + path("M-19,12 L-8,-21", "none", "#4a3220", 2.6)
            + path("M-18.4,11 L-8.4,-19", "none", "#fff", .5, .35)
            + path("M-11.4,-19.6 L-4.2,-23", "none", OL, 3.2)
            + path("M-11.4,-19.6 L-4.2,-23", "none", "#8a9096", 1.8)
            + stick(-8.6, -20.6, -7.4, -26.4, "#5a3a1e", 2.0)
            + f'<circle cx="-7.1" cy="-27.2" r="1.4" fill="#8a9096" stroke="{OL}" stroke-width=".6"/>')


def back_axe():
    return (stick(-19, 12, -8, -24, "#7a5230", 2.4)
            + f'<path d="M-9,-28 L-1,-24 Q1,-17 -6,-15 L-8.4,-20 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1" stroke-linejoin="round"/>'
            + path("M-1.6,-23.4 Q-.4,-18 -5.4,-16.4", "none", "#f2f4f6", .8, .7))


def back_club():
    return (f'<path d="M-20,12 L-17,13 L-8,-17 Q-9,-24.6 -14.2,-21.6 Z" fill="url(#gWood)" stroke="{OL}" stroke-width="1.1" stroke-linejoin="round"/>'
            + f'<circle cx="-12" cy="-18" r=".8" fill="{OL}"/><circle cx="-10.6" cy="-21.4" r=".7" fill="{OL}"/>')


def back_spear():
    return (stick(-23, 16, -6, -46, "#7a5230", 2.2)
            + f'<path d="M-6,-46 L-3,-50 L-4.6,-58.4 L-8.6,-50 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1" stroke-linejoin="round"/>'
            + path("M-5.2,-49 L-4.8,-55.4", "none", "#fff", .6, .6))


def back_bow():
    return (f'<path d="M-24,-26 Q-12,-6 -22,16" fill="none" stroke="{OL}" stroke-width="4.2" stroke-linecap="round"/>'
            + '<path d="M-24,-26 Q-12,-6 -22,16" fill="none" stroke="url(#gWood)" stroke-width="2.4" stroke-linecap="round"/>'
            + '<path d="M-24,-26 L-22,16" stroke="#d8cfb8" stroke-width=".5"/>')


def back_xbow():
    return (f'<path d="M-24,-20 L-8,-8 L-8,-5 L-24,-16 Z" fill="url(#gWood)" stroke="{OL}" stroke-width="1" stroke-linejoin="round"/>'
            + f'<path d="M-22,-26 Q-27,-12 -17,-4" fill="none" stroke="{OL}" stroke-width="3.8" stroke-linecap="round"/>'
            + '<path d="M-22,-26 Q-27,-12 -17,-4" fill="none" stroke="url(#gWood)" stroke-width="2.2" stroke-linecap="round"/>')


def back_shield():
    cx, cy, r = -17, -3, 10.4
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#8a6a3a" stroke="{OL}" stroke-width="1.2"/>'
            + f'<circle cx="{cx}" cy="{cy}" r="{r - 1.4}" fill="none" stroke="#5a3e1e" stroke-width="1.6"/>'
            + path(f"M{cx - r * .9},{cy - r * .2} L{cx + r * .9},{cy - r * .25} M{cx - r * .2},{cy - r * .9} L{cx - r * .24},{cy + r * .9}", "none", "#000", .6, .3)
            + f'<circle cx="{cx}" cy="{cy}" r="2.6" fill="url(#gSteel)" stroke="{OL}" stroke-width=".8"/>'
            + f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#gShield)"/>')


def quiver_bolts():
    """Étui à carreaux de la ceinture, côté dos."""
    return (f'<path d="M-15.4,-12 L-9.4,-13.6 L-7.4,4 L-13,5.2 Z" fill="#5a4026" stroke="{OL}" stroke-width="1"/>'
            + path("M-14.4,-8 L-9,-9.4 M-13.6,-2 L-8.4,-3.4", "none", "#2a1a0e", .6, .6)
            + '<path d="M-14,-12.4 L-14.6,-17 M-12.2,-13 L-12.4,-17.6 M-10.4,-13.4 L-10,-17.2" stroke="#d8cfb8" stroke-width="1.5" stroke-linecap="round"/>'
            + path("M-14.6,-17 l-.8,-1 M-12.4,-17.6 l-.6,-1.2 M-10,-17.2 l-.2,-1.4", "none", "#a03a2a", 1.0)
            + path("M-8.4,-12 L8,2", "none", OL, 1.5) + path("M-8.4,-12 L8,2", "none", "#5a4026", .8))


# ---------------------------------------------------------------- étendard
def banner_pole():
    return (stick(-17, 18, -17, -56, "#6a4426", 2.0)
            + f'<circle cx="-17" cy="-57" r="1.9" fill="#c9a24a" stroke="{OL}" stroke-width=".6"/>'
            + path("M-17.6,-52 L-16.4,-52 M-17.6,-14 L-16.4,-14", "none", OL, .6, .6))


FLAG = "M-18,-54 L-35,-52.4 L-31.6,-47 L-35,-41.6 L-18,-40 Z"


def banner_flag():
    """Drap de l'étendard (teinté par la couleur principale de la bannière)."""
    return (path(FLAG, W, OL, 1.0)
            + path("M-22,-53.4 Q-24,-47 -22,-40.4 M-28,-52.8 Q-30,-47 -28,-41", "none", "#000", .6, .22)
            + shade("M-18,-47 L-35,-46.6 L-35,-41.6 L-18,-40 Z", .1))


def banner_flag_trim():
    """Liseré et chevron du drap (teinté par la couleur secondaire)."""
    return (path("M-18,-54 L-35,-52.4 M-18,-40 L-35,-41.6", "none", W, 1.4, .95)
            + path("M-21,-51 L-27,-47 L-21,-43", "none", W, 1.5, .9))


# ---------------------------------------------------------------- pièces d'armure
def armor_gorget():
    return (path("M-7.2,-17 Q0,-11 8,-17 L7.4,-13.4 Q0,-8 -6.4,-13.4 Z", "url(#gSteel)", OL, .9)
            + path("M-5,-14 Q0,-10.4 6,-14", "none", "#5d6268", .6)
            + light("M-6,-16.4 Q0,-11.8 7,-16.4", .5, .6))


def armor_pauldron_off():
    """Épaulière gauche (côté dos) : brigandine rivetée."""
    return (path("M-4,-16 Q-12,-19.4 -16.4,-11 Q-15.8,-5.6 -10.6,-5 Q-9.6,-11.4 -4,-14 Z", "#6b3126", OL, 1.0)
            + path("M-6.5,-14.5 Q-12,-15.6 -14.8,-10.6 M-8,-12 Q-11,-12.5 -13.4,-9", "none", "#2a120e", .6, .7)
            + f'<circle cx="-13.4" cy="-11.2" r=".9" fill="#d9c9a0" stroke="{OL}" stroke-width=".3"/>'
            + f'<circle cx="-9.2" cy="-14.6" r=".9" fill="#d9c9a0" stroke="{OL}" stroke-width=".3"/>')


def armor_aventail():
    """Camail de mailles tombant du casque sur le cou."""
    from gen_sprites import rings
    p = "M-8.4,-22 Q-9.6,-15.6 -4.4,-12.4 L6.4,-12.4 Q10.4,-15.6 10.6,-22 L8.4,-20.4 Q0,-16.4 -6.4,-20.4 Z"
    return (path(p, "url(#gSteel)", OL, 1.0)
            + f'<clipPath id="cav"><path d="{p}"/></clipPath><g clip-path="url(#cav)"><path d="{rings(-10, 11, -22, -12)}" stroke="#23272c" stroke-width=".4" fill="none" opacity=".7"/></g>')


def armor_knees():
    """Genouillères d'acier."""
    one = lambda x: (f'<ellipse cx="{x}" cy="12.2" rx="3.4" ry="2.6" fill="url(#gSteel)" stroke="{OL}" stroke-width=".9"/>'
                     + path(f"M{x - 2},11.4 Q{x},10.4 {x + 2},11.4", "none", "#fff", .5, .6))
    return one(-4.2) + one(5.8)


def main_vari():
    for name, fn in (("helm_pot", helm_pot), ("bandana_face", bandana_face), ("hat_felt", hat_felt),
                     ("torso_studded", torso_studded), ("fur_collar", fur_collar),
                     ("orc_spikes", orc_spikes), ("orc_hide", orc_hide),
                     ("skel_plate", skel_plate), ("skel_shroud", skel_shroud), ("skel_crown", skel_crown), ("skel_chain", skel_chain),
                     ("back_sword", back_sword), ("back_axe", back_axe), ("back_club", back_club), ("back_spear", back_spear),
                     ("back_bow", back_bow), ("back_xbow", back_xbow), ("back_shield", back_shield), ("quiver_bolts", quiver_bolts),
                     ("banner_pole", banner_pole), ("banner_flag", banner_flag), ("banner_flag_trim", banner_flag_trim),
                     ("armor_gorget", armor_gorget), ("armor_pauldron_off", armor_pauldron_off),
                     ("armor_aventail", armor_aventail), ("armor_knees", armor_knees)):
        write(name, fn())
    for v in (1, 2, 3):
        write(f"paint_orc_{v}", paint_orc(v))
