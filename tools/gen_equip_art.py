#!/usr/bin/env python3
"""Art original de la vague « contenu d'équipement » : calques de figurine (assets/sprites/) et icônes d'objets
(assets/icons_items/ + assets/icons/), pour les armes, casques et armures ajoutés dans Data.WPN / HEAD / BODY et les armes à histoire.

Aucune ressource externe : tout est dessiné ici (licence du projet). Appelé par tools/gen_sprites.py et tools/gen_item_icons.py,
ou seul :  py tools/gen_equip_art.py   puis   godot --headless --import
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS_ITEMS = os.path.join(ROOT, "assets", "icons_items")
ICONS_OLD = os.path.join(ROOT, "assets", "icons")

# armes ordinaires ajoutées et leur main (x, y) sur la figurine ; les armes à histoire empruntent le calque de leur modèle (Data.UNIQUES.look)
WEAPON_HANDS = {"dague": (14.2, -1), "epee_courte": (14.5, -0.5), "rapiere": (14.4, -0.5), "hache_bataille": (13.6, -1),
                "marteau_guerre": (14.3, -1), "baton_ferre": (13.0, -1), "pique": (13.4, -1), "fronde": (14.0, -1),
                "arbalete_legere": (16.5, -5), "arc_long": (20.5, -8)}
HEADS = ["cagoule_cuir", "barbute", "heaume_crete", "casque_orque", "casque_rouille"]
BODIES = ["cuir_cloute", "haubert_surcot", "cuirasse_peaux", "plastron_orque", "cotte_rouillee"]
UNIQUE_LOOKS = {"u_dague_veuve": "dague", "u_marteau_forgeron": "marteau_guerre", "u_hache_aurore": "hache_bataille",
                "u_arc_mirelune": "arc_long", "u_pique_gardien": "pique"}


# ====================================================================== calques de figurine
def weapon_layer(w, g):
    OL, path, stick, light = g.OL, g.path, g.stick, g.light
    if w == "dague":
        return (stick(13.3, 4, 14.4, -2, "#5a3a1e", 1.6) + f'<circle cx="13.1" cy="5.5" r="1.7" fill="url(#gSteel)" stroke="{OL}" stroke-width=".7"/>'
                + f'<path d="M13.9,-3.2 L15.9,-2.8 L19.8,-21.4 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width=".9" stroke-linejoin="round"/>'
                + path("M14.8,-4 L19,-19.6", "none", "#fff", .5, .6) + stick(11.8, -4.2, 17.6, -2.4, "#8a9096", 1.7))
    if w == "epee_courte":
        return (stick(13.3, 4, 14.6, -2, "#5a3a1e", 1.7) + f'<circle cx="13.2" cy="5.6" r="1.9" fill="url(#gSteel)" stroke="{OL}" stroke-width=".8"/>'
                + f'<path d="M13.5,-3.9 L16.5,-3.2 L21.6,-28.5 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1" stroke-linejoin="round"/>'
                + path("M15,-4.4 L20.8,-26", "none", "#6d737a", .7) + path("M14.2,-5 L20.6,-26.6", "none", "#fff", .5, .6)
                + stick(10.6, -4.6, 19.4, -2.2, "#8a9096", 1.9))
    if w == "rapiere":
        return (stick(13.3, 4, 14.5, -1.4, "#4a2e1a", 1.4) + f'<circle cx="13.2" cy="5.4" r="1.6" fill="#9a8a5a" stroke="{OL}" stroke-width=".7"/>'
                + f'<path d="M14.1,-3.8 L15.5,-3.4 L25,-42 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width=".9" stroke-linejoin="round"/>'
                + path("M14.9,-4.4 L24.4,-40", "none", "#fff", .5, .6)
                + f'<path d="M10.2,-5.6 Q14,-0.4 19.2,-3.4 L18,-5.4 Q14.4,-3.6 11.6,-6.8 Z" fill="#9a8a5a" stroke="{OL}" stroke-width=".8" stroke-linejoin="round"/>'
                + path("M11,-3.4 Q12.4,1.2 15.4,1.8", "none", "#9a8a5a", 1.0) + path("M11,-3.4 Q12.4,1.2 15.4,1.8", "none", OL, .3))
    if w == "hache_bataille":
        return (stick(10.5, 11, 21, -31, "#7a5230", 2.6) + path("M13.2,1.5 L14.4,2 M16,-5 L17.2,-4.5 M18.4,-14 L19.6,-13.5", "none", OL, .6, .6)
                + f'<circle cx="10.5" cy="11.2" r="1.4" fill="#5a3a1e" stroke="{OL}" stroke-width=".6"/>'
                + f'<path d="M19.4,-27.5 L26.6,-37 Q38,-26.4 30,-12.4 L21.4,-19.4 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1.1" stroke-linejoin="round"/>'
                + f'<path d="M19.6,-28.5 L13.6,-35.4 Q8.4,-25 15.6,-16.4 L20.4,-20.6 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1" stroke-linejoin="round"/>'
                + f'<path d="M20.2,-30.6 L21.8,-41 L23.4,-31 Z" fill="#8a9096" stroke="{OL}" stroke-width=".8" stroke-linejoin="round"/>'
                + path("M27.2,-35 Q35.8,-26 29.6,-14.4", "none", "#f2f4f6", .9, .75) + path("M14,-33 Q10.4,-25 15.8,-18", "none", "#f2f4f6", .6, .5)
                + path("M21.6,-21.6 L24.6,-18.4 M20.6,-24 L24.6,-26", "none", "#2a2e33", .5, .6))
    if w == "marteau_guerre":
        return (stick(12, 8, 19.6, -19, "#5a3a1e", 2.3) + path("M13.6,1.5 l1.3,.5 M15.6,-5 l1.3,.5", "none", OL, .6, .6)
                + f'<g transform="rotate(-24 20 -22)"><rect x="13.6" y="-27.2" width="8" height="10.4" rx=".8" fill="url(#gSteel)" stroke="{OL}" stroke-width="1"/>'
                + f'<path d="M21.6,-26 L31,-22 L21.6,-18.6 Z" fill="#6a7076" stroke="{OL}" stroke-width=".9" stroke-linejoin="round"/>'
                + f'<rect x="12.4" y="-25.8" width="2.2" height="7.6" fill="#8a9096" stroke="{OL}" stroke-width=".6"/></g>'
                + path("M15.6,-26.4 L20.2,-27.6", "none", "#fff", .6, .6))
    if w == "baton_ferre":
        return (stick(8, 13, 22.4, -42, "#8a6238", 2.1) + path("M10,6 l1.2,.5 M14,-8 l1.2,.5 M18,-22 l1.2,.5", "none", OL, .5, .6)
                + f'<path d="M21.2,-40 L24.2,-39 L23.4,-48 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width=".9" stroke-linejoin="round"/>'
                + "".join(f'<circle cx="{x}" cy="{y}" r="1.9" fill="#6a7076" stroke="{OL}" stroke-width=".7"/>' for x, y in ((20.6, -36), (14.6, -13), (9, 10)))
                + f'<path d="M7.2,14 L9.6,14.6 L8.6,17 Z" fill="#6a7076" stroke="{OL}" stroke-width=".6"/>')
    if w == "pique":
        return (stick(8, 14, 24, -48, "#7a5230", 2.2) + path("M12,1 L11.2,-2 M16,-14 L15.2,-17 M20,-30 L19.2,-33", "none", OL, .6, .6)
                + f'<rect x="21.8" y="-50.2" width="4.6" height="3" rx=".7" fill="#6a7076" stroke="{OL}" stroke-width=".6" transform="rotate(-14 24 -49)"/>'
                + f'<path d="M24,-50 L27.6,-55 L25.4,-63.4 L21.6,-55 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1" stroke-linejoin="round"/>'
                + path("M25,-52 L25.4,-60.4", "none", "#fff", .6, .6)
                + f'<path d="M20.4,-46.4 L18.4,-43.4 M27.2,-48.8 L29.4,-46.4" stroke="{OL}" stroke-width="1.3" stroke-linecap="round"/>')
    if w == "fronde":
        return (f'<path d="M14.4,-1.4 Q16,-14 23,-26.6 M14.4,-1.4 Q19,-14 24.6,-24.6" fill="none" stroke="{OL}" stroke-width="1.7" stroke-linecap="round"/>'
                + '<path d="M14.4,-1.4 Q16,-14 23,-26.6 M14.4,-1.4 Q19,-14 24.6,-24.6" fill="none" stroke="#a88a58" stroke-width=".8" stroke-linecap="round"/>'
                + f'<path d="M21.4,-28.4 Q25.6,-30 27,-25.4 Q24.6,-22.2 21.4,-24 Z" fill="#6a4426" stroke="{OL}" stroke-width=".9" stroke-linejoin="round"/>'
                + f'<circle cx="24.4" cy="-26" r="1.7" fill="#9aa0a6" stroke="{OL}" stroke-width=".6"/>'
                + path("M30,-34 Q34,-26 31,-18", "none", "#fff", .6, .3))
    if w == "arbalete_legere":
        return (f'<path d="M12,-6.4 L29,-5.4 L29,-3.2 L12,-3.6 Z" fill="url(#gWood)" stroke="{OL}" stroke-width="1" stroke-linejoin="round"/>'
                + f'<path d="M24,-19 Q32.4,-4.4 24,10" fill="none" stroke="{OL}" stroke-width="4" stroke-linecap="round"/>'
                + '<path d="M24,-19 Q32.4,-4.4 24,10" fill="none" stroke="url(#gWood)" stroke-width="2.3" stroke-linecap="round"/>'
                + '<path d="M24,-19 L19.6,-4.6 L24,10" fill="none" stroke="#d8cfb8" stroke-width=".6"/>'
                + f'<rect x="20" y="-6.4" width="6" height="3" rx=".7" fill="#6a7076" stroke="{OL}" stroke-width=".7"/>'
                + path("M13,-5.8 L28,-4.8", "none", "#fff", .5, .35)
                + f'<path d="M19.6,-4.6 L31,-4.6" stroke="{OL}" stroke-width="1.3"/><path d="M30,-5.8 L33,-4.6 L30,-3.4 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width=".6"/>')
    if w == "arc_long":
        return (f'<path d="M17,-53 Q35,-17 17,18" fill="none" stroke="{OL}" stroke-width="4.6"/>'
                + '<path d="M17,-53 Q35,-17 17,18" fill="none" stroke="url(#gWood)" stroke-width="2.8"/>'
                + path("M18,-49 Q32.6,-17 18,15", "none", "#fff", .5, .35) + '<path d="M17,-53 L17,18" stroke="#d8cfb8" stroke-width=".6"/>'
                + path("M19.8,-12 Q21.8,-8 19.8,-3.4", "#3a2818", OL, .5)
                + f'<circle cx="17" cy="-53.4" r="1" fill="#d8cfb8" stroke="{OL}" stroke-width=".4"/><circle cx="17" cy="18.4" r="1" fill="#d8cfb8" stroke="{OL}" stroke-width=".4"/>')
    raise KeyError(w)


def _rust_gradient():
    return ('<defs><linearGradient id="gRust" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#b98a62"/><stop offset=".5" stop-color="#8a5a3a"/>'
            '<stop offset="1" stop-color="#4a2e1c"/></linearGradient></defs>')


def helm_layer(k, g):
    OL, path, light, shade = g.OL, g.path, g.light, g.shade
    if k == "barbute":
        return (f'<path d="M-8.8,-14.4 L-9.2,-31 Q-8.8,-39.6 1,-40.4 Q10.6,-39.6 10.8,-31 L10.4,-14.4 Q8.2,-11.2 4.6,-12.4 L1,-15 L-3,-12.4 Q-7,-11.2 -8.8,-14.4 Z" fill="url(#gSteel)" stroke="{OL}" stroke-width="1.3" stroke-linejoin="round"/>'
                + '<path d="M-1,-33.4 L10.4,-33.4 L10.4,-29.6 L6.4,-29.6 L6.4,-18.4 L2.4,-18.4 L2.4,-29.6 L-1,-29.6 Z" fill="#0d0907"/>'
                + path("M1,-40.2 L1,-33.6", "none", "#5d6268", .8, .7) + path("M-9,-31 Q1,-34 10.7,-31", "none", "#5d6268", 1.1)
                + path("M9.4,-37.6 L10,-15.4", "none", "#f0f2f4", .9, .5)
                + "".join(f'<circle cx="{x}" cy="{y}" r=".6" fill="#d6d9dc" stroke="{OL}" stroke-width=".25"/>' for x, y in ((-6.6, -34), (-6.6, -26), (-6.6, -19)))
                + shade("M-8.7,-31 L-9.2,-31 L-8.8,-14.4 Q-4,-13 -3,-14.4 Q-4.6,-24 -4.2,-31 Z", .2))
    if k == "heaume_crete":
        base = g.HELMETS["heaume"]
        crest = (f'<path d="M-8,-38 Q-4,-56 12.4,-41 L10.6,-37.4 Q3,-46 -4.6,-37 Z" fill="#8a2a22" stroke="{OL}" stroke-width="1" stroke-linejoin="round"/>'
                 + path("M-5,-41 Q2,-52 10,-41", "none", "#d9584a", .8, .6) + path("M-1,-47 L-1,-38 M3,-49 L3,-38.4 M7,-47 L7,-39", "none", "#4a120e", .5, .5)
                 + f'<rect x="-9" y="-38" width="21" height="2.4" rx=".8" fill="#9a8a5a" stroke="{OL}" stroke-width=".6"/>')
        return base + crest
    if k == "casque_orque":
        return (f'<path d="M-8.4,-26.5 Q-9,-38 1,-41.4 Q11.4,-38.4 11,-26.5 Z" fill="#7a6e60" stroke="{OL}" stroke-width="1.2"/>'
                + f'<path d="M-6.4,-36 Q-12.4,-40 -12.4,-49 Q-7,-44 -3,-38.4 Z" fill="#d8cfae" stroke="{OL}" stroke-width=".9" stroke-linejoin="round"/>'
                + f'<path d="M7,-38.6 Q14.4,-41 15.4,-50 Q9.4,-46 4.6,-39.4 Z" fill="#d8cfae" stroke="{OL}" stroke-width=".9" stroke-linejoin="round"/>'
                + f'<rect x="-9" y="-29.4" width="20.4" height="3.2" fill="#4a3a2a" stroke="{OL}" stroke-width=".8"/>'
                + "".join(f'<circle cx="{x}" cy="-27.8" r=".65" fill="#c9c0a0" stroke="{OL}" stroke-width=".25"/>' for x in (-6.5, -2.5, 1.5, 5.5, 9.4))
                + f'<path d="M7.4,-27.5 L10.8,-27.5 L10.2,-18.4 Q8.8,-17.4 7.6,-18.4 Z" fill="#7a6e60" stroke="{OL}" stroke-width=".9"/>'
                + path("M-8.4,-26.5 Q-9.5,-23 -8.2,-19.4 L-6,-20.4 Q-6.4,-23.6 -6,-26.5 Z", "#5a5044", OL, .7)
                + path("M2,-39.6 Q6.4,-37.6 8.6,-31", "none", "#fff", .8, .45) + path("M-5,-34 L-2,-31 M3,-35 L5,-32", "none", "#2a2218", .5, .6))
    if k == "cagoule_cuir":
        s = g.HELMETS["capuchon"].replace('fill="#ffffff"', 'fill="#6e4e30"')
        studs = "".join(f'<circle cx="{x}" cy="{y}" r=".7" fill="#d6cfae" stroke="{OL}" stroke-width=".25"/>' for x, y in ((-7.4, -30), (-5.4, -24), (-7, -18.6), (-1.6, -33.6), (-3.6, -16.8)))
        return s + studs
    if k == "casque_rouille":
        s = _rust_gradient() + g.HELMETS["casque"].replace("url(#gSteel)", "url(#gRust)").replace("#6a7076", "#7a4e32").replace("#d6d9dc", "#caa27a")
        marks = (path("M-4,-37 L-2,-33 L-5,-30 L-3,-27", "none", "#2a1608", .8, .8) + '<ellipse cx="5.6" cy="-33.6" rx="2" ry="1.4" fill="#2a1608" opacity=".55"/>'
                 + '<ellipse cx="-5.4" cy="-30" rx="1.2" ry=".9" fill="#d9a05c" opacity=".7"/>')
        return s + marks
    raise KeyError(k)


def torso_layer(k, g):
    T, OL, W, path, light, shade, rings = g.T, g.OL, g.W, g.path, g.light, g.shade, g.rings
    s = ""
    if k == "cuir_cloute":
        s += f'<path d="{T}" fill="#6a4a2c"/>'
        s += path("M-8,-14 L-8.4,10 M-3.5,-15.6 L-3.8,10 M1,-15.6 L1,10 M5.5,-15.6 L5.8,10 M10,-13 L10.4,10", "none", "#3a2616", .5, .55)
        for y in (-11, -6, -1, 4):
            for x in (-9.5, -4.5, 0.5, 5.5, 10.5):
                s += f'<circle cx="{x}" cy="{y}" r=".85" fill="#d6cfae" stroke="{OL}" stroke-width=".3"/><circle cx="{x - .25}" cy="{y - .25}" r=".28" fill="#fff" opacity=".7"/>'
        s += path("M0,-15.6 L0,10", "none", "#2a1a0e", .9, .8)
        s += path("M-5,-15.6 Q0,-11 5,-15.6 L5,-13.4 Q0,-9 -5,-13.4 Z", "#4a3220", OL, .6)
        s += f'<rect x="-12.8" y="6.4" width="25.6" height="2.6" fill="#2e1e12" stroke="{OL}" stroke-width=".5"/><rect x="-1" y="6" width="3.6" height="3.4" fill="#9a8a5a" stroke="{OL}" stroke-width=".5"/>'
    elif k == "haubert_surcot":
        s += (f'<path d="{T}" fill="url(#gSteel)"/><clipPath id="ct2"><path d="{T}"/></clipPath>'
              f'<g clip-path="url(#ct2)"><path d="{rings(-14, 14, -15, 11)}" stroke="#23272c" stroke-width=".45" fill="none" opacity=".75"/>'
              '<path d="M-14,-3 L14,-3 L14,12 L-14,12 Z" fill="#2f4a6a"/>'
              '<path d="M-14,-3 L14,-3 L14,-1.4 L-14,-1.4 Z" fill="#d6b85a"/><path d="M-14,10.6 L14,10.6 L14,12 L-14,12 Z" fill="#d6b85a"/>'
              '<path d="M0,-3 L0,12" stroke="#d6b85a" stroke-width="1.6"/>'
              '<path d="M-6,3 l12,0 M0,-0.4 l0,8" stroke="#e8d28a" stroke-width=".7" opacity=".0"/></g>')
        s += path("M-6,-15.6 Q0,-10 6,-15.6", "#2a2e33", OL, .8, extra='opacity=".9"')
        s += f'<rect x="-12.8" y="-3.6" width="25.6" height="2.4" fill="#4a3220" stroke="{OL}" stroke-width=".5"/><rect x="-1" y="-4" width="3.6" height="3.2" fill="#d6b85a" stroke="{OL}" stroke-width=".5"/>'
        s += light("M-10,-12 Q-12,-6 -11.5,-4", .35, .7)
    elif k == "cuirasse_peaux":
        s += f'<path d="{T}" fill="#8a6a46"/>'
        s += path("M-12,-8 L-2,-10 L0,2 L-12,4 Z", "#6e5236", "#2a1a0e", .5, .9) + path("M2,-12 L12,-8 L11,3 L1,0 Z", "#a07c52", "#2a1a0e", .5, .9)
        s += path("M-1,-14 L-2,10 M-12,-8 L-2,-10 M2,-12 L12,-8", "none", "#3a2616", .5, .7)
        s += path("M-12.6,3 l3,2.4 l2.4,-2.4 l3,2.6 l2.6,-2.4 l3,2.6 l2.6,-2.4 l3,2.6 l2.4,-2.4 l3,2.4", "#d8c9a8", OL, .6)
        s += path("M-6.4,-15.6 L-4.4,-12 L-2.4,-14.6 L0,-11.4 L2.4,-14.6 L4.4,-12 L6.4,-15.6 Z", "#d8c9a8", OL, .6)
        s += f'<rect x="-12.8" y="4.4" width="25.6" height="1.8" fill="#4a3220" stroke="{OL}" stroke-width=".4"/>'
        s += path("M-10.4,-14 l-2,3 M10.6,-14 l2,3", "none", "#d8c9a8", 1.6)
    elif k == "plastron_orque":
        s += f'<path d="{T}" fill="#4c4f52"/>'
        for y in (-9, -2.4, 4.2):
            s += path(f"M-12.6,{y} Q0,{y + 1.6} 12.6,{y}", "none", "#1d1f21", .8, .9) + path(f"M-12,{y - 0.6} Q0,{y + 1} 12,{y - 0.6}", "none", "#9a9ea2", .35, .5)
        s += path("M0,-15.6 L0,10", "none", "#1d1f21", 1.2, .8)
        s += "".join(f'<circle cx="{x}" cy="{y}" r=".8" fill="#b8bcc0" stroke="{OL}" stroke-width=".3"/>' for x in (-9, -4, 4, 9) for y in (-12, -5.4, 1.2, 7.8))
        s += path("M-6,-15.6 Q0,-10.4 6,-15.6", "#2a2e33", OL, .8)
        s += path("M-13.4,-6 L-12,-14 M13.4,-6 L12,-14", "none", "#b8bcc0", .6, .6)
        s += f'<path d="M-13,-12 L-17.2,-19.4 L-9.4,-14.8 Z M13,-12 L17.4,-19.6 L9.6,-14.8 Z" fill="#6a6e72" stroke="{OL}" stroke-width=".8" stroke-linejoin="round"/>'
    elif k == "cotte_rouillee":
        s += (_rust_gradient() + f'<path d="{T}" fill="url(#gRust)"/><clipPath id="ct3"><path d="{T}"/></clipPath>'
              f'<g clip-path="url(#ct3)"><path d="{rings(-14, 14, -15, 11)}" stroke="#2a1608" stroke-width=".45" fill="none" opacity=".8"/>'
              '<path d="M-5,-2 L-1,3 L-6,6 Z M6,-7 L9,-1 L4,0 Z M-12,4 L-8,12 L-13,12 Z M2,6 L7,12 L0,12 Z" fill="#17110c" opacity=".85"/>'
              '<ellipse cx="-7" cy="-8" rx="3" ry="1.8" fill="#d9a05c" opacity=".35"/></g>')
        s += path("M-6,-15.6 Q0,-10 6,-15.6", "#3a2210", OL, .8, extra='opacity=".9"')
        s += f'<rect x="-12.8" y="2.5" width="25.6" height="2.6" fill="#2e1e12" stroke="{OL}" stroke-width=".5"/>'
        s += path("M-12,10 l1.6,3 l1.6,-3 l2,3.4 l1.6,-3.4 M5,10 l1.6,3.4 l1.6,-3 l1.6,3 l1.8,-3", "#5a3a22", OL, .5)
    else:
        raise KeyError(k)
    return (s + f'<path d="{T}" fill="url(#gShade)"/>' + f'<path d="{T}" fill="none" stroke="{OL}" stroke-width="1.3"/>')


def main_sprites():
    import gen_sprites as g
    for w, xy in WEAPON_HANDS.items():
        g.HANDS[w] = xy
        g.write("weapon_" + w, weapon_layer(w, g))
        base = "arc" if w == "arc_long" else ("arbalete" if w == "arbalete_legere" else w)
        g.write("arm_" + w, g.arm(base))
        g.write("hand_" + w, g.hand(*xy))
        g.write("skel_arm_" + w, g.skel_arm(base))
        g.write("skel_hand_" + w, g.skel_hand(*xy))
    for k in HEADS:
        g.write("helm_" + k, helm_layer(k, g))
    for k in BODIES:
        g.write("torso_" + k, torso_layer(k, g))
    print("calques d'équipement écrits :", len(WEAPON_HANDS) * 5 + len(HEADS) + len(BODIES))


# ====================================================================== icônes d'objets (512 x 512)
def rot(pts, ang, ox=0.0, oy=0.0, sc=1.0):
    a = math.radians(ang)
    c, s = math.cos(a), math.sin(a)
    return [(256 + ox + (x * c - y * s) * sc, 256 + oy + (x * s + y * c) * sc) for x, y in pts]


def poly(pts):
    return "M" + " L".join("%.1f %.1f" % p for p in pts) + " Z"


def polyc(pts):
    return poly([(x + 256, y + 256) for x, y in pts])


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def circ(cx, cy, r, n=22):
    return [(cx + r * math.cos(math.tau * i / n), cy + r * math.sin(math.tau * i / n)) for i in range(n)]


def arc(cx, cy, rx, ry, a0, a1, n=16):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def qb(p0, p1, p2, n=14):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / n for i in range(n + 1)]]


def ribbon(pts, w0, w1=None):
    """Bande d'épaisseur variable le long d'une courbe."""
    w1 = w0 if w1 is None else w1
    left, right = [], []
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L, dx / L
        w = (w0 + (w1 - w0) * i / max(1, n - 1)) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return left + right[::-1]


def weapon_shapes(w):
    """Formes (liste de polygones) d'une arme, orientées pointe vers le haut puis tournées de 45°."""
    if w == "dague":
        s = [[(0, -200), (30, -70), (26, 30), (-26, 30), (-30, -70)], rect(-72, 30, 72, 58), rect(-13, 58, 13, 150), circ(0, 172, 27)]
        return [rot(p, 45, sc=1.18) for p in s]
    if w == "epee_courte":
        s = [[(0, -230), (34, -140), (30, 20), (-30, 20), (-34, -140)], rect(-76, 20, 76, 48), rect(-13, 48, 13, 130), circ(0, 152, 26)]
        return [rot(p, 45, sc=1.1) for p in s]
    if w == "rapiere":
        s = [[(0, -270), (13, -30), (-13, -30)], [(-62, -30), (62, -30), (54, 14), (0, 40), (-54, 14)], rect(-9, 40, 9, 140), circ(0, 158, 20)]
        return [rot(p, 45, oy=10, sc=1.0) for p in s]
    if w == "hache_bataille":
        right = [(14, -200), (130, -230), (170, -130), (120, -30), (14, -70)]
        left = [(-14, -200), (-110, -222), (-140, -130), (-100, -40), (-14, -70)]
        s = [rect(-13, -210, 13, 260), right, left, [(-12, -205), (0, -265), (12, -205)], circ(0, 268, 20)]
        return [rot(p, 45, oy=-4, sc=0.92) for p in s]
    if w == "marteau_guerre":
        s = [rect(-13, -90, 13, 260), rect(-100, -190, 36, -90), [(36, -190), (160, -150), (36, -100)], rect(-120, -184, -100, -96), circ(0, 270, 20)]
        return [rot(p, 45, oy=-6, sc=0.95) for p in s]
    if w == "baton_ferre":
        s = [rect(-10, -230, 10, 230), [(-18, -228), (0, -300), (18, -228)], rect(-18, -140, 18, -104), rect(-18, 40, 18, 76), rect(-16, 214, 16, 258)]
        return [rot(p, 45, sc=0.82) for p in s]
    if w == "pique":
        s = [rect(-8, -130, 8, 270), [(0, -300), (34, -190), (0, -134), (-34, -190)], rect(-16, -140, 16, -112), rect(-40, -126, 40, -112)]
        return [rot(p, 45, oy=4, sc=0.84) for p in s]
    if w == "fronde":
        pouch = circ(0, 70, 52)
        cord_l = ribbon(qb((-46, 40), (-40, -80), (-4, -200)), 12)
        cord_r = ribbon(qb((46, 40), (40, -80), (4, -200)), 12)
        return [rot(p, 20, oy=10) for p in (pouch, cord_l, cord_r, circ(0, -210, 26), rect(-12, -330, 12, -220))]
    if w == "arbalete_legere":
        limbs = ribbon(qb((-190, -120), (0, -40), (190, -120)), 34, 26)
        return [rot(p, 0, oy=-20, sc=0.9) for p in (limbs, rect(-14, -110, 14, 220), rect(-34, 40, 34, 84), circ(0, 232, 14), [(0, -190), (14, -90), (-14, -90)], ribbon([(-180, -108), (0, 120), (180, -108)], 7))]
    if w == "arc_long":
        bow = ribbon(qb((-60, -250), (170, 0), (-60, 250)), 36, 36)
        string = rect(-66, -250, -52, 250)
        return [rot(p, 15) for p in (bow, string, rect(-30, -22, 30, 22))]
    raise KeyError(w)


def head_shapes(k):
    if k == "barbute":
        outer = [(-108, -30)] + arc(0, -30, 108, 130, 180, 360) + [(108, -30), (104, 100), (60, 150), (30, 124), (0, 140), (-30, 124), (-60, 150), (-104, 100)]
        hole = [(-74, -52), (74, -52), (74, -8), (28, -8), (28, 96), (-28, 96), (-28, -8), (-74, -8)]
        return [polyc(outer) + " " + polyc(hole)]
    if k == "heaume_crete":
        outer = [(-104, 120)] + [(-108, -20)] + arc(0, -20, 108, 128, 180, 360) + [(108, -20), (104, 120)]
        slit = rect(-66, -2, 66, 26)
        crest = ribbon(qb((-98, -88), (0, -330), (98, -88)), 50, 50)
        return [polyc(outer) + " " + polyc(slit), polyc(crest), polyc(rect(-108, -30, 108, -4))]
    if k == "casque_orque":
        dome = arc(0, 20, 112, 130, 180, 360) + [(112, 20), (112, 60), (-112, 60), (-112, 20)]
        horn_l = ribbon(qb((-98, -50), (-190, -80), (-180, -230)), 56, 12)
        horn_r = ribbon(qb((98, -50), (190, -80), (180, -230)), 56, 12)
        return [polyc(dome), polyc(horn_l), polyc(horn_r), polyc(rect(-16, 40, 16, 140))]
    if k == "cagoule_cuir":
        outer = [(0, -210), (66, -140), (118, -20), (112, 128), (-112, 128), (-118, -20), (-66, -140)]
        face = circ(8, 8, 58, 20)
        face = [(x, 8 + (y - 8) * 1.3) for x, y in face]
        return [polyc(outer) + " " + polyc(face)]
    if k == "casque_rouille":
        outer = arc(0, 20, 110, 130, 180, 360) + [(110, 20), (112, 70), (86, 56), (66, 84), (38, 54), (10, 90), (-18, 56), (-46, 86), (-72, 56), (-96, 82), (-112, 66)]
        slit = rect(-70, 10, 70, 30)
        crack = [(-30, -100), (-10, -60), (-34, -30), (-16, 0), (-4, -30), (-18, -62), (-14, -100)]
        return [polyc(outer) + " " + polyc(slit) + " " + polyc(crack), polyc(rect(-14, 30, 14, 120))]
    raise KeyError(k)


def _tunic(hem=130, jag=None):
    top = [(-66, -170), (-24, -194), (0, -166), (24, -194), (66, -170), (164, -112), (128, -20), (88, -56)]
    bottom = [(88, hem), (-88, hem)]
    if jag:
        bottom = jag
    return top + bottom + [(-88, -56), (-128, -20), (-164, -112)]


def body_shapes(k):
    if k == "cuir_cloute":
        holes = ""
        for y in (-100, -50, 0, 50):
            for x in (-56, 0, 56):
                holes += " " + polyc([(px + x, py + y) for px, py in circ(0, 0, 10, 10)])
        return [polyc(_tunic(140)) + holes]
    if k == "cuirasse_peaux":
        jag = []
        x = 88
        step = 22
        i = 0
        while x > -88:
            jag.append((x, 130 + (22 if i % 2 else 0)))
            x -= step
            i += 1
        jag.append((-88, 130))
        neck = [(-66, -170), (-40, -150), (-24, -194), (-8, -150), (0, -166), (8, -150), (24, -194), (40, -150), (66, -170), (164, -112), (128, -20), (88, -56)]
        s = neck + jag + [(-88, -56), (-128, -20), (-164, -112)]
        return [polyc(s)]
    if k == "plastron_orque":
        s = [(-80, -176), (-24, -196), (0, -170), (24, -196), (80, -176), (120, -120), (104, -20), (96, 140), (0, 160), (-96, 140), (-104, -20), (-120, -120)]
        spikes = [[(-120, -130), (-196, -236), (-84, -170)], [(120, -130), (196, -236), (84, -170)]]
        bands = rect(-100, -40, 100, -10)
        return [polyc(s), polyc(spikes[0]), polyc(spikes[1])]
    if k == "cotte_rouillee":
        jag = [(88, 120), (70, 160), (50, 128), (30, 170), (8, 132), (-12, 168), (-34, 128), (-54, 164), (-72, 126), (-88, 150)]
        tear = [(-30, -60), (10, -20), (-34, 14)]
        tear2 = [(40, -100), (70, -60), (34, -50)]
        return [polyc(_tunic(jag=jag)) + " " + polyc(tear) + " " + polyc(tear2), polyc(rect(-96, 0, 96, 22))]
    if k == "haubert_surcot":
        jag = [(88, 200), (14, 200), (0, 120), (-14, 200), (-88, 200)]
        return [polyc(_tunic(jag=jag))]
    raise KeyError(k)


def _wrap(paths, top, bottom, outline="#17100a", ow=24, under="", over=""):
    ps = "".join('<path fill-rule="evenodd" d="%s"/>' % d for d in paths)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs>' % (top, bottom) + under
            + '<g fill="%s" stroke="%s" stroke-width="%d" stroke-linejoin="round" stroke-linecap="round">%s</g>' % (outline, outline, ow, ps)
            + '<g fill="url(#g)">%s</g>' % ps + over + '</svg>')


def icon_paths(genre, key):
    base = UNIQUE_LOOKS.get(key, key)
    if genre == "weapon":
        return [poly(p) for p in weapon_shapes(base)]
    if genre == "head":
        return head_shapes(base)
    return body_shapes(base)


def main_icons(out_items=ICONS_ITEMS, out_old=ICONS_OLD):
    import gen_item_icons as gi
    n = 0
    os.makedirs(out_items, exist_ok=True)
    jobs = [("weapon", k) for k in WEAPON_HANDS] + [("head", k) for k in HEADS] + [("body", k) for k in BODIES]
    for genre, key in jobs:
        ps = icon_paths(genre, key)
        with open(os.path.join(out_items, "%s_%s.svg" % (genre, key)), "w", encoding="utf-8") as f:
            f.write(_wrap(ps, "#f3e2ad", "#c8a24c"))
        with open(os.path.join(out_old, key + ".svg"), "w", encoding="utf-8") as f:
            f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">%s</svg>' % "".join('<path fill="#d9ccaa" fill-rule="evenodd" d="%s"/>' % d for d in ps))
        n += 1
    for key, look in UNIQUE_LOOKS.items():
        ps = icon_paths("weapon", key)
        halo = '<g fill="none" stroke="#e8b93a" stroke-opacity="0.5" stroke-width="64" stroke-linejoin="round">%s</g>' % "".join('<path d="%s"/>' % d for d in ps)
        stars = gi.sparkle(426, 90, 72, "#fff0b8") + gi.sparkle(86, 426, 44, "#ffe08a")
        with open(os.path.join(out_items, "weapon_%s.svg" % key), "w", encoding="utf-8") as f:
            f.write(_wrap(ps, "#fff3bd", "#dc9d1e", outline="#2a1a05", ow=26, under=halo, over=stars))
        n += 1
    print("icônes d'équipement écrites :", n)
    return n


def main():
    main_sprites()
    main_icons()


if __name__ == "__main__":
    main()
